//! mube Pico W ファームウェアの土台。
//!
//! 現状: CYW43439 を起動し、WPA2 で WiFi に接続して DHCP で IP を取得したうえで、
//! TCP ポート 6000 を listen し、`mube_core::serve_connection` でロックコマンドを捌く。
//! SG90 サーボ（GP15 PWM + GP14 電源ゲート）への指令は `SERVO_CMD: Signal` 経由で
//! `servo_task` が受け取る。オンボード LED は接続中に点灯する
//!（Pico W の LED は GPIO ではなく CYW43 側にぶら下がっているため、
//! 制御にも WiFi チップの初期化が要る）。
//!
//! ロック状態は単一ソース `LOCK_STATE` に集約し、TCP コマンド・GP17 ボタン（トグル）・
//! 二色ステータス LED（GP16=赤=施錠 / GP18=黄緑=解錠）が同じ状態を参照する。
//! オンボード LED（CYW43）は TCP 接続状態の表示。ボタンは内部プルアップ（アクティブ Low）。
//!
//! ここから先（スマートロック本体）の積み残し:
//!   - 手回し後の状態再同期・省電力運用
//!
//! 注意: このコードは embassy の公式 examples（examples/rp の wifi 系）に倣っている。

#![no_std]
#![no_main]

mod config;
mod http;
mod servo;

use core::cell::Cell;

use config::{WIFI_PASSWORD, WIFI_SSID};
use cyw43::SpiBus;
use cyw43_pio::PioSpi;
use defmt::*;
use embassy_executor::Spawner;
use embassy_net::tcp::TcpSocket;
use embassy_net::{Config as NetConfig, StackResources};
use embassy_rp::bind_interrupts;
use embassy_rp::clocks::RoscRng;
use embassy_rp::dma::{Channel, InterruptHandler as DmaInterruptHandler};
use embassy_rp::gpio::{Input, Level, Output, Pull};
use embassy_rp::peripherals::{DMA_CH0, PIO0};
use embassy_rp::pio::{InterruptHandler, Pio};
use embassy_rp::pwm::{Config as PwmConfig, Pwm};
use embassy_sync::blocking_mutex::raw::CriticalSectionRawMutex;
use embassy_sync::blocking_mutex::Mutex as BlockingMutex;
use embassy_sync::signal::Signal;
use embassy_time::{Duration, Timer};
use servo::Servo;
use mube_core::serve::serve_connection;
use mube_core::{LockPort, LockState};
use static_cell::StaticCell;
use {defmt_rtt as _, panic_probe as _};

bind_interrupts!(struct Irqs {
    PIO0_IRQ_0 => InterruptHandler<PIO0>;
    DMA_IRQ_0 => DmaInterruptHandler<DMA_CH0>;
});

/// 遠隔ロック操作を受ける TCP ポート。
const LOCK_PORT: u16 = 6000;

/// 無通信で切断するまでの秒数。シングル接続サーバーでの占有を防ぐ。
const IDLE_TIMEOUT_SECS: u64 = 30;

/// サーボへの施錠/解錠指令。`apply_target` が叩く。
/// Signal は最新値のみ保持するため、指令が連続しても安全側（最新状態）へ収束する。
static SERVO_CMD: Signal<CriticalSectionRawMutex, LockState> = Signal::new();

/// 唯一の現在ロック状態。TCP STATUS とボタンのトグルが参照する単一ソース。
/// 起動時は安全側に施錠。
static LOCK_STATE: BlockingMutex<CriticalSectionRawMutex, Cell<LockState>> =
    BlockingMutex::new(Cell::new(LockState::Locked));

/// 目標状態を適用する: 現在状態を即時更新し、サーボタスクへ駆動指令を送る。
/// TCP コマンドもボタンも必ずこれを通すことで状態が一意になる。
fn apply_target(target: LockState) {
    LOCK_STATE.lock(|c| c.set(target));
    SERVO_CMD.signal(target);
}

/// firmware 側 `LockPort`: 現在状態は LOCK_STATE、適用は apply_target。
struct FwLockPort;
impl LockPort for FwLockPort {
    fn current(&self) -> LockState {
        LOCK_STATE.lock(|c| c.get())
    }
    fn apply(&self, target: LockState) {
        apply_target(target);
    }
}

/// 二色ステータス LED を状態に合わせて点灯する（施錠=赤 / 解錠=黄緑、同時点灯はしない）。
fn set_status_led(led_r: &mut Output<'static>, led_g: &mut Output<'static>, state: LockState) {
    match state {
        LockState::Locked => {
            led_r.set_high();
            led_g.set_low();
        }
        LockState::Unlocked => {
            led_r.set_low();
            led_g.set_high();
        }
    }
}

/// 指令を待ってサーボをワンショット駆動し、二色 LED を最新状態に更新し続けるタスク。
#[embassy_executor::task]
async fn servo_task(
    mut servo: Servo<'static>,
    mut led_r: Output<'static>,
    mut led_g: Output<'static>,
) -> ! {
    // 起動時は安全側 Locked を表示（LOCK_STATE 初期値に追従）。
    set_status_led(&mut led_r, &mut led_g, LOCK_STATE.lock(|c| c.get()));
    loop {
        let state = SERVO_CMD.wait().await;
        info!("servo: move_to {}", state);
        servo.move_to(state).await;
        set_status_led(&mut led_r, &mut led_g, state);
    }
}

/// GP17 のタクトスイッチ（内部プルアップ・アクティブ Low）を監視し、押下ごとにロックをトグルする。
/// 内部プルアップに依存（外付け抵抗なし＝ Issue #27 の方針）。20ms デバウンスでチャタを除く。
#[embassy_executor::task]
async fn button_task(mut btn: Input<'static>) -> ! {
    loop {
        btn.wait_for_falling_edge().await; // 押下（High→Low）
        Timer::after(Duration::from_millis(20)).await; // デバウンス
        if btn.is_low() {
            let target = LOCK_STATE.lock(|c| c.get()).toggled();
            info!("button: toggle -> {}", target);
            apply_target(target);
        }
        btn.wait_for_high().await; // リリースまで待ち、押しっぱなしの連発を防ぐ
    }
}

/// CYW43 ドライバを回し続けるタスク。
#[embassy_executor::task]
async fn cyw43_task(
    runner: cyw43::Runner<'static, SpiBus<Output<'static>, PioSpi<'static, PIO0, 0>>>,
) -> ! {
    runner.run().await
}

/// ネットワークスタック（DHCP 等）を回し続けるタスク。
#[embassy_executor::task]
async fn net_task(mut runner: embassy_net::Runner<'static, cyw43::NetDriver<'static>>) -> ! {
    runner.run().await
}

#[embassy_executor::main]
async fn main(spawner: Spawner) {
    let p = embassy_rp::init(Default::default());

    // サーボ駆動: PWM 信号 = GP15（slice7 ch B）、電源ゲート = GP14（active-high）。
    let gate = Output::new(p.PIN_14, Level::Low);
    let servo_pwm = Pwm::new_output_b(p.PWM_SLICE7, p.PIN_15, PwmConfig::default());
    let servo = Servo::new(servo_pwm, gate);
    // 二色ステータス LED: 赤=GP16（施錠）, 黄緑=GP18（解錠）。コモンカソード、active-high。
    let led_r = Output::new(p.PIN_16, Level::Low);
    let led_g = Output::new(p.PIN_18, Level::Low);
    spawner.spawn(servo_task(servo, led_r, led_g).unwrap());
    // ボタン: GP17 内部プルアップ（アクティブ Low）。押下でロックをトグル。
    let button = Input::new(p.PIN_17, Pull::Up);
    spawner.spawn(button_task(button).unwrap());

    // CYW43 ファームウェアブロブ。cyw43-firmware/ を埋め込む（README の取得手順を参照）。
    // cyw43 v0.7.0 は 3 つ要る: firmware / nvram（基板設定, new へ）/ clm（国別規制, control.init へ）。
    // nvram を渡さない/取り違えると "waiting for HT clock" で起動が止まる。
    // aligned_bytes! マクロで A4 アライメントを付ける。
    let fw = cyw43::aligned_bytes!("../cyw43-firmware/43439A0.bin");
    let clm = cyw43::aligned_bytes!("../cyw43-firmware/43439A0_clm.bin");
    let nvram = cyw43::aligned_bytes!("../cyw43-firmware/nvram_rp2040.bin");

    // CYW43 との PIO-SPI 配線（Pico W 固定ピン）。
    let pwr = Output::new(p.PIN_23, Level::Low);
    let cs = Output::new(p.PIN_25, Level::High);
    let mut pio = Pio::new(p.PIO0, Irqs);
    let dma = Channel::new(p.DMA_CH0, Irqs);
    let spi = PioSpi::new(
        &mut pio.common,
        pio.sm0,
        cyw43_pio::DEFAULT_CLOCK_DIVIDER,
        pio.irq0,
        cs,
        p.PIN_24,
        p.PIN_29,
        dma,
    );

    static STATE: StaticCell<cyw43::State> = StaticCell::new();
    let state = STATE.init(cyw43::State::new());
    // cyw43 v0.7.0: new(state, pwr, spi, firmware, nvram)。CLM は起動後に control.init で読む。
    let (net_device, mut control, runner) = cyw43::new(state, pwr, spi, fw, nvram).await;
    spawner.spawn(cyw43_task(runner).unwrap());

    // CLM（国別規制データ）をロード。ランナーを spawn した後に行う必要がある。
    control.init(clm).await;

    control
        .set_power_management(cyw43::PowerManagementMode::PowerSave)
        .await;

    // ネットワークスタック（DHCPv4）。
    let net_config = NetConfig::dhcpv4(Default::default());
    let seed = RoscRng.next_u64();
    static RESOURCES: StaticCell<StackResources<5>> = StaticCell::new();
    let (stack, net_runner) = embassy_net::new(
        net_device,
        net_config,
        RESOURCES.init(StackResources::new()),
        seed,
    );
    spawner.spawn(net_task(net_runner).unwrap());

    // 認証が未設定（プレースホルダのまま）なら join は永久に失敗する。
    // ビルド時 env の渡し忘れを、パスワード誤り等と区別できるよう defmt に明示する。
    if !config::WIFI_CONFIGURED {
        warn!("WiFi 認証が未設定（プレースホルダ使用）。ビルド時に WIFI_SSID / WIFI_PASSWORD を渡すこと。このまま join は失敗し続けます。");
    }

    // WPA2 で接続。失敗したら少し待って再試行。
    loop {
        match control
            .join(WIFI_SSID, cyw43::JoinOptions::new(WIFI_PASSWORD.as_bytes()))
            .await
        {
            Ok(_) => break,
            Err(err) => {
                warn!("join failed ({:?}), retrying...", err);
                Timer::after(Duration::from_secs(2)).await;
            }
        }
    }
    info!("WiFi connected, waiting for DHCP...");

    stack.wait_config_up().await;
    if let Some(cfg) = stack.config_v4() {
        info!("DHCP up: IP = {}", cfg.address);
    }

    // 遠隔ロック操作: ポート LOCK_PORT を listen し、1 接続ずつ serve する。
    // 判断ロジックは mube_core::serve_connection（host テスト済み）。ここはアダプタ配線。
    let mut rx_buf = [0u8; 512];
    let mut tx_buf = [0u8; 512];
    let port = FwLockPort;

    loop {
        let mut socket = TcpSocket::new(stack, &mut rx_buf, &mut tx_buf);
        control.gpio_set(0, false).await; // 待受中: オンボード LED 消灯
        if let Err(e) = socket.accept(LOCK_PORT).await {
            warn!("accept failed: {:?}", e);
            continue;
        }
        info!("client connected on :{}", LOCK_PORT);
        control.gpio_set(0, true).await; // 接続中: オンボード LED 点灯
        socket.set_timeout(Some(Duration::from_secs(IDLE_TIMEOUT_SECS)));
        if let Err(e) = serve_connection(&mut socket, &port).await {
            warn!("serve error: {:?}", e);
        }
        info!("client disconnected");
    }
}

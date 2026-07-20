//! mube Pico W ファームウェアの土台。
//!
//! 現状: CYW43439 を起動し、WPA2 で WiFi に接続して DHCP で IP を取得したうえで、
//! picoserve で HTTP ポート 80 を listen し、埋め込み yew SPA と JSON API を配信する。
//! SG90 サーボ（GP15 PWM + GP14 電源ゲート）への指令は `SERVO_CMD: Signal` 経由で
//! `servo_task` が受け取る（Pico W の LED は GPIO ではなく CYW43 側にぶら下がっているため、
//! 制御にも WiFi チップの初期化が要る）。
//!
//! ロック状態は単一ソース `LOCK_STATE` に集約し、HTTP API・GP17 ボタン（トグル）・
//! 二色ステータス LED（GP16=赤=施錠 / GP18=黄緑=解錠）が同じ状態を参照する。
//! ボタンは内部プルアップ（アクティブ Low）。
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
use mube_core::LockState;
use static_cell::StaticCell;
use {defmt_rtt as _, panic_probe as _};

bind_interrupts!(struct Irqs {
    PIO0_IRQ_0 => InterruptHandler<PIO0>;
    DMA_IRQ_0 => DmaInterruptHandler<DMA_CH0>;
});

/// HTTP WebUI を配信するポート。
const HTTP_PORT: u16 = 80;

/// port 80 の HTTP 設定を 'static に固定して全 worker で共有する。
/// ルータ（`http::make_app()`）は `Router<impl PathRouter>` で具体型を名前で書けない
/// （stable Rust に type_alias_impl_trait が無い）ため StaticCell では共有せず、
/// 各 worker タスク内でローカルに構築する。ルータはハンドラ（クロージャ＝実質 ZST）と
/// `&'static` アセットだけを保持するので複製コストは無視できる。
static CONFIG: StaticCell<picoserve::Config> = StaticCell::new();

/// picoserve の worker（同時接続）数。各 worker が自前の TcpSocket とバッファを持つ。
const HTTP_WORKERS: usize = 2;

/// 無通信で切断するまでの秒数。1 クライアントによる占有を防ぐ。
const IDLE_TIMEOUT_SECS: u64 = 30;

/// サーボへの施錠/解錠指令。`apply_target` が叩く。
/// Signal は最新値のみ保持するため、指令が連続しても安全側（最新状態）へ収束する。
static SERVO_CMD: Signal<CriticalSectionRawMutex, LockState> = Signal::new();

/// 唯一の現在ロック状態。TCP STATUS とボタンのトグルが参照する単一ソース。
/// 起動時は安全側に施錠。
static LOCK_STATE: BlockingMutex<CriticalSectionRawMutex, Cell<LockState>> =
    BlockingMutex::new(Cell::new(LockState::Locked));

/// 目標状態を適用する: 現在状態を即時更新し、サーボタスクへ駆動指令を送る。
/// HTTP API もボタンも必ずこれを通すことで状態が一意になる。
pub(crate) fn apply_target(target: LockState) {
    LOCK_STATE.lock(|c| c.set(target));
    SERVO_CMD.signal(target);
}

/// http.rs から現在のロック状態を読むための口。
pub(crate) fn current_state() -> LockState {
    LOCK_STATE.lock(|c| c.get())
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

    // 接続表示はここでは常時消灯（状態は二色 LED が担う）。
    control.gpio_set(0, false).await;

    // HTTP WebUI: port 80 で SPA＋JSON API を配信する。設定だけ 'static 共有。
    let config = CONFIG.init(
        picoserve::Config::new(picoserve::Timeouts {
            start_read_request: Duration::from_secs(IDLE_TIMEOUT_SECS),
            persistent_start_read_request: Duration::from_secs(IDLE_TIMEOUT_SECS),
            read_request: Duration::from_secs(IDLE_TIMEOUT_SECS),
            write: Duration::from_secs(IDLE_TIMEOUT_SECS),
        })
        // 複数ソケットで捌くので keep-alive 可（1 クライアント占有を避けるための前提）。
        .keep_connection_alive(),
    );

    // worker を HTTP_WORKERS 本 spawn。各 worker が自前の TcpSocket＋バッファ＋ルータで port 80 を捌く。
    for id in 0..HTTP_WORKERS {
        spawner.spawn(http_worker(id, stack, config).unwrap());
    }
}

/// port 80 の HTTP を 1 本の worker として捌くタスク。pool_size 分だけ並列に立てる。
/// 各 worker が独立した受信/送信バッファ・HTTP バッファ・ルータを持つ（RAM を圧迫しないサイズ）。
#[embassy_executor::task(pool_size = HTTP_WORKERS)]
async fn http_worker(
    id: usize,
    stack: embassy_net::Stack<'static>,
    config: &'static picoserve::Config,
) {
    // ルータの具体型は名前で書けない（impl PathRouter）ため、ここでローカルに構築する。
    // `listen_and_serve` は shutdown_signal=Pending で永久に await するため実際には返らない
    // （戻り型は NoGracefulShutdown だが到達しない）。ローカル app もタスク生存中ずっと生きる。
    let app = http::make_app();
    let mut http_buffer = [0u8; 2048];
    let mut rx = [0u8; 1024];
    let mut tx = [0u8; 1024];
    picoserve::Server::new(&app, config, &mut http_buffer)
        .listen_and_serve(id, stack, HTTP_PORT, &mut rx, &mut tx)
        .await;
}

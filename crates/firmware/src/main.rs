//! smtlk Pico W ファームウェアの土台。
//!
//! 現状: CYW43439 を起動し、WPA2 で WiFi に接続して DHCP で IP を取得したうえで、
//! SG90 サーボ（GP15 PWM + GP14 電源ゲート）を Signal 経由のデモループで
//! 3 秒ごとに施錠/解錠する。オンボード LED は疎通確認のハートビートとして点滅する
//!（Pico W の LED は GPIO ではなく CYW43 側にぶら下がっているため、
//! 点滅にも WiFi チップの初期化が要る）。
//!
//! サーボ指令の継ぎ目（`SERVO_CMD: Signal`）は将来 TCP 受信ハンドラから叩く想定。
//!
//! ここから先（スマートロック本体）の積み残し:
//!   - 遠隔操作の口（embassy-net の TCP/HTTP サーバ等）→ `SERVO_CMD.signal(state)` を叩く
//!   - 手回し後の状態再同期・省電力運用
//!
//! 注意: このコードは embassy の公式 examples（examples/rp の wifi 系）に倣っている。

#![no_std]
#![no_main]

mod config;
mod servo;

use config::{WIFI_PASSWORD, WIFI_SSID};
use cyw43::SpiBus;
use cyw43_pio::PioSpi;
use defmt::*;
use embassy_executor::Spawner;
use embassy_net::{Config as NetConfig, StackResources};
use embassy_rp::bind_interrupts;
use embassy_rp::dma::{Channel, InterruptHandler as DmaInterruptHandler};
use embassy_rp::gpio::{Level, Output};
use embassy_rp::peripherals::{DMA_CH0, PIO0};
use embassy_rp::pio::{InterruptHandler, Pio};
use embassy_rp::pwm::{Config as PwmConfig, Pwm};
use embassy_sync::blocking_mutex::raw::CriticalSectionRawMutex;
use embassy_sync::signal::Signal;
use embassy_time::{Duration, Timer};
use servo::Servo;
use smtlk_core::LockState;
use static_cell::StaticCell;
use {defmt_rtt as _, panic_probe as _};

bind_interrupts!(struct Irqs {
    PIO0_IRQ_0 => InterruptHandler<PIO0>;
    DMA_IRQ_0 => DmaInterruptHandler<DMA_CH0>;
});

/// サーボへの施錠/解錠指令。デモループが送り、将来は TCP 受信ハンドラが同じ口を叩く。
/// Signal は最新値のみ保持するため、指令が連続しても安全側（最新状態）へ収束する。
static SERVO_CMD: Signal<CriticalSectionRawMutex, LockState> = Signal::new();

/// 指令を待ってサーボをワンショット駆動し続けるタスク。
#[embassy_executor::task]
async fn servo_task(mut servo: Servo<'static>) -> ! {
    loop {
        let state = SERVO_CMD.wait().await;
        info!("servo: move_to {}", state);
        servo.move_to(state).await;
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
    // Servo::new が divider/top を設定するため、ここは PwmConfig::default() を渡せばよい。
    let gate = Output::new(p.PIN_14, Level::Low);
    let servo_pwm = Pwm::new_output_b(p.PWM_SLICE7, p.PIN_15, PwmConfig::default());
    let servo = Servo::new(servo_pwm, gate);
    spawner.spawn(servo_task(servo).unwrap());

    // CYW43 ファームウェアブロブ。cyw43-firmware/ を埋め込む（README の取得手順を参照）。
    // cyw43 v0.7.0 では aligned_bytes! マクロで A4 アライメントが要る。
    let fw = cyw43::aligned_bytes!("../cyw43-firmware/43439A0.bin");
    let clm = cyw43::aligned_bytes!("../cyw43-firmware/43439A0_clm.bin");

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
    // cyw43 v0.7.0: new() takes fw and clm (nvram) as Aligned<A4, [u8]>; control.init() は廃止。
    let (net_device, mut control, runner) = cyw43::new(state, pwr, spi, fw, clm).await;
    spawner.spawn(cyw43_task(runner).unwrap());

    control
        .set_power_management(cyw43::PowerManagementMode::PowerSave)
        .await;

    // ネットワークスタック（DHCPv4）。
    let net_config = NetConfig::dhcpv4(Default::default());
    // TODO: seed はハードウェア RNG (embassy_rp::clocks::RoscRng 等) から取るべき。
    let seed = 0x0123_4567_89ab_cdef;
    static RESOURCES: StaticCell<StackResources<5>> = StaticCell::new();
    let (stack, net_runner) = embassy_net::new(
        net_device,
        net_config,
        RESOURCES.init(StackResources::new()),
        seed,
    );
    spawner.spawn(net_task(net_runner).unwrap());

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

    // 施錠/解錠デモ: 数秒ごとに状態を反転して SERVO_CMD へ送る。
    // LED は疎通確認のハートビート。将来この送出を TCP 受信ハンドラへ置き換える。
    let period = Duration::from_secs(3);
    let mut state = LockState::Locked;
    loop {
        SERVO_CMD.signal(state);
        control.gpio_set(0, true).await;
        Timer::after(period).await;
        control.gpio_set(0, false).await;
        state = match state {
            LockState::Locked => LockState::Unlocked,
            LockState::Unlocked => LockState::Locked,
        };
    }
}

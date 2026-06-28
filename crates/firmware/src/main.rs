//! smtlk Pico W ファームウェアの土台。
//!
//! 現状: CYW43439 を起動し、WPA2 で WiFi に接続して DHCP で IP を取得したうえで、
//! TCP ポート 6000 を listen し、`smtlk_core::serve_connection` でロックコマンドを捌く。
//! SG90 サーボ（GP15 PWM + GP14 電源ゲート）への指令は `SERVO_CMD: Signal` 経由で
//! `servo_task` が受け取る。オンボード LED は接続中に点灯する
//!（Pico W の LED は GPIO ではなく CYW43 側にぶら下がっているため、
//! 制御にも WiFi チップの初期化が要る）。
//!
//! サーボ指令の継ぎ目（`SERVO_CMD: Signal`）は `SignalSink` アダプタ経由で
//! `serve_connection` から叩かれる。
//!
//! ここから先（スマートロック本体）の積み残し:
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
use embassy_net::tcp::TcpSocket;
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
use smtlk_core::serve::{serve_connection, ServoSink};
use smtlk_core::{LockController, LockState};
use static_cell::StaticCell;
use {defmt_rtt as _, panic_probe as _};

bind_interrupts!(struct Irqs {
    PIO0_IRQ_0 => InterruptHandler<PIO0>;
    DMA_IRQ_0 => DmaInterruptHandler<DMA_CH0>;
});

/// 遠隔ロック操作を受ける TCP ポート。
const LOCK_PORT: u16 = 6000;

/// サーボへの施錠/解錠指令。TCP 受信ハンドラが `SignalSink` 経由で叩く。
/// Signal は最新値のみ保持するため、指令が連続しても安全側（最新状態）へ収束する。
static SERVO_CMD: Signal<CriticalSectionRawMutex, LockState> = Signal::new();

/// `ServoSink` を `SERVO_CMD` で実装するアダプタ。serve_connection の結論をサーボタスクへ橋渡しする。
struct SignalSink(&'static Signal<CriticalSectionRawMutex, LockState>);

impl ServoSink for SignalSink {
    fn send(&self, state: LockState) {
        self.0.signal(state);
    }
}

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

    // 遠隔ロック操作: ポート LOCK_PORT を listen し、1 接続ずつ serve する。
    // 判断ロジックは smtlk_core::serve_connection（host テスト済み）。ここはアダプタ配線。
    let mut rx_buf = [0u8; 512];
    let mut tx_buf = [0u8; 512];
    let mut controller = LockController::new(); // 接続をまたいで状態保持
    let sink = SignalSink(&SERVO_CMD);

    loop {
        let mut socket = TcpSocket::new(stack, &mut rx_buf, &mut tx_buf);
        control.gpio_set(0, false).await; // 待受中: LED 消灯
        if let Err(e) = socket.accept(LOCK_PORT).await {
            warn!("accept failed: {:?}", e);
            continue;
        }
        info!("client connected on :{}", LOCK_PORT);
        control.gpio_set(0, true).await; // 接続中: LED 点灯
        if let Err(e) = serve_connection(&mut socket, &mut controller, &sink).await {
            warn!("serve error: {:?}", e);
        }
        info!("client disconnected");
    }
}

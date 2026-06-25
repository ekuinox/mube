//! SG90 サーボ駆動。電源ゲート（GP14）と PWM 信号（GP15）を協調させ、
//! 「給電 → 目標角のパルス送出 → 整定待ち → 給電断」のワンショットで施錠/解錠する。
//!
//! 角度→パルス幅の期待値（`pulse_us`）:
//!   pulse_us(0)   == 1000   // 施錠端
//!   pulse_us(90)  == 1500   // 中点
//!   pulse_us(180) == 2000   // 解錠端（フルストローク上端）
//!
//! 実機合わせはこのファイル冒頭のキャリブ定数 5 つだけを触る。SG90 は個体差が
//! 大きい（フルストロークが 500–2500µs に振れる）。まず安全側（狭い MIN/MAX）で
//! 焼き、唸らない・突き当てない範囲を実測で広げること（サムターン保護のため）。

use defmt::Format;
use embassy_rp::gpio::Output;
use embassy_rp::pwm::{Config as PwmConfig, Pwm};
use embassy_time::{Duration, Timer};
use fixed::traits::ToFixed;

// --- キャリブ定数（実機合わせはここだけ触る） ---
const SERVO_MIN_US: u16 = 1000; // フルストローク下端のパルス幅[µs]
const SERVO_MAX_US: u16 = 2000; // フルストローク上端のパルス幅[µs]
const LOCK_DEG: u16 = 0; // 施錠側の角度
const UNLOCK_DEG: u16 = 90; // 解錠側の角度（サムターンの回転量に合わせる）
const SETTLE_MS: u64 = 500; // パルス送出後に到達を待つ時間

// --- PWM 構成（50Hz: div=125 で 1µs/tick、top=20000 で 20ms 周期） ---
pub const PWM_DIV: u8 = 125;
pub const PWM_TOP: u16 = 20000;

/// 角度[deg]→パルス幅[µs]。u16 同士の積は溢れるため u32 で計算する。
/// pulse_us(0)=1000, pulse_us(90)=1500, pulse_us(180)=2000。
const fn pulse_us(deg: u16) -> u16 {
    (SERVO_MIN_US as u32
        + (SERVO_MAX_US - SERVO_MIN_US) as u32 * deg as u32 / 180) as u16
}

/// 施錠/解錠の 2 状態。
#[derive(Clone, Copy, PartialEq, Eq, Format)]
pub enum LockState {
    Locked,
    Unlocked,
}

impl LockState {
    const fn deg(self) -> u16 {
        match self {
            LockState::Locked => LOCK_DEG,
            LockState::Unlocked => UNLOCK_DEG,
        }
    }
}

/// サーボ駆動。PWM（GP15 = slice7 ch B）と電源ゲート（GP14, active-high）を保持する。
pub struct Servo<'d> {
    pwm: Pwm<'d>,
    gate: Output<'d>,
    cfg: PwmConfig,
}

impl<'d> Servo<'d> {
    /// 初期状態は「給電断・PWM 停止」。`pwm` は main 側で `Pwm::new_output_b(
    /// PWM_SLICE7, PIN_15, PwmConfig::default())` として渡す。`gate` は GP14。
    pub fn new(pwm: Pwm<'d>, gate: Output<'d>) -> Self {
        let mut cfg = PwmConfig::default();
        cfg.divider = (PWM_DIV as u16).to_fixed();
        cfg.top = PWM_TOP;
        cfg.compare_b = 0;
        cfg.enable = false;
        let mut servo = Self { pwm, gate, cfg };
        servo.pwm.set_config(&servo.cfg);
        servo.gate.set_low(); // 給電断で待機
        servo
    }

    /// ワンショット駆動: 給電 → 目標角のパルス送出 → 整定待ち → 給電断。
    pub async fn move_to(&mut self, state: LockState) {
        self.gate.set_high(); // Q1 ON = サーボに給電
        self.cfg.compare_b = pulse_us(state.deg());
        self.cfg.enable = true;
        self.pwm.set_config(&self.cfg); // パルス送出開始
        Timer::after(Duration::from_millis(SETTLE_MS)).await;
        self.cfg.enable = false;
        self.pwm.set_config(&self.cfg); // PWM 停止
        self.gate.set_low(); // 給電断（唸り・消費電力・寿命対策）
    }
}

//! SG90 サーボ駆動。電源ゲート（GP14）と PWM 信号（GP15）を協調させ、
//! 「給電 → 目標角のパルス送出 → 整定待ち → 給電断」のワンショットで施錠/解錠する。
//!
//! 角度→パルス幅変換とキャリブ定数（SERVO_MIN_US / SERVO_MAX_US / LOCK_DEG / UNLOCK_DEG）は
//! `mube_core::servo_math` にある。実機合わせはそちらを触る。SG90 は個体差が
//! 大きい（フルストロークが 500–2500µs に振れる）。まず安全側（狭い MIN/MAX）で
//! 焼き、唸らない・突き当てない範囲を実測で広げること（サムターン保護のため）。
//!
//! このファイルには整定待ち `SETTLE_MS`（給電からパルス完了までの待機時間）のみ残る。

use embassy_rp::gpio::Output;
use embassy_rp::pwm::{Config as PwmConfig, Pwm};
use embassy_time::{Duration, Timer};
use fixed::traits::ToFixed;
use mube_core::servo_math::pulse_us_for;
use mube_core::LockState;

const SETTLE_MS: u64 = 500; // パルス送出後に到達を待つ時間

// --- PWM 構成（50Hz: div=125 で 1µs/tick、top=20000 で 20ms 周期） ---
pub const PWM_DIV: u8 = 125;
pub const PWM_TOP: u16 = 20000;

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
        self.cfg.compare_b = pulse_us_for(state);
        self.cfg.enable = true;
        self.pwm.set_config(&self.cfg); // パルス送出開始
        Timer::after(Duration::from_millis(SETTLE_MS)).await;
        self.cfg.enable = false;
        self.pwm.set_config(&self.cfg); // PWM 停止
        self.gate.set_low(); // 給電断（唸り・消費電力・寿命対策）
    }
}

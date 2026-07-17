//! サーボ角度の純粋変換。キャリブ定数はここに集約（実機合わせはここだけ触る）。
//! pulse_us(0)=1000, pulse_us(90)=1500, pulse_us(180)=2000。

use crate::lock::LockState;

// --- キャリブ定数（実機合わせはここだけ触る） ---
const SERVO_MIN_US: u16 = 1000; // フルストローク下端のパルス幅[µs]
const SERVO_MAX_US: u16 = 2000; // フルストローク上端のパルス幅[µs]
const LOCK_DEG: u16 = 0; // 施錠側の角度
const UNLOCK_DEG: u16 = 150; // 解錠側の角度（サムターンの回転量に合わせる）

/// 角度[deg]→パルス幅[µs]。u16 同士の積は溢れるため u32 で計算する。
pub const fn pulse_us(deg: u16) -> u16 {
    (SERVO_MIN_US as u32 + (SERVO_MAX_US - SERVO_MIN_US) as u32 * deg as u32 / 180) as u16
}

/// 施錠/解錠状態に対応するパルス幅[µs]。
pub const fn pulse_us_for(state: LockState) -> u16 {
    let deg = match state {
        LockState::Locked => LOCK_DEG,
        LockState::Unlocked => UNLOCK_DEG,
    };
    pulse_us(deg)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::lock::LockState;

    #[test]
    fn pulse_us_endpoints() {
        assert_eq!(pulse_us(0), 1000);
        assert_eq!(pulse_us(90), 1500);
        assert_eq!(pulse_us(180), 2000);
    }

    #[test]
    fn pulse_us_for_states() {
        assert_eq!(pulse_us_for(LockState::Locked), 1000);
        assert_eq!(pulse_us_for(LockState::Unlocked), 1833);
    }
}

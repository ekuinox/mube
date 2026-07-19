//! サーボ角度の純粋変換。キャリブ定数はここに集約（実機合わせはここだけ触る）。
//! pulse_us(0)=1000, pulse_us(90)=1500, pulse_us(180)=2000。
//!
//! 実機確定値（2026-07-19, #77）: LOCK=180(2000µs)/UNLOCK=0(1000µs) で施錠⇔解錠の
//! 完遂を確認（結合部の掛かりを確保した場合）。施錠は高パルス側＝当初想定と逆向き。
//! この SG90 個体は ~1250µs 以下で内部メカ端に当たり唸るため、UNLOCK 指令(1000µs)は
//! メカ端で止まった状態になるが、整定後に給電ゲートが切れるので実用上許容している。

use crate::lock::LockState;

// --- キャリブ定数（実機合わせはここだけ触る） ---
const SERVO_MIN_US: u16 = 1000; // フルストローク下端のパルス幅[µs]
const SERVO_MAX_US: u16 = 2000; // フルストローク上端のパルス幅[µs]
const LOCK_DEG: u16 = 180; // 施錠側の角度（施錠は高パルス側。実機確定）
const UNLOCK_DEG: u16 = 0; // 解錠側の角度（メカ端当て。ゲート断で無音化）

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
        assert_eq!(pulse_us_for(LockState::Locked), 2000);
        assert_eq!(pulse_us_for(LockState::Unlocked), 1000);
    }
}

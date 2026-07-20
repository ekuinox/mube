//! ロック状態と純粋関数 `decide()`（`Outcome` / `reply_for`）。

/// 施錠/解錠の 2 状態。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
#[cfg_attr(feature = "defmt", derive(defmt::Format))]
pub enum LockState {
    Locked,
    Unlocked,
}

impl LockState {
    /// 施錠⇄解錠を反転する。ボタンのトグル操作で使う。
    pub fn toggled(self) -> LockState {
        match self {
            LockState::Locked => LockState::Unlocked,
            LockState::Unlocked => LockState::Locked,
        }
    }
}

use crate::command::{parse, Command};

/// `decide` の結果。`servo` が `Some` ならその状態へサーボを駆動する。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Outcome {
    pub servo: Option<LockState>,
    pub reply: &'static str,
}

/// 受信した 1 行と現在状態から、状態遷移指令と応答を決める純粋関数。
/// `servo` が `Some(target)` なら呼び出し側がその状態へサーボを駆動・永続化する。
/// STATUS は駆動せず `current` を反映した応答だけ返す。
pub fn decide(line: &[u8], current: LockState) -> Outcome {
    match parse(line) {
        Some(Command::Lock) => Outcome { servo: Some(LockState::Locked), reply: "LOCKED\n" },
        Some(Command::Unlock) => Outcome { servo: Some(LockState::Unlocked), reply: "UNLOCKED\n" },
        Some(Command::Status) => Outcome { servo: None, reply: reply_for(current) },
        None => Outcome { servo: None, reply: "ERR\n" },
    }
}

/// 現在状態に対応する STATUS 応答文字列。
fn reply_for(state: LockState) -> &'static str {
    match state {
        LockState::Locked => "LOCKED\n",
        LockState::Unlocked => "UNLOCKED\n",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn toggled_flips_state() {
        assert_eq!(LockState::Locked.toggled(), LockState::Unlocked);
        assert_eq!(LockState::Unlocked.toggled(), LockState::Locked);
    }

    #[test]
    fn lock_drives_servo_and_replies() {
        let o = decide(b"LOCK\n", LockState::Unlocked);
        assert_eq!(o.servo, Some(LockState::Locked));
        assert_eq!(o.reply, "LOCKED\n");
    }

    #[test]
    fn unlock_drives_servo_and_replies() {
        let o = decide(b"UNLOCK\n", LockState::Locked);
        assert_eq!(o.servo, Some(LockState::Unlocked));
        assert_eq!(o.reply, "UNLOCKED\n");
    }

    #[test]
    fn status_does_not_drive_and_reflects_current() {
        let o = decide(b"STATUS\n", LockState::Unlocked);
        assert_eq!(o.servo, None);
        assert_eq!(o.reply, "UNLOCKED\n");
        let o2 = decide(b"STATUS\n", LockState::Locked);
        assert_eq!(o2.reply, "LOCKED\n");
    }

    #[test]
    fn invalid_errs_no_drive() {
        let o = decide(b"FOO\n", LockState::Locked);
        assert_eq!(o.servo, None);
        assert_eq!(o.reply, "ERR\n");
    }

    #[test]
    fn lock_idempotent_still_drives_servo() {
        let o = decide(b"LOCK\n", LockState::Locked); // 同状態でも駆動を指令する
        assert_eq!(o.servo, Some(LockState::Locked));
    }

    #[test]
    fn unlock_idempotent_still_drives_servo() {
        let o = decide(b"UNLOCK\n", LockState::Unlocked); // 同状態でも駆動を指令する
        assert_eq!(o.servo, Some(LockState::Unlocked));
    }
}

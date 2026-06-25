//! ロック状態と状態機械（`LockController` / `Outcome` / `handle_line`）。

/// 施錠/解錠の 2 状態。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
#[cfg_attr(feature = "defmt", derive(defmt::Format))]
pub enum LockState {
    Locked,
    Unlocked,
}

use crate::command::{parse, Command};

/// `handle_line` の結果。`servo` が `Some` ならその状態へサーボを駆動する。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Outcome {
    pub servo: Option<LockState>,
    pub reply: &'static str,
}

/// ロック制御の状態機械。物理状態は持たず、最後に指令した論理状態のみ保持する。
pub struct LockController {
    state: LockState,
}

impl LockController {
    /// 起動時は安全側に施錠。
    pub const fn new() -> Self {
        Self { state: LockState::Locked }
    }

    pub fn state(&self) -> LockState {
        self.state
    }

    /// 受信した 1 行を解釈して状態遷移と応答を返す。
    pub fn handle_line(&mut self, line: &[u8]) -> Outcome {
        match parse(line) {
            Some(Command::Lock) => {
                self.state = LockState::Locked;
                Outcome { servo: Some(LockState::Locked), reply: "LOCKED\n" }
            }
            Some(Command::Unlock) => {
                self.state = LockState::Unlocked;
                Outcome { servo: Some(LockState::Unlocked), reply: "UNLOCKED\n" }
            }
            Some(Command::Status) => Outcome {
                servo: None,
                reply: match self.state {
                    LockState::Locked => "LOCKED\n",
                    LockState::Unlocked => "UNLOCKED\n",
                },
            },
            None => Outcome { servo: None, reply: "ERR\n" },
        }
    }
}

impl Default for LockController {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unlock_drives_servo_and_replies() {
        let mut c = LockController::new();
        let o = c.handle_line(b"UNLOCK\n");
        assert_eq!(o.servo, Some(LockState::Unlocked));
        assert_eq!(o.reply, "UNLOCKED\n");
        assert_eq!(c.state(), LockState::Unlocked);
    }

    #[test]
    fn status_does_not_drive_servo() {
        let mut c = LockController::new(); // 初期 Locked
        let o = c.handle_line(b"STATUS\n");
        assert_eq!(o.servo, None);
        assert_eq!(o.reply, "LOCKED\n");
        assert_eq!(c.state(), LockState::Locked);
    }

    #[test]
    fn relock_still_commands_servo() {
        let mut c = LockController::new(); // 初期 Locked
        let o = c.handle_line(b"LOCK\n");
        assert_eq!(o.servo, Some(LockState::Locked)); // 同状態でも指令する
        assert_eq!(o.reply, "LOCKED\n");
    }

    #[test]
    fn reunlock_still_commands_servo() {
        let mut c = LockController::new();
        c.handle_line(b"UNLOCK\n"); // 一度 Unlocked へ
        let o = c.handle_line(b"UNLOCK\n"); // 同状態でも再主張
        assert_eq!(o.servo, Some(LockState::Unlocked));
        assert_eq!(o.reply, "UNLOCKED\n");
    }

    #[test]
    fn invalid_keeps_state_and_errs() {
        let mut c = LockController::new();
        let o = c.handle_line(b"FOO\n");
        assert_eq!(o.servo, None);
        assert_eq!(o.reply, "ERR\n");
        assert_eq!(c.state(), LockState::Locked);
    }

    #[test]
    fn status_reflects_last_command() {
        let mut c = LockController::new();
        c.handle_line(b"UNLOCK\n");
        let s = c.handle_line(b"STATUS\n");
        assert_eq!(s.reply, "UNLOCKED\n");
    }
}

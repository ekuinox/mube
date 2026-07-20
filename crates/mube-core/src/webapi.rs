//! HTTP WebUI 用の純ロジック：状態⇄JSON と、ルート→目標状態のマッピング。
//! HTTP のパース/ソケットは firmware(picoserve) 側。ここは host テスト可能な純関数だけ。

use crate::lock::LockState;

/// WebUI から来る操作。HTTP ルートに対応する。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Action {
    Lock,
    Unlock,
    Toggle,
    Status,
}

/// 状態の JSON 表現（API レスポンスボディ）。
pub fn state_json(state: LockState) -> &'static str {
    match state {
        LockState::Locked => "{\"state\":\"LOCKED\"}",
        LockState::Unlocked => "{\"state\":\"UNLOCKED\"}",
    }
}

/// 操作と現在状態から、駆動すべき目標状態を決める。
/// Status は駆動しない（None）。Lock/Unlock は固定、Toggle は現在状態を反転。
pub fn target_for(action: Action, current: LockState) -> Option<LockState> {
    match action {
        Action::Lock => Some(LockState::Locked),
        Action::Unlock => Some(LockState::Unlocked),
        Action::Toggle => Some(current.toggled()),
        Action::Status => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn state_json_maps_both_states() {
        assert_eq!(state_json(LockState::Locked), "{\"state\":\"LOCKED\"}");
        assert_eq!(state_json(LockState::Unlocked), "{\"state\":\"UNLOCKED\"}");
    }

    #[test]
    fn lock_and_unlock_are_fixed_targets() {
        assert_eq!(target_for(Action::Lock, LockState::Unlocked), Some(LockState::Locked));
        assert_eq!(target_for(Action::Lock, LockState::Locked), Some(LockState::Locked));
        assert_eq!(target_for(Action::Unlock, LockState::Locked), Some(LockState::Unlocked));
    }

    #[test]
    fn toggle_flips_current() {
        assert_eq!(target_for(Action::Toggle, LockState::Locked), Some(LockState::Unlocked));
        assert_eq!(target_for(Action::Toggle, LockState::Unlocked), Some(LockState::Locked));
    }

    #[test]
    fn status_does_not_drive() {
        assert_eq!(target_for(Action::Status, LockState::Locked), None);
        assert_eq!(target_for(Action::Status, LockState::Unlocked), None);
    }
}

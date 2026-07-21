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

/// API レスポンス `{"state":"LOCKED"|"UNLOCKED"}` の JSON 契約。
/// webui はこれを serde-json-core でデシリアライズする。firmware は同じ契約の
/// 固定文字列 `as_json()` を返す（両者の一致は下の契約テストで担保）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
#[cfg_attr(feature = "serde", derive(serde::Serialize, serde::Deserialize))]
pub struct StatusResponse {
    pub state: LockState,
}

impl LockState {
    /// 状態の JSON 表現（API レスポンスボディ）。
    /// 実行時シリアライズにしない理由: 取りうる値が 2 つしかなく、&'static str なら
    /// フラッシュ直置きでバッファ管理も不要。`StatusResponse` の serde 直列化との
    /// 一致は契約テスト（as_json_matches_serde_contract）が保証する。
    pub fn as_json(self) -> &'static str {
        match self {
            LockState::Locked => "{\"state\":\"LOCKED\"}",
            LockState::Unlocked => "{\"state\":\"UNLOCKED\"}",
        }
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
    fn as_json_maps_both_states() {
        assert_eq!(LockState::Locked.as_json(), "{\"state\":\"LOCKED\"}");
        assert_eq!(LockState::Unlocked.as_json(), "{\"state\":\"UNLOCKED\"}");
    }

    /// as_json の固定文字列と StatusResponse の serde 直列化が同一であること
    /// （firmware が返す JSON を webui が必ずパースできること）の契約テスト。
    #[cfg(feature = "serde")]
    #[test]
    fn as_json_matches_serde_contract() {
        for state in [LockState::Locked, LockState::Unlocked] {
            let json = serde_json_core::to_string::<_, 32>(&StatusResponse { state }).unwrap();
            assert_eq!(json.as_str(), state.as_json());
            let (parsed, _) = serde_json_core::from_str::<StatusResponse>(state.as_json()).unwrap();
            assert_eq!(parsed.state, state);
        }
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

//! ロック状態。`LockController`/`Outcome`（状態機械）は Task 3 で実装する。

/// 施錠/解錠の 2 状態。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
#[cfg_attr(feature = "defmt", derive(defmt::Format))]
pub enum LockState {
    Locked,
    Unlocked,
}

//! ロック状態。施錠/解錠の 2 状態と反転操作。

/// 施錠/解錠の 2 状態。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
#[cfg_attr(feature = "defmt", derive(defmt::Format))]
pub enum LockState {
    Locked,
    Unlocked,
}

impl LockState {
    /// 施錠⇄解錠を反転する。ボタンのトグル操作・toggle API で使う。
    pub fn toggled(self) -> LockState {
        match self {
            LockState::Locked => LockState::Unlocked,
            LockState::Unlocked => LockState::Locked,
        }
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
}

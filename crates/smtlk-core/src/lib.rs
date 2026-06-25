//! ハード非依存のロック制御ロジック。host で cargo test できる
//! （firmware からは no_std 依存として使う）。
#![cfg_attr(not(test), no_std)]

pub mod command;
pub mod lock;
pub mod servo_math;

pub use lock::{LockController, LockState, Outcome};

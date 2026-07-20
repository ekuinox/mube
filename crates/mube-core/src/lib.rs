//! ハード非依存のロック制御ロジック。host で cargo test できる
//! （firmware からは no_std 依存として使う）。
#![cfg_attr(not(test), no_std)]

pub mod command;
pub mod lock;
pub mod serve;
pub mod servo_math;
pub mod webapi;

pub use lock::{decide, LockState, Outcome};
pub use serve::{serve_connection, LockPort, LINE_MAX};
pub use webapi::{state_json, target_for, Action};

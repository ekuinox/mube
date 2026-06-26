# host テスト可能な core 分離 実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ファームのハード非依存ロジックを `crates/smtlk-core` に分離し、実機なしで `cargo test`（host）検証できる土台を作る。ロック・コマンドの解釈と状態機械を host テスト付きで実装する（ソケット I/O は次サイクル）。

**Architecture:** ルートを Cargo workspace 化し、`crates/firmware`（現 `src/` 移設、embassy/PWM/WiFi 接合部のみ）と `crates/smtlk-core`（`#![cfg_attr(not(test), no_std)]` の純粋ロジック lib）に分ける。core はサーボ角度変換・`LockState`・コマンドパース・ロック状態機械を持ち、host で `cargo test` できる。firmware は core に依存して接合だけ担う。

**Tech Stack:** Rust（firmware は `#![no_std]`、core は no_std だが host テスト可能）、embassy（rp/time/sync/net/executor）、RP2040、ビルドは Nix devShell（thumbv6m クロス）。

## Global Constraints

- ビルド・検証は必ず Nix devShell 経由: `nix develop -c cargo ...`（`nix` は PATH 上にある前提。`cargo` は dev シェルの rustup が供給）。
- 既定ターゲットは `thumbv6m-none-eabi`（ルート `.cargo/config.toml` の `[build] target`）。`firmware` は no_std/no_main で host ビルド不可。
- host テストのターゲットは `aarch64-unknown-linux-gnu`（dev 機固定）。cargo alias `host-test` で叩く: `cargo host-test` = `cargo test -p smtlk-core --target aarch64-unknown-linux-gnu`。
- `smtlk-core` は `#![cfg_attr(not(test), no_std)]`。依存ほぼゼロ。`defmt` は任意フィーチャ（`[features] defmt = ["dep:defmt"]`）で firmware が有効化。`fixed` は firmware に残す。
- Cargo の `[profile.*]` は workspace 仮想マニフェスト（ルート Cargo.toml）に置く（メンバーに置くと無視/警告）。
- GPIO/PWM 等ハード定数（`PWM_DIV`/`PWM_TOP`/`SETTLE_MS`）と `Servo` は firmware 側に残す。core はハードに触れない。
- WiFi 土台とサーボのデモループ挙動は不変に保つ（compile 緑を維持）。`LockController`/`command` は本サイクルでは未配線（次サイクルの TCP リスナが利用）。
- コマンドプロトコル: `LOCK`/`UNLOCK`/`STATUS` のみ、前後 ASCII 空白トリム・大小文字無視。応答は `"LOCKED\n"`/`"UNLOCKED\n"`/`"ERR\n"`（全て `&'static str`）。`LockController` 初期状態は `Locked`。コマンドは同状態でも常にサーボ指令を出す。

---

### Task 1: workspace 化と firmware 移設、smtlk-core 骨格＋純粋ロジック移設

ハード非依存の純粋ロジック（`LockState`・`pulse_us`）を core へ移し、firmware を core 依存へ組み替える。本タスクは構造移行で、検証は compile 緑（host テストは Task 2 以降）。

**Files:**
- Create: `Cargo.toml`（ルートを workspace 仮想マニフェストに書き換え）
- Create: `crates/firmware/Cargo.toml`（現パッケージ＋`smtlk-core` 依存）
- Move: `src/` → `crates/firmware/src/`、`build.rs`・`memory.x`・`cyw43-firmware/` → `crates/firmware/`（`git mv` で履歴保持）
- Create: `crates/smtlk-core/Cargo.toml`、`crates/smtlk-core/src/lib.rs`、`crates/smtlk-core/src/lock.rs`、`crates/smtlk-core/src/servo_math.rs`
- Modify: `crates/firmware/src/servo.rs`（`LockState`/`pulse_us`/キャリブ削除、core 利用へ）
- Modify: `crates/firmware/src/main.rs`（`LockState` の import 元を core へ）
- Modify: `.cargo/config.toml`（`[alias] host-test` 追加。ルート据え置き）

**Interfaces:**
- Produces:
  - `smtlk_core::LockState`（`Locked`/`Unlocked`、`Copy`、`Debug`/`PartialEq`/`Eq`、`defmt` フィーチャ時 `defmt::Format`）
  - `smtlk_core::servo_math::pulse_us(deg: u16) -> u16`（const fn）
  - `smtlk_core::servo_math::pulse_us_for(state: LockState) -> u16`（const fn）
  - `crates/smtlk-core/src/command.rs`・`lock.rs` の `LockController`/`Outcome` は Task 2/3 で追加
- Consumes: なし（既存コードの移設）

- [ ] **Step 1: ディレクトリ移設（git mv で履歴保持）**

```bash
cd /home/ekuinox/works/repos/git/ekuinox/smtlk/.claude/worktrees/testable-core
mkdir -p crates/firmware crates/smtlk-core/src
git mv src crates/firmware/src
git mv build.rs crates/firmware/build.rs
git mv memory.x crates/firmware/memory.x
git mv cyw43-firmware crates/firmware/cyw43-firmware
```

- [ ] **Step 2: ルート `Cargo.toml` を workspace 仮想マニフェストに書き換え**

ルート `Cargo.toml` の中身を以下で全置換する（`[profile.*]` は現 firmware から移設）。

```toml
[workspace]
resolver = "2"
members = ["crates/firmware", "crates/smtlk-core"]

# サイズ優先。embedded ではデバッグビルドでも opt-level を上げないと体感が重い。
[profile.dev]
opt-level = "s"
debug = 2
lto = false

[profile.release]
opt-level = "s"
debug = 2
lto = "fat"
codegen-units = 1
```

- [ ] **Step 3: `crates/firmware/Cargo.toml` を作成（現パッケージ＋core 依存、profile は除く）**

```toml
[package]
name = "smtlk-firmware"
version = "0.1.0"
edition = "2021"
license = "MIT OR Apache-2.0"
description = "Pico W (RP2040) firmware for the smtlk smart lock — Embassy async + CYW43 WiFi"

# embassy は crates.io 公開版に固定（再現性は版指定＋Cargo.lock で担保）。
# 版を上げる際は各クレートの CHANGELOG と feature 名の変更に注意する。
[dependencies]
smtlk-core = { path = "../smtlk-core", features = ["defmt"] }

embassy-executor = { version = "0.10", features = ["platform-cortex-m", "executor-thread", "executor-interrupt", "defmt"] }
embassy-time = { version = "0.5", features = ["defmt", "defmt-timestamp-uptime"] }
embassy-rp = { version = "0.10", features = ["defmt", "unstable-pac", "time-driver", "critical-section-impl", "rp2040"] }
embassy-sync = { version = "0.8", features = ["defmt"] }
embassy-net = { version = "0.9", features = ["defmt", "tcp", "udp", "dns", "dhcpv4", "medium-ethernet"] }
cyw43 = { version = "0.7", features = ["defmt", "firmware-logs"] }
cyw43-pio = { version = "0.10", features = ["defmt"] }

defmt = "0.3"
defmt-rtt = "0.4"
panic-probe = { version = "0.3", features = ["print-defmt"] }

cortex-m = { version = "0.7", features = ["inline-asm"] }
cortex-m-rt = "0.7"
static_cell = "2"
portable-atomic = { version = "1", features = ["critical-section"] }
embedded-hal-async = "1.0"
embedded-io-async = "0.6"
heapless = "0.8"
fixed = "1"
```

- [ ] **Step 4: `crates/smtlk-core/Cargo.toml` を作成**

```toml
[package]
name = "smtlk-core"
version = "0.1.0"
edition = "2021"
license = "MIT OR Apache-2.0"
description = "Hardware-agnostic lock-control logic for smtlk (host-testable)"

[dependencies]
defmt = { version = "0.3", optional = true }

[features]
defmt = ["dep:defmt"]
```

- [ ] **Step 5: `crates/smtlk-core/src/lib.rs` を作成**

`LockController`/`Outcome` は Task 3 で追加するため、本タスクの re-export は `LockState` のみに絞る（Task 3 Step 4 で広げる）。

```rust
//! ハード非依存のロック制御ロジック。host で cargo test できる
//! （firmware からは no_std 依存として使う）。
#![cfg_attr(not(test), no_std)]

pub mod command;
pub mod lock;
pub mod servo_math;

pub use lock::LockState;
```

- [ ] **Step 6: `crates/smtlk-core/src/lock.rs` を作成（本タスクは LockState のみ。Controller は Task 3）**

```rust
//! ロック状態。`LockController`/`Outcome`（状態機械）は Task 3 で実装する。

/// 施錠/解錠の 2 状態。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
#[cfg_attr(feature = "defmt", derive(defmt::Format))]
pub enum LockState {
    Locked,
    Unlocked,
}
```

- [ ] **Step 7: `crates/smtlk-core/src/command.rs` をスタブ作成（中身は Task 2）**

`lib.rs` が `pub mod command;` を要求するため、最小スタブを置く（Task 2 で本実装）。

```rust
//! 受信バイト列のコマンド解釈（本実装は Task 2）。
```

- [ ] **Step 8: `crates/smtlk-core/src/servo_math.rs` を作成（pulse_us を servo.rs から移設）**

```rust
//! サーボ角度の純粋変換。キャリブ定数はここに集約（実機合わせはここだけ触る）。
//! pulse_us(0)=1000, pulse_us(90)=1500, pulse_us(180)=2000。

use crate::lock::LockState;

// --- キャリブ定数（実機合わせはここだけ触る） ---
const SERVO_MIN_US: u16 = 1000; // フルストローク下端のパルス幅[µs]
const SERVO_MAX_US: u16 = 2000; // フルストローク上端のパルス幅[µs]
const LOCK_DEG: u16 = 0; // 施錠側の角度
const UNLOCK_DEG: u16 = 90; // 解錠側の角度（サムターンの回転量に合わせる）

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
```

- [ ] **Step 9: `crates/firmware/src/servo.rs` を改修（LockState/pulse_us/キャリブを削除し core を使う）**

`servo.rs` から `LockState` 定義・`pulse_us`・キャリブ定数（`SERVO_MIN_US`/`SERVO_MAX_US`/`LOCK_DEG`/`UNLOCK_DEG`）・`LockState::deg` を削除。`SETTLE_MS`・`PWM_DIV`・`PWM_TOP`・`Servo` は残す。冒頭 use と `move_to` を次に変更:

import 部（`use defmt::Format;` を削除し core を追加）:
```rust
use embassy_rp::gpio::Output;
use embassy_rp::pwm::{Config as PwmConfig, Pwm};
use embassy_time::{Duration, Timer};
use fixed::traits::ToFixed;
use smtlk_core::servo_math::pulse_us_for;
use smtlk_core::LockState;
```

`move_to` 内のパルス計算を差し替え:
```rust
        self.cfg.compare_b = pulse_us_for(state);
```

（`SETTLE_MS`/`PWM_DIV`/`PWM_TOP` 定数と `Servo` 構造体・`new`・`move_to` の他の行はそのまま。ファイル冒頭の doc コメントのうち pulse_us 期待値の記述は core 側へ移ったので、servo.rs 側は「角度→パルス変換は smtlk_core::servo_math」を指す一文に簡略化してよい。）

- [ ] **Step 10: `crates/firmware/src/main.rs` の LockState import 元を core へ**

```rust
use servo::Servo;
use smtlk_core::LockState;
```

（元の `use servo::{LockState, Servo};` を上記2行に置換。他は不変。）

- [ ] **Step 11: `.cargo/config.toml` に host-test alias を追加（ルート据え置き）**

末尾に追記:
```toml
[alias]
# host でロジックの単体テストを回す（既定ターゲットは thumbv6m なので明示上書き）。
# dev 機が別アーキの場合はトリプルを合わせること。
host-test = "test -p smtlk-core --target aarch64-unknown-linux-gnu"
```

- [ ] **Step 12: firmware の thumbv6m ビルドと lock 整合を確認**

```bash
nix develop -c cargo build 2>&1 | tail -20
nix develop -c cargo build --locked 2>&1 | tail -5
```
Expected: 両方 `Finished`。移設の相対パス（`include_bytes!("../cyw43-firmware/…")`・`memory.x`）でエラーが出たら配置とパスを確認して修正。`--locked` が落ちたら一度 `cargo build` 後に `Cargo.lock` をコミット対象に含める。

- [ ] **Step 13: コミット**

```bash
git add -A
git commit -m "refactor: workspace 化し smtlk-core を分離（LockState/pulse_us を core へ移設）"
```

---

### Task 2: smtlk-core の host テスト土台（servo_math + command パース、TDD）

`cargo host-test` が緑になる状態を作る。最小の servo_math テストでハーネスを実証し、`command.rs` をパース実装＋テストで埋める。

**Files:**
- Modify: `crates/smtlk-core/src/command.rs`（パース本実装＋テスト）
- Modify: `crates/smtlk-core/src/servo_math.rs`（テスト追加）

**Interfaces:**
- Consumes: `smtlk_core::LockState`、`servo_math::{pulse_us, pulse_us_for}`（Task 1）
- Produces: `smtlk_core::command::{Command, parse}`
  - `pub enum Command { Lock, Unlock, Status }`（`Copy`/`PartialEq`/`Eq`/`Debug`）
  - `pub fn parse(line: &[u8]) -> Option<Command>`

- [ ] **Step 1: servo_math に host テストを書く（ハーネス実証・先に失敗確認）**

`crates/smtlk-core/src/servo_math.rs` 末尾に追加:
```rust
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
        assert_eq!(pulse_us_for(LockState::Unlocked), 1500);
    }
}
```

- [ ] **Step 2: host-test を走らせてハーネスが動くことを確認**

```bash
nix develop -c cargo host-test 2>&1 | tail -20
```
Expected: PASS（`test result: ok. 2 passed`）。ここで host ターゲットでビルド・実行が成立することを確認する。alias やターゲットの問題があればここで露見する。

- [ ] **Step 3: command パースの失敗テストを書く**

`crates/smtlk-core/src/command.rs` を次に置換（実装はまだ `todo!` で、まず失敗を見る）:
```rust
//! 受信バイト列のコマンド解釈。前後 ASCII 空白をトリムし大小文字無視。

/// 受理するコマンド。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Command {
    Lock,
    Unlock,
    Status,
}

/// 1 行をコマンドへ。不正は None。
pub fn parse(_line: &[u8]) -> Option<Command> {
    unimplemented!()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_basic() {
        assert_eq!(parse(b"LOCK\n"), Some(Command::Lock));
        assert_eq!(parse(b"UNLOCK\r\n"), Some(Command::Unlock));
        assert_eq!(parse(b"STATUS\n"), Some(Command::Status));
    }

    #[test]
    fn case_insensitive_and_trimmed() {
        assert_eq!(parse(b"lock\n"), Some(Command::Lock));
        assert_eq!(parse(b"  STATUS  \n"), Some(Command::Status));
    }

    #[test]
    fn rejects_unknown_and_empty() {
        assert_eq!(parse(b""), None);
        assert_eq!(parse(b"FOO\n"), None);
        assert_eq!(parse(b"LOCKED\n"), None);
    }
}
```

- [ ] **Step 4: テストが失敗することを確認**

```bash
nix develop -c cargo host-test 2>&1 | tail -20
```
Expected: command の3テストが panic（`unimplemented`）で FAIL。

- [ ] **Step 5: parse を実装**

`command.rs` の `parse` と内部ヘルパを実装に置換:
```rust
/// 1 行をコマンドへ。前後 ASCII 空白をトリムし大小文字無視。不正は None。
pub fn parse(line: &[u8]) -> Option<Command> {
    let t = trim_ascii(line);
    if eq_ignore_case(t, b"LOCK") {
        Some(Command::Lock)
    } else if eq_ignore_case(t, b"UNLOCK") {
        Some(Command::Unlock)
    } else if eq_ignore_case(t, b"STATUS") {
        Some(Command::Status)
    } else {
        None
    }
}

fn trim_ascii(mut s: &[u8]) -> &[u8] {
    while let [first, rest @ ..] = s {
        if first.is_ascii_whitespace() {
            s = rest;
        } else {
            break;
        }
    }
    while let [rest @ .., last] = s {
        if last.is_ascii_whitespace() {
            s = rest;
        } else {
            break;
        }
    }
    s
}

fn eq_ignore_case(a: &[u8], b: &[u8]) -> bool {
    a.len() == b.len() && a.iter().zip(b).all(|(x, y)| x.eq_ignore_ascii_case(y))
}
```

- [ ] **Step 6: テストが通ることを確認**

```bash
nix develop -c cargo host-test 2>&1 | tail -20
```
Expected: PASS（servo_math 2 + command 3 = 5 passed）。

- [ ] **Step 7: コミット**

```bash
git add crates/smtlk-core/src/command.rs crates/smtlk-core/src/servo_math.rs
git commit -m "test: smtlk-core の host テスト土台（servo_math + command パース）"
```

---

### Task 3: smtlk-core のロック状態機械（LockController/handle_line、TDD）

受信行を解釈して状態遷移とサーボ指令・応答を返す `LockController` を host テスト付きで実装する。

**Files:**
- Modify: `crates/smtlk-core/src/lock.rs`（`LockController`/`Outcome`/`handle_line` ＋テスト）
- Modify: `crates/smtlk-core/src/lib.rs`（re-export を `LockController`/`Outcome` まで広げる）

**Interfaces:**
- Consumes: `command::{Command, parse}`（Task 2）、`LockState`（Task 1）
- Produces:
  - `pub struct Outcome { pub servo: Option<LockState>, pub reply: &'static str }`
  - `pub struct LockController`（`new()`/`state()`/`handle_line(&mut self, &[u8]) -> Outcome`）

- [ ] **Step 1: 状態機械の失敗テストを書く**

`crates/smtlk-core/src/lock.rs` の `LockState` 定義の下に、まず型のスタブとテストを足す（実装は次ステップ）:
```rust
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

    pub fn handle_line(&mut self, _line: &[u8]) -> Outcome {
        unimplemented!()
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
```

- [ ] **Step 2: テストが失敗することを確認**

```bash
nix develop -c cargo host-test 2>&1 | tail -20
```
Expected: lock の5テストが panic（`unimplemented`）で FAIL（servo_math/command は引き続き PASS）。

- [ ] **Step 3: handle_line を実装**

`lock.rs` の `handle_line` を実装に置換:
```rust
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
```

- [ ] **Step 4: lib.rs の re-export を広げる**

`crates/smtlk-core/src/lib.rs` の re-export を更新:
```rust
pub use lock::{LockController, LockState, Outcome};
```

- [ ] **Step 5: host テストが全部通ることを確認**

```bash
nix develop -c cargo host-test 2>&1 | tail -20
```
Expected: PASS（servo_math 2 + command 3 + lock 5 = 10 passed、警告なし）。

- [ ] **Step 6: firmware が引き続き thumbv6m で緑か確認（core 変更の波及チェック）**

```bash
nix develop -c cargo build 2>&1 | tail -5
```
Expected: `Finished`。`LockController`/`command` は firmware から未使用だが lib なので警告は出ない。

- [ ] **Step 7: コミット**

```bash
git add crates/smtlk-core/src/lock.rs crates/smtlk-core/src/lib.rs
git commit -m "feat: smtlk-core にロック状態機械 LockController/handle_line（host テスト付き）"
```

---

### Task 4: README/ドキュメント更新

新レイアウト・host テスト手順・未配線の継ぎ目を README に反映する。

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: なし
- Produces: なし

- [ ] **Step 1: README のファーム節を更新**

`README.md` のファーム関連箇所に、既存の文体・見出し階層に合わせて次の主旨を反映する（src パスの変更、host テスト、未配線の継ぎ目）:

- ソースが `crates/firmware/`（接合部）と `crates/smtlk-core/`（ハード非依存ロジック）に分かれたこと。ルートは Cargo workspace。
- ビルドは従来どおり `nix develop -c cargo build`（thumbv6m）。ソース移設に伴いファーム個別レンダ等のパス記述があれば `crates/firmware/...` に直す。
- ロジックの host テスト: `nix develop -c cargo host-test`（= `cargo test -p smtlk-core --target aarch64-unknown-linux-gnu` の alias）。実機なしでロック・コマンド解釈と状態機械を検証できる。
- 遠隔操作（TCP）の判断ロジック（`smtlk_core::lock::LockController` / `command`）は実装・テスト済みだが、実際のソケット I/O 配線は次サイクル（実機/シミュレータ確認が要るため）であること。

具体的な追記例（既存トーンに合わせて調整可）:
```
## ソース構成（Rust ファーム）
ルートは Cargo workspace。`crates/firmware/` が embassy/WiFi/PWM の接合部、
`crates/smtlk-core/` がハード非依存のロジック（LockState・コマンド解釈・状態機械・
サーボ角度変換）で、実機なしで host テストできる。

## ロジックの host テスト
    nix develop -c cargo host-test
ロック・コマンド（LOCK/UNLOCK/STATUS）の解釈と状態機械を host で検証する。
TCP 受信ハンドラの判断は smtlk_core::lock::LockController に実装・テスト済みだが、
ソケット I/O の配線は実機/シミュレータ確認が要るため次サイクル。
```

- [ ] **Step 2: コミット**

```bash
git add README.md
git commit -m "docs: workspace 構成と host テスト手順を README へ反映"
```

---

## 完了条件

- `nix develop -c cargo host-test` が緑（servo_math 2 + command 3 + lock 5 = 10 passed）。実機なしでロジックを検証できる。
- `nix develop -c cargo build`（thumbv6m）が緑、サーボのデモ挙動は不変。`cargo build --locked` も緑。
- ロジックは `crates/smtlk-core` に隔離され、`LockController`/`command` はテスト済みで TCP 配線を待つ状態。

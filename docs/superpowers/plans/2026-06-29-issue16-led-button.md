# Issue #16: GP16/GP17 + 二色LED 実装 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** GP16(LED)/GP17(ボタン) をファームに実装し、LED を二色コモンカソード化してロック状態（施錠=赤／解錠=黄緑）を表示、ボタンで施錠⇄解錠トグルできるようにする。

**Architecture:** ロック状態を firmware の単一ソース `LOCK_STATE` に集約し、TCP・ボタン・LED が同じ状態を参照する。`smtlk-core` は状態を持たない純粋関数 `decide()` と `LockPort` トレイトへリファクタして host テスト可能性を保つ。ボタンは内部プルアップ（#27 をクローズ）、LED は servo_task が駆動後にセットする。

**Tech Stack:** Rust / Embassy (embassy-rp, embassy-sync 0.8 blocking Mutex + Signal) / thumbv6m-none-eabi / Python netlist / OpenSCAD（本タスクでは SCAD 変更なし）

## Global Constraints

- Rust 変更後は `nix develop -c cargo host-test` を通すこと（落ちたまま完了にしない）。
- 素の `cargo`/`uv`/`openscad` は `nix develop -c <cmd>` 経由で実行する。
- ファームのコンパイル確認は CYW43 ブロブが要る。実ブロブが無い環境では空ダミーを作る:
  `mkdir -p crates/firmware/cyw43-firmware && touch crates/firmware/cyw43-firmware/43439A0.bin crates/firmware/cyw43-firmware/43439A0_clm.bin`（gitignore 済み、コミットしない）。
- ファーム検証コマンド（CI と同一）:
  `nix develop -c cargo check -p smtlk-firmware --locked --target thumbv6m-none-eabi`
  および `nix develop -c cargo clippy -p smtlk-firmware --locked --target thumbv6m-none-eabi -- -D warnings`。
- `Cargo.lock` はコミット済み。`--locked` で再現する。新規 crate 依存は追加しない（既存の embassy-sync/embassy-rp で足りる）。
- WiFi 認証（config.rs）と CYW43 ブロブの実値は会話・コミットに載せない。
- 二色LED の色割り当て: 施錠=赤(GP16)、解錠=黄緑(GP18)。両色同時点灯は使わない。
- 新規 GPIO は GP18（LED 黄緑）。ボタンは GP17 内部プルアップ（アクティブLow）。

---

## File Structure

- `crates/smtlk-core/src/lock.rs` — `LockState`（+`toggled()`）, `Outcome`, 純粋関数 `decide()`。`LockController` は廃止。
- `crates/smtlk-core/src/serve.rs` — `LockPort` トレイト（`ServoSink` を置換）, `serve_connection` 新シグネチャ。
- `crates/smtlk-core/src/lib.rs` — re-export 更新。
- `crates/firmware/src/main.rs` — `LOCK_STATE`/`apply_target`/`FwLockPort`、servo_task の LED 駆動、button_task、配線。
- `crates/firmware/src/servo.rs` — 変更なし（LED は main 側 servo_task が所有）。
- `circuit/netlist.py` — GPIO/PARTS/NETS/PART_META を二色LED + GP18 + Rled2 に更新。
- `docs/parts-selection.md` / `README.md` — 二色LED・ボタン・GP割り当て・プルアップ方針を反映。

---

## Task 1: `LockState::toggled()` を core に追加

**Files:**
- Modify: `crates/smtlk-core/src/lock.rs`
- Test: 同ファイル `#[cfg(test)] mod tests`

**Interfaces:**
- Produces: `impl LockState { pub fn toggled(self) -> LockState }`（Locked⇄Unlocked）。Task 5（button_task）が使う。

- [ ] **Step 1: 失敗するテストを書く**

`crates/smtlk-core/src/lock.rs` の `mod tests` 内に追加:

```rust
    #[test]
    fn toggled_flips_state() {
        assert_eq!(LockState::Locked.toggled(), LockState::Unlocked);
        assert_eq!(LockState::Unlocked.toggled(), LockState::Locked);
    }
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `nix develop -c cargo test -p smtlk-core --target x86_64-unknown-linux-gnu toggled_flips_state`
Expected: コンパイルエラー（`no method named toggled`）。

- [ ] **Step 3: 最小実装**

`LockState` enum 定義（`lock.rs` 冒頭）の直後に追加:

```rust
impl LockState {
    /// 施錠⇄解錠を反転する。ボタンのトグル操作で使う。
    pub fn toggled(self) -> LockState {
        match self {
            LockState::Locked => LockState::Unlocked,
            LockState::Unlocked => LockState::Locked,
        }
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `nix develop -c cargo test -p smtlk-core --target x86_64-unknown-linux-gnu toggled_flips_state`
Expected: PASS。

- [ ] **Step 5: commit**

```bash
git add crates/smtlk-core/src/lock.rs
git commit -m "feat(core): LockState::toggled() を追加"
```

---

## Task 2: core を `decide()` + `LockPort` へリファクタ（単一ソース化の土台）

`LockController`（状態保持）を純粋関数 `decide()` に、`ServoSink` を `LockPort`（read+apply）に置換する。コンパイルが割れないよう lock.rs / serve.rs / lib.rs とテストを一括で変更する。

**Files:**
- Modify: `crates/smtlk-core/src/lock.rs`
- Modify: `crates/smtlk-core/src/serve.rs`
- Modify: `crates/smtlk-core/src/lib.rs`

**Interfaces:**
- Consumes: `parse`/`Command`（command.rs, 既存）、`LockState::toggled`（Task 1）。
- Produces:
  - `pub fn decide(line: &[u8], current: LockState) -> Outcome`
  - `pub struct Outcome { pub servo: Option<LockState>, pub reply: &'static str }`（既存維持）
  - `pub trait LockPort { fn current(&self) -> LockState; fn apply(&self, target: LockState); }`
  - `pub async fn serve_connection<T, P>(transport: &mut T, port: &P) -> Result<(), T::Error> where T: Read + Write, P: LockPort`
  - lib.rs: `pub use lock::{decide, LockState, Outcome};` `pub use serve::{serve_connection, LockPort, LINE_MAX};`
  Task 3（firmware）がこれらを使う。

- [ ] **Step 1: lock.rs を `decide()` 化（テストも移植）**

`crates/smtlk-core/src/lock.rs` の `LockController` 構造体・`impl LockController`・`impl Default` を削除し、純粋関数に置き換える。`LockState`/`toggled`/`Outcome` は残す。`use crate::command::{parse, Command};` は維持。

```rust
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
```

lock.rs の `mod tests` を `decide()` ベースに書き換える（Task 1 の `toggled_flips_state` は残す）:

```rust
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
```

- [ ] **Step 2: serve.rs を `LockPort` 化**

`crates/smtlk-core/src/serve.rs` の import を更新（`LockController` → `decide`）:

```rust
use crate::lock::{decide, LockState};
```

`ServoSink` トレイトを削除し `LockPort` を追加:

```rust
/// ロック状態の読み書き口。STATUS 用の現在状態取得と、確定状態の永続化＋サーボ駆動を担う。
/// firmware は共有状態（LOCK_STATE）＋サーボ Signal を、テストはメモリ上の mock を実装する。
pub trait LockPort {
    /// STATUS 応答に使う現在のロック状態。
    fn current(&self) -> LockState;
    /// 確定した目標状態を適用する（永続化＋サーボ駆動）。
    fn apply(&self, target: LockState);
}
```

`serve_connection` のシグネチャと本体を差し替える（`controller`/`sink` を単一 `port` に）:

```rust
pub async fn serve_connection<T, P>(transport: &mut T, port: &P) -> Result<(), T::Error>
where
    T: Read + Write,
    P: LockPort,
{
    let mut line = [0u8; LINE_MAX];
    let mut len = 0usize;
    let mut overflow = false;
    let mut chunk = [0u8; 64];

    loop {
        let n = transport.read(&mut chunk).await?;
        if n == 0 {
            return Ok(());
        }
        for &b in &chunk[..n] {
            if b == b'\n' {
                if overflow {
                    overflow = false;
                } else {
                    let outcome = decide(&line[..len], port.current());
                    transport.write_all(outcome.reply.as_bytes()).await?;
                    if let Some(state) = outcome.servo {
                        port.apply(state);
                    }
                }
                len = 0;
            } else if overflow {
                // 読み捨て
            } else if len < LINE_MAX {
                line[len] = b;
                len += 1;
            } else {
                transport.write_all(b"ERR\n").await?;
                overflow = true;
                len = 0;
            }
        }
    }
}
```

- [ ] **Step 3: serve.rs テストの mock を `LockPort` に更新**

`mod tests` 内の `MockSink`（`ServoSink` 実装）を `MockPort`（`LockPort` 実装）に置き換える。`use core::cell::{Cell, RefCell};` を使う（既存 import の `RefCell` に `Cell` を追加）:

```rust
    struct MockPort {
        state: Cell<LockState>,
        applied: RefCell<Vec<LockState>>,
    }
    impl MockPort {
        fn new(initial: LockState) -> Self {
            Self { state: Cell::new(initial), applied: RefCell::new(Vec::new()) }
        }
    }
    impl LockPort for MockPort {
        fn current(&self) -> LockState {
            self.state.get()
        }
        fn apply(&self, target: LockState) {
            self.state.set(target);
            self.applied.borrow_mut().push(target);
        }
    }
```

各テストの呼び出しを `serve_connection(&mut t, &port)` 形に直し、検証を `port.applied` で行う。`LockController::new()` の行は削除する。更新後のテスト本体（6 件）:

```rust
    #[test]
    fn single_command_drives_and_replies() {
        let mut t = MockTransport::new(&[b"UNLOCK\n"]);
        let port = MockPort::new(LockState::Locked);
        block_on(serve_connection(&mut t, &port)).unwrap();
        assert_eq!(&t.out[..], b"UNLOCKED\n");
        assert_eq!(port.applied.borrow().as_slice(), &[LockState::Unlocked]);
    }

    #[test]
    fn status_reflects_current_state() {
        let mut t = MockTransport::new(&[b"STATUS\n"]);
        let port = MockPort::new(LockState::Unlocked);
        block_on(serve_connection(&mut t, &port)).unwrap();
        assert_eq!(&t.out[..], b"UNLOCKED\n");
        assert!(port.applied.borrow().is_empty());
    }

    #[test]
    fn multiple_commands_in_one_read() {
        let mut t = MockTransport::new(&[b"UNLOCK\nSTATUS\nLOCK\n"]);
        let port = MockPort::new(LockState::Locked);
        block_on(serve_connection(&mut t, &port)).unwrap();
        // UNLOCK→UNLOCKED, STATUS→（適用後 Unlocked）UNLOCKED, LOCK→LOCKED
        assert_eq!(&t.out[..], b"UNLOCKED\nUNLOCKED\nLOCKED\n");
        assert_eq!(port.applied.borrow().as_slice(), &[LockState::Unlocked, LockState::Locked]);
    }

    #[test]
    fn line_split_across_reads() {
        let mut t = MockTransport::new(&[b"UNL", b"OCK\n"]);
        let port = MockPort::new(LockState::Locked);
        block_on(serve_connection(&mut t, &port)).unwrap();
        assert_eq!(&t.out[..], b"UNLOCKED\n");
        assert_eq!(port.applied.borrow().as_slice(), &[LockState::Unlocked]);
    }

    #[test]
    fn invalid_line_replies_err_no_drive() {
        let mut t = MockTransport::new(&[b"FOO\n"]);
        let port = MockPort::new(LockState::Locked);
        block_on(serve_connection(&mut t, &port)).unwrap();
        assert_eq!(&t.out[..], b"ERR\n");
        assert!(port.applied.borrow().is_empty());
    }

    #[test]
    fn overlong_line_discarded_then_recovers() {
        let mut over = Vec::new();
        over.extend_from_slice(&[b'A'; 40]);
        over.extend_from_slice(b"\nLOCK\n");
        let mut t = MockTransport::new(&[over.as_slice()]);
        let port = MockPort::new(LockState::Unlocked);
        block_on(serve_connection(&mut t, &port)).unwrap();
        assert_eq!(&t.out[..], b"ERR\nLOCKED\n");
        assert_eq!(port.applied.borrow().as_slice(), &[LockState::Locked]);
    }

    #[test]
    fn crlf_and_lowercase_command() {
        let mut t = MockTransport::new(&[b"unlock\r\n"]);
        let port = MockPort::new(LockState::Locked);
        block_on(serve_connection(&mut t, &port)).unwrap();
        assert_eq!(&t.out[..], b"UNLOCKED\n");
        assert_eq!(port.applied.borrow().as_slice(), &[LockState::Unlocked]);
    }

    #[test]
    fn trailing_bytes_without_newline_not_executed() {
        let mut t = MockTransport::new(&[b"UNLOCK"]);
        let port = MockPort::new(LockState::Locked);
        block_on(serve_connection(&mut t, &port)).unwrap();
        assert!(t.out.is_empty());
        assert!(port.applied.borrow().is_empty());
    }
```

（旧 `MockSink` 定義と旧テスト本体は置き換えで消える。`use core::cell::RefCell;` を `use core::cell::{Cell, RefCell};` にすること。）

- [ ] **Step 4: lib.rs の re-export を更新**

`crates/smtlk-core/src/lib.rs`:

```rust
pub use lock::{decide, LockState, Outcome};
pub use serve::{serve_connection, LockPort, LINE_MAX};
```

（`LockController` と `ServoSink` の re-export を削除。）

- [ ] **Step 5: host テストを通す**

Run: `nix develop -c cargo host-test`
Expected: 全テスト PASS（lock.rs / serve.rs / command.rs / servo_math.rs）。

- [ ] **Step 6: commit**

```bash
git add crates/smtlk-core/src/lock.rs crates/smtlk-core/src/serve.rs crates/smtlk-core/src/lib.rs
git commit -m "refactor(core): LockController/ServoSink を decide()/LockPort へ（STATUS 単一ソース化）"
```

---

## Task 3: firmware の単一ソース状態と LockPort 配線

`LOCK_STATE`（共有現在状態）・`apply_target`・`FwLockPort` を追加し、TCP serve ループを新 `serve_connection` に繋ぐ。LED/ボタンは後続タスクで追加。

**Files:**
- Modify: `crates/firmware/src/main.rs`

**Interfaces:**
- Consumes: `serve_connection`, `LockPort`, `LockState`（Task 2）。
- Produces:
  - `static LOCK_STATE: blocking_mutex::Mutex<CriticalSectionRawMutex, Cell<LockState>>`
  - `fn apply_target(target: LockState)`（`LOCK_STATE` 更新 + `SERVO_CMD.signal`）。Task 5（button）が使う。
  - `struct FwLockPort`（`LockPort` 実装）。

- [ ] **Step 1: import と use を更新**

`crates/firmware/src/main.rs` の use 群を変更:
- 削除: `use smtlk_core::serve::{serve_connection, ServoSink};`、`use smtlk_core::{LockController, LockState};`
- 追加:
```rust
use core::cell::Cell;
use embassy_sync::blocking_mutex::Mutex as BlockingMutex;
use smtlk_core::serve::serve_connection;
use smtlk_core::{LockPort, LockState};
```
（既存の `use embassy_sync::blocking_mutex::raw::CriticalSectionRawMutex;` と `use embassy_sync::signal::Signal;` は維持。）

- [ ] **Step 2: 共有状態・ヘルパ・ポートを定義**

既存の `static SERVO_CMD: ...` 定義の直後、`struct SignalSink` 周辺を次で置き換える（`SignalSink` と `impl ServoSink for SignalSink` は削除）:

```rust
/// 唯一の現在ロック状態。TCP STATUS とボタンのトグルが参照する単一ソース。
/// 起動時は安全側に施錠。
static LOCK_STATE: BlockingMutex<CriticalSectionRawMutex, Cell<LockState>> =
    BlockingMutex::new(Cell::new(LockState::Locked));

/// 目標状態を適用する: 現在状態を即時更新し、サーボタスクへ駆動指令を送る。
/// TCP コマンドもボタンも必ずこれを通すことで状態が一意になる。
fn apply_target(target: LockState) {
    LOCK_STATE.lock(|c| c.set(target));
    SERVO_CMD.signal(target);
}

/// firmware 側 `LockPort`: 現在状態は LOCK_STATE、適用は apply_target。
struct FwLockPort;
impl LockPort for FwLockPort {
    fn current(&self) -> LockState {
        LOCK_STATE.lock(|c| c.get())
    }
    fn apply(&self, target: LockState) {
        apply_target(target);
    }
}
```

- [ ] **Step 3: serve ループを新シグネチャに繋ぐ**

`main` の TCP 受付ループ周辺（旧 `let mut controller = LockController::new();` と `let sink = SignalSink(&SERVO_CMD);`）を置き換える:

```rust
    let mut rx_buf = [0u8; 512];
    let mut tx_buf = [0u8; 512];
    let port = FwLockPort;

    loop {
        let mut socket = TcpSocket::new(stack, &mut rx_buf, &mut tx_buf);
        control.gpio_set(0, false).await; // 待受中: オンボード LED 消灯
        if let Err(e) = socket.accept(LOCK_PORT).await {
            warn!("accept failed: {:?}", e);
            continue;
        }
        info!("client connected on :{}", LOCK_PORT);
        control.gpio_set(0, true).await; // 接続中: オンボード LED 点灯
        if let Err(e) = serve_connection(&mut socket, &port).await {
            warn!("serve error: {:?}", e);
        }
        info!("client disconnected");
    }
```

- [ ] **Step 4: ダミーブロブを用意（実ブロブが無い場合）**

```bash
mkdir -p crates/firmware/cyw43-firmware
[ -s crates/firmware/cyw43-firmware/43439A0.bin ] || touch crates/firmware/cyw43-firmware/43439A0.bin
[ -s crates/firmware/cyw43-firmware/43439A0_clm.bin ] || touch crates/firmware/cyw43-firmware/43439A0_clm.bin
```

- [ ] **Step 5: ファームのコンパイルと lint を確認**

Run: `nix develop -c cargo check -p smtlk-firmware --locked --target thumbv6m-none-eabi`
Expected: コンパイル成功。
Run: `nix develop -c cargo clippy -p smtlk-firmware --locked --target thumbv6m-none-eabi -- -D warnings`
Expected: warning なしで成功。

- [ ] **Step 6: commit**

```bash
git add crates/firmware/src/main.rs
git commit -m "feat(firmware): LOCK_STATE 単一ソース + FwLockPort 配線"
```

---

## Task 4: 二色ステータス LED（GP16=赤 / GP18=黄緑）を servo_task に追加

**Files:**
- Modify: `crates/firmware/src/main.rs`

**Interfaces:**
- Consumes: `LockState`, `LOCK_STATE`（Task 3）、`SERVO_CMD`（既存）。
- Produces: `servo_task(servo, led_r, led_g)` が駆動後に LED をセット。`fn set_status_led(&mut Output, &mut Output, LockState)`。

- [ ] **Step 1: LED セットのヘルパを追加**

`main.rs`（`apply_target` の近く）に追加:

```rust
/// 二色ステータス LED を状態に合わせて点灯する（施錠=赤 / 解錠=黄緑、同時点灯はしない）。
fn set_status_led(led_r: &mut Output<'static>, led_g: &mut Output<'static>, state: LockState) {
    match state {
        LockState::Locked => {
            led_r.set_high();
            led_g.set_low();
        }
        LockState::Unlocked => {
            led_r.set_low();
            led_g.set_high();
        }
    }
}
```

- [ ] **Step 2: servo_task を LED 所有に変更**

既存 `servo_task` を置き換える:

```rust
/// 指令を待ってサーボをワンショット駆動し、二色 LED を最新状態に更新し続けるタスク。
#[embassy_executor::task]
async fn servo_task(
    mut servo: Servo<'static>,
    mut led_r: Output<'static>,
    mut led_g: Output<'static>,
) -> ! {
    // 起動時は安全側 Locked を表示（LOCK_STATE 初期値に追従）。
    set_status_led(&mut led_r, &mut led_g, LOCK_STATE.lock(|c| c.get()));
    loop {
        let state = SERVO_CMD.wait().await;
        info!("servo: move_to {}", state);
        servo.move_to(state).await;
        set_status_led(&mut led_r, &mut led_g, state);
    }
}
```

- [ ] **Step 3: main で LED 出力を生成して渡す**

`main` のサーボ初期化部（`spawner.spawn(servo_task(servo).unwrap());` の行）を置き換える。既存ファイルの spawn 記法（`spawner.spawn(task(...).unwrap())` の形）に合わせ、ここは変えない:

```rust
    // サーボ駆動: PWM 信号 = GP15（slice7 ch B）、電源ゲート = GP14（active-high）。
    let gate = Output::new(p.PIN_14, Level::Low);
    let servo_pwm = Pwm::new_output_b(p.PWM_SLICE7, p.PIN_15, PwmConfig::default());
    let servo = Servo::new(servo_pwm, gate);
    // 二色ステータス LED: 赤=GP16（施錠）, 黄緑=GP18（解錠）。コモンカソード、active-high。
    let led_r = Output::new(p.PIN_16, Level::Low);
    let led_g = Output::new(p.PIN_18, Level::Low);
    spawner.spawn(servo_task(servo, led_r, led_g).unwrap());
```

- [ ] **Step 4: コンパイルと lint を確認**

Run: `nix develop -c cargo check -p smtlk-firmware --locked --target thumbv6m-none-eabi`
Expected: コンパイル成功。
Run: `nix develop -c cargo clippy -p smtlk-firmware --locked --target thumbv6m-none-eabi -- -D warnings`
Expected: warning なしで成功。

- [ ] **Step 5: commit**

```bash
git add crates/firmware/src/main.rs
git commit -m "feat(firmware): 二色ステータス LED（GP16=赤/GP18=黄緑）を servo_task に追加"
```

---

## Task 5: ボタン（GP17・内部プルアップ・トグル）を実装（#27 クローズ）

**Files:**
- Modify: `crates/firmware/src/main.rs`

**Interfaces:**
- Consumes: `LOCK_STATE`/`apply_target`（Task 3）、`LockState::toggled`（Task 1）。
- Produces: `button_task(btn: Input<'static>)`。

- [ ] **Step 1: import に Input/Pull を追加**

`main.rs` の gpio import を拡張:

```rust
use embassy_rp::gpio::{Input, Level, Output, Pull};
```

- [ ] **Step 2: button_task を追加**

`servo_task` の近くに追加:

```rust
/// GP17 のタクトスイッチ（内部プルアップ・アクティブ Low）を監視し、押下ごとにロックをトグルする。
/// 内部プルアップに依存（外付け抵抗なし＝ Issue #27 の方針）。20ms デバウンスでチャタを除く。
#[embassy_executor::task]
async fn button_task(mut btn: Input<'static>) -> ! {
    loop {
        btn.wait_for_falling_edge().await; // 押下（High→Low）
        Timer::after(Duration::from_millis(20)).await; // デバウンス
        if btn.is_low() {
            let target = LOCK_STATE.lock(|c| c.get()).toggled();
            info!("button: toggle -> {}", target);
            apply_target(target);
        }
        btn.wait_for_high().await; // リリースまで待ち、押しっぱなしの連発を防ぐ
    }
}
```

- [ ] **Step 3: main でボタンを生成して spawn**

`main` の LED/サーボ spawn の近くに追加:

```rust
    // ボタン: GP17 内部プルアップ（アクティブ Low）。押下でロックをトグル。
    let button = Input::new(p.PIN_17, Pull::Up);
    spawner.spawn(button_task(button).unwrap());
```

- [ ] **Step 4: コンパイルと lint を確認**

Run: `nix develop -c cargo check -p smtlk-firmware --locked --target thumbv6m-none-eabi`
Expected: コンパイル成功。
Run: `nix develop -c cargo clippy -p smtlk-firmware --locked --target thumbv6m-none-eabi -- -D warnings`
Expected: warning なしで成功。

- [ ] **Step 5: core の host テストが依然通ることを確認（回帰なし）**

Run: `nix develop -c cargo host-test`
Expected: 全テスト PASS。

- [ ] **Step 6: commit**

```bash
git add crates/firmware/src/main.rs
git commit -m "feat(firmware): GP17 ボタンで施錠/解錠トグル（内部プルアップ, #27 クローズ）"
```

---

## Task 6: 回路ネットリストを二色 LED + GP18 + Rled2 に更新

**Files:**
- Modify: `circuit/netlist.py`

**Interfaces:**
- Produces: GP18=`led_g`、`D1` 二色 LED（R/G/K）、`Rled2`(330R) を含む BOM / from-to。

- [ ] **Step 1: GPIO に led_g を追加し led をリネーム**

`circuit/netlist.py:71` を変更:

```python
GPIO = {"servo": "GP15", "gate": "GP14", "led_r": "GP16", "led_g": "GP18", "btn": "GP17"}
```

- [ ] **Step 2: PARTS を更新**

`PARTS` の `U1` と `D1` を変更し、`Rled2` を追加:

```python
    "U1": ["VBUS", "GND", GPIO["servo"], GPIO["gate"], GPIO["led_r"], GPIO["led_g"], GPIO["btn"]],
```
```python
    "Rled": ["1", "2"],
    "Rled2": ["1", "2"],
```
```python
    "D1": ["R", "G", "K"],
```

- [ ] **Step 3: PART_META を更新**

```python
    "Rled": ("Resistor", "330R"),
    "Rled2": ("Resistor", "330R"),
```
```python
    "D1": ("2-color LED (R/YG, common-cathode)", "OSRGHC5B32A"),
```

- [ ] **Step 4: build_nets の LED 配線を二色化**

`build_nets` の `GND` リストはそのまま（`("D1", "K")` が共通カソードとして既に含まれる）。`LED_DRV` / `LED_A` の 2 行を、次の 4 行に置き換える:

```python
        "LED_DRV_R": [("U1", gpio["led_r"]), ("Rled", "1")],
        "LED_A_R": [("Rled", "2"), ("D1", "R")],
        "LED_DRV_G": [("U1", gpio["led_g"]), ("Rled2", "1")],
        "LED_A_G": [("Rled2", "2"), ("D1", "G")],
```

- [ ] **Step 5: ネットリストテストを通す**

Run: `nix develop -c ./test/netlist_test.py`
Expected: ERC エラーなしで PASS（終了コード 0）。失敗時は未参照ピン/未定義参照を表示するので、該当の PARTS/NETS の綴りを修正する。

- [ ] **Step 6: commit**

```bash
git add circuit/netlist.py
git commit -m "feat(circuit): 二色LED(GP16赤/GP18黄緑)+Rled2 に更新"
```

---

## Task 7: ドキュメント更新（parts-selection.md / README.md / main.rs コメント）

**Files:**
- Modify: `docs/parts-selection.md`
- Modify: `README.md`
- Modify: `crates/firmware/src/main.rs`（モジュールコメント）

- [ ] **Step 1: parts-selection.md メイン表を更新**

`D1` 行を二色 LED へ差し替え、`Rled` 行の必要数を 2 にする:

```markdown
| Rled 330Ω | カーボン抵抗(炭素皮膜抵抗) 1/4W330Ω | 秋月 | [R-25331](https://akizukidenshi.com/catalog/g/g125331/) | ¥180 | 100 | 2 | ¥4 |
| D1 2色LED | 2色LED 赤・黄緑5mm カソードコモン 乳白色 OSRGHC5B32A（10個入） | 秋月 | [I-06314](https://akizukidenshi.com/catalog/g/gI-06314/) | ¥150 | 10 | 1 | ¥15 |
```

（旧 `Rled 330Ω`（必要数1, 按分¥2）と旧 `D1 LED`（OSDR5113A, I-11655）の行を置換。）

- [ ] **Step 2: 概算サマリを更新**

`docs/parts-selection.md` の「概算サマリ」節の数値を再計算して反映する。変更点:
- ①理論按分: D1 ¥20→¥15（−¥5）、Rled 按分 ¥2→¥4（+¥2）。差し引き −¥3 → ¥3,235 を **¥3,232** に更新。
- ②実支出: 旧 D1 単品 ¥20 を新 D1 10個パック ¥150 に差し替え（+¥130）。¥3,975 を **¥4,105** に更新。内訳の秋月額も同額に更新。
- 補足文の数量按分に齟齬がないか確認する。

- [ ] **Step 3: 購入先まとめ表を更新**

`docs/parts-selection.md` の「購入先まとめ」表の D1 行を二色 LED に差し替え、Rled 行を「330Ω（100本入）×2本使用」に更新:

```markdown
| 秋月電子通商 | [R-25331](https://akizukidenshi.com/catalog/g/g125331/) | カーボン抵抗 1/4W 330Ω（100本入, 2本使用） |
| 秋月電子通商 | [I-06314](https://akizukidenshi.com/catalog/g/gI-06314/) | 2色LED 赤・黄緑 5mm カソードコモン 乳白色 OSRGHC5B32A（10個入） |
```

- [ ] **Step 4: 備考に二色 LED の注意を追記**

「代替候補」の旧・単色赤 LED 10個パック（I-01318）の行を削除し、「注意点」節に追記:

```markdown
- 二色LED（D1, OSRGHC5B32A）はコモンカソード。3 本足のうち共通カソード（K）を GND、赤アノード（R）を GP16、黄緑アノード（G）を GP18 へ。足の並びはデータシートで確認すること。赤・黄緑とも Vf=2.1V のため抵抗は両側 330Ω で明るさが揃う。施錠=赤・解錠=黄緑で点灯し、同時点灯はしない。
```

- [ ] **Step 5: README.md を更新**

`README.md` の TCP セクション（84 行目付近「接続中はオンボード LED が点灯する。」）の直後に、状態表示とボタンの説明を追記:

```markdown

ロック状態は外付けの二色LED（D1）で表示する（施錠=赤 GP16 / 解錠=黄緑 GP18、コモンカソード）。
オンボード LED（CYW43）は TCP 接続状態の表示で、役割を分担する。
GP17 のタクトスイッチを押すと施錠⇄解錠をトグルできる（室内側の手動操作）。ボタンは
Pico W の内部プルアップを使う（外付けプルアップ抵抗は付けない）。ボタン操作も TCP STATUS に反映される。
```

- [ ] **Step 6: main.rs のモジュールコメントを更新**

`crates/firmware/src/main.rs` 冒頭のモジュールコメントの「積み残し」節（`//!   - 手回し後の状態再同期・省電力運用`）の前に、実装済みの旨を反映:

```rust
//! ロック状態は単一ソース `LOCK_STATE` に集約し、TCP コマンド・GP17 ボタン（トグル）・
//! 二色ステータス LED（GP16=赤=施錠 / GP18=黄緑=解錠）が同じ状態を参照する。
//! オンボード LED（CYW43）は TCP 接続状態の表示。ボタンは内部プルアップ（アクティブ Low）。
//!
//! ここから先（スマートロック本体）の積み残し:
//!   - 手回し後の状態再同期・省電力運用
```

- [ ] **Step 7: 最終確認**

Run: `nix develop -c cargo host-test`
Expected: PASS。
Run: `nix develop -c cargo check -p smtlk-firmware --locked --target thumbv6m-none-eabi`
Expected: コンパイル成功。

- [ ] **Step 8: commit**

```bash
git add docs/parts-selection.md README.md crates/firmware/src/main.rs
git commit -m "docs: 二色LED・GP17ボタン・GP18 を反映（parts-selection/README/firmware コメント）"
```

---

## 完了条件

- `nix develop -c cargo host-test` 全 PASS（`decide`/`toggled`/`serve_connection` mock）。
- `nix develop -c cargo check -p smtlk-firmware --locked --target thumbv6m-none-eabi` 成功、clippy warning なし。
- `nix develop -c ./test/netlist_test.py` PASS。
- GP16(赤)/GP18(黄緑)/GP17(ボタン) がファームで駆動・参照され、状態が `LOCK_STATE` に一元化、STATUS がボタン操作を反映。
- ドキュメント（parts-selection / README / main.rs コメント）が実装と整合。
- Issue #16 を満たし、#27 を内部プルアップ採用＋ドキュメント明記でクローズ可能。
```

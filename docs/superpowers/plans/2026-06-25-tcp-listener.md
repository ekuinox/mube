# TCP リスナーのトレイト化とモック通しテスト 実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 遠隔ロック操作の serve ループ（読む→行分割→`handle_line`→応答→サーボ送出、接続ライフサイクル込み）を `embedded-io-async` トレイト境界で `smtlk-core` に置き、host でモック通しテストする。firmware は `TcpSocket` を渡すアダプタ配線のみ。

**Architecture:** `smtlk-core` に `ServoSink` トレイトと async `serve_connection<T: Read+Write, S: ServoSink>` を新設。host テストはメモリ上の `MockTransport`（`embedded_io_async::{Read,Write}` 実装）＋ `MockSink` を `embassy_futures::block_on` で回す。firmware は `SignalSink`（`SERVO_CMD.signal` を叩く）と TCP リスナタスクを足し、既存のデモループを撤去する。

**Tech Stack:** Rust（firmware は `#![no_std]`、core は no_std だが host テスト可能）、embassy（rp/net/sync/time/futures）、`embedded-io-async`、RP2040、ビルドは Nix devShell。

## Global Constraints

- ビルド・検証は Nix devShell 経由: `export PATH="/nix/var/nix/profiles/default/bin:$HOME/.cargo/bin:$PATH"` してから `nix develop -c cargo ...`。
- host テスト: `nix develop -c cargo host-test`（alias = `cargo test -p smtlk-core --target aarch64-unknown-linux-gnu`）。firmware クロスビルド: `nix develop -c cargo build`（thumbv6m）。
- `smtlk-core` は `#![cfg_attr(not(test), no_std)]`。本サイクルで増える依存は通常依存 `embedded-io-async = "0.6"` と dev-dependency `embassy-futures = "0.1"` のみ。`heapless` は使わず素の配列＋カーソル。
- I/O 抽象は自前トレイトを作らず `embedded-io-async` の `Read`/`Write` に乗る（embassy-net `TcpSocket` が実装済み）。
- 検証の足回りは embassy 優先: host テストの async 駆動は `embassy_futures::block_on`（`futures`/`tokio` を使わない）。
- `serve_connection` の挙動: read 0 バイト = 接続終了 → `Ok(())`。read/write エラー → `Err(T::Error)`。長すぎ行（`\n` 前に `LINE_MAX` 満杯）→ `ERR\n` を一度送り次の `\n` まで読み捨て。改行なしで接続終了した末尾バイトはコマンド実行しない。
- `LINE_MAX = 32`。TCP ポート `LOCK_PORT = 6000`。同時1接続のみ。`LockController` はデバイスに1個で接続をまたいで状態保持。
- 応答は全て `&'static str`（`Outcome.reply`）。既存の WiFi/サーボ土台と `servo_task`/`SERVO_CMD` は不変。既存の「3秒自動トグル」デモループは撤去。

---

### Task 1: smtlk-core に serve_connection とモック通しテスト（TDD）

I/O トレイト境界で serve ループを実装し、host モックテストで通し検証する。

**Files:**
- Modify: `crates/smtlk-core/Cargo.toml`（`embedded-io-async` 依存と `embassy-futures` dev-dependency 追加）
- Modify: `crates/smtlk-core/src/lib.rs`（`pub mod serve;` と re-export 追加）
- Create: `crates/smtlk-core/src/serve.rs`（`ServoSink`・`serve_connection`・host テスト）

**Interfaces:**
- Consumes: `crate::lock::{LockController, LockState}`、`embedded_io_async::{Read, Write}`
- Produces:
  - `pub const LINE_MAX: usize = 32;`
  - `pub trait ServoSink { fn send(&self, state: LockState); }`
  - `pub async fn serve_connection<T, S>(transport: &mut T, controller: &mut LockController, sink: &S) -> Result<(), T::Error> where T: embedded_io_async::Read + embedded_io_async::Write, S: ServoSink`

- [ ] **Step 1: core に依存追加、モジュール宣言、serve.rs 骨格＋最初の失敗テスト**

`crates/smtlk-core/Cargo.toml` を次にする（`[dependencies]` に `embedded-io-async`、新規 `[dev-dependencies]`）:
```toml
[package]
name = "smtlk-core"
version = "0.1.0"
edition = "2021"
license = "MIT OR Apache-2.0"
description = "Hardware-agnostic lock-control logic for smtlk (host-testable)"

[dependencies]
defmt = { version = "0.3", optional = true }
embedded-io-async = "0.6"

[dev-dependencies]
embassy-futures = "0.1"

[features]
defmt = ["dep:defmt"]
```

`crates/smtlk-core/src/lib.rs` にモジュールと re-export を追加:
```rust
//! ハード非依存のロック制御ロジック。host で cargo test できる
//! （firmware からは no_std 依存として使う）。
#![cfg_attr(not(test), no_std)]

pub mod command;
pub mod lock;
pub mod serve;
pub mod servo_math;

pub use lock::{LockController, LockState, Outcome};
pub use serve::{serve_connection, ServoSink, LINE_MAX};
```

`crates/smtlk-core/src/serve.rs` を作成（`serve_connection` は一旦 `todo!()`、モックと最初のテストを置く）:
```rust
//! TCP 等のバイトストリーム上でロックコマンドを捌く serve ループ。
//! I/O は `embedded-io-async` のトレイト境界で受けるので、firmware は `TcpSocket` を、
//! テストはメモリ上のモックを渡せる。

use crate::lock::{LockController, LockState};
use embedded_io_async::{Read, Write};

/// 1 行の最大バイト数。これを超えて改行が来ない行は不正として読み捨てる。
pub const LINE_MAX: usize = 32;

/// サーボへ駆動状態を渡す同期の口。firmware は `Signal::signal` を、テストは記録用を実装する。
pub trait ServoSink {
    fn send(&self, state: LockState);
}

/// 1 接続を捌く。read が 0 を返す（接続終了）まで、受信を行に切って `handle_line` し、
/// 応答を書き、サーボ指令があれば `sink` へ送る。read/write エラーはそのまま返す。
pub async fn serve_connection<T, S>(
    transport: &mut T,
    controller: &mut LockController,
    sink: &S,
) -> Result<(), T::Error>
where
    T: Read + Write,
    S: ServoSink,
{
    let _ = (transport, controller, sink);
    todo!()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::lock::LockController;
    use core::cell::RefCell;
    use embassy_futures::block_on;
    use std::vec::Vec;

    /// スクリプトされた read チャンク列を順に返し、尽きたら Ok(0)=EOF。write は out に追記。
    /// 注: 各チャンクは 1 回の read で返す。serve 側の read バッファは 64 バイトなので、
    /// テストのチャンクは 64 バイト以下にすること。
    struct MockTransport {
        chunks: Vec<Vec<u8>>,
        idx: usize,
        out: Vec<u8>,
    }
    impl MockTransport {
        fn new(chunks: &[&[u8]]) -> Self {
            Self {
                chunks: chunks.iter().map(|c| c.to_vec()).collect(),
                idx: 0,
                out: Vec::new(),
            }
        }
    }

    #[derive(Debug)]
    struct MockError;
    impl embedded_io_async::Error for MockError {
        fn kind(&self) -> embedded_io_async::ErrorKind {
            embedded_io_async::ErrorKind::Other
        }
    }
    impl embedded_io_async::ErrorType for MockTransport {
        type Error = MockError;
    }
    impl Read for MockTransport {
        async fn read(&mut self, buf: &mut [u8]) -> Result<usize, MockError> {
            if self.idx >= self.chunks.len() {
                return Ok(0);
            }
            let chunk = &self.chunks[self.idx];
            self.idx += 1;
            let n = chunk.len().min(buf.len());
            buf[..n].copy_from_slice(&chunk[..n]);
            Ok(n)
        }
    }
    impl Write for MockTransport {
        async fn write(&mut self, buf: &[u8]) -> Result<usize, MockError> {
            self.out.extend_from_slice(buf);
            Ok(buf.len())
        }
        async fn flush(&mut self) -> Result<(), MockError> {
            Ok(())
        }
    }

    struct MockSink {
        sent: RefCell<Vec<LockState>>,
    }
    impl MockSink {
        fn new() -> Self {
            Self { sent: RefCell::new(Vec::new()) }
        }
    }
    impl ServoSink for MockSink {
        fn send(&self, state: LockState) {
            self.sent.borrow_mut().push(state);
        }
    }

    #[test]
    fn single_command_drives_and_replies() {
        let mut t = MockTransport::new(&[b"UNLOCK\n"]);
        let mut ctrl = LockController::new();
        let sink = MockSink::new();
        block_on(serve_connection(&mut t, &mut ctrl, &sink)).unwrap();
        assert_eq!(&t.out[..], b"UNLOCKED\n");
        assert_eq!(sink.sent.borrow().as_slice(), &[LockState::Unlocked]);
    }
}
```

- [ ] **Step 2: host-test を走らせて失敗を確認**

```bash
export PATH="/nix/var/nix/profiles/default/bin:$HOME/.cargo/bin:$PATH"
nix develop -c cargo host-test 2>&1 | tail -20
```
Expected: `single_command_drives_and_replies` が `todo!`/`not yet implemented` で FAIL（既存テストは PASS）。

- [ ] **Step 3: serve_connection を実装**

`serve.rs` の `serve_connection` 本体を置換:
```rust
pub async fn serve_connection<T, S>(
    transport: &mut T,
    controller: &mut LockController,
    sink: &S,
) -> Result<(), T::Error>
where
    T: Read + Write,
    S: ServoSink,
{
    let mut line = [0u8; LINE_MAX]; // 組み立て中の行
    let mut len = 0usize; // line の有効バイト数
    let mut overflow = false; // 長すぎ行: 次の改行まで読み捨て
    let mut chunk = [0u8; 64]; // read 用

    loop {
        let n = transport.read(&mut chunk).await?;
        if n == 0 {
            return Ok(()); // 接続終了
        }
        for &b in &chunk[..n] {
            if b == b'\n' {
                if overflow {
                    overflow = false; // 行末まで来たので回復
                } else {
                    let outcome = controller.handle_line(&line[..len]);
                    transport.write_all(outcome.reply.as_bytes()).await?;
                    if let Some(state) = outcome.servo {
                        sink.send(state);
                    }
                }
                len = 0;
            } else if overflow {
                // 読み捨て
            } else if len < LINE_MAX {
                line[len] = b;
                len += 1;
            } else {
                // 改行が来ないままバッファ満杯 → 長すぎ行
                transport.write_all(b"ERR\n").await?;
                overflow = true;
                len = 0;
            }
        }
    }
}
```

- [ ] **Step 4: 最初のテストが通ることを確認**

```bash
nix develop -c cargo host-test 2>&1 | tail -20
```
Expected: `single_command_drives_and_replies` が PASS（既存も PASS）。

- [ ] **Step 5: 残りの通しテストを追加**

`serve.rs` の `mod tests` に追記:
```rust
    #[test]
    fn multiple_commands_in_one_read() {
        let mut t = MockTransport::new(&[b"UNLOCK\nSTATUS\nLOCK\n"]);
        let mut ctrl = LockController::new();
        let sink = MockSink::new();
        block_on(serve_connection(&mut t, &mut ctrl, &sink)).unwrap();
        // UNLOCK→UNLOCKED, STATUS→（現状態 Unlocked）UNLOCKED, LOCK→LOCKED
        assert_eq!(&t.out[..], b"UNLOCKED\nUNLOCKED\nLOCKED\n");
        // STATUS は駆動しないので Unlocked, Locked の 2 件だけ
        assert_eq!(
            sink.sent.borrow().as_slice(),
            &[LockState::Unlocked, LockState::Locked]
        );
    }

    #[test]
    fn line_split_across_reads() {
        let mut t = MockTransport::new(&[b"UNL", b"OCK\n"]);
        let mut ctrl = LockController::new();
        let sink = MockSink::new();
        block_on(serve_connection(&mut t, &mut ctrl, &sink)).unwrap();
        assert_eq!(&t.out[..], b"UNLOCKED\n");
        assert_eq!(sink.sent.borrow().as_slice(), &[LockState::Unlocked]);
    }

    #[test]
    fn invalid_line_replies_err_no_drive() {
        let mut t = MockTransport::new(&[b"FOO\n"]);
        let mut ctrl = LockController::new();
        let sink = MockSink::new();
        block_on(serve_connection(&mut t, &mut ctrl, &sink)).unwrap();
        assert_eq!(&t.out[..], b"ERR\n");
        assert!(sink.sent.borrow().is_empty());
    }

    #[test]
    fn overlong_line_discarded_then_recovers() {
        // 40 バイトの無改行（LINE_MAX=32 超）→ ERR、その後の正常行は処理される
        let mut over = Vec::new();
        over.extend_from_slice(&[b'A'; 40]);
        over.extend_from_slice(b"\nLOCK\n");
        let mut t = MockTransport::new(&[over.as_slice()]);
        let mut ctrl = LockController::new();
        let sink = MockSink::new();
        block_on(serve_connection(&mut t, &mut ctrl, &sink)).unwrap();
        assert_eq!(&t.out[..], b"ERR\nLOCKED\n");
        assert_eq!(sink.sent.borrow().as_slice(), &[LockState::Locked]);
    }

    #[test]
    fn trailing_bytes_without_newline_not_executed() {
        let mut t = MockTransport::new(&[b"UNLOCK"]); // 末尾改行なしで EOF
        let mut ctrl = LockController::new();
        let sink = MockSink::new();
        block_on(serve_connection(&mut t, &mut ctrl, &sink)).unwrap();
        assert!(t.out.is_empty());
        assert!(sink.sent.borrow().is_empty());
    }
```

注: `overlong_line_discarded_then_recovers` のチャンクは 46 バイトで 64 以下なので 1 read で返る。`MockTransport` の制約（チャンク ≤ 64 バイト）を満たす。

- [ ] **Step 6: 全テストが通ることを確認**

```bash
nix develop -c cargo host-test 2>&1 | tail -20
```
Expected: 既存 11 ＋ serve 6 = 17 passed、警告なし。失敗したら serve_connection を見直して緑になるまで修正。

- [ ] **Step 7: firmware が引き続き thumbv6m で緑か確認（core 変更の波及チェック）**

```bash
nix develop -c cargo build 2>&1 | tail -5
```
Expected: `Finished`。`serve_connection`/`ServoSink` は firmware から未使用だが lib なので警告は出ない。

- [ ] **Step 8: コミット**

```bash
git add crates/smtlk-core/Cargo.toml crates/smtlk-core/src/lib.rs crates/smtlk-core/src/serve.rs Cargo.lock
git commit -m "feat: smtlk-core に serve_connection（I/O トレイト境界・モック通しテスト）"
```

---

### Task 2: firmware に TCP リスナーを配線（SignalSink、デモループ撤去、compile 緑）

`serve_connection` を embassy-net の `TcpSocket` で駆動する。本タスクの検証は compile 緑（実 TCP の動作確認は次サイクル）。

**Files:**
- Modify: `crates/firmware/src/main.rs`（`SignalSink`、TCP リスナ、デモループ撤去、use 追加）

**Interfaces:**
- Consumes: `smtlk_core::serve::{serve_connection, ServoSink}`、`smtlk_core::LockController`、`smtlk_core::LockState`、既存 `SERVO_CMD`
- Produces: なし（バイナリ配線）

- [ ] **Step 1: use と SignalSink、ポート定数を追加**

`crates/firmware/src/main.rs` の import 群に追加:
```rust
use embassy_net::tcp::TcpSocket;
use smtlk_core::serve::{serve_connection, ServoSink};
use smtlk_core::{LockController, LockState};
```
（既存の `use smtlk_core::LockState;` がある場合は重複させず上の行に統合する。）

`SERVO_CMD` 定義の近くに追加:
```rust
/// 遠隔ロック操作を受ける TCP ポート。
const LOCK_PORT: u16 = 6000;

/// `ServoSink` を `SERVO_CMD` で実装するアダプタ。serve_connection の結論をサーボタスクへ橋渡しする。
struct SignalSink(&'static Signal<CriticalSectionRawMutex, LockState>);

impl ServoSink for SignalSink {
    fn send(&self, state: LockState) {
        self.0.signal(state);
    }
}
```

- [ ] **Step 2: デモループを TCP accept ループへ置換**

`main` 末尾の「施錠/解錠デモ」ループ（`let period = Duration::from_secs(3); ... loop { SERVO_CMD.signal(state); ... }` 全体）を次に置換する。`stack` は既存の `embassy_net::new` の戻り値（DHCP 確立済み）。

```rust
    // 遠隔ロック操作: ポート LOCK_PORT を listen し、1 接続ずつ serve する。
    // 判断ロジックは smtlk_core::serve_connection（host テスト済み）。ここはアダプタ配線。
    let mut rx_buf = [0u8; 512];
    let mut tx_buf = [0u8; 512];
    let mut controller = LockController::new(); // 接続をまたいで状態保持
    let sink = SignalSink(&SERVO_CMD);

    loop {
        let mut socket = TcpSocket::new(stack, &mut rx_buf, &mut tx_buf);
        control.gpio_set(0, false).await; // 待受中: LED 消灯
        if let Err(e) = socket.accept(LOCK_PORT).await {
            warn!("accept failed: {:?}", e);
            continue;
        }
        info!("client connected on :{}", LOCK_PORT);
        control.gpio_set(0, true).await; // 接続中: LED 点灯
        if let Err(e) = serve_connection(&mut socket, &mut controller, &sink).await {
            warn!("serve error: {:?}", e);
        }
        info!("client disconnected");
    }
```

注（embassy-net 0.9 への適合）: `TcpSocket::new` の引数（`stack` の渡し方）、`accept(port)` のシグネチャ、`TcpSocket` が `embedded_io_async::{Read, Write}` を実装するために必要なフィーチャ、`socket` のクローズ手順は、embassy-net 0.9 の API に合わせてビルドエラーに従い調整する。`stack` が `Copy` でループ内で再利用できること、`rx_buf`/`tx_buf` の借用がループで成立することを確認する（各反復で前の `socket` は drop 済み）。

- [ ] **Step 3: 冒頭の積み残しコメントを更新**

`main.rs` 冒頭の doc コメントの積み残し記述（「遠隔操作の口（embassy-net の TCP/HTTP サーバ等）→ SERVO_CMD.signal(state) を叩く」）を、実装済み（TCP リスナが `serve_connection` 経由で `SERVO_CMD` を叩く）に合わせて更新する。デモループ撤去も反映。

- [ ] **Step 4: thumbv6m ビルドと lock 整合を確認**

```bash
export PATH="/nix/var/nix/profiles/default/bin:$HOME/.cargo/bin:$PATH"
nix develop -c cargo build 2>&1 | tail -20
nix develop -c cargo build --locked 2>&1 | tail -5
```
Expected: 両方 `Finished`。embassy-net の API 不一致が出たら Step 2 の注に従って調整し、緑になるまで繰り返す。WiFi/サーボ土台のロジックは変えない。

- [ ] **Step 5: コミット**

```bash
git add crates/firmware/src/main.rs Cargo.lock
git commit -m "feat: TCP リスナーを配線（SignalSink・serve_connection・デモループ撤去）"
```

---

### Task 3: README 更新

遠隔操作の使い方と、host テストで serve ループまで検証できることを README に反映する。

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: なし
- Produces: なし

- [ ] **Step 1: README に遠隔操作と検証範囲を追記**

`README.md` のファーム関連箇所に、既存の文体・見出し階層に合わせて次の主旨を反映する:
- 遠隔操作: WiFi 接続後、TCP ポート 6000 に接続して 1 行ずつコマンドを送る（`LOCK` / `UNLOCK` / `STATUS`、行末 `\n`）。応答は `LOCKED` / `UNLOCKED` / `ERR`。同時1接続、LED は接続中点灯。
- 例（bench 確認時）: `nc <pico-ip> 6000` などで `UNLOCK` を送るとサーボが解錠側へ動く。
- serve ループ（行分割・接続終了・エラー・長すぎ行）は `smtlk_core::serve::serve_connection` に実装され、`nix develop -c cargo host-test` でモック通しテスト済み。未検証で残るのは `TcpSocket` を渡すアダプタ配線のみで、実機での実 TCP 確認が次の作業。

追記例（既存トーンに合わせて調整可）:
```
## 遠隔操作（TCP）
WiFi 接続後、TCP ポート 6000 で 1 接続ずつコマンドを受ける。1 行 1 コマンド（`\n` 区切り）:
LOCK / UNLOCK / STATUS。応答は LOCKED / UNLOCKED / ERR。LED は接続中に点灯。
    nc <pico の IP> 6000
    UNLOCK
serve ループ自体（行分割・接続終了・エラー処理）は smtlk_core::serve_connection に実装され、
cargo host-test でモックにより通しテスト済み。実機での実 TCP 接続確認は次の作業。
```

- [ ] **Step 2: コミット**

```bash
git add README.md
git commit -m "docs: TCP 遠隔操作の使い方と host テスト範囲を README へ反映"
```

---

## 完了条件

- `nix develop -c cargo host-test` が緑（既存 11 ＋ serve 6 = 17 passed）。serve ループ全体（行分割・接続ライフサイクル・エラー・長すぎ行）を実機なしで検証ずみ。
- `nix develop -c cargo build`（thumbv6m）が緑、`cargo build --locked` も緑。WiFi/サーボ土台は不変、デモループは撤去。
- 未検証で残るのは `TcpSocket` を `serve_connection` に渡すアダプタ配線のみ。実機での実 TCP 接続・サーボ動作は次サイクル。

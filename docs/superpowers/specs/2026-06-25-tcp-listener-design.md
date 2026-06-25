# TCP リスナーのトレイト化とモック通しテスト 設計仕様

- 日付: 2026-06-25
- ステータス: 確定
- 対象: 遠隔ロック操作の TCP serve ループを I/O トレイト境界で組み、host でモック通しテストする
- 関連: `2026-06-25-testable-core-design.md`（smtlk-core / LockController）、`2026-06-25-servo-pwm-control-design.md`（Signal 継ぎ目）

## 1. 背景と目的

`smtlk-core` には受信1行を解釈する `LockController::handle_line` が host テスト付きで実装済み。だがその周り（ソケットから読む→行に切る→`handle_line`→応答を書く→サーボへ送る）は firmware にあって未テスト。実機にしばらく触れない期間でも、この serve ループ全体（行分割・接続ライフサイクル・エラー処理）を host でモック通しテストできるようにする。

I/O を標準トレイト境界（`embedded-io-async`）で抽象化し、serve ループ本体を `smtlk-core` へ置く。firmware は `TcpSocket` を渡すだけ、テストはメモリ上のモックを渡すだけ。未検証で残るのは「`TcpSocket` を渡すアダプタ配線」のみにする。

### 設計判断
- I/O は自前トレイトを作らず `embedded-io-async` の `Read`/`Write` に乗る。embassy-net の `TcpSocket` が実装済みで firmware アダプタが消え、未検証の表面積が最小になる。`smtlk-core` が持つ依存は純粋な I/O トレイトだけでハード非依存性は崩れない。
- 検証の足回りは embassy を優先採用する。host テストの async 駆動は `futures`/`tokio` でなく `embassy_futures::block_on`（no_std・no-alloc）。`embassy_sync::pipe::Pipe`（embedded-io-async 実装）も検討したが、EOF やスクリプト入力を表現しにくいため、transport モックは小さな自前実装にする。
- 同時1接続のみ対応（スマートロックに多重接続は不要・YAGNI）。`LockController` はデバイスに1個で接続をまたいで状態を保持する。

## 2. スコープ

- 作るもの:
  - `smtlk-core`: `ServoSink` トレイトと、async な `serve_connection`（行分割・ディスパッチ・応答・サーボ送出・接続ライフサイクル）。
  - host テスト: `MockTransport`（`embedded_io_async::{Read, Write}` 実装）と `MockSink`、`embassy_futures::block_on` による通しテスト。
  - `crates/firmware`: `SignalSink`（`ServoSink` 実装）と TCP リスナタスク。既存のデモループ撤去。
- 作らないもの（非目標）:
  - 同時複数接続、接続ごとのタスク。
  - 認証・暗号化・TLS。まずは平文の最小プロトコル（既存 LOCK/UNLOCK/STATUS）。
  - 実機/シミュレータでの実 TCP 動作確認（次サイクル。本サイクルは host モックテストと firmware の compile 緑まで）。
  - 手回し後の状態再同期・省電力運用の作り込み。

## 3. `smtlk-core` の設計

### 3.1 `ServoSink`（`lock.rs` もしくは新規 `serve.rs`）
```
pub trait ServoSink {
    fn send(&self, state: LockState);
}
```
- サーボへ駆動状態を渡す同期の口。firmware は `Signal::signal` を、テストは記録用モックを実装する。

### 3.2 `serve_connection`（新規 `serve.rs`）
```
pub async fn serve_connection<T, S>(
    transport: &mut T,
    controller: &mut LockController,
    sink: &S,
) -> Result<(), T::Error>
where
    T: embedded_io_async::Read + embedded_io_async::Write,
    S: ServoSink,
```
- 動作:
  1. 固定長バッファ `[u8; LINE_MAX]`（`LINE_MAX = 32`）に `transport.read` で読み足す。
  2. read が 0 バイト = 接続終了 → `Ok(())` を返す。
  3. バッファ内の `\n` ごとに1行を切り出し、`controller.handle_line(line)` を呼ぶ。
  4. `outcome.reply` を `transport.write_all` で送る。
  5. `outcome.servo` が `Some(state)` なら `sink.send(state)`。
  6. read/write がエラーを返したら、そのまま `Err` を上位へ返す（接続を諦める）。
- 長すぎる行（`\n` が来る前にバッファ満杯）: `ERR\n` を一度送り、以降は次の `\n` まで読み捨ててバッファをリセットする（discard モード）。これにより1本の壊れた行が後続を巻き込まない。
- 改行を含まないまま接続終了した末尾の半端なバイトは、コマンドとして実行しない（誤指令防止）。
- 依存: `smtlk-core` の通常依存に `embedded-io-async` を追加（no_std・ハード非依存）。`heapless` は使わず素の配列＋カーソルでバッファを持つ。

### 3.3 host テスト（`serve.rs` の `#[cfg(test)]`）
- `MockTransport`: 入力バイト列（`&[u8]` を分割スクリプト可能）から `read` で少しずつ返し、流し切ったら `Ok(0)`=EOF。`write` は出力 `Vec<u8>` に追記。`embedded_io_async::{Read, Write, ErrorType}` を実装。
- `MockSink`: `send` された `LockState` を `RefCell<Vec<LockState>>` 等に記録。
- 駆動: `embassy_futures::block_on(serve_connection(&mut t, &mut ctrl, &sink))`。
- dev-dependency: `embassy-futures`（テストの `block_on`）。
- 検証ケース:
  - 単一コマンド: `b"UNLOCK\n"` → 出力 `b"UNLOCKED\n"`、sink = `[Unlocked]`。
  - 複数コマンド一括: `b"UNLOCK\nSTATUS\nLOCK\n"` → `b"UNLOCKED\nUNLOCKED\nLOCKED\n"`、sink = `[Unlocked, Locked]`（STATUS は駆動しない）。
  - 行が read をまたぐ分割: `["UNL", "OCK\n"]` → `b"UNLOCKED\n"`、sink = `[Unlocked]`。
  - 不正行: `b"FOO\n"` → `b"ERR\n"`、sink 空。
  - 長すぎ行の読み捨て: `LINE_MAX` 超の無改行 → `ERR\n` 一度、その後の正常行は正しく処理。
  - 改行なし EOF: `b"UNLOCK"`（末尾改行なしで接続終了）→ 出力なし、sink 空。

## 4. `crates/firmware` の配線（compile 緑どまり・次サイクルで実機確認）

- `SignalSink`:
  ```
  struct SignalSink(&'static Signal<CriticalSectionRawMutex, LockState>);
  impl ServoSink for SignalSink { fn send(&self, s: LockState) { self.0.signal(s); } }
  ```
- TCP リスナ: ポート定数 `const LOCK_PORT: u16 = 6000;`（ファイル先頭に隔離、後で変更容易）。WiFi/DHCP 確立後、`embassy_net::tcp::TcpSocket` で `LOCK_PORT` を listen し、1接続ずつ accept → デバイス共有の `LockController`（1個・接続をまたいで状態保持）と `SignalSink` を渡して `serve_connection` → 切れたら次を accept。
- 既存の「3秒ごと自動トグル」のデモループは撤去。`servo_task` と `SERVO_CMD` はそのまま（`SignalSink` が `SERVO_CMD` を叩く）。
- LED: 接続中インジケータとして使う（クライアント接続中は点灯など、生存確認）。詳細は実装プランで詰める。
- 既存の WiFi 接続ロジック（join→DHCP→IP 表示）は不変。

## 5. 検証方法

- `nix develop -c cargo host-test`: `serve_connection` の通しテスト（§3.3 の全ケース）と既存 core テストが緑。serve ループ全体（行分割・接続終了・エラー・長すぎ行）を実機なしで検証できる。
- `nix develop -c cargo build`（thumbv6m クロス）: firmware が緑。デモループ撤去後も WiFi/サーボ土台は不変。
- `nix develop -c cargo build --locked`: Cargo.lock 整合。
- ⚠️ 実機での実 TCP 接続・サーボ動作は対象外（次サイクル）。未検証で残るのは `TcpSocket` を `serve_connection` に渡すアダプタ配線のみ。

## 6. リスクと留意

- `embedded-io-async` の `Read`/`Write`/`ErrorType` のシグネチャは版で差があり得る。firmware 既存版（`embedded-io-async = "0.6"`）に合わせ、`TcpSocket` が同じ版のトレイトを実装することを確認する。
- `serve_connection` のジェネリック境界とライフタイムが `TcpSocket`（借用・`'static` 周り）で満たせること。満たせない場合は配線側で調整（core のテストには影響しない）。
- `embassy_futures::block_on` は host でも動くが、テストが将来 await をまたぐ並行モック（Pipe 双方向等）に発展する場合は再検討する。本サイクルはスクリプト入力＋EOF の決定的モックに限定。
- LED の扱いはハード接合部であり host テスト対象外。挙動の確定は bench 作業に委ねる。

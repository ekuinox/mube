# host テスト可能な core の確立（ロック制御ロジックの分離）設計仕様

- 日付: 2026-06-25
- ステータス: 確定
- 対象: ファームのハード非依存ロジックを `smtlk-core` に分離し、実機なしで `cargo test` 検証できる土台を作る
- 関連: `2026-06-25-servo-pwm-control-design.md`（サーボ駆動・Signal 継ぎ目）、`be89342`（WiFi 土台）

## 1. 背景と目的

しばらく実機での動作確認ができない期間に、品質を落とさず前進したい。現状ファームは `#![no_std]` バイナリで、検証は「`cargo build` 緑」しかなく、実際の挙動は bench が要る。

そこで「遠隔ロック操作」を二層に割る:

- 頭（ロジック）: 受信バイト→コマンド解釈、施錠状態の遷移、応答の組み立て。ハード非依存で host で完全にテストできる。
- 手足（I/O）: embassy-net のソケット I/O とサーボ駆動。実機 or シミュレータが要る。

本サイクルは頭を `smtlk-core` として切り出し、host ユニットテストで作り込む。手足（TCP ソケット配線）は検証手段が整ってから差し込む薄い続きとする。

### 設計判断
- 検証できない塊を最小化するため、ハード/ネットワークに触れない判断ロジックを全部テスト可能な単位へ隔離する。残る未検証は薄い I/O 接合部だけになる。
- シミュレータ（Wokwi/Renode）は embassy の cyw43 PIO-SPI ドライバを忠実に回せる確証がなく、トークン/アカウントも要るため、本サイクルでは採らない。host テストで堅く積む（実機復帰後に別途スパイク）。

## 2. スコープ

- 作るもの:
  - ルートを Cargo workspace 化し、`crates/firmware`（現 `src/` 移設）と `crates/smtlk-core`（新規 lib）に分ける。
  - `smtlk-core`: ハード非依存ロジック（`LockState`・コマンドのパース・ロック状態機械・サーボ角度の純粋変換）を host テスト付きで実装。
  - host テスト用の cargo alias（`host-test`）。
- 作らないもの（非目標・次サイクル）:
  - embassy-net の TCP リスナ（ソケット I/O）。本サイクルでは `LockController`/`command` を「テスト済みだが未配線」で残す。
  - 実機/シミュレータでの動作確認。
  - ボタン（GP17）/ ステータス LED（GP16）の本実装、省電力運用の作り込み。
  - 認証・暗号化など TCP プロトコルの堅牢化（まずは平文の最小プロトコル）。

## 3. リポジトリ構成

```
Cargo.toml                       # [workspace] members = ["crates/firmware", "crates/smtlk-core"]（仮想マニフェスト）
.cargo/config.toml               # thumbv6m 強制 + probe-rs runner + [alias] host-test
crates/
  firmware/
    Cargo.toml                   # 現 smtlk-firmware パッケージ。smtlk-core に依存（features=["defmt"]）
    build.rs
    memory.x
    cyw43-firmware/43439A0*.bin
    src/{main,config,servo}.rs
  smtlk-core/
    Cargo.toml                   # 依存ほぼゼロ。defmt は任意フィーチャ
    src/{lib,lock,command,servo_math}.rs
scad/ circuit/ viewer/ docs/     # ルート据え置き（firmware とは無関係）
```

移設で動く相対パスを必ず修正する: `include_bytes!("../cyw43-firmware/…")`、`memory.x`、`build.rs`、`.cargo` の配置。

## 4. `smtlk-core` のロジック設計

### 4.1 サーボ角度（`servo_math.rs`）
- サーボ駆動の数値変換（純粋関数）。`pulse_us(deg) -> u16` とキャリブ定数を servo-pwm 仕様から移設。
- 期待値: `pulse_us(0)=1000`, `pulse_us(90)=1500`, `pulse_us(180)=2000`。u32 中間計算でオーバーフロー回避。
- `fixed`(PWM 分周)には依存しない。分周は firmware 側の責務。

### 4.2 ロック状態（`lock.rs`）
- `pub enum LockState { Locked, Unlocked }`（`Copy`。`defmt::Format` は任意フィーチャ時のみ導出）。
- `pub struct LockController { state: LockState }`。初期状態は `Locked`（起動時は安全側に施錠）。
- `pub struct Outcome { servo: Option<LockState>, reply: &'static str }`。
- `pub fn handle_line(&mut self, line: &[u8]) -> Outcome`:
  - `LOCK`   → `state=Locked`、`Outcome{ servo: Some(Locked),   reply: "LOCKED\n" }`
  - `UNLOCK` → `state=Unlocked`、`Outcome{ servo: Some(Unlocked), reply: "UNLOCKED\n" }`
  - `STATUS` → `Outcome{ servo: None, reply: 現状態の "LOCKED\n"/"UNLOCKED\n" }`
  - パース失敗 → `Outcome{ servo: None, reply: "ERR\n" }`、状態は不変
- 設計判断: コマンドは現状態と同じでも常にサーボ指令を出す（`servo: Some(..)`）。手回し後でも位置を再主張でき安全、かつ core は物理状態を持たず決定的でテストしやすい。`reply` は全て `&'static str`（no_std でアロケータ不要）。

### 4.3 コマンドのパース（`command.rs`）
- `pub enum Command { Lock, Unlock, Status }`。
- `pub fn parse(line: &[u8]) -> Option<Command>`。不正は `None`。
- 受理規則: 前後 ASCII 空白（`\r`/`\n`/スペース/タブ）をトリム、大小文字無視。`LOCK`/`UNLOCK`/`STATUS` のみ受理。

### 4.4 firmware からの利用
- `servo.rs` は core の `servo_math`/`LockState` を使う。デモループの挙動は不変（compile 緑を維持）。
- `command`/`LockController` は本サイクルでは未配線（次サイクルの TCP リスナが利用）。core lib の未使用 public 要素は警告を出さない。

## 5. ビルド/テスト構成

- ルート `.cargo/config.toml` は `build.target = thumbv6m-none-eabi` と probe-rs runner を維持。`firmware` は no_std/no_main で host ビルド不可のため既定 thumbv6m が正しい。`smtlk-core` は `not(test)` で no_std なので thumbv6m に乗る。
- host テストはターゲットを明示上書きする alias を追加:
  ```toml
  [alias]
  host-test = "test -p smtlk-core --target aarch64-unknown-linux-gnu"
  ```
  `host-test` は cargo alias（外部サブコマンドではない）。dev 環境は nix の aarch64 機に固定のためトリプル直書きで可。host std はツールチェーン同梱で `rust-toolchain.toml` の `targets` 追加不要。
- `smtlk-core` は `#![cfg_attr(not(test), no_std)]`。テストビルド時のみ std が入り host で実行、thumbv6m 依存時は no_std。
- 依存: `smtlk-core` は依存ほぼゼロ。`defmt` は `[features] defmt = ["dep:defmt"]` の任意フィーチャ（firmware が有効化）。`fixed` は firmware に残す。

## 6. 検証方法

- `nix develop -c cargo host-test`: core の host ユニットテストが緑 ← 本サイクルの主検証。
- `nix develop -c cargo build`: firmware（thumbv6m クロス）が緑、デモ挙動不変。
- `nix develop -c cargo build --locked`: Cargo.lock 整合。
- テスト観点（`smtlk-core`）:
  - パース: `LOCK\n` / `lock\n` / `UNLOCK\r\n` / ` STATUS \n` / `""` / `FOO\n`。
  - 状態機械: lock→status→unlock→status の系列、同状態への再 lock が `Some` を返す、不正行が `ERR` を返し state 不変。
  - `pulse_us`: 0/90/180 の期待値。
- ⚠️ 実機/ネットワークでの動作確認は対象外（手足は次サイクル）。

## 7. リスクと留意

- 移設の相対パス崩れ（cyw43-firmware/memory.x/build.rs/.cargo）。移設直後に `cargo build` が緑であることを必ず確認する。
- workspace 既定ターゲットが thumbv6m なので、host テストは alias/`--target` 明示を忘れると thumbv6m を狙って失敗する。検証手順を README に明記。
- host トリプル直書き（aarch64-unknown-linux-gnu）は dev 機固定の前提。別機で動かす場合は alias を調整する旨をコメントに残す。
- `LockController`/`command` がこのサイクルでは未配線。死蔵に見えるが意図的（次サイクルの TCP で配線）。spec/README にその旨を残す。

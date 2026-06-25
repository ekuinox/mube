# サーボ PWM 制御（施錠/解錠駆動）設計仕様

- 日付: 2026-06-25
- ステータス: 確定
- 対象: Pico W ファームウェアで SG90 サーボを PWM 駆動し、サムターンを施錠/解錠する
- 関連: `2026-06-24-pcb-netlist-as-code-design.md`（電気設計・GPIO 割当）、`be89342`（WiFi 土台）

## 1. スコープ

- **作るもの**:
  - `src/servo.rs`: サーボ駆動をカプセル化する `Servo` 型と `LockState`。ワンショット動作（給電→パルス送出→整定待ち→電源カット）。
  - サーボの電源ゲート（GP14, MOSFET 駆動）と PWM 信号（GP15）の協調制御。
  - 指令源を分離する継ぎ目: `embassy_sync::signal::Signal<LockState>`。
  - `src/main.rs`: WiFi 土台を維持したまま、LED 点滅ループを「数秒ごとに lock⇄unlock を Signal へ送るデモ」に発展。
- **前提整備（本作業に含める）**:
  - embassy クレート群を `branch = "main"` 追従から crates.io の公開バージョン指定に切り替え、feature 名ドリフトで壊れているビルドを復旧する。
- **作らないもの（非目標）**:
  - TCP/HTTP など遠隔操作の口（次スコープ。本設計は将来 TCP が差し込める継ぎ目だけ用意する）。
  - ボタン（GP17）/ ステータス LED（GP16）の本実装（次スコープ。LED はデモのハートビート用途のみ）。
  - 手回し後の状態再同期・省電力運用の作り込み（ワンショットで給電断する範囲に留める）。
  - サーボ角度の実機合わせ（定数を1か所に隔離するが、実測値の確定は bench 作業）。

### 設計判断
- 基板が電源ゲート（GP14→Q1）を持つ = 「動作時だけ給電」の思想。よってワンショット駆動とし、整定後は給電断する（唸り・消費電力・サーボ寿命に有利、サムターンは一度回せば物理的に留まるため保持トルク不要）。
- 「誰が指令を出すか（デモ / 将来 TCP）」と「どう物理で回すか（`Servo`）」を `Signal` で分離する。これにより TCP は後から無改修で差し込める。
- embassy を `branch = "main"` のまま放置すると再び壊れる。embassy は crates.io に公開済みのため、git 参照ではなく公開バージョン指定＋`Cargo.lock` コミットに倒す（semver で安定、github fetch 不要、CI/オフラインでも堅い）。

## 2. リポジトリ構成

```
src/
  main.rs    # WiFi/net 初期化（維持）＋ サーボタスク spawn ＋ デモループ
  servo.rs   # 新規: Servo 型・LockState・キャリブ定数・ワンショット move_to
  config.rs  # 既存（WiFi 認証）。変更なし
Cargo.toml   # embassy を rev 固定、feature 名を現行 main に修正
Cargo.lock   # 新規コミット（再現性確保）
```

## 3. モジュール設計

### 3.1 `servo.rs`

- `LockState { Locked, Unlocked }` — 施錠/解錠の2状態。`Copy`。
- キャリブ定数（ファイル冒頭に1か所集約。実機合わせはここだけ触る）:
  - `SERVO_MIN_US = 1000` / `SERVO_MAX_US = 2000` — フルストローク端のパルス幅[µs]。
  - `LOCK_DEG = 0` / `UNLOCK_DEG = 90` — 各状態の角度。
  - `SETTLE_MS = 500` — パルス送出後に到達を待つ時間。
- `deg→µs` 純粋関数 `pulse_us(deg)`:
  - `pulse_us(deg) = SERVO_MIN_US + (SERVO_MAX_US - SERVO_MIN_US) * deg / 180`
  - 期待値: `pulse_us(0)=1000`, `pulse_us(90)=1500`, `pulse_us(180)=2000`。
- `Servo` 構造体:
  - 保持: PWM（GP15, slice7 ch B）と電源ゲート `Output`（GP14）。
  - `async fn move_to(&mut self, state: LockState)`:
    1. ゲート ON（サーボに給電）。
    2. `state`→`deg`→`pulse_us` を計算し PWM コンペア値に設定（PWM enable）。
    3. `SETTLE_MS` 待つ（`embassy_time::Timer`）。
    4. PWM disable ＋ ゲート OFF（給電断）。

### 3.2 PWM 構成

- RP2040 クロック 125MHz。`div = 125` → 1µs/tick、`top = 20000` → 20ms 周期 = 50Hz。
- コンペア値 = パルス幅[µs] が直接書ける（`pulse_us` の戻り値をそのまま使える）。
- GP15 = PWM slice 7 channel B（`Pwm::new_output_b`）。GP14 は素の `Output`（PWM ではなくゲート制御）。

### 3.3 指令の継ぎ目と `main.rs`

- `static SERVO_CMD: Signal<CriticalSectionRawMutex, LockState>` を1個用意。
- サーボタスク: `loop { let s = SERVO_CMD.wait().await; servo.move_to(s).await; }`。
- 本スコープ（デモ）: main のループが数秒ごとに `SERVO_CMD.signal(Locked / Unlocked)` を交互送出。
- 将来（TCP）: 受信ハンドラが同じ `SERVO_CMD.signal(...)` を送るだけ。サーボ側は無改修。
- `Signal` は最新値のみ保持。指令が連続しても最新状態へ収束し、取りこぼしが安全側に働く。

## 4. 前提整備: embassy を crates.io 公開バージョンへ固定

- 現状 `branch = "main"` 追従のため feature 名ドリフトでビルド不能（例: `arch-cortex-m` は現行 `platform-cortex-m`）。
- embassy 全クレートは crates.io に公開済み（確認値）: embassy-executor 0.10.0 / embassy-rp 0.10.0 / embassy-time 0.5.1 / embassy-sync 0.8.0 / embassy-net 0.9.1 / cyw43 0.7.0 / cyw43-pio 0.10.0。
- 手順:
  1. Cargo.toml の git 依存（`branch = "main"`）を crates.io バージョン指定へ置換。
  2. `cargo build` のエラーに従い feature 名を公開版へ総当たり修正（`arch-cortex-m` → `platform-cortex-m` 等）。
  3. WiFi 土台（`PioSpi::new` / `control.join` 等）が公開版 API と食い違う箇所をエラーに従って調整し、引き続きビルドできることを確認。
  4. `cargo build` 緑を確認し `Cargo.lock` をコミット（再現性確保）。
- コミット順: 「embassy 版固定」→「servo モジュール」→「main デモ配線」。

## 5. 検証方法

- `nix develop -c cargo build`（thumbv6m クロス）が緑 — 自動で確認できる範囲。
- `pulse_us` の期待値（§3.1）をコメントで明示。
- 実機動作（サーボが実際に回る／唸らない／突き当てない）は bench で確認する領域:
  - probe-rs もしくは BOOTSEL+UF2 で焼く。
  - 数秒ごとに lock⇄unlock するのを目視。
  - 実機合わせ手順（安全側の狭い MIN/MAX で焼き、唸らない・突き当てない範囲を実測で広げる）を PR/README に明記。サムターンを物理的に壊さないため。
- ⚠️ 自動テストは持たない（no_std 単体クレートで host テストは割に合わない）。compile + bench の二段構え。

## 6. リスクと留意

- **embassy 公開版の API 差**: #1 の WiFi 土台は embassy main の example に倣って書かれているため、`PioSpi::new` / `control.join` など公開版とシグネチャが食い違う恐れ。feature 名修正と併せて、WiFi 土台が引き続きビルドできることを必ず確認する。
- **サーボ個体差**: SG90 はストロークが個体で 500–2500µs に振れる。初期値は安全側（1000–2000）で焼き、実測で広げる。
- **突き当て**: 角度設定を誤るとサムターン/ギアに無理がかかる。bench は手で止められる状態で初回投入する。

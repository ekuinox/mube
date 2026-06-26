# サーボ PWM 制御 実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pico W で SG90 サーボを PWM 駆動し、電源ゲートと協調したワンショット動作でサムターンを施錠/解錠する。指令源は `Signal` で分離し、デモループから駆動する（将来 TCP を無改修で差し込める）。

**Architecture:** 新規 `src/servo.rs` がサーボ駆動（PWM GP15 ＋ 電源ゲート GP14）をカプセル化。`src/main.rs` は既存の WiFi 土台を維持しつつ、`static Signal<LockState>` 経由でサーボタスクへ指令を送るデモループに発展させる。前提として embassy 依存を crates.io 公開バージョンへ固定し、壊れているビルドを復旧する。

**Tech Stack:** Rust（`#![no_std]`）、embassy（executor / rp / time / sync）、RP2040、SG90 サーボ、ビルドは Nix devShell（thumbv6m クロス）。

## Global Constraints

- ターゲットは `thumbv6m-none-eabi`。ビルド・確認は必ず `nix develop -c cargo build` で行う（`nix` は PATH 上にある前提。`cargo` は dev シェルの rustup が供給）。
- クレートは `#![no_std]` バイナリ。host で動く自動テストは持たない（spec §5）。各タスクの検証は「`cargo build` 緑」＋「コメントで固定した期待値」。
- embassy 依存は crates.io 公開バージョン指定（git 参照禁止）。確認済み版: embassy-executor 0.10.0 / embassy-rp 0.10.0 / embassy-time 0.5.1 / embassy-sync 0.8.0 / embassy-net 0.9.1 / cyw43 0.7.0 / cyw43-pio 0.10.0。
- GPIO 割当（`circuit/netlist.py` の `GPIO` と一致させる）: サーボ信号 = GP15、電源ゲート = GP14。GP14 の Q1 は SERVO_RTN（サーボの GND 戻り）を切る低側 N-MOSFET なので、ゲート **High = 給電**（active-high）。
- PWM: GP15 = PWM slice 7 channel B。`div = 125`・`top = 20000` で 50Hz、コンペア値 = パルス幅[µs]。
- WiFi 土台（#1 の `cyw43` / `embassy-net` 初期化）は壊さず維持する。
- embassy は API ドリフトが速い。本プラン中のコードは embassy 0.10 系の想定で書いてあるが、`cargo build` のエラーに従って公開版の正確なシグネチャ（`Pwm` の型・`Config` のフィールド名・ライフタイム）へ合わせること。

---

### Task 1: embassy を crates.io 公開バージョンへ固定し、ビルドを復旧

**Files:**
- Modify: `Cargo.toml`（`[dependencies]` の embassy 7 クレート）
- Create: `Cargo.lock`（コミット対象に追加）

**Interfaces:**
- Consumes: なし（土台修正）
- Produces: `nix develop -c cargo build` が緑になる状態。後続タスクが `embassy_rp::pwm`・`embassy_sync::signal` を使える前提を確立。

- [ ] **Step 1: 現状のビルド失敗を確認（ベースライン）**

Run: `nix develop -c cargo build 2>&1 | tail -20`
Expected: FAIL。`embassy-executor` で `feature \`arch-cortex-m\`` が無い旨のエラー（feature 名ドリフト）。

- [ ] **Step 2: Cargo.toml の embassy 依存を crates.io バージョンへ置換**

`[dependencies]` の embassy 系 7 行を git 参照から版指定へ。feature は現行公開版の名称に合わせる（`arch-cortex-m` → `platform-cortex-m`）。冒頭の「git 追従にしている」旨のコメントも実態に合わせて書き換える。

```toml
# embassy は crates.io 公開版に固定（再現性は版指定＋Cargo.lock で担保）。
# 版を上げる際は各クレートの CHANGELOG と feature 名の変更に注意する。
[dependencies]
embassy-executor = { version = "0.10", features = ["arch-cortex-m", "executor-thread", "executor-interrupt", "defmt"] }
embassy-time = { version = "0.5", features = ["defmt", "defmt-timestamp-uptime"] }
embassy-rp = { version = "0.10", features = ["defmt", "unstable-pac", "time-driver", "critical-section-impl", "rp2040"] }
embassy-sync = { version = "0.8", features = ["defmt"] }
embassy-net = { version = "0.9", features = ["defmt", "tcp", "udp", "dns", "dhcpv4", "medium-ethernet"] }
cyw43 = { version = "0.7", features = ["defmt", "firmware-logs"] }
cyw43-pio = { version = "0.10", features = ["defmt"] }
```

注: `arch-cortex-m` は version="0.10" でのみ正しい feature 名。Step 4 のエラーが「該当 feature 無し」を示したら、エラーメッセージの `available features` 一覧から対応する名前へ各クレート個別に直す（例: `platform-cortex-m`）。git 参照時の `branch = "main"` は HEAD（更に新しい版）を引くため feature 名が違っていた。

- [ ] **Step 3: 既存 WiFi 土台の API 差分を埋める**

`src/main.rs` の WiFi 初期化（`PioSpi::new` / `cyw43::new` / `control.join` / `embassy_net::new`）が公開版でシグネチャが違う場合、Step 4 のビルドエラーに従って引数・型を調整する。ロジック（接続→DHCP→IP 表示）は変えない。差分が無ければ何もしない。

- [ ] **Step 4: ビルドして緑を確認（feature 名・API はエラーに従い修正）**

Run: `nix develop -c cargo build 2>&1 | tail -20`
Expected: 最終的に `Finished` で成功。途中で feature 名や API の不一致が出たら、エラーの `available features` / シグネチャに従って Step 2・Step 3 を修正して再ビルドし、緑になるまで繰り返す。

- [ ] **Step 5: コミット**

```bash
git add Cargo.toml Cargo.lock src/main.rs
git commit -m "build: embassy 依存を crates.io 公開版へ固定しビルド復旧"
```

---

### Task 2: `src/servo.rs` — サーボ駆動モジュール

**Files:**
- Create: `src/servo.rs`

**Interfaces:**
- Consumes: `embassy_rp::pwm::{Pwm, Config}`、`embassy_rp::gpio::Output`、`embassy_time::{Timer, Duration}`。
- Produces:
  - `pub enum LockState { Locked, Unlocked }`（`Copy`、`defmt::Format`）
  - `pub struct Servo<'d>`
  - `pub fn Servo::new(pwm: Pwm<'d>, gate: Output<'d>) -> Servo<'d>`
  - `pub async fn Servo::move_to(&mut self, state: LockState)`
  - PWM 構成定数 `PWM_DIV: u8 = 125`、`PWM_TOP: u16 = 20000`（main 側で初期 `Pwm` を作る際に参照）

- [ ] **Step 1: `pulse_us` の期待値をモジュール doc に固定（テスト代替）**

host テストを持たない方針のため、純粋関数 `pulse_us` の期待値をコメントで明示し、これを検証の拠り所にする。`src/servo.rs` 冒頭に以下を書く。

```rust
//! SG90 サーボ駆動。電源ゲート（GP14）と PWM 信号（GP15）を協調させ、
//! 「給電 → 目標角のパルス送出 → 整定待ち → 給電断」のワンショットで施錠/解錠する。
//!
//! 角度→パルス幅の期待値（`pulse_us`）:
//!   pulse_us(0)   == 1000   // 施錠端
//!   pulse_us(90)  == 1500   // 中点
//!   pulse_us(180) == 2000   // 解錠端（フルストローク上端）
//!
//! 実機合わせはこのファイル冒頭のキャリブ定数 5 つだけを触る。SG90 は個体差が
//! 大きい（フルストロークが 500–2500µs に振れる）。まず安全側（狭い MIN/MAX）で
//! 焼き、唸らない・突き当てない範囲を実測で広げること（サムターン保護のため）。
```

- [ ] **Step 2: キャリブ定数・PWM 定数・`pulse_us`・`LockState` を実装**

```rust
use defmt::Format;
use embassy_rp::gpio::Output;
use embassy_rp::pwm::{Config as PwmConfig, Pwm};
use embassy_time::{Duration, Timer};

// --- キャリブ定数（実機合わせはここだけ触る） ---
const SERVO_MIN_US: u16 = 1000; // フルストローク下端のパルス幅[µs]
const SERVO_MAX_US: u16 = 2000; // フルストローク上端のパルス幅[µs]
const LOCK_DEG: u16 = 0; // 施錠側の角度
const UNLOCK_DEG: u16 = 90; // 解錠側の角度（サムターンの回転量に合わせる）
const SETTLE_MS: u64 = 500; // パルス送出後に到達を待つ時間

// --- PWM 構成（50Hz: div=125 で 1µs/tick、top=20000 で 20ms 周期） ---
pub const PWM_DIV: u8 = 125;
pub const PWM_TOP: u16 = 20000;

/// 角度[deg]→パルス幅[µs]。u16 同士の積は溢れるため u32 で計算する。
/// pulse_us(0)=1000, pulse_us(90)=1500, pulse_us(180)=2000。
const fn pulse_us(deg: u16) -> u16 {
    (SERVO_MIN_US as u32
        + (SERVO_MAX_US - SERVO_MIN_US) as u32 * deg as u32 / 180) as u16
}

/// 施錠/解錠の 2 状態。
#[derive(Clone, Copy, PartialEq, Eq, Format)]
pub enum LockState {
    Locked,
    Unlocked,
}

impl LockState {
    const fn deg(self) -> u16 {
        match self {
            LockState::Locked => LOCK_DEG,
            LockState::Unlocked => UNLOCK_DEG,
        }
    }
}
```

- [ ] **Step 3: `Servo` 構造体とワンショット `move_to` を実装**

```rust
/// サーボ駆動。PWM（GP15 = slice7 ch B）と電源ゲート（GP14, active-high）を保持する。
pub struct Servo<'d> {
    pwm: Pwm<'d>,
    gate: Output<'d>,
    cfg: PwmConfig,
}

impl<'d> Servo<'d> {
    /// 初期状態は「給電断・PWM 停止」。`pwm` は main 側で `Pwm::new_output_b(
    /// PWM_SLICE7, PIN_15, PwmConfig::default())` として渡す。`gate` は GP14。
    pub fn new(pwm: Pwm<'d>, gate: Output<'d>) -> Self {
        let mut cfg = PwmConfig::default();
        cfg.divider = PWM_DIV.into();
        cfg.top = PWM_TOP;
        cfg.compare_b = 0;
        cfg.enable = false;
        let mut servo = Self { pwm, gate, cfg };
        servo.pwm.set_config(&servo.cfg);
        servo.gate.set_low(); // 給電断で待機
        servo
    }

    /// ワンショット駆動: 給電 → 目標角のパルス送出 → 整定待ち → 給電断。
    pub async fn move_to(&mut self, state: LockState) {
        self.gate.set_high(); // Q1 ON = サーボに給電
        self.cfg.compare_b = pulse_us(state.deg());
        self.cfg.enable = true;
        self.pwm.set_config(&self.cfg); // パルス送出開始
        Timer::after(Duration::from_millis(SETTLE_MS)).await;
        self.cfg.enable = false;
        self.pwm.set_config(&self.cfg); // PWM 停止
        self.gate.set_low(); // 給電断（唸り・消費電力・寿命対策）
    }
}
```

注（embassy 0.10 への適合）: `Pwm` のライフタイム/型、`Config` のフィールド名（`divider` / `top` / `compare_b` / `enable`）、`divider` への代入方法（`PWM_DIV.into()` が通らなければ `(PWM_DIV as u16).into()` 等）は、Step 4 のビルドエラーに従って公開版の API へ合わせる。

- [ ] **Step 4: モジュールを宣言してビルド**

`src/main.rs` の `mod config;` の隣に `mod servo;` を追加（まだ未使用の警告は次タスクで解消）。

Run: `nix develop -c cargo build 2>&1 | tail -20`
Expected: `Finished` で成功（`Servo`/`LockState` 未使用の dead_code 警告は許容、または `#[allow(dead_code)]` を一時付与せず Task 3 で解消する想定）。

- [ ] **Step 5: コミット**

```bash
git add src/servo.rs src/main.rs
git commit -m "feat: servo モジュール（ワンショット駆動・電源ゲート協調・キャリブ定数集約）"
```

---

### Task 3: `src/main.rs` — サーボタスク spawn と Signal デモ配線

**Files:**
- Modify: `src/main.rs`（use 追加、`static SERVO_CMD`、`servo_task`、main 内のペリフェラル配線、末尾の点滅ループをデモへ）

**Interfaces:**
- Consumes: Task 2 の `servo::{Servo, LockState, PWM_DIV, PWM_TOP}`。
- Produces: `static SERVO_CMD: Signal<CriticalSectionRawMutex, LockState>`（将来 TCP ハンドラが `SERVO_CMD.signal(state)` で同じ口を叩く継ぎ目）。

- [ ] **Step 1: use と Signal、servo_task を追加**

`src/main.rs` の import 群に追加:

```rust
use embassy_rp::pwm::{Config as PwmConfig, Pwm};
use embassy_sync::blocking_mutex::raw::CriticalSectionRawMutex;
use embassy_sync::signal::Signal;
use servo::{LockState, Servo, PWM_DIV, PWM_TOP};
```

`mod config;` の下に `mod servo;`（Task 2 Step 4 で追加済みなら重複させない）。

`Irqs` 定義の下あたりに、指令の継ぎ目とサーボタスクを追加:

```rust
/// サーボへの施錠/解錠指令。デモループが送り、将来は TCP 受信ハンドラが同じ口を叩く。
/// Signal は最新値のみ保持するため、指令が連続しても安全側（最新状態）へ収束する。
static SERVO_CMD: Signal<CriticalSectionRawMutex, LockState> = Signal::new();

/// 指令を待ってサーボをワンショット駆動し続けるタスク。
#[embassy_executor::task]
async fn servo_task(mut servo: Servo<'static>) -> ! {
    loop {
        let state = SERVO_CMD.wait().await;
        info!("servo: move_to {}", state);
        servo.move_to(state).await;
    }
}
```

- [ ] **Step 2: main 内でサーボを配線して spawn**

`let p = embassy_rp::init(Default::default());` の直後（WiFi 初期化の前）に追加:

```rust
// サーボ駆動: PWM 信号 = GP15（slice7 ch B）、電源ゲート = GP14（active-high）。
let gate = Output::new(p.PIN_14, Level::Low);
let mut servo_cfg = PwmConfig::default();
servo_cfg.divider = PWM_DIV.into();
servo_cfg.top = PWM_TOP;
servo_cfg.enable = false;
let servo_pwm = Pwm::new_output_b(p.PWM_SLICE7, p.PIN_15, servo_cfg);
let servo = Servo::new(servo_pwm, gate);
unwrap!(spawner.spawn(servo_task(servo)));
```

注: `Pwm::new_output_b` の正確な引数順・型（`p.PWM_SLICE7` / `p.PIN_15`）と `Servo::new` に渡す初期 `Pwm` の作り方は embassy 0.10 のシグネチャに合わせる（ビルドエラーに従う）。`PWM_DIV`/`PWM_TOP` は `servo` モジュールの `pub const`。

- [ ] **Step 3: 末尾の LED 点滅ループを施錠/解錠デモへ置換**

現状の最終ループ（`// オンボード LED 点滅` 以降、`let delay = ...; loop { control.gpio_set ... }`）を以下に置換:

```rust
// 施錠/解錠デモ: 数秒ごとに状態を反転して SERVO_CMD へ送る。
// LED は疎通確認のハートビート。将来この送出を TCP 受信ハンドラへ置き換える。
let period = Duration::from_secs(3);
let mut state = LockState::Locked;
loop {
    SERVO_CMD.signal(state);
    control.gpio_set(0, true).await;
    Timer::after(period).await;
    control.gpio_set(0, false).await;
    state = match state {
        LockState::Locked => LockState::Unlocked,
        LockState::Unlocked => LockState::Locked,
    };
}
```

- [ ] **Step 4: 冒頭の積み残しコメントを更新**

`src/main.rs` 冒頭の doc コメントから「SG90 サーボの PWM 制御」の積み残し行を削り、現状（サーボのワンショット駆動をデモループで駆動、TCP は未実装の継ぎ目あり）を反映する。

- [ ] **Step 5: ビルドして緑を確認**

Run: `nix develop -c cargo build 2>&1 | tail -20`
Expected: `Finished` で成功。`Servo`/`LockState` の未使用警告が消えていること。

- [ ] **Step 6: コミット**

```bash
git add src/main.rs
git commit -m "feat: サーボタスクと Signal デモ配線（LED 点滅を施錠/解錠デモへ）"
```

---

### Task 4: README に実機検証手順を追記

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: なし
- Produces: bench での焼き方・実機合わせ手順のドキュメント。

- [ ] **Step 1: ファーム節に bench 検証・実機合わせ手順を追記**

`README.md` のファーム関連の節に、以下の主旨を追記（既存の文体・見出し階層に合わせる）:

```
## サーボ動作確認（bench）
probe-rs か BOOTSEL+UF2 で焼くと、起動・WiFi 接続後に約3秒ごとに施錠⇄解錠を繰り返す
（オンボード LED がハートビート）。サーボ給電は動作時だけ ON（GP14 の電源ゲート）。

実機合わせ: `src/servo.rs` 冒頭のキャリブ定数 5 つ（SERVO_MIN_US / SERVO_MAX_US /
LOCK_DEG / UNLOCK_DEG / SETTLE_MS）だけを調整する。SG90 は個体差が大きいので、
まず安全側（狭い MIN/MAX）で焼き、唸らない・突き当てない範囲を実測で広げること。
初回はサムターンを手で止められる状態で投入する（突き当て保護）。
```

- [ ] **Step 2: コミット**

```bash
git add README.md
git commit -m "docs: サーボの bench 検証と実機合わせ手順を README へ追記"
```

---

## 完了条件

- `nix develop -c cargo build` が緑（Task 1〜3 の各末尾で確認済み）。
- 施錠/解錠が `Signal` 経由でデモループから駆動され、将来 TCP ハンドラが `SERVO_CMD.signal(...)` を叩くだけで差し込める。
- 実機動作（サーボが回る／唸らない／突き当てない）は bench でお兄ちゃんが確認する領域（README に手順記載）。

# Issue #16: GP16(LED) / GP17(ボタン) ファームウェア実装 + 二色LED 化

## 概要

回路ネットリストに定義済みだがファーム未実装の GP16(LED) / GP17(ボタン) を実装する。
あわせて LED を単色から**二色コモンカソードLED**へ拡張し、ロック状態（施錠=赤／解錠=黄緑）を
色で表示する。ボタンは押すたびに施錠⇄解錠を**トグル**する室内側の手動操作とする。

ボタン・TCP・LED が同じ「現在のロック状態」を参照するため、状態を firmware の**単一ソース**に
集約し、TCP の STATUS 応答もボタン操作を反映するようにする。`smtlk-core` は host テスト可能性を
保ったままリファクタする。

- 親 Issue: #12（B1）
- 同時クローズ: #27（D3 ボタンプルアップ）— 内部プルアップ採用＋ドキュメント明記で解決
- 対象ラベル: circuit + firmware

## 1. ピン割り当て / ハードウェア

| 機能 | ピン | 極性 | 備考 |
|------|------|------|------|
| LED 赤（施錠表示） | GP16 | アクティブHigh | 既存 `led` を `led_r` にリネーム |
| LED 黄緑（解錠表示） | **GP18（新規）** | アクティブHigh | `led_g` 追加。空きピン、GP16/17 と物理的に近接 |
| ボタン | GP17 | アクティブLow | 内部プルアップ。SW1 のもう一端は GND |
| 二色LED 共通 | — | — | コモンカソード（K）→ GND、各アノードに抵抗 |

オンボードLED（CYW43 gpio0）は現状どおり「TCP接続中=点灯／待受中=消灯」の通信状態表示として残す。
外付け二色LED がロック状態を担い、役割を分担する。

二色LED は赤と黄緑で順方向電圧が等しい（ともに Vf=2.1V）ため、両色とも同じ 330Ω 抵抗で
明るさが揃う。配線（コモンカソード, GP16 High で赤点灯, GP18 High で黄緑点灯）:

```
        赤チップ(625nm)
GP16 ─[Rled 330Ω]─▶|─┐
                     A  ├─ K(共通) ── GND
GP18 ─[Rled2 330Ω]─▶|─┘
        黄緑チップ(570nm)
```

| GP16(赤) | GP18(黄緑) | 表示 | 意味 |
|----------|-----------|------|------|
| Low  | Low  | 消灯 | （起動前のみ） |
| High | Low  | 赤   | Locked |
| Low  | High | 黄緑 | Unlocked |

両色同時点灯（黄）は本設計では使わない。

## 2. 回路（circuit/netlist.py）

- `GPIO` に `led_g: "GP18"` を追加し、既存 `led` を `led_r: "GP16"` にリネーム。
- `PARTS["U1"]` の GPIO ピン列に `led_g` を追加。
- `D1` を二色LED（3ピン: R/G/K コモンカソード）に変更。ピンを `["R", "G", "K"]` とする。
- `Rled2`（330Ω, 黄緑側）を追加。
- `NETS` を更新:
  - `LED_DRV`（赤）: `("U1", led_r)` → `("Rled", "1")`、`("Rled", "2")` → `("D1", "R")`
  - `LED_DRV_G`（黄緑）: `("U1", led_g)` → `("Rled2", "1")`、`("Rled2", "2")` → `("D1", "G")`
  - `GND` に `("D1", "K")`（共通カソード）を含める（旧 `("D1", "K")` の扱いを置換）。
- `PART_META` の `D1` を二色LED品名へ更新、`Rled2` を追加。
- 変更後 `nix develop -c ./test/netlist_test.py` を通す。

## 3. ファームウェア アーキテクチャ

### 単一ソースの現在状態

```rust
// firmware（main.rs）
static LOCK_STATE: Mutex<CriticalSectionRawMutex, Cell<LockState>>; // 唯一の現在状態
static SERVO_CMD:  Signal<CriticalSectionRawMutex, LockState>;       // サーボ駆動チャネル（既存）
```

`apply_target(t)` ヘルパ = `LOCK_STATE := t`（楽観的に即時更新）＋ `SERVO_CMD.signal(t)`。
TCP もボタンも必ずこのヘルパ経由で状態を変える。

データフロー:

- **TCP LOCK/UNLOCK** → `decide` が target を返す → `apply_target(target)`
- **TCP STATUS** → `LOCK_STATE` を読んで応答（ボタン操作も反映される）
- **ボタン押下** → `LOCK_STATE` を読み `toggled()` した値を `apply_target`
- **servo_task** → `SERVO_CMD` を待ってサーボ駆動、駆動後に二色LED(GP16/GP18)をセット
  （servo_task が LED 出力を所有）。起動時は安全側 Locked=赤を点灯。
- **オンボードLED** → 接続/WiFi 表示のまま（変更なし）

LED は servo_task が駆動後にセットするため、物理整定後の状態を表示する（~500ms 遅延は許容）。
`LOCK_STATE` は `apply_target` 時点で即更新されるため、STATUS とボタンのトグルは遅延なく整合する。

### ボタンタスク

```rust
let mut btn = Input::new(p.PIN_17, Pull::Up); // アクティブLow
loop {
    btn.wait_for_falling_edge().await;          // 押下
    Timer::after(Duration::from_millis(20)).await; // デバウンス
    if btn.is_low() {                            // 押下確定
        let cur = LOCK_STATE.lock(|c| c.get());
        apply_target(cur.toggled());
    }
    btn.wait_for_high().await;                    // リリース待ち（チャタ防止）
}
```

専用 `button_task` として spawn する。

## 4. smtlk-core リファクタ（host テスト維持）

STATUS をボタン反映可能にし、ロジックを純粋に保つため:

- `LockController`（内部状態保持）→ **純粋関数 `decide(line: &[u8], current: LockState) -> Outcome`** に変更。
  状態を持たず、現在状態を引数で受け取る。`Outcome { servo: Option<LockState>, reply: &'static str }` は維持。
  - STATUS: `servo=None`, reply は `current` から決定。
  - LOCK/UNLOCK: `servo=Some(target)`, reply は target から決定。
  - 不正: `servo=None`, reply=`"ERR\n"`。
- `ServoSink` トレイト → **`LockPort`** に置換:
  ```rust
  pub trait LockPort {
      fn current(&self) -> LockState; // STATUS 用の読み取り
      fn apply(&self, target: LockState); // 永続化 + サーボ駆動
  }
  ```
  - firmware 実装: `current()` は `LOCK_STATE` 読み取り、`apply()` は `apply_target`（`LOCK_STATE` 更新 + `SERVO_CMD.signal`）。
  - host テスト実装: `Cell<LockState>` + 適用履歴記録の mock。
- `serve_connection` のシグネチャを変更: `&mut controller` + `&sink` → 単一の `port: &impl LockPort`。
  各行ごとに `let cur = port.current(); let o = decide(line, cur); write(o.reply); if let Some(t)=o.servo { port.apply(t); }`。
- `LockState::toggled(self) -> LockState` を追加（ボタン用。純粋・テスト可能）。
- `lib.rs` の re-export を更新（`LockController` 廃止、`decide` / `LockPort` を公開）。

## 5. テスト

host テスト（`nix develop -c cargo host-test`, 実機不要）で以下を担保:

- `decide()` 純粋テスト（既存 lock.rs テストを移植）:
  - LOCK/UNLOCK が `Some(target)` と正しい reply を返す
  - STATUS が `None` と current に応じた reply を返す
  - 不正入力が `None` + `"ERR\n"`
- `LockState::toggled()` の単体テスト（Locked⇄Unlocked）。
- `serve_connection` を mock `LockPort` で（既存 serve.rs テストを移植・更新）:
  - 単発/複数コマンド、行分割、長すぎ行回復、CRLF/小文字
  - STATUS が `port.current()` を反映
  - LOCK/UNLOCK が `port.apply(target)` を呼ぶ
- ボタンタスク本体（embassy/HAL 依存）は host テスト対象外。トグル判断ロジックは `toggled()` に
  切り出して純粋テストする。

ファームのビルド: `nix develop -c cargo build --locked`（thumbv6m）が通ること。

## 6. ドキュメント更新

- `docs/parts-selection.md`:
  - メイン表 `D1` を二色LED **OSRGHC5B32A**（[I-06314](https://akizukidenshi.com/catalog/g/gI-06314/), ¥150/10個, 1台按分 ¥15）へ変更。
  - `Rled` の 1台必要数を 1→2 に（赤・黄緑両側で 330Ω×2、同一商品 R-25331）。
  - 概算サマリ・購入先まとめ・代替候補（旧 単色赤LED I-11655 / I-01318 を二色LED へ）を更新。
  - 備考に二色LEDのピン配置（コモンカソード, データシート要確認）と極性注意を追記。
- `README.md`: GP16/GP17/GP18 の役割、ボタン=トグル、二色LED の色割り当て、ボタンは内部プルアップ
  （#27 の解決方針）を追記。
- `crates/firmware/src/main.rs` のモジュールコメント（積み残し節）を更新。

## 7. 兄弟Issueへの波及

- **#27（D3）**: 内部プルアップ採用＋README/doc 明記でクローズ。外付け抵抗は追加しない。
- **#12（親）**: B1 完了でチェック。
- main.rs:14 の「手回し後の状態再同期」TODO は物理センサ非搭載のため別物として据え置き。

## スコープ外（YAGNI）

- 黄色（赤+緑同時点灯）やサーボ駆動中の中間表示。
- RGB（3色独立）化。
- ボタン長押し等の多機能化。
- 手回し（物理操作）後の状態再同期。

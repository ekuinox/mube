# ユニバーサル基板の配線設計とピン再割当 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** LED とボタンとサーボの GPIO を基板上の実装位置に合わせて組み替え、ユニバーサル基板 P-03229 の配線見本を機械検証つきで生成できるようにする。

**Architecture:** 結線の正は `circuit/parts.ts` の `NETS` のまま。新設する `circuit/perfboard/` は「どの穴に何を置いたか」だけを持つ配置データと、それを `NETS` と突き合わせる検証、SVG と結線表の描画に分ける。方位（+X が右など）の対応表は `scripts/axes.ts` に 1 つだけ置き、文書と図の両方がそこを見る。

**Tech Stack:** TypeScript（bun test）、Rust（embassy-rp, thumbv6m-none-eabi）、OpenSCAD（参照のみ）

**Spec:** `docs/superpowers/specs/2026-08-23-perfboard-wiring-design.md`

## Global Constraints

- 実行環境の非対話シェルには `bun` / `cargo` / `just` が PATH に無い。すべて `nix develop -c` を前置する。
- 方位は「室内側からドアを正面に見て」の向きで書く。+X が右、−X が左（ドア枠側）、+Y が上、−Y が下（ハンドル側）、+Z が手前。
- 穴グリッドは 25 列 16 行を仮定する（列は +X 端が 1、行は −Y 端が A）。Task 5 の Step 1 で実測して確定させる。
- Pico はソケットの pin1 を 1 列目に置く。pin n（1〜20 番）は列 n の行 L、pin n（21〜40 番）は列 41 − n の行 E。
- 新しいピン割当: LED_DRV_R = GP9（12 番）、LED_DRV_G = GP10（14 番）、BTN = GP5（7 番）、SERVO_SIG = GP22（29 番）、GATE_DRV = GP20（26 番）。
- Rust を変更したらコミット前に `nix develop -c cargo host-test` と `nix develop -c cargo clippy --all-targets -- -D warnings` を通す。host-test だけだと CI の clippy で落ちる。
- 派生物（`circuit/build/`、`*.stl`）はコミットしない。

---

### Task 1: 方位の対応表と検査

**Files:**
- Create: `scripts/axes.ts`
- Create: `scripts/axes.test.ts`
- Modify: `.github/workflows/ci.yml`（`bun test enclosure/scripts/ scripts/lockctl.test.ts` の行）
- Modify: `Justfile`

**Interfaces:**
- Consumes: なし
- Produces: `AXIS_LABELS: Record<string, string>`、`VIEWPOINT: string`、`axisLabel(axis: string): string`、`axisWithLabel(axis: string): string`、`normaliseAxis(axis: string): string`

- [ ] **Step 1: 失敗するテストを書く**

`scripts/axes.test.ts`:

```ts
// scripts/axes.test.ts
import { expect, test } from "bun:test"
import { readdirSync, readFileSync, statSync } from "node:fs"
import { join } from "node:path"
import { AXIS_LABELS, VIEWPOINT, axisLabel, axisWithLabel, normaliseAxis } from "./axes"

// 目的: 全角マイナス（U+2212）と ASCII ハイフンを同じ軸として扱えること。
test("軸記号の表記ゆれを正規化する", () => {
  expect(normaliseAxis("−X")).toBe("-X")
  expect(axisLabel("−X")).toBe("左")
  expect(axisLabel("-X")).toBe("左")
})

// 目的: 併記の形（+X（右））を対応表から組み立てられること。
test("併記の文字列を組み立てる", () => {
  expect(axisWithLabel("+X")).toBe("+X（右）")
  expect(axisWithLabel("−Y")).toBe("−Y（下）")
})

// 目的: 未知の軸を黙って通さないこと。対応表に無い軸は綴り間違いなので落とす。
test("未知の軸は例外", () => {
  expect(() => axisLabel("+W")).toThrow()
})

// 併記のパターン。軸記号の直後に全角括弧が続くもの。
const ANNOTATION = /([+\-−±])([XYZ])（([^）]*)）/g
const DIRECTION_WORDS = new Set(Object.values(AXIS_LABELS))

function walk(dir: string, out: string[] = []): string[] {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name)
    if (statSync(p).isDirectory()) walk(p, out)
    else if (p.endsWith(".md") || p.endsWith(".scad")) out.push(p)
  }
  return out
}

const TARGETS = [...walk("docs"), ...walk("enclosure/models"), "README.md", "CLAUDE.md"]

// 目的: 文書に書かれた併記が対応表と一致すること。方向語を書いた併記だけを見る。
// 「+X（ヒンジ側）」のように方向語でない補足は、方位の主張ではないので対象外。
test("文書の方位の併記が対応表と一致する", () => {
  const wrong: string[] = []
  for (const file of TARGETS) {
    const text = readFileSync(file, "utf8")
    for (const m of text.matchAll(ANNOTATION)) {
      const [whole, sign, axis, inner] = m
      const head = inner.split("、")[0].trim()
      if (!DIRECTION_WORDS.has(head)) continue
      const expected = AXIS_LABELS[normaliseAxis(`${sign}${axis}`)]
      if (head !== expected) wrong.push(`${file}: ${whole} は ${expected} のはず`)
    }
  }
  expect(wrong).toEqual([])
})

// 目的: 併記のある文書が視点を宣言していること。視点が無いと左右が反転して読める。
test("方位を併記する文書は視点を宣言している", () => {
  const missing: string[] = []
  for (const file of TARGETS) {
    const text = readFileSync(file, "utf8")
    const hasDirection = [...text.matchAll(ANNOTATION)].some((m) =>
      DIRECTION_WORDS.has(m[3].split("、")[0].trim()))
    if (hasDirection && !text.includes(VIEWPOINT)) missing.push(file)
  }
  expect(missing).toEqual([])
})

// 目的: 対応表の根拠が params.scad に残っていること。
// 筐体の向きを変える改修が入ったら、ここが落ちて対応表の見直しを促す。
test("params.scad が −X と −Y の意味を保っている", () => {
  const scad = readFileSync("enclosure/models/params.scad", "utf8")
  expect(scad).toMatch(/clear_left\s*=\s*\d+;\s*\/\/\s*-X to door edge\/frame/)
  expect(scad).toMatch(/clear_down\s*=\s*\d+;\s*\/\/\s*-Y to door handle/)
})
```

- [ ] **Step 2: 落ちることを確認**

Run: `nix develop -c bun test scripts/axes.test.ts`
Expected: FAIL（`Cannot find module './axes'`）

- [ ] **Step 3: 対応表を実装**

`scripts/axes.ts`:

```ts
// scripts/axes.ts
// 方位の正。ドアを室内側から正面に見たときの向きで書く。
// 根拠は enclosure/models/params.scad の 2 行:
//   clear_left = 50;  // -X to door edge/frame  → −X はドア枠側 ＝ 左
//   clear_down = 65;  // -Y to door handle      → −Y はハンドル側 ＝ 下
// レバーハンドルはサムターンの下にあるので −Y が下になる。

export const VIEWPOINT = "室内側から"

export const AXIS_LABELS: Record<string, string> = {
  "+X": "右",
  "-X": "左",
  "+Y": "上",
  "-Y": "下",
  "+Z": "手前",
  "-Z": "奥",
  "±X": "左右",
  "±Y": "上下",
  "±Z": "前後",
}

/** 全角マイナス（U+2212）を ASCII ハイフンへ寄せる。文書側の表記ゆれを吸収する。 */
export function normaliseAxis(axis: string): string {
  return axis.replace(/−/g, "-")
}

export function axisLabel(axis: string): string {
  const label = AXIS_LABELS[normaliseAxis(axis)]
  if (!label) throw new Error(`unknown axis: ${axis}`)
  return label
}

/** 文書と図で使う併記の形。例: axisWithLabel("+X") === "+X（右）" */
export function axisWithLabel(axis: string): string {
  return `${axis}（${axisLabel(axis)}）`
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `nix develop -c bun test scripts/axes.test.ts`
Expected: PASS（6 tests）

- [ ] **Step 5: CI と Justfile に載せる**

`.github/workflows/ci.yml` の該当行を書き換える。

```yaml
      - name: bun test (enclosure ヘルパ + lockctl + 方位の併記)
        run: nix develop --command bun test enclosure/scripts/ scripts/
```

`Justfile` に追加する（既存の `test-enclosure` の下）。

```
# 方位の併記が対応表と一致するかを検査
test-axes:
    bun test scripts/axes.test.ts
```

- [ ] **Step 6: 全体が通ることを確認**

Run: `nix develop -c bun test enclosure/scripts/ scripts/`
Expected: PASS（既存の enclosure 15 件と lockctl の分を含む）

- [ ] **Step 7: コミット**

```bash
git add scripts/axes.ts scripts/axes.test.ts .github/workflows/ci.yml Justfile
git commit -m "feat(docs): 方位の対応表と、併記の取り違えを検出する検査を追加"
```

---

### Task 2: ファームのピン再割当

**Files:**
- Modify: `crates/mube-firmware/src/main.rs:5-11`（モジュールコメント）、`:148`（ボタンの doc）、`:230-239`（初期化）
- Modify: `crates/mube-firmware/src/servo.rs:1`、`:24`、`:32-33`（doc コメント）

**Interfaces:**
- Consumes: なし
- Produces: なし（外部に出る型は変わらない。`Servo::new` の引数も同じ）

このタスクの検証は型検査が担う。embassy-rp の `Pwm::new_output_a` は slice と ch A ピンの組み合わせをトレイトで縛るので、slice とピンの取り違えはコンパイルエラーになる。

- [ ] **Step 1: 現状のビルドが通ることを確認（基準点）**

Run: `nix develop -c cargo check -p mube-firmware --target thumbv6m-none-eabi`
Expected: PASS

- [ ] **Step 2: 誤った組み合わせで落ちることを確認**

`main.rs:232` を一時的に `Pwm::new_output_b(p.PWM_SLICE3, p.PIN_22, PwmConfig::default())` にする（ch を B のまま、ピンだけ GP22 にする）。

Run: `nix develop -c cargo check -p mube-firmware --target thumbv6m-none-eabi`
Expected: FAIL（`PIN_22` が `ChannelBPin<PWM_SLICE3>` を満たさない旨のエラー）

これで「型検査がピンと slice の対応を見ている」ことが確認できる。確認したら次の Step で正しい形に直す。

- [ ] **Step 3: 初期化を書き換える**

`main.rs:230-239` を次にする。

```rust
    // サーボ駆動: PWM 信号 = GP22（slice3 ch A）、電源ゲート = GP20（active-high）。
    let gate = Output::new(p.PIN_20, Level::Low);
    let servo_pwm = Pwm::new_output_a(p.PWM_SLICE3, p.PIN_22, PwmConfig::default());
    let servo = Servo::new(servo_pwm, gate);
    // 二色ステータス LED: 赤=GP9（施錠）, 黄緑=GP10（解錠）。コモンカソード、active-high。
    let led_r = Output::new(p.PIN_9, Level::Low);
    let led_g = Output::new(p.PIN_10, Level::Low);
    spawner.spawn(servo_task(servo, led_r, led_g).unwrap());
    // ボタン: GP5 内部プルアップ（アクティブ Low）。押下でロックをトグル。
    let button = Input::new(p.PIN_5, Pull::Up);
```

- [ ] **Step 4: doc コメントを合わせる**

`main.rs:5` を `//! SG90 サーボ（GP22 PWM + GP20 電源ゲート）への指令は \`SERVO_CMD: Signal\` 経由で` にする。

`main.rs:9-10` を次にする。

```rust
//! ロック状態は単一ソース `LOCK_STATE` に集約し、HTTP API・GP5 ボタン（トグル）・
//! 二色ステータス LED（GP9=赤=施錠 / GP10=黄緑=解錠）が同じ状態を参照する。
```

`main.rs:148` の `/// GP17 のタクトスイッチ` を `/// GP5 のタクトスイッチ` にする。

`servo.rs:1` を `//! SG90 サーボ駆動。電源ゲート（GP20）と PWM 信号（GP22）を協調させ、` にする。

`servo.rs:24` を `/// サーボ駆動。PWM（GP22 = slice3 ch A）と電源ゲート（GP20, active-high）を保持する。` にする。

`servo.rs:32-33` を次にする。

```rust
    /// 初期状態は「給電断・PWM 停止」。`pwm` は main 側で `Pwm::new_output_a(
    /// PWM_SLICE3, PIN_22, PwmConfig::default())` として渡す。`gate` は GP20。
```

- [ ] **Step 5: ビルドと lint とテスト**

Run: `nix develop -c cargo check -p mube-firmware --target thumbv6m-none-eabi`
Expected: PASS

Run: `nix develop -c cargo clippy -p mube-firmware --target thumbv6m-none-eabi -- -D warnings`
Expected: PASS

Run: `nix develop -c cargo host-test`
Expected: PASS（19 tests。`mube-core` はピン番号を持たないので期待値は変わらない）

- [ ] **Step 6: コミット**

```bash
git add crates/mube-firmware/src/main.rs crates/mube-firmware/src/servo.rs
git commit -m "feat(firmware): GPIO を基板の実装位置へ再割当（LED=GP9/GP10, ボタン=GP5, サーボ=GP22/GP20）"
```

---

### Task 3: 回路ネットリストのピン名更新

**Files:**
- Modify: `circuit/parts.ts:13`（`U1` の `pinLabels`）、`:32-39`（`NETS`）
- Modify: `circuit/parts.test.ts:11-18`（`EXPECTED_NETS`）
- Modify: `circuit/breadboard/footprints.ts:15`（`U1` の `pinOrder`）
- Modify: `circuit/breadboard/subcircuit.test.ts:17-18`、`:28`
- Modify: `circuit/erc.test.ts:46`（テスト用の作り物のピン名。実回路とは無関係だが表記をそろえる）

**Interfaces:**
- Consumes: なし
- Produces: `U1` のピンラベルが `VBUS` `GND` `GP22` `GP20` `GP9` `GP10` `GP5` になる。`circuit/perfboard/board.ts` の `PICO_PIN_OF_LABEL` がこのラベルを鍵に使う。

- [ ] **Step 1: 期待値を先に書き換えて落とす**

`circuit/parts.test.ts` の `EXPECTED_NETS` のうち 5 行を書き換える。

```ts
  SERVO_SIG: ["M1.SIG", "U1.GP22"],
  GATE_DRV: ["Rg.pin1", "U1.GP20"],
  LED_DRV_R: ["Rled.pin1", "U1.GP9"],
  LED_DRV_G: ["Rled2.pin1", "U1.GP10"],
  BTN: ["SW1.pin1", "U1.GP5"],
```

`circuit/breadboard/subcircuit.test.ts` の 17-18 行と 28 行を書き換える。

```ts
    SERVO_SIG: ["M1.SIG", "U1.GP22"],
    GATE_DRV:  ["Rg.pin1", "U1.GP20"],
```

```ts
  expect(nets.BTN.sort()).toEqual(["SW1.pin1", "U1.GP5"])
```

- [ ] **Step 2: 落ちることを確認**

Run: `cd circuit && nix develop -c bun test`
Expected: FAIL（`parts.test.ts` と `subcircuit.test.ts` が期待値の不一致で落ちる）

- [ ] **Step 3: 部品定義を書き換える**

`circuit/parts.ts:13` を次にする。ラベルの並び順は物理ピン番号の昇順にそろえる。

```ts
  { ref: "U1", kind: "chip", pinLabels: { pin1: "VBUS", pin2: "GND", pin3: "GP5", pin4: "GP9", pin5: "GP10", pin6: "GP20", pin7: "GP22" } },
```

`circuit/parts.ts` の `NETS` の 5 行を書き換える。

```ts
  { name: "SERVO_SIG", endpoints: [".U1 .GP22", ".M1 .SIG"] },
  { name: "GATE_DRV", endpoints: [".U1 .GP20", ".Rg .pin1"] },
  { name: "LED_DRV_R", endpoints: [".U1 .GP9", ".Rled .pin1"] },
  { name: "LED_DRV_G", endpoints: [".U1 .GP10", ".Rled2 .pin1"] },
  { name: "BTN", endpoints: [".U1 .GP5", ".SW1 .pin1"] },
```

`circuit/breadboard/footprints.ts:15` を次にする。

```ts
  U1:   { pinOrder: ["VBUS", "GND", "GP5", "GP9", "GP10", "GP20", "GP22"], edgeAffinity: "left",  label: "U1",  value: "Pico W" },
```

`circuit/erc.test.ts:46` の `"GP17"` を `"GP5"` にする。

- [ ] **Step 4: 通ることを確認**

Run: `cd circuit && nix develop -c bun test`
Expected: PASS（ERC 29 件を含む既存の全件）

- [ ] **Step 5: コミット**

```bash
git add circuit/parts.ts circuit/parts.test.ts circuit/breadboard/footprints.ts circuit/breadboard/subcircuit.test.ts circuit/erc.test.ts
git commit -m "feat(circuit): ネットリストの U1 ピン名を新しい GPIO 割当へ更新"
```

---

### Task 4: 文書のピン番号更新と #90 設計書の訂正

**Files:**
- Modify: `docs/firmware.md:133-134`、`:172`
- Modify: `docs/parts-selection.md:68`、`:98`
- Modify: `docs/superpowers/specs/2026-08-16-universal-pcb-cover-design.md:76-78`、`:83-93`

**Interfaces:**
- Consumes: Task 1 の `scripts/axes.ts`（併記の規則）
- Produces: なし

- [ ] **Step 1: firmware.md を書き換える**

133-134 行を次にする。

```markdown
ロック状態は外付けの二色 LED（D1）で表示する（施錠=赤 GP9 / 解錠=黄緑 GP10、コモンカソード）。
GP5 のタクトスイッチを押すと施錠⇄解錠をトグルできる（室内側の手動操作）。
```

172 行を `サーボ給電は動作時だけ ON にする（GP20 の電源ゲート）。` にする。

- [ ] **Step 2: parts-selection.md を書き換える**

68 行の `ゲートは Pico W の GP14（3.3V）から` を `ゲートは Pico W の GP20（3.3V）から` にする。

98 行の `赤アノード（R）を GP16、黄緑アノード（G）を GP18 へ` を `赤アノード（R）を GP9、黄緑アノード（G）を GP10 へ` にする。

- [ ] **Step 3: #90 設計書の反転記述を訂正する**

`2026-08-16-universal-pcb-cover-design.md` の 76-78 行を次に差し替える。視点の宣言をここで入れる（Task 1 の検査が要求する）。

```markdown
配置は `circuit/parts.ts` のネットリストと Pico W のピン配置から導いた。使用ピンは VBUS / GND と、LED とボタンの GP5 / GP9 / GP10、サーボ系の GP20 / GP22 である。前者は 1〜20 番列に、後者は 21〜40 番列に並ぶ（割当の根拠は docs/superpowers/specs/2026-08-23-perfboard-wiring-design.md）。

方位は室内側からドアを正面に見た向きで書く。USB を +X（右）へ向けると、1〜20 番列が +Y（上）辺、21〜40 番列が −Y（下）辺に来る。基板を横置きに保ったまま回せる向きは 0 度と 180 度の二つだけなので、この対応は選べない。結果、LED とスイッチの系統は +Y（上）側だけで、サーボ信号とゲート駆動の系統は −Y（下）側だけで閉じる。
```

- [ ] **Step 4: 部品配置の表を訂正する**

同ファイル 83-93 行の表を、新しい設計書の決定 2 と同じ内容にする。

```markdown
| D1 2色LED | (0, +16.5) | 3 本足が 12、13、14 番ピンの列に乗る。屋根がハニカムなので窓に合わせる必要はない（ただし「LED の見え方」の項の 3 帯は避ける） |
| Rled 330Ω | (+2.5, +12.7) | GP9（12 番）と D1.R の間 |
| Rled2 330Ω | (−2.5, +12.7) | GP10（14 番）と D1.G の間 |
| SW1 用 2pin コネクタ | (+14, +14.0) | GP5（7 番）と GND（8 番）の列に乗る。スイッチ本体はカバー側 |
| C1 470µF | (+22, −15.2) | −Y（下）側。VBUS（40 番）と GND（38 番）に近く、サーボへの 5V の引き回しの途中に入る |
| C2 100nF | (+25.4, −16.5) | C1 に隣接（parts-selection.md の指示） |
| Q1 MOSFET | (−5.1, −15.2) | GP20（26 番）の下。背が高い（基板上 16mm）が屋根は −Y（下）側ほど高いので問題ない |
| Rg 220Ω | (−6, −11.4) | GP20 ⇔ Q1.G の間 |
| Rgs 10kΩ | (−2.5, −12.7) | Q1.G ⇔ GND |
| D2 1N5819 | (−1.3, −19.1) | SERVO_RTN（Q1.D）とサーボコネクタの間 |
| サーボ 3pin | (+2.5, −19.1) | 基板の −Y（下）端。ペデスタルが隣なのでケーブルが最短で降りる。SIG は GP22（29 番）と同じ列 |
```

- [ ] **Step 5: 方位の検査を通す**

Run: `nix develop -c bun test scripts/axes.test.ts`
Expected: PASS（併記を足した #90 設計書が視点の宣言を持つこと、括弧の中身が対応表と一致することを見る）

- [ ] **Step 6: コミット**

```bash
git add docs/firmware.md docs/parts-selection.md docs/superpowers/specs/2026-08-16-universal-pcb-cover-design.md
git commit -m "docs: GPIO 番号を新しい割当へ更新し、#90 設計書のピン列の反転記述を訂正"
```

---

### Task 5: 穴グリッドのモデル

**Files:**
- Create: `circuit/perfboard/board.ts`
- Create: `circuit/perfboard/board.test.ts`

**Interfaces:**
- Consumes: なし
- Produces: `COLS`、`ROWS`、`PITCH`、`Hole = { col: number; row: number }`、`holeId(h: Hole): string`、`parseHole(id: string): Hole`、`holeXY(h: Hole): { x: number; y: number }`、`pinHole(pin: number): Hole`、`PIN_ROW_LOW`、`PIN_ROW_HIGH`、`PICO_GND_PINS: number[]`、`PICO_PIN_OF_LABEL: Record<string, number>`

- [ ] **Step 1: 現物の穴を数えて COLS と ROWS を確定する**

基板 P-03229 を手に取り、列（印刷された番号、+X（右）端が 1）と行（右端の letter）を数える。
25 列 16 行なら以降のコードをそのまま使う。違っていたら `board.ts` の `COLS` / `ROWS` を実測値にし、Step 4 のテストが落ちる場合は期待値を実測に合わせて直す。

行数が奇数だった場合は、`PIN_ROW_LOW` が整数にならずテストが落ちる。そのときは Pico を中心から 1.27mm ずらして載せることになるので、`PIN_ROW_LOW` / `PIN_ROW_HIGH` を実際に刺す行の番号で直接指定し、設計書の決定 3 に実測結果を追記する。

- [ ] **Step 2: 失敗するテストを書く**

`circuit/perfboard/board.test.ts`:

```ts
// circuit/perfboard/board.test.ts
import { expect, test } from "bun:test"
import {
  COLS, ROWS, PIN_ROW_HIGH, PIN_ROW_LOW,
  holeId, holeXY, parseHole, pinHole, PICO_PIN_OF_LABEL,
} from "./board"

// 目的: ソケットの 2 列が 7 ピッチ離れ、かつ穴の上に乗ること。
// 行数が奇数だとこの条件を満たせないので、グリッドの仮定が壊れたらここで落ちる。
test("ピン列は 7 ピッチ離れた整数行に乗る", () => {
  expect(PIN_ROW_HIGH - PIN_ROW_LOW).toBe(7)
  expect(Number.isInteger(PIN_ROW_LOW)).toBe(true)
  expect(Number.isInteger(PIN_ROW_HIGH)).toBe(true)
})

// 目的: 40 ピンすべてがグリッドの内側に収まること。
test("全ヘッダピンがグリッドに収まる", () => {
  for (let pin = 1; pin <= 40; pin++) {
    const h = pinHole(pin)
    expect(h.col >= 1 && h.col <= COLS).toBe(true)
    expect(h.row >= 1 && h.row <= ROWS).toBe(true)
  }
})

// 目的: pin1 と pin40 が同じ列（USB 側の端）に、pin20 と pin21 が同じ列に来ること。
test("向かい合うピンが同じ列に来る", () => {
  expect(pinHole(1).col).toBe(pinHole(40).col)
  expect(pinHole(20).col).toBe(pinHole(21).col)
})

// 目的: 新しい割当のピンが設計書どおりの穴に来ること。
test("割当済みのピンが設計書の穴に一致する", () => {
  expect(holeId(pinHole(PICO_PIN_OF_LABEL.GP9))).toBe("L12")
  expect(holeId(pinHole(PICO_PIN_OF_LABEL.GP10))).toBe("L14")
  expect(holeId(pinHole(PICO_PIN_OF_LABEL.GP5))).toBe("L7")
  expect(holeId(pinHole(PICO_PIN_OF_LABEL.GP22))).toBe("E12")
  expect(holeId(pinHole(PICO_PIN_OF_LABEL.GP20))).toBe("E15")
  expect(holeId(pinHole(PICO_PIN_OF_LABEL.VBUS))).toBe("E1")
})

// 目的: 穴 ID と座標の往復が壊れないこと。
test("穴 ID の往復と mm 変換", () => {
  expect(parseHole("L12")).toEqual({ col: 12, row: 12 })
  expect(holeId({ col: 12, row: 12 })).toBe("L12")
  const { x, y } = holeXY(pinHole(29))
  expect(x).toBeCloseTo(2.54, 2)
  expect(y).toBeCloseTo(-8.89, 2)
})
```

- [ ] **Step 3: 落ちることを確認**

Run: `cd circuit && nix develop -c bun test perfboard/board.test.ts`
Expected: FAIL（`Cannot find module './board'`）

- [ ] **Step 4: 実装**

`circuit/perfboard/board.ts`:

```ts
// circuit/perfboard/board.ts
// ユニバーサル基板 P-03229（72×47mm, 片面めっき）の穴グリッド。
// ランドは独立なので、このモデルは導通を一切持たない。繋がるのはワイヤだけ。
//
// 方位は室内側からドアを正面に見た向き。
// 列は +X（右）端を 1 として −X（左）へ、行は −Y（下）端を 1（A）として +Y（上）へ数える。

export const COLS = 25
export const ROWS = 16 // 偶数でないとピン列がグリッド中心から等距離に乗らない
export const PITCH = 2.54

export type Hole = { col: number; row: number }

const CENTER_COL = (COLS + 1) / 2
const CENTER_ROW = (ROWS + 1) / 2

/** 21〜40 番のピン列（−Y（下）側）。 */
export const PIN_ROW_LOW = CENTER_ROW - 3.5
/** 1〜20 番のピン列（+Y（上）側）。 */
export const PIN_ROW_HIGH = CENTER_ROW + 3.5

export function holeId(h: Hole): string {
  return `${String.fromCharCode(64 + h.row)}${h.col}`
}

export function parseHole(id: string): Hole {
  const m = /^([A-Z])(\d+)$/.exec(id)
  if (!m) throw new Error(`bad hole id: ${id}`)
  return { row: m[1].charCodeAt(0) - 64, col: Number(m[2]) }
}

/** 基板ローカル座標（原点は基板中心、単位 mm）。 */
export function holeXY(h: Hole): { x: number; y: number } {
  return { x: (CENTER_COL - h.col) * PITCH, y: (h.row - CENTER_ROW) * PITCH }
}

/** Pico ヘッダのピン番号 → 穴。pin1 を 1 列目に置き、+X（右）端へ寄せる。 */
export function pinHole(pin: number): Hole {
  if (!Number.isInteger(pin) || pin < 1 || pin > 40) throw new Error(`bad pin: ${pin}`)
  return pin <= 20
    ? { col: pin, row: PIN_ROW_HIGH }
    : { col: 41 - pin, row: PIN_ROW_LOW }
}

/**
 * Pico の GND ピン。基板内部で同一ノードなので、検証では 1 つに束ねる。
 * 33 番は AGND で、アナロググランドとして分けてあるため含めない。
 */
export const PICO_GND_PINS = [3, 8, 13, 18, 23, 28, 38]

/** parts.ts の U1 pinLabels → ヘッダピン番号。 */
export const PICO_PIN_OF_LABEL: Record<string, number> = {
  VBUS: 40,
  GND: 38,
  GP5: 7,
  GP9: 12,
  GP10: 14,
  GP20: 26,
  GP22: 29,
}
```

- [ ] **Step 5: 通ることを確認**

Run: `cd circuit && nix develop -c bun test perfboard/board.test.ts`
Expected: PASS（5 tests）

- [ ] **Step 6: コミット**

```bash
git add circuit/perfboard/board.ts circuit/perfboard/board.test.ts
git commit -m "feat(circuit): ユニバーサル基板の穴グリッドモデルを追加"
```

---

### Task 6: 配線の検証

**Files:**
- Create: `circuit/perfboard/verify.ts`
- Create: `circuit/perfboard/verify.test.ts`
- Modify: `circuit/breadboard/model.ts:33`（`class UnionFind` を `export class UnionFind` にする）

**Interfaces:**
- Consumes: Task 5 の `board.ts`（`pinHole`、`holeId`、`PICO_GND_PINS`、`PICO_PIN_OF_LABEL`）
- Produces: `Wire = { from: string; to: string; net: string; side: "solder" | "component" }`、`Layout = { legs: Record<string, string>; wires: Wire[] }`、`verifyLayout(layout: Layout, allowUnconnected?: string[]): string[]`

- [ ] **Step 1: 失敗するテストを書く**

`circuit/perfboard/verify.test.ts`:

```ts
// circuit/perfboard/verify.test.ts
import { expect, test } from "bun:test"
import { verifyLayout, type Layout } from "./verify"

// 最小の作り物。実データ（layout.ts）は Task 7 で検証する。
// GND は Pico の内部結線に頼るので、SW1.pin2 は 8 番ピンの穴へ落とす。
function minimal(): Layout {
  return {
    legs: { "SW1.pin1": "N7", "SW1.pin2": "N8" },
    wires: [
      { from: "N7", to: "L7", net: "BTN", side: "solder" },
      { from: "N8", to: "L8", net: "GND", side: "solder" },
    ],
  }
}

// 目的: 正しく繋がった配置が、BTN について問題を出さないこと。
test("繋がっている配置は BTN の指摘を出さない", () => {
  const problems = verifyLayout(minimal())
  expect(problems.filter((p) => p.includes("BTN"))).toEqual([])
})

// 目的: ワイヤを 1 本落とすと未接続として検出されること。
test("未接続を検出する", () => {
  const layout = minimal()
  layout.wires = layout.wires.filter((w) => w.net !== "BTN")
  expect(verifyLayout(layout).some((p) => p.includes("BTN") && p.includes("未接続"))).toBe(true)
})

// 目的: 異なるネットが同じ穴に集まったらショートとして検出されること。
test("ショートを検出する", () => {
  const layout = minimal()
  layout.wires.push({ from: "L7", to: "L8", net: "BTN", side: "solder" })
  expect(verifyLayout(layout).some((p) => p.includes("ショート"))).toBe(true)
})

// 目的: 同じ穴に 2 本の足を挿す配置を弾くこと。物理的に入らない。
test("穴の重複を検出する", () => {
  const layout = minimal()
  layout.legs["D1.K"] = "N7"
  expect(verifyLayout(layout).some((p) => p.includes("重複"))).toBe(true)
})

// 目的: ネットの端点に穴を割り当て忘れたら取りこぼしとして検出されること。
test("穴の割り当て漏れを検出する", () => {
  const problems = verifyLayout(minimal())
  expect(problems.some((p) => p.includes("穴が無い") && p.includes("M1.SIG"))).toBe(true)
})
```

- [ ] **Step 2: 落ちることを確認**

Run: `cd circuit && nix develop -c bun test perfboard/verify.test.ts`
Expected: FAIL（`Cannot find module './verify'`）

- [ ] **Step 3: `UnionFind` を公開する**

`circuit/breadboard/model.ts` の `class UnionFind` を `export class UnionFind` にする。他の変更はしない。

- [ ] **Step 4: 実装**

`circuit/perfboard/verify.ts`:

```ts
// circuit/perfboard/verify.ts
// 配置データ（layout.ts）が parts.ts の NETS を満たしているかを検証する。
// layout.ts は「どの穴に何を置いたか」しか主張しない。繋がっているかを言うのはここだけ。

import { NETS } from "../parts"
import { normaliseEndpoint } from "../breadboard/subcircuit"
import { UnionFind } from "../breadboard/model"
import { PICO_GND_PINS, PICO_PIN_OF_LABEL, holeId, pinHole } from "./board"

export type Wire = {
  from: string
  to: string
  net: string
  side: "solder" | "component"
}

export type Layout = {
  /** "D1.R" → "O12"。U1 のピンは pinHole() から導くので書かない。 */
  legs: Record<string, string>
  wires: Wire[]
}

/** 端点 "Ref.pin" → 穴 ID。U1 だけはヘッダのピン配置から導く。 */
function holeOf(layout: Layout, endpoint: string): string | undefined {
  const [ref, pin] = endpoint.split(".")
  if (ref === "U1") {
    const number = PICO_PIN_OF_LABEL[pin]
    return number === undefined ? undefined : holeId(pinHole(number))
  }
  return layout.legs[endpoint]
}

export function verifyLayout(layout: Layout, allowUnconnected: string[] = []): string[] {
  const problems: string[] = []
  const uf = new UnionFind()

  // Pico の GND ピンは基板内部で繋がっている。ここだけは配線が無くても同一ノード。
  const gndHoles = PICO_GND_PINS.map((p) => holeId(pinHole(p)))
  for (const h of gndHoles.slice(1)) uf.union(gndHoles[0], h)

  for (const w of layout.wires) uf.union(w.from, w.to)

  // 穴の重複。ヘッダピンの穴も占有済みとして数える。
  const occupied: Record<string, string> = {}
  for (let pin = 1; pin <= 40; pin++) occupied[holeId(pinHole(pin))] = `U1.pin${pin}`
  for (const [leg, hole] of Object.entries(layout.legs)) {
    if (occupied[hole]) problems.push(`穴の重複: ${hole} に ${occupied[hole]} と ${leg}`)
    else occupied[hole] = leg
  }

  // ネットごとの導通。
  const groupNets: Record<string, Set<string>> = {}
  for (const net of NETS) {
    const endpoints = net.endpoints.map(normaliseEndpoint).filter((e) => !allowUnconnected.includes(e))
    const groups: string[] = []
    for (const e of endpoints) {
      const hole = holeOf(layout, e)
      if (!hole) {
        problems.push(`穴が無い: ${net.name} の ${e}`)
        continue
      }
      const g = uf.groupOf(hole)
      groups.push(g)
      ;(groupNets[g] ??= new Set()).add(net.name)
    }
    if (groups.length > 1 && new Set(groups).size > 1) {
      problems.push(`未接続: ${net.name} の端点が ${new Set(groups).size} 個の島に分かれている`)
    }
  }

  // ショート。同じ島に 2 つ以上のネットが乗ったら配線ミス。
  for (const [group, nets] of Object.entries(groupNets)) {
    if (nets.size > 1) problems.push(`ショート: ${[...nets].join(" と ")} が同じ島（${group}）`)
  }

  return problems
}
```

- [ ] **Step 5: 通ることを確認**

Run: `cd circuit && nix develop -c bun test perfboard/verify.test.ts`
Expected: PASS（5 tests）

Run: `cd circuit && nix develop -c bun test`
Expected: PASS（`UnionFind` の公開で既存が壊れていないこと）

- [ ] **Step 6: コミット**

```bash
git add circuit/perfboard/verify.ts circuit/perfboard/verify.test.ts circuit/breadboard/model.ts
git commit -m "feat(circuit): ユニバーサル基板の配置を NETS と突き合わせる検証を追加"
```

---

### Task 7: 配置データ

**Files:**
- Create: `circuit/perfboard/layout.ts`
- Create: `circuit/perfboard/layout.test.ts`

**Interfaces:**
- Consumes: Task 6 の `Layout` 型と `verifyLayout`
- Produces: `LAYOUT: Layout`

穴の割り当ては設計書の決定 2 に対応する。行 A が −Y（下）端、行 L と行 E がピン列。
+Y（上）側が LED とスイッチ、−Y（下）側がサーボと電源になる。

- [ ] **Step 1: 失敗するテストを書く**

`circuit/perfboard/layout.test.ts`:

```ts
// circuit/perfboard/layout.test.ts
import { expect, test } from "bun:test"
import { ALLOW_UNCONNECTED } from "../netlist"
import { LAYOUT } from "./layout"
import { verifyLayout } from "./verify"

// 目的: 実際の配置データが NETS をすべて満たすこと。
// 未接続・ショート・穴の重複・割り当て漏れのいずれも無い状態を配線見本の合格条件とする。
test("配置データが全ネットを満たす", () => {
  expect(verifyLayout(LAYOUT, ALLOW_UNCONNECTED)).toEqual([])
})

// 目的: 上下の役割分担が崩れていないこと。
// LED とスイッチは +Y（上）側、サーボと電源は −Y（下）側に閉じる。
test("部品が設計どおりの側に載っている", () => {
  const rowOf = (id: string) => id.charCodeAt(0) - 64
  const upper = ["D1.R", "D1.K", "D1.G", "SW1.pin1", "SW1.pin2", "Rled.pin1", "Rled2.pin1"]
  const lower = ["M1.SIG", "M1.VPLUS", "M1.GND", "Q1.G", "Q1.D", "Q1.S", "C1.pin1", "C2.pin1"]
  for (const leg of upper) expect(rowOf(LAYOUT.legs[leg])).toBeGreaterThan(12)
  for (const leg of lower) expect(rowOf(LAYOUT.legs[leg])).toBeLessThan(5)
})
```

- [ ] **Step 2: 落ちることを確認**

Run: `cd circuit && nix develop -c bun test perfboard/layout.test.ts`
Expected: FAIL（`Cannot find module './layout'`）

- [ ] **Step 3: 実装**

`circuit/perfboard/layout.ts`:

```ts
// circuit/perfboard/layout.ts
// 基板上のどの穴に何を置くかだけを持つ。繋がっているかどうかはここでは主張しない。
// 検証は verify.ts の仕事。設計書は docs/superpowers/specs/2026-08-23-perfboard-wiring-design.md。
//
// 方位は室内側からドアを正面に見た向き。行 P が +Y（上）端、行 A が −Y（下）端、
// 列 1 が +X（右）端。ピン列は 1〜20 番が行 L、21〜40 番が行 E。

import type { Layout } from "./verify"

export const LAYOUT: Layout = {
  legs: {
    // +Y（上）側: 表示と入力
    "D1.R": "O12",
    "D1.K": "O13",
    "D1.G": "O14",
    "Rled.pin1": "M12",
    "Rled.pin2": "N12",
    "Rled2.pin1": "M14",
    "Rled2.pin2": "N14",
    "SW1.pin1": "N7",
    "SW1.pin2": "N8",

    // −Y（下）側: 動力と電源
    "M1.VPLUS": "A11",
    "M1.SIG": "A12",
    "M1.GND": "A13",
    "D2.cathode": "B12",
    "D2.anode": "B13",
    "Q1.S": "C13",
    "Q1.D": "C14",
    "Q1.G": "C15",
    "Rg.pin1": "D16",
    "Rg.pin2": "C16",
    "Rgs.pin1": "C17",
    "Rgs.pin2": "D17",
    "C1.pin1": "B4",
    "C1.pin2": "B6",
    "C2.pin1": "C4",
    "C2.pin2": "C6",
  },
  wires: [
    // LED（+Y 側）。K は 13 番ピン（GND）の列へ真下に落ちる。
    { from: "L12", to: "M12", net: "LED_DRV_R", side: "solder" },
    { from: "N12", to: "O12", net: "LED_A_R", side: "solder" },
    { from: "L14", to: "M14", net: "LED_DRV_G", side: "solder" },
    { from: "N14", to: "O14", net: "LED_A_G", side: "solder" },
    { from: "O13", to: "L13", net: "GND", side: "solder" },

    // スイッチ（+Y 側）。2 本とも真下の 7 番と 8 番へ。
    { from: "N7", to: "L7", net: "BTN", side: "solder" },
    { from: "N8", to: "L8", net: "GND", side: "solder" },

    // サーボ信号とゲート駆動（−Y 側）
    { from: "A12", to: "E12", net: "SERVO_SIG", side: "solder" },
    { from: "E15", to: "D16", net: "GATE_DRV", side: "solder" },
    { from: "C16", to: "C15", net: "GATE", side: "solder" },
    { from: "C17", to: "C16", net: "GATE", side: "solder" },
    { from: "D17", to: "E18", net: "GND", side: "solder" },

    // サーボのリターン。Q1.D とサーボ GND と D2 のアノードで閉じる短いループ。
    { from: "C14", to: "B13", net: "SERVO_RTN", side: "solder" },
    { from: "B13", to: "A13", net: "SERVO_RTN", side: "solder" },

    // 5V。VBUS からバルクコンを経てサーボへ。
    { from: "E1", to: "B4", net: "V5", side: "solder" },
    { from: "B4", to: "C4", net: "V5", side: "solder" },
    { from: "C4", to: "B12", net: "V5", side: "solder" },
    { from: "B12", to: "A11", net: "V5", side: "solder" },

    // GND。Q1.S はバルクコンの負極へ直接返し、サーボのリターンを Pico の内部プレーン
    // だけに頼らせない。38 番ピンとバルクコンを繋ぐことで USB からの帰り道も閉じる。
    { from: "E3", to: "B6", net: "GND", side: "solder" },
    { from: "B6", to: "C6", net: "GND", side: "solder" },
    { from: "B6", to: "C13", net: "GND", side: "solder" },
    { from: "C13", to: "E13", net: "GND", side: "solder" },
  ],
}
```

- [ ] **Step 4: 通ることを確認**

Run: `cd circuit && nix develop -c bun test perfboard/layout.test.ts`
Expected: PASS（2 tests）

落ちた場合、`verifyLayout` の指摘がそのまま直し方になる。「未接続」ならワイヤが足りず、「ショート」なら余計な結線があり、「穴の重複」なら 2 つの足が同じ穴を取り合っている。

- [ ] **Step 5: コミット**

```bash
git add circuit/perfboard/layout.ts circuit/perfboard/layout.test.ts
git commit -m "feat(circuit): ユニバーサル基板の配置データを追加（検証つき）"
```

---

### Task 8: 描画と結線表

**Files:**
- Create: `circuit/perfboard/render.ts`
- Create: `circuit/perfboard/render.test.ts`
- Create: `circuit/perfboard-build.ts`
- Create: `docs/perfboard-wiring.md`（生成物だがコミットする）
- Modify: `Justfile`
- Modify: `README.md`（コマンド表）、`CLAUDE.md`（コマンド表）
- Modify: `backlog/tasks/task-4 - rebuild-circuit-on-universal-board.md`

**Interfaces:**
- Consumes: Task 5 の `board.ts`、Task 6 の `Layout`、Task 7 の `LAYOUT`、Task 1 の `axisWithLabel`
- Produces: `renderSvg(layout: Layout): string`、`renderTable(layout: Layout): string`

- [ ] **Step 1: 失敗するテストを書く**

`circuit/perfboard/render.test.ts`:

```ts
// circuit/perfboard/render.test.ts
import { expect, test } from "bun:test"
import { COLS, ROWS } from "./board"
import { LAYOUT } from "./layout"
import { renderSvg, renderTable } from "./render"

// 目的: グリッドの穴が全部描かれること。描き漏らすと現物と数が合わなくなる。
test("SVG に全ての穴が描かれる", () => {
  const svg = renderSvg(LAYOUT)
  expect(svg.match(/class="hole"/g)?.length).toBe(COLS * ROWS)
})

// 目的: 配線が 1 本残らず描かれること。
test("SVG に全てのワイヤが描かれる", () => {
  const svg = renderSvg(LAYOUT)
  expect(svg.match(/class="wire"/g)?.length).toBe(LAYOUT.wires.length)
})

// 目的: 方位の凡例が対応表から描かれること。図だけ見て向きが分かる状態にする。
test("SVG に方位の凡例が入る", () => {
  const svg = renderSvg(LAYOUT)
  for (const word of ["右", "左", "上", "下"]) expect(svg).toContain(word)
  expect(svg).toContain("室内側から")
})

// 目的: 結線表が全ワイヤを穴 ID で並べること。半田付けはこの表を見て進める。
test("結線表に全てのワイヤが並ぶ", () => {
  const table = renderTable(LAYOUT)
  for (const w of LAYOUT.wires) expect(table).toContain(`| ${w.from} | ${w.to} |`)
})
```

- [ ] **Step 2: 落ちることを確認**

Run: `cd circuit && nix develop -c bun test perfboard/render.test.ts`
Expected: FAIL（`Cannot find module './render'`）

- [ ] **Step 3: 実装**

`circuit/perfboard/render.ts`:

```ts
// circuit/perfboard/render.ts
// 配置データを SVG と結線表に落とす。方位の凡例は scripts/axes.ts の対応表から描く。

import { axisWithLabel, VIEWPOINT } from "../../scripts/axes"
import { COLS, PITCH, ROWS, holeId, parseHole } from "./board"
import type { Layout } from "./verify"

const MARGIN = 24
const SCALE = 6 // mm あたりの px

const NET_COLORS: Record<string, string> = {
  V5: "#e6194B",
  GND: "#222222",
  SERVO_RTN: "#9A6324",
  SERVO_SIG: "#4363d8",
  GATE_DRV: "#f58231",
  GATE: "#f58231",
  LED_DRV_R: "#e6194B",
  LED_A_R: "#e6194B",
  LED_DRV_G: "#3cb44b",
  LED_A_G: "#3cb44b",
  BTN: "#911eb4",
}

// 列 1 は +X（右）端なので、画面上は右へ行くほど列番号が小さい。
// 行 1（A）は −Y（下）端なので、画面上は下へ行くほど行番号が小さい。
function xy(id: string): { x: number; y: number } {
  const h = parseHole(id)
  return {
    x: MARGIN + (COLS - h.col) * PITCH * SCALE,
    y: MARGIN + (ROWS - h.row) * PITCH * SCALE,
  }
}

export function renderSvg(layout: Layout): string {
  const w = MARGIN * 2 + (COLS - 1) * PITCH * SCALE
  const h = MARGIN * 2 + (ROWS - 1) * PITCH * SCALE + 40 // 凡例のぶん
  const out: string[] = []
  out.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">`)
  out.push(`<rect width="${w}" height="${h}" fill="#f7f3e8"/>`)

  for (let col = 1; col <= COLS; col++)
    for (let row = 1; row <= ROWS; row++) {
      const p = xy(holeId({ col, row }))
      out.push(`<circle class="hole" cx="${p.x}" cy="${p.y}" r="2.2" fill="#fff" stroke="#c9b98f"/>`)
    }

  for (const [leg, hole] of Object.entries(layout.legs)) {
    const p = xy(hole)
    out.push(`<circle class="leg" cx="${p.x}" cy="${p.y}" r="3.4" fill="#8a7a4e"/>`)
    out.push(`<text class="leg-label" x="${p.x + 5}" y="${p.y - 4}" font-size="7">${leg}</text>`)
  }

  for (const wire of layout.wires) {
    const a = xy(wire.from)
    const b = xy(wire.to)
    const dash = wire.side === "solder" ? ` stroke-dasharray="4 3"` : ""
    const color = NET_COLORS[wire.net] ?? "#666"
    out.push(`<line class="wire" x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}" stroke="${color}" stroke-width="2"${dash}/>`)
  }

  // 方位の凡例。破線は裏面（はんだ面）を通る線。
  const legendY = h - 12
  out.push(`<text x="${MARGIN}" y="${legendY}" font-size="10">${VIEWPOINT}見て ${axisWithLabel("+X")} ${axisWithLabel("-X")} ${axisWithLabel("+Y")} ${axisWithLabel("-Y")} / 破線 = 裏面</text>`)
  out.push(`</svg>`)
  return out.join("\n")
}

export function renderTable(layout: Layout): string {
  const rows = layout.wires.map(
    (w) => `| ${w.from} | ${w.to} | ${w.net} | ${w.side === "solder" ? "裏" : "表"} |`)
  return [
    `<!-- circuit/perfboard-build.ts の生成物。手で編集しない。 -->`,
    ``,
    `# ユニバーサル基板の結線表`,
    ``,
    `方位は${VIEWPOINT}ドアを正面に見た向き。${axisWithLabel("+X")}が列 1、${axisWithLabel("-Y")}が行 A。`,
    `穴 ID は「行の letter + 列番号」。面の「裏」ははんだ面を通す線。`,
    ``,
    `| from | to | ネット | 面 |`,
    `| --- | --- | --- | --- |`,
    ...rows,
    ``,
  ].join("\n")
}
```

- [ ] **Step 4: 通ることを確認**

Run: `cd circuit && nix develop -c bun test perfboard/render.test.ts`
Expected: PASS（4 tests）

- [ ] **Step 5: 生成スクリプトを書く**

`circuit/perfboard-build.ts`:

```ts
// circuit/perfboard-build.ts
// 配線見本を書き出す。SVG は派生物（非コミット）、結線表はコミットする。
import { mkdirSync, writeFileSync } from "node:fs"
import { LAYOUT } from "./perfboard/layout"
import { renderSvg, renderTable } from "./perfboard/render"
import { verifyLayout } from "./perfboard/verify"
import { ALLOW_UNCONNECTED } from "./netlist"

const problems = verifyLayout(LAYOUT, ALLOW_UNCONNECTED)
if (problems.length) {
  console.error(problems.join("\n"))
  process.exit(1)
}

mkdirSync("build", { recursive: true })
writeFileSync("build/perfboard.svg", renderSvg(LAYOUT))
writeFileSync("../docs/perfboard-wiring.md", renderTable(LAYOUT))
console.log(`ok: ${LAYOUT.wires.length} wires`)
```

- [ ] **Step 6: 生成して結線表をコミット対象にする**

Run: `cd circuit && nix develop -c bun perfboard-build.ts`
Expected: `ok: 22 wires` と表示され、`circuit/build/perfboard.svg` と `docs/perfboard-wiring.md` ができる

- [ ] **Step 7: 結線表が生成物と一致し続けるテストを足す**

`circuit/perfboard/render.test.ts` に追記する。

```ts
// 目的: コミット済みの結線表が生成結果と一致すること。
// 配置を変えて再生成し忘れると、現物と文書がずれるのでここで落とす。
test("コミット済みの結線表が最新である", async () => {
  const committed = await Bun.file("../docs/perfboard-wiring.md").text()
  expect(committed).toBe(renderTable(LAYOUT))
})
```

Run: `cd circuit && nix develop -c bun test perfboard/render.test.ts`
Expected: PASS（5 tests）

- [ ] **Step 8: Justfile とコマンド表を更新**

`Justfile` に追加する。

```
# ユニバーサル基板の配線見本を生成（SVG + 結線表）
perfboard:
    cd circuit && bun perfboard-build.ts
```

`README.md` と `CLAUDE.md` のコマンド表に 1 行足す。

```
| ユニバーサル基板の配線見本 | `just perfboard` | `cd circuit && bun perfboard-build.ts` |
```

- [ ] **Step 9: backlog を更新**

`backlog/tasks/task-4 - rebuild-circuit-on-universal-board.md` の「作業項目」に 1 行足す。

```markdown
- 配線見本（`just perfboard`）の結線表どおりにはんだ付けする。配置を動かしたら再生成して `docs/perfboard-wiring.md` を更新する。
```

- [ ] **Step 10: 全体を通す**

Run: `cd circuit && nix develop -c bun test`
Expected: PASS

Run: `nix develop -c bun test enclosure/scripts/ scripts/`
Expected: PASS

Run: `nix develop -c cargo host-test`
Expected: PASS

- [ ] **Step 11: コミット**

```bash
git add circuit/perfboard/render.ts circuit/perfboard/render.test.ts circuit/perfboard-build.ts docs/perfboard-wiring.md Justfile README.md CLAUDE.md "backlog/tasks/task-4 - rebuild-circuit-on-universal-board.md"
git commit -m "feat(circuit): ユニバーサル基板の配線見本（SVG + 結線表）を生成する"
```

---

## 実機での確認（計画の外）

ここまではすべてモデル上の主張である。次は現物で確かめる。

- 結線表どおりにはんだ付けし、導通をテスターで当たる
- ファームを書き込み、TCP 経由の施錠と解錠、LED の 2 色、ボタンのトグルを確認する
- USB プラグがカバーの切欠きから届くか（Pico が #90 の想定より 4mm ほど −X（左）寄りに載るため）

結果は TASK-4 の受け入れ条件として記録する。

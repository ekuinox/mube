# ブレッドボード自動 place & route Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 部品ref集合を渡すと、`circuit/parts.ts` の結線を拾い、ブレッドボード上の配置とジャンパ配線を自動生成し、電気検証済みの配線図SVGを出力する汎用パイプラインを作る。

**Architecture:** subcircuit(ネット抽出) → footprints(使用ピン) → place(1D順序ソルバ) → route(チャネルルータ) → verify(union-find実行時ゲート) → render(SVG)。既存 `circuit/breadboard/model.ts`(穴/列タイ/union-find) と `render.ts`(描画) を土台に再利用。手書き `servo-layout.ts` を自動生成へ一本化。

**Tech Stack:** TypeScript / bun（`circuit/` で実行。PATHに無ければ `nix develop -c bun ...`）。純関数中心で host テスト可能。

## Global Constraints

- 電気的正しさは `verify.ts`(union-find) が保証：出力は常に正しいか**例外で明示失敗**（黙って間違えない）。
- 決定的：乱数は seed 固定。同じ入力→同じ出力（同一SVG）。
- ブレッドボード制約：信号ジャンパは**上段(a-e)内**にしか置けない（列タイ `U<col>` を共有するため。下段 f-j は別ノード `L<col>`）。配線 lane は row c/d/e、row b は電源/GNDレールスタブ専用。
- レールネット(`V5→TP`, `GND→TN`)は各ピン→レールの短スタブで処理し、**配置コスト(配線長/交差)から除外**。信号ネットのみ最適化。
- フットプリントは**使用ピンのみの簡易**（各使用ピン=1列、上段 row a、部品間1列の隙間）。実寸フットプリントは非対象。
- 交差は許容（被覆線）。エラーにせずログで交差数/トラック数を可視化。
- `build/` 配下は非コミットの派生物。SVG はコミットしない。
- 既存 `model.ts` の型を使う：`Hole`, `Jumper`, `Rail`, `StripRow`, `COLS`, `nodeOf`, `buildConnectivity`。

---

## ファイル構成

新規（すべて `circuit/breadboard/`）:
- `layout-types.ts` — パイプライン共有の型（`Placement`, `RouteResult`, `ComponentMeta`, `BreadboardLayout`）。
- `config.ts` — 定数（`RAIL_NETS`, `WEIGHTS`, `SIGNAL_LANES`, `RAIL_STUB_ROW`）。
- `footprints.ts` — 部品ごとの `Footprint`（正規ピン順・端寄りタグ・描画ヒント・ラベル/値）テーブル。
- `subcircuit.ts` — `normaliseEndpoint`, `subcircuitNets`, `PRESETS`。`servo-nets.ts` の汎用版。
- `verify.ts` — `verifyLayout` 純関数（網羅・全結線・ショート無しを検査、エラー文字列配列）。
- `place.ts` — `placeParts` 1D配置ソルバ。
- `route.ts` — `routeNets` チャネルルータ。
- `autolayout.ts` — `autoLayout` オーケストレータ（place→route→verify(throw)→`BreadboardLayout`）。
- `breadboard-auto.ts` — CLI。
変更:
- `render.ts` — `renderBreadboardSvg(layout: BreadboardLayout)` に引数化。極性/帯/注記をデータ駆動に。
- `render.test.ts` — `autoLayout` 由来のレイアウトで描画をスモークテスト。
- `package.json` — `breadboard` スクリプトを `breadboard-auto.ts` へ。
削除（最終タスク）:
- `servo-layout.ts`, `servo-nets.ts`, `servo-verify.test.ts`, `breadboard-servo.ts`。

---

## Task 1: 共有型・定数・フットプリント（静的データ）

**Files:**
- Create: `circuit/breadboard/layout-types.ts`, `circuit/breadboard/config.ts`, `circuit/breadboard/footprints.ts`
- Test: `circuit/breadboard/footprints.test.ts`

**Interfaces:**
- Produces:
  - `layout-types.ts`: `Placement`, `RouteResult`, `ComponentMeta`, `BreadboardLayout`（下記）。
  - `config.ts`: `RAIL_NETS: Record<string, Rail>`, `WEIGHTS: {span:number;cross:number;edge:number;width:number}`, `SIGNAL_LANES: StripRow[]`, `RAIL_STUB_ROW: StripRow`。
  - `footprints.ts`: `type EdgeAffinity = "left"|"right"|null`, `interface Footprint`, `FOOTPRINTS: Record<string, Footprint>`。

- [ ] **Step 1: 型を書く**

```ts
// circuit/breadboard/layout-types.ts
import type { Hole, Jumper } from "./model"

export interface Placement {
  order: string[]                          // 左→右の部品順
  cols: number                             // 使用した総列数
  partColumns: Record<string, number[]>    // ref → 占有列
  pinHoles: Record<string, Hole>           // "Ref.pin" → Hole(row a)
}

export interface RouteResult {
  jumpers: Jumper[]
  stats: { crossings: number; tracksUsed: number }
}

export interface ComponentMeta {
  label: string
  value?: string
  pins: string[]           // "Ref.pin" list（描画で束ねる）
  polarityPin?: string     // "+" を描くピン（"Ref.pin"）
  stripePin?: string       // カソード帯を描くピン（"Ref.pin"）
}

export interface BreadboardLayout {
  pinHoles: Record<string, Hole>
  jumpers: Jumper[]
  components: Record<string, ComponentMeta>
  notes: string[]
  stats: { crossings: number; tracksUsed: number; cols: number }
}
```

- [ ] **Step 2: 定数を書く**

```ts
// circuit/breadboard/config.ts
import type { Rail, StripRow } from "./model"

// ネット名 → レール。これらは配置コストから除外され、各ピン→レールの短スタブで配線される。
export const RAIL_NETS: Record<string, Rail> = { V5: "TP", GND: "TN" }

// 配置コスト重み。可読性(span,cross)を厚め、幅を薄く。実測で調整可。
export const WEIGHTS = { span: 3, cross: 5, edge: 2, width: 1 }

// 信号ジャンパの水平レーン（上段のみ。列タイ U<col> を共有するため下段は使えない）。
export const SIGNAL_LANES: StripRow[] = ["c", "d", "e"]
// 電源/GNDレールスタブが使う上段の行。
export const RAIL_STUB_ROW: StripRow = "b"
```

- [ ] **Step 3: フットプリントテーブルを書く**

`pinOrder` は各部品の正規ピン順。実際に配置するのはサブ回路ネットに現れるピンのみ（後段でフィルタ）。ピン名は `parts.ts` の trace セレクタ由来の名前（`normaliseEndpoint` 後）に一致させる：chipは pinLabels（VBUS/GND/GP15…, SIG/VPLUS/GND, G/D/S, R/G/K）、抵抗/コンデンサは pin1/pin2、ダイオードは anode/cathode。

```ts
// circuit/breadboard/footprints.ts
export type EdgeAffinity = "left" | "right" | null

export interface Footprint {
  pinOrder: string[]       // 正規ピン順（pin名のみ、refは付けない）
  edgeAffinity: EdgeAffinity
  label: string
  value?: string
  polarityPin?: string     // pin名（"+"を描く）
  stripePin?: string       // pin名（カソード帯）
}

// ref → Footprint。smtlk 全12部品を網羅。
export const FOOTPRINTS: Record<string, Footprint> = {
  U1:   { pinOrder: ["VBUS", "GND", "GP15", "GP14", "GP16", "GP18", "GP17"], edgeAffinity: "left",  label: "U1",  value: "Pico W" },
  M1:   { pinOrder: ["SIG", "VPLUS", "GND"], edgeAffinity: "right", label: "M1",  value: "Servo" },
  Q1:   { pinOrder: ["G", "D", "S"], edgeAffinity: null, label: "Q1",  value: "MOSFET" },
  Rg:   { pinOrder: ["pin1", "pin2"], edgeAffinity: null, label: "Rg",  value: "220Ω" },
  Rgs:  { pinOrder: ["pin1", "pin2"], edgeAffinity: null, label: "Rgs", value: "10kΩ" },
  Rled: { pinOrder: ["pin1", "pin2"], edgeAffinity: null, label: "Rled", value: "330Ω" },
  Rled2:{ pinOrder: ["pin1", "pin2"], edgeAffinity: null, label: "Rled2", value: "330Ω" },
  D1:   { pinOrder: ["R", "G", "K"], edgeAffinity: "right", label: "D1",  value: "2-LED" },
  SW1:  { pinOrder: ["pin1", "pin2"], edgeAffinity: "right", label: "SW1", value: "Tact" },
  C1:   { pinOrder: ["pin1", "pin2"], edgeAffinity: null, label: "C1",  value: "470uF", polarityPin: "pin1" },
  C2:   { pinOrder: ["pin1", "pin2"], edgeAffinity: null, label: "C2",  value: "100nF" },
  D2:   { pinOrder: ["cathode", "anode"], edgeAffinity: null, label: "D2", value: "Flyback", stripePin: "cathode" },
}
```

- [ ] **Step 4: テストを書く**

```ts
// circuit/breadboard/footprints.test.ts
import { expect, test } from "bun:test"
import { FOOTPRINTS } from "./footprints"
import { RAIL_NETS } from "./config"

test("FOOTPRINTS が smtlk 全12部品を網羅", () => {
  const refs = ["U1","M1","Q1","Rg","Rgs","Rled","Rled2","D1","SW1","C1","C2","D2"]
  for (const r of refs) expect(FOOTPRINTS[r], `missing footprint ${r}`).toBeDefined()
})

test("各フットプリントの pinOrder が非空・重複なし", () => {
  for (const [ref, fp] of Object.entries(FOOTPRINTS)) {
    expect(fp.pinOrder.length, `${ref} empty pinOrder`).toBeGreaterThan(0)
    expect(new Set(fp.pinOrder).size, `${ref} dup pins`).toBe(fp.pinOrder.length)
  }
})

test("RAIL_NETS は V5→TP, GND→TN", () => {
  expect(RAIL_NETS).toEqual({ V5: "TP", GND: "TN" })
})
```

- [ ] **Step 5: 実行して通す**

Run（`circuit/`）: `bun test breadboard/footprints.test.ts`
Expected: 3 pass。落ちたら FOOTPRINTS の網羅漏れ等を修正。

- [ ] **Step 6: コミット**

```bash
git add circuit/breadboard/layout-types.ts circuit/breadboard/config.ts circuit/breadboard/footprints.ts circuit/breadboard/footprints.test.ts
git commit -m "feat(breadboard): 共有型・定数・フットプリントテーブルを追加"
```

---

## Task 2: サブ回路ネット抽出（subcircuit.ts）

**Files:**
- Create: `circuit/breadboard/subcircuit.ts`, `circuit/breadboard/subcircuit.test.ts`

**Interfaces:**
- Consumes: `NETS` from `../parts`。
- Produces:
  - `normaliseEndpoint(ep: string): string`（`".U1 .VBUS"`→`"U1.VBUS"`）
  - `subcircuitNets(parts: Set<string>): Record<string, string[]>`（ネット名→ソート済み `"Ref.pin"` 配列。選択部品の端点のみ、端点2未満のネットは除外）
  - `PRESETS: Record<string, string[]>`（`SERVO_DRIVE`, `LED_BUTTON`, `FULL`）

- [ ] **Step 1: テストを書く**

```ts
// circuit/breadboard/subcircuit.test.ts
import { expect, test } from "bun:test"
import { normaliseEndpoint, subcircuitNets, PRESETS } from "./subcircuit"

test("normaliseEndpoint", () => {
  expect(normaliseEndpoint(".U1 .VBUS")).toBe("U1.VBUS")
  expect(normaliseEndpoint(".D2 .cathode")).toBe("D2.cathode")
  expect(normaliseEndpoint(".Rg .pin1")).toBe("Rg.pin1")
})

test("SERVO_DRIVE サブ回路が期待の6ネットを抽出", () => {
  const nets = subcircuitNets(new Set(PRESETS.SERVO_DRIVE))
  expect(nets).toEqual({
    V5:        ["C1.pin1", "C2.pin1", "D2.cathode", "M1.VPLUS", "U1.VBUS"],
    GND:       ["C1.pin2", "C2.pin2", "Q1.S", "Rgs.pin2", "U1.GND"],
    SERVO_RTN: ["D2.anode", "M1.GND", "Q1.D"],
    SERVO_SIG: ["M1.SIG", "U1.GP15"],
    GATE_DRV:  ["Rg.pin1", "U1.GP14"],
    GATE:      ["Q1.G", "Rg.pin2", "Rgs.pin1"],
  })
})

test("FULL は全12部品を含む", () => {
  expect(new Set(PRESETS.FULL)).toEqual(
    new Set(["U1","M1","Q1","Rg","Rgs","Rled","Rled2","D1","SW1","C1","C2","D2"]))
  // LED/ボタン系ネットも現れる（例: BTN は SW1+U1.GP17）
  const nets = subcircuitNets(new Set(PRESETS.FULL))
  expect(nets.BTN.sort()).toEqual(["SW1.pin1", "U1.GP17"])
})
```

- [ ] **Step 2: 実行して落ちるのを確認**

Run（`circuit/`）: `bun test breadboard/subcircuit.test.ts`
Expected: FAIL（`Cannot find module './subcircuit'`）。

- [ ] **Step 3: 実装**

```ts
// circuit/breadboard/subcircuit.ts
import { NETS } from "../parts"

export function normaliseEndpoint(ep: string): string {
  return ep.replace(/\./g, " ").trim().split(/\s+/).join(".")
}

// 部品ref集合 → ネット名→ソート済み "Ref.pin" 配列。選択部品の端点のみ、端点2未満は除外。
export function subcircuitNets(parts: Set<string>): Record<string, string[]> {
  const result: Record<string, string[]> = {}
  for (const net of NETS) {
    const filtered = net.endpoints
      .map(normaliseEndpoint)
      .filter((ep) => parts.has(ep.split(".")[0]))
      .sort()
    if (filtered.length >= 2) result[net.name] = filtered
  }
  return result
}

export const PRESETS: Record<string, string[]> = {
  SERVO_DRIVE: ["U1", "M1", "Q1", "Rg", "Rgs", "C1", "C2", "D2"],
  LED_BUTTON:  ["U1", "Rled", "Rled2", "D1", "SW1"],
  FULL:        ["U1", "M1", "Q1", "Rg", "Rgs", "Rled", "Rled2", "D1", "SW1", "C1", "C2", "D2"],
}
```

- [ ] **Step 4: 実行して通す**

Run（`circuit/`）: `bun test breadboard/subcircuit.test.ts`
Expected: 3 pass。`SERVO_DRIVE` の期待値が実 NETS と食い違ったら、`parts.ts` が正なので**テスト期待値を実結果に合わせて**直す（ピン名の綴り等）。

- [ ] **Step 5: コミット**

```bash
git add circuit/breadboard/subcircuit.ts circuit/breadboard/subcircuit.test.ts
git commit -m "feat(breadboard): サブ回路ネット抽出とプリセットを追加"
```

---

## Task 3: レイアウト検証（verify.ts）

**Files:**
- Create: `circuit/breadboard/verify.ts`, `circuit/breadboard/verify.test.ts`

**Interfaces:**
- Consumes: `nodeOf`, `buildConnectivity`, `Hole`, `Jumper` from `./model`。
- Produces: `verifyLayout(nets: Record<string,string[]>, pinHoles: Record<string,Hole>, jumpers: Jumper[]): string[]`（エラー文字列配列。空＝合格）。

- [ ] **Step 1: テストを書く**

正しい最小レイアウト（1ネット2ピンを列タイ or ジャンパで繋ぐ）と、壊れたレイアウト（未接続・ショート）を用意して検査。

```ts
// circuit/breadboard/verify.test.ts
import { expect, test } from "bun:test"
import type { Hole, Jumper } from "./model"
import { verifyLayout } from "./verify"

const s = (col: number, row: any): Hole => ({ kind: "strip", col, row })

// N1: A.p(col1)–B.p(col3) をジャンパで接続。N2: C.p(col5)–D.p(col7) をジャンパで接続。
const pinHoles: Record<string, Hole> = {
  "A.p": s(1, "a"), "B.p": s(3, "a"), "C.p": s(5, "a"), "D.p": s(7, "a"),
}
const good: Jumper[] = [
  { from: s(1, "c"), to: s(3, "c"), net: "N1" },
  { from: s(5, "c"), to: s(7, "c"), net: "N2" },
]
const nets = { N1: ["A.p", "B.p"], N2: ["C.p", "D.p"] }

test("正しいレイアウトはエラー無し", () => {
  expect(verifyLayout(nets, pinHoles, good)).toEqual([])
})

test("未接続を検出", () => {
  const errs = verifyLayout(nets, pinHoles, [good[0]]) // N2 のジャンパを外す
  expect(errs.some((e) => e.includes("N2"))).toBe(true)
})

test("ショートを検出", () => {
  const shorted: Jumper[] = [...good, { from: s(3, "d"), to: s(5, "d"), net: "X" }] // N1とN2を橋絡
  const errs = verifyLayout(nets, pinHoles, shorted)
  expect(errs.some((e) => e.toLowerCase().includes("short"))).toBe(true)
})

test("穴未割当を検出", () => {
  const errs = verifyLayout({ N1: ["A.p", "Z.p"] }, pinHoles, good)
  expect(errs.some((e) => e.includes("Z.p"))).toBe(true)
})
```

- [ ] **Step 2: 実行して落ちるのを確認**

Run（`circuit/`）: `bun test breadboard/verify.test.ts`
Expected: FAIL（module 無し）。

- [ ] **Step 3: 実装**

```ts
// circuit/breadboard/verify.ts
import { type Hole, type Jumper, nodeOf, buildConnectivity } from "./model"

// 網羅・全結線・ショート無しを検査。エラー文字列配列（空＝合格）。
export function verifyLayout(
  nets: Record<string, string[]>,
  pinHoles: Record<string, Hole>,
  jumpers: Jumper[],
): string[] {
  const errors: string[] = []
  const conn = buildConnectivity(jumpers)

  // group 代表 → その group に属するネット名の集合（ショート検出用）
  const groupNets = new Map<string, Set<string>>()

  for (const [netName, pins] of Object.entries(nets)) {
    const groups = new Set<string>()
    for (const pin of pins) {
      const hole = pinHoles[pin]
      if (!hole) { errors.push(`pin ${pin} (net ${netName}) has no hole`); continue }
      const g = conn.groupOf(nodeOf(hole))
      groups.add(g)
      if (!groupNets.has(g)) groupNets.set(g, new Set())
      groupNets.get(g)!.add(netName)
    }
    if (groups.size > 1) errors.push(`net ${netName} not fully connected (${groups.size} groups)`)
  }

  for (const [g, netSet] of groupNets) {
    if (netSet.size > 1) errors.push(`short: nets ${[...netSet].sort().join(", ")} share group ${g}`)
  }
  return errors
}
```

- [ ] **Step 4: 実行して通す**

Run（`circuit/`）: `bun test breadboard/verify.test.ts`
Expected: 4 pass。

- [ ] **Step 5: コミット**

```bash
git add circuit/breadboard/verify.ts circuit/breadboard/verify.test.ts
git commit -m "feat(breadboard): レイアウト検証(union-find)の純関数を追加"
```

---

## Task 4: 1D配置ソルバ（place.ts）

**Files:**
- Create: `circuit/breadboard/place.ts`, `circuit/breadboard/place.test.ts`

**Interfaces:**
- Consumes: `FOOTPRINTS` from `./footprints`; `RAIL_NETS`, `WEIGHTS` from `./config`; `Placement` from `./layout-types`; `Hole` from `./model`。
- Produces:
  - `usedPinsByPart(refs: string[], nets: Record<string,string[]>): Record<string, string[]>`（ref → 使用ピン名"pin"のみ、footprint順）
  - `assignColumns(order: string[], usedPins: Record<string,string[]>): Placement`（順序→列割付。部品間1列空ける、pin は row a）
  - `placementCost(pl: Placement, nets: Record<string,string[]>): number`
  - `placeParts(refs: string[], nets: Record<string,string[]>, seed?: number): Placement`（n≤8 総当り、それ超は seed 付き 2-opt。最小コストの Placement）

- [ ] **Step 1: テストを書く**

```ts
// circuit/breadboard/place.test.ts
import { expect, test } from "bun:test"
import { assignColumns, placementCost, placeParts, usedPinsByPart } from "./place"

const NETS = {
  V5: ["A.p1", "B.p1"],          // レールネット扱い？→ V5/GND のみレール。ここはテスト用の一般ネット
  N1: ["A.p2", "B.p2"],
}

test("usedPinsByPart は footprint 順で使用ピンだけ返す", () => {
  const used = usedPinsByPart(["Rg", "Rgs"], { GATE: ["Rg.pin2", "Rgs.pin1"], X: ["Rg.pin1", "Rgs.pin2"] })
  expect(used.Rg).toEqual(["pin1", "pin2"])   // footprint 順
  expect(used.Rgs).toEqual(["pin1", "pin2"])
})

test("assignColumns: 部品間に1列の隙間、pin は row a、幅が正しい", () => {
  const used = { A: ["p1", "p2"], B: ["p1"] }
  const pl = assignColumns(["A", "B"], used)
  // A:col1,2  gap col3  B:col4
  expect(pl.partColumns.A).toEqual([1, 2])
  expect(pl.partColumns.B).toEqual([4])
  expect(pl.pinHoles["A.p2"]).toEqual({ kind: "strip", col: 2, row: "a" })
  expect(pl.cols).toBe(4)
})

test("placeParts は接続部品を隣接させ低コスト順序を選ぶ（決定的）", () => {
  // 2部品2ピンの単純例。順序に依らずコスト同じでも、決定的に安定した結果を返す。
  const refs = ["Rg", "Rgs"]
  const nets = { GATE: ["Rg.pin2", "Rgs.pin1"] }
  const a = placeParts(refs, nets, 1)
  const b = placeParts(refs, nets, 1)
  expect(a.order).toEqual(b.order)        // 決定的
  expect(a.cols).toBeLessThanOrEqual(6)
})
```

- [ ] **Step 2: 実行して落ちるのを確認**

Run（`circuit/`）: `bun test breadboard/place.test.ts`
Expected: FAIL（module 無し）。

- [ ] **Step 3: 実装**

```ts
// circuit/breadboard/place.ts
import type { Hole } from "./model"
import type { Placement } from "./layout-types"
import { FOOTPRINTS } from "./footprints"
import { RAIL_NETS, WEIGHTS } from "./config"

// ref → 使用ピン（footprint pinOrder 順、サブ回路ネットに現れるものだけ）
export function usedPinsByPart(refs: string[], nets: Record<string, string[]>): Record<string, string[]> {
  const usedSet: Record<string, Set<string>> = {}
  for (const r of refs) usedSet[r] = new Set()
  for (const pins of Object.values(nets)) {
    for (const p of pins) {
      const [ref, pin] = p.split(".")
      if (usedSet[ref]) usedSet[ref].add(pin)
    }
  }
  const out: Record<string, string[]> = {}
  for (const r of refs) {
    const order = FOOTPRINTS[r]?.pinOrder ?? [...usedSet[r]]
    out[r] = order.filter((p) => usedSet[r].has(p))
  }
  return out
}

// 順序 → 列割付。部品iを連続列、部品間に1列の隙間。pin は row a。
export function assignColumns(order: string[], usedPins: Record<string, string[]>): Placement {
  const partColumns: Record<string, number[]> = {}
  const pinHoles: Record<string, Hole> = {}
  let col = 1
  for (const ref of order) {
    const pins = usedPins[ref]
    const cols: number[] = []
    for (const pin of pins) {
      cols.push(col)
      pinHoles[`${ref}.${pin}`] = { kind: "strip", col, row: "a" }
      col++
    }
    partColumns[ref] = cols
    col++ // gap
  }
  return { order, cols: Math.max(0, col - 2), partColumns, pinHoles }
}

// 信号ネット（レールネット除外）だけでコスト算出。
export function placementCost(pl: Placement, nets: Record<string, string[]>): number {
  const colOf = (pinKey: string) => pl.pinHoles[pinKey]?.col ?? 0
  const signalNets = Object.entries(nets).filter(([name]) => !(name in RAIL_NETS))

  // span
  let span = 0
  const intervals: Array<[number, number]> = []
  for (const [, pins] of signalNets) {
    const cs = pins.map(colOf).filter((c) => c > 0)
    if (cs.length < 2) continue
    const lo = Math.min(...cs), hi = Math.max(...cs)
    span += hi - lo
    intervals.push([lo, hi])
  }
  // crossing: 区間が重なるペア数
  let cross = 0
  for (let i = 0; i < intervals.length; i++)
    for (let j = i + 1; j < intervals.length; j++) {
      const [a1, a2] = intervals[i], [b1, b2] = intervals[j]
      if (a1 < b2 && b1 < a2) cross++
    }
  // edge affinity
  let edge = 0
  for (const ref of pl.order) {
    const aff = FOOTPRINTS[ref]?.edgeAffinity
    if (!aff) continue
    const cols = pl.partColumns[ref]
    if (aff === "left") edge += Math.min(...cols) - 1
    else edge += pl.cols - Math.max(...cols)
  }
  return WEIGHTS.span * span + WEIGHTS.cross * cross + WEIGHTS.edge * edge + WEIGHTS.width * pl.cols
}

// seed 付き決定的乱数（mulberry32）
function rng(seed: number) {
  let a = seed >>> 0
  return () => {
    a |= 0; a = (a + 0x6D2B79F5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function permutations<T>(arr: T[]): T[][] {
  if (arr.length <= 1) return [arr]
  const out: T[][] = []
  for (let i = 0; i < arr.length; i++) {
    const rest = [...arr.slice(0, i), ...arr.slice(i + 1)]
    for (const p of permutations(rest)) out.push([arr[i], ...p])
  }
  return out
}

// n≤8 総当り、それ超は seed 付き 2-opt（近傍=2部品スワップ）で山登り＋再スタート。
export function placeParts(refs: string[], nets: Record<string, string[]>, seed = 1): Placement {
  const used = usedPinsByPart(refs, nets)
  const evalOrder = (order: string[]): { pl: Placement; cost: number } => {
    const pl = assignColumns(order, used)
    return { pl, cost: placementCost(pl, nets) }
  }

  if (refs.length <= 8) {
    let best = evalOrder(refs)
    for (const perm of permutations(refs)) {
      const cand = evalOrder(perm)
      if (cand.cost < best.cost) best = cand
    }
    return best.pl
  }

  const rand = rng(seed)
  let best = evalOrder(refs)
  for (let restart = 0; restart < 20; restart++) {
    // ランダム初期順
    const order = [...refs]
    for (let i = order.length - 1; i > 0; i--) {
      const j = Math.floor(rand() * (i + 1));
      [order[i], order[j]] = [order[j], order[i]]
    }
    let cur = evalOrder(order)
    let improved = true
    while (improved) {
      improved = false
      for (let i = 0; i < order.length; i++)
        for (let j = i + 1; j < order.length; j++) {
          const cand = [...cur.pl.order];
          [cand[i], cand[j]] = [cand[j], cand[i]]
          const e = evalOrder(cand)
          if (e.cost < cur.cost) { cur = e; improved = true }
        }
    }
    if (cur.cost < best.cost) best = cur
  }
  return best.pl
}
```

- [ ] **Step 4: 実行して通す**

Run（`circuit/`）: `bun test breadboard/place.test.ts`
Expected: 3 pass。

- [ ] **Step 5: コミット**

```bash
git add circuit/breadboard/place.ts circuit/breadboard/place.test.ts
git commit -m "feat(breadboard): 1D配置ソルバ(コスト関数+総当り/2-opt)を追加"
```

---

## Task 5: チャネルルータ（route.ts）

**Files:**
- Create: `circuit/breadboard/route.ts`, `circuit/breadboard/route.test.ts`

**Interfaces:**
- Consumes: `Placement`, `RouteResult` from `./layout-types`; `RAIL_NETS`, `SIGNAL_LANES`, `RAIL_STUB_ROW` from `./config`; `Hole`, `Jumper` from `./model`; `verifyLayout` from `./verify`（テストで使用）。
- Produces: `routeNets(pl: Placement, nets: Record<string,string[]>): RouteResult`。

- [ ] **Step 1: テストを書く**

配置＋ネットからジャンパを生成し、`verifyLayout` を通ることを確認（＝配線が正しい）。

```ts
// circuit/breadboard/route.test.ts
import { expect, test } from "bun:test"
import { assignColumns, usedPinsByPart } from "./place"
import { routeNets } from "./route"
import { verifyLayout } from "./verify"

test("生成ジャンパが verifyLayout を通る（信号＋レール混在）", () => {
  const refs = ["U1", "Rg", "Q1"]
  const nets = {
    V5: ["U1.VBUS"],                    // 端点1だが（他部品なし）→ ここでは検証用に2以上に調整
    GATE_DRV: ["U1.GP14", "Rg.pin1"],
    GATE: ["Rg.pin2", "Q1.G"],
    GND: ["U1.GND", "Q1.S"],
  }
  const used = usedPinsByPart(refs, nets)
  const pl = assignColumns(["U1", "Rg", "Q1"], used)
  const { jumpers, stats } = routeNets(pl, nets)
  // V5 は端点1なので検証対象から外す（端点2未満は verify で扱わない前提のネットのみ渡す）
  const checkable = { GATE_DRV: nets.GATE_DRV, GATE: nets.GATE, GND: nets.GND }
  expect(verifyLayout(checkable, pl.pinHoles, jumpers)).toEqual([])
  expect(stats.tracksUsed).toBeGreaterThanOrEqual(1)
})

test("レールネットは各ピン→レールのスタブになる", () => {
  const refs = ["U1", "Q1"]
  const nets = { GND: ["U1.GND", "Q1.S"] }
  const used = usedPinsByPart(refs, nets)
  const pl = assignColumns(["U1", "Q1"], used)
  const { jumpers } = routeNets(pl, nets)
  // GND のジャンパは全て rail 端点(TN)を持つ
  const gndJ = jumpers.filter((j) => j.net === "GND")
  expect(gndJ.length).toBe(2)
  expect(gndJ.every((j) => j.from.kind === "rail" || j.to.kind === "rail")).toBe(true)
})
```

- [ ] **Step 2: 実行して落ちるのを確認**

Run（`circuit/`）: `bun test breadboard/route.test.ts`
Expected: FAIL（module 無し）。

- [ ] **Step 3: 実装**

```ts
// circuit/breadboard/route.ts
import { type Hole, type Jumper } from "./model"
import type { Placement, RouteResult } from "./layout-types"
import { RAIL_NETS, SIGNAL_LANES, RAIL_STUB_ROW } from "./config"

// ネット名 → 安定した色（信号用パレット）
const PALETTE = ["#4363d8", "#f58231", "#911eb4", "#3cb44b", "#e6194B", "#42d4f4", "#f032e6", "#9A6324", "#808000", "#469990"]
function colorForNet(name: string, idx: number): string {
  if (name === "V5") return "red"
  if (name === "GND") return "black"
  return PALETTE[idx % PALETTE.length]
}

export function routeNets(pl: Placement, nets: Record<string, string[]>): RouteResult {
  const jumpers: Jumper[] = []
  const colOf = (pinKey: string) => pl.pinHoles[pinKey]?.col

  // 1) レールネット: 各ピン列 → レールへの短スタブ（row RAIL_STUB_ROW）
  const railNetNames = new Set(Object.keys(RAIL_NETS))
  for (const [name, pins] of Object.entries(nets)) {
    if (!railNetNames.has(name)) continue
    const rail = RAIL_NETS[name]
    for (const pin of pins) {
      const col = colOf(pin)
      if (col == null) continue
      jumpers.push({
        from: { kind: "strip", col, row: RAIL_STUB_ROW } as Hole,
        to: { kind: "rail", rail, col } as Hole,
        net: name, color: colorForNet(name, 0),
      })
    }
  }

  // 2) 信号ネット: 相異なる列をチェーンで連結。各セグメントを lane に割付。
  type Seg = { lo: number; hi: number; net: string; colorIdx: number }
  const segments: Seg[] = []
  let netIdx = 0
  for (const [name, pins] of Object.entries(nets)) {
    if (railNetNames.has(name)) continue
    const cols = [...new Set(pins.map(colOf).filter((c): c is number => c != null))].sort((a, b) => a - b)
    for (let i = 0; i + 1 < cols.length; i++) {
      segments.push({ lo: cols[i], hi: cols[i + 1], net: name, colorIdx: netIdx })
    }
    netIdx++
  }

  // left-edge 法: 左端でソート、各セグメントを重ならない最下トラックへ。空き無ければ交差許容で最小衝突トラックへ。
  segments.sort((a, b) => a.lo - b.lo || a.hi - b.hi)
  const laneEnds: number[][] = SIGNAL_LANES.map(() => []) // 各laneに置いた [lo,hi] の hi 群（重なり判定用）
  const lanePlaced: Array<Array<[number, number]>> = SIGNAL_LANES.map(() => [])
  let crossings = 0
  const usedLanes = new Set<number>()

  const overlaps = (placed: Array<[number, number]>, lo: number, hi: number) =>
    placed.some(([l, h]) => lo < h && l < hi)

  for (const seg of segments) {
    let lane = SIGNAL_LANES.findIndex((_, li) => !overlaps(lanePlaced[li], seg.lo, seg.hi))
    if (lane === -1) {
      // 交差許容: 最も衝突の少ない lane へ
      let bestLi = 0, bestConf = Infinity
      SIGNAL_LANES.forEach((_, li) => {
        const conf = lanePlaced[li].filter(([l, h]) => seg.lo < h && l < seg.hi).length
        if (conf < bestConf) { bestConf = conf; bestLi = li }
      })
      lane = bestLi
      crossings += bestConf
    }
    lanePlaced[lane].push([seg.lo, seg.hi])
    usedLanes.add(lane)
    const row = SIGNAL_LANES[lane]
    jumpers.push({
      from: { kind: "strip", col: seg.lo, row } as Hole,
      to: { kind: "strip", col: seg.hi, row } as Hole,
      net: seg.net, color: colorForNet(seg.net, seg.colorIdx),
    })
  }

  return { jumpers, stats: { crossings, tracksUsed: usedLanes.size } }
}
```

- [ ] **Step 4: 実行して通す**

Run（`circuit/`）: `bun test breadboard/route.test.ts`
Expected: 2 pass。`hi(seg)` のヘルパは lane 探索内のスコープの都合。落ちたら `overlaps`/交差カウントのロジックを確認。

- [ ] **Step 5: コミット**

```bash
git add circuit/breadboard/route.ts circuit/breadboard/route.test.ts
git commit -m "feat(breadboard): チャネルルータ(レールスタブ+信号lane割付)を追加"
```

---

## Task 6: オーケストレータ（autolayout.ts）

**Files:**
- Create: `circuit/breadboard/autolayout.ts`, `circuit/breadboard/autolayout.test.ts`

**Interfaces:**
- Consumes: `subcircuitNets`, `PRESETS` from `./subcircuit`; `placeParts` from `./place`; `routeNets` from `./route`; `verifyLayout` from `./verify`; `FOOTPRINTS` from `./footprints`; `BreadboardLayout`, `ComponentMeta` from `./layout-types`。
- Produces: `autoLayout(refs: string[], seed?: number): BreadboardLayout`（verify 失敗時は throw）。

- [ ] **Step 1: テストを書く**

各プリセットで通しの自動出力が検証を通ることを保証（＝自動出力は常に電気的に正しい）。

```ts
// circuit/breadboard/autolayout.test.ts
import { expect, test } from "bun:test"
import { autoLayout } from "./autolayout"
import { PRESETS } from "./subcircuit"

for (const name of ["SERVO_DRIVE", "LED_BUTTON", "FULL"]) {
  test(`${name}: 自動レイアウトが電気検証を通る`, () => {
    const layout = autoLayout(PRESETS[name])
    // autoLayout 内部で verify 済み（失敗なら throw）。ここでは形の健全性を確認。
    expect(Object.keys(layout.components).length).toBeGreaterThan(0)
    expect(layout.jumpers.length).toBeGreaterThan(0)
    expect(layout.stats.cols).toBeGreaterThan(0)
  })
}

test("決定的: 同入力・同seedで同一出力", () => {
  const a = autoLayout(PRESETS.SERVO_DRIVE, 7)
  const b = autoLayout(PRESETS.SERVO_DRIVE, 7)
  expect(JSON.stringify(a)).toBe(JSON.stringify(b))
})
```

- [ ] **Step 2: 実行して落ちるのを確認**

Run（`circuit/`）: `bun test breadboard/autolayout.test.ts`
Expected: FAIL（module 無し）。

- [ ] **Step 3: 実装**

```ts
// circuit/breadboard/autolayout.ts
import type { BreadboardLayout, ComponentMeta } from "./layout-types"
import { subcircuitNets } from "./subcircuit"
import { placeParts } from "./place"
import { routeNets } from "./route"
import { verifyLayout } from "./verify"
import { FOOTPRINTS } from "./footprints"
import { usedPinsByPart } from "./place"

export function autoLayout(refs: string[], seed = 1): BreadboardLayout {
  const nets = subcircuitNets(new Set(refs))
  const pl = placeParts(refs, nets, seed)
  const { jumpers, stats } = routeNets(pl, nets)

  // 実行時ゲート: 電気検証（端点2未満のネットは nets に含まれないので全ネット検査可）
  const errors = verifyLayout(nets, pl.pinHoles, jumpers)
  if (errors.length) throw new Error("autoLayout verification failed:\n" + errors.join("\n"))

  // components メタ（描画用）: 使用ピンのみ、footprint の描画ヒントを反映
  const used = usedPinsByPart(refs, nets)
  const components: Record<string, ComponentMeta> = {}
  for (const ref of refs) {
    const fp = FOOTPRINTS[ref]
    const pins = used[ref].map((p) => `${ref}.${p}`)
    if (pins.length === 0) continue
    components[ref] = {
      label: fp?.label ?? ref,
      value: fp?.value,
      pins,
      polarityPin: fp?.polarityPin ? `${ref}.${fp.polarityPin}` : undefined,
      stripePin: fp?.stripePin ? `${ref}.${fp.stripePin}` : undefined,
    }
  }

  const notes = [
    "電源/GNDはレール。信号は c/d/e レーン。",
    "極性・カソード帯・部品向きは実物で確認。",
    `交差 ${stats.crossings} / lane ${stats.tracksUsed} 使用。`,
  ]

  return { pinHoles: pl.pinHoles, jumpers, components, notes, stats: { ...stats, cols: pl.cols } }
}
```

- [ ] **Step 4: 実行して通す**

Run（`circuit/`）: `bun test breadboard/autolayout.test.ts`
Expected: 4 pass（3プリセット＋決定性）。`FULL` が verify で throw したら route/place のバグ。エラー文のネット名を手がかりに route.ts のチェーン生成・lane 割付を修正（テストを緩めない）。

- [ ] **Step 5: コミット**

```bash
git add circuit/breadboard/autolayout.ts circuit/breadboard/autolayout.test.ts
git commit -m "feat(breadboard): 自動レイアウトのオーケストレータ(検証ゲート付き)を追加"
```

---

## Task 7: render 引数化・CLI・手書きから自動へ切替

**Files:**
- Modify: `circuit/breadboard/render.ts`（`renderBreadboardSvg(layout: BreadboardLayout)` へ引数化。極性/帯/注記をデータ駆動に）
- Modify: `circuit/breadboard/render.test.ts`（`autoLayout` 由来レイアウトでスモーク）
- Create: `circuit/breadboard-auto.ts`（CLI）
- Modify: `circuit/package.json`（`breadboard` スクリプト）
- Delete: `circuit/breadboard/servo-layout.ts`, `circuit/breadboard/servo-nets.ts`, `circuit/breadboard/servo-verify.test.ts`, `circuit/breadboard-servo.ts`

**Interfaces:**
- Consumes: `BreadboardLayout` from `./layout-types`; `autoLayout` from `./autolayout`; `PRESETS` from `./subcircuit`。
- Produces: `renderBreadboardSvg(layout: BreadboardLayout): string`。

- [ ] **Step 1: render.ts を引数化**

`render.ts` の `import { PIN_HOLES, JUMPERS, COMPONENTS } from "./servo-layout"` を削除し、`renderBreadboardSvg(layout: BreadboardLayout)` の引数から取る。関数冒頭で分解：

```ts
// circuit/breadboard/render.ts 冒頭（import 差し替え）
import { COLS, type Hole, type StripRow } from "./model"
import type { BreadboardLayout } from "./layout-types"

export function renderBreadboardSvg(layout: BreadboardLayout): string {
  const { pinHoles: PIN_HOLES, jumpers: JUMPERS, components: COMPONENTS, notes } = layout
  // ...既存の描画ロジックはこのローカル変数を参照するよう維持...
```

**重要（幅の自動追従）**：`render.ts` は現在ハードコードの `COLS`(=30) で穴グリッド・ボード幅・SVG width を描いている。`FULL`(12部品)は約40列を要し 30 を超えるため、**描画列数を動的化**する：関数冒頭で
```ts
  const maxCol = Math.max(
    30,
    ...Object.values(PIN_HOLES).map((h) => (h.kind === "strip" ? h.col : h.col)),
    ...JUMPERS.flatMap((j) => [j.from, j.to].map((h) => h.col)),
  )
```
を求め、穴グリッドのループ・SVG width・ボード外形・レール長を `COLS` ではなく `maxCol` で描く（`COLS` 参照を `maxCol` に置換）。`buildConnectivity` は 30 超の列ノードも遅延生成で扱えるため検証は問題ない。

極性/帯のハードコード（`PIN_HOLES["C1.pin1"]`, `PIN_HOLES["D2.cathode"]`）を、`COMPONENTS` の各 `polarityPin`/`stripePin` を走査する形に置換：

```ts
  // 極性(+): polarityPin を持つ部品
  for (const c of Object.values(COMPONENTS)) {
    if (!c.polarityPin) continue
    const h = PIN_HOLES[c.polarityPin]; if (!h) continue
    const { x, y } = holeXY(h)
    parts.push(text(x, y - 6, "+", { size: 9, anchor: "middle", fill: "#c00" }))
  }
  // カソード帯: stripePin を持つ部品
  for (const c of Object.values(COMPONENTS)) {
    if (!c.stripePin) continue
    const h = PIN_HOLES[c.stripePin]; if (!h) continue
    const { x, y } = holeXY(h)
    parts.push(`<rect x="${x - 5}" y="${y - 5}" width="2" height="10" fill="#333"/>`)
  }
```

（`text`/`holeXY` 等の既存ヘルパはそのまま。既存の C1/D2 専用ブロックは削除して上記に統一。）注記はハードコード配列を `notes`（引数）に置換。

- [ ] **Step 2: render.test.ts を autoLayout 由来に更新**

```ts
// circuit/breadboard/render.test.ts
import { expect, test } from "bun:test"
import { renderBreadboardSvg } from "./render"
import { autoLayout } from "./autolayout"
import { PRESETS } from "./subcircuit"

test("SERVO_DRIVE の自動レイアウトを描画: svg・全ref・ジャンパ線・穴を含む", () => {
  const layout = autoLayout(PRESETS.SERVO_DRIVE)
  const svg = renderBreadboardSvg(layout)
  expect(svg.includes("<svg")).toBe(true)
  for (const ref of PRESETS.SERVO_DRIVE) expect(svg, `missing ${ref}`).toContain(ref)
  expect((svg.match(/<line/g) ?? []).length).toBeGreaterThanOrEqual(layout.jumpers.length)
  expect((svg.match(/<circle/g) ?? []).length).toBeGreaterThanOrEqual(30 * 10)
})
```

- [ ] **Step 3: CLI を作る**

```ts
// circuit/breadboard-auto.ts
// 使い方: bun breadboard-auto.ts <PRESET名 | ref,ref,...>  （既定 SERVO_DRIVE）
import { mkdirSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { autoLayout } from "./breadboard/autolayout"
import { renderBreadboardSvg } from "./breadboard/render"
import { PRESETS } from "./breadboard/subcircuit"

const arg = process.argv[2] ?? "SERVO_DRIVE"
const refs = PRESETS[arg] ?? arg.split(",").map((s) => s.trim()).filter(Boolean)
const name = arg in PRESETS ? arg.toLowerCase() : "custom"

const layout = autoLayout(refs)
const svg = renderBreadboardSvg(layout)
const out = join(import.meta.dir, "build", "breadboard-" + name + ".svg")
mkdirSync(dirname(out), { recursive: true })
writeFileSync(out, svg)
console.log(`wrote ${out} (crossings=${layout.stats.crossings}, lanes=${layout.stats.tracksUsed}, cols=${layout.stats.cols})`)
```

（注: 出力先は repo-root の `build/`。`breadboard-servo.ts` は `import.meta.dir/../build` を使っていた。`breadboard-auto.ts` は `circuit/` 直下なので `import.meta.dir/build`… ではなく `join(import.meta.dir, "..", "build", ...)` が正しい。**実装時に `breadboard-servo.ts` の出力先解決をそのまま踏襲すること**。上記 `join(import.meta.dir, "build", ...)` は `circuit/build` になるので `".."` を挟んで `repo-root/build` にする。）

- [ ] **Step 4: package.json 更新＋旧ファイル削除**

`circuit/package.json` の `"breadboard"` を `"bun breadboard-auto.ts"` に変更。
削除：`git rm circuit/breadboard/servo-layout.ts circuit/breadboard/servo-nets.ts circuit/breadboard/servo-verify.test.ts circuit/breadboard-servo.ts`

- [ ] **Step 5: 全テスト＋再生成**

Run（`circuit/`）:
- `bun test`（全体）→ 緑（旧 servo テストは消え、新パイプラインのテストが通る）
- `bun breadboard-auto.ts SERVO_DRIVE` → `build/breadboard-servo.svg` 生成、統計表示
Expected: テスト全 pass、SVG 生成。`Cannot find module './servo-layout'` 等の未更新参照が残っていたら潰す。SVG はコミットしない（`git status` で未ステージ確認）。

- [ ] **Step 6: コミット**

```bash
git add circuit/breadboard/render.ts circuit/breadboard/render.test.ts circuit/breadboard-auto.ts circuit/package.json
git rm circuit/breadboard/servo-layout.ts circuit/breadboard/servo-nets.ts circuit/breadboard/servo-verify.test.ts circuit/breadboard-servo.ts
git commit -m "feat(breadboard): renderを引数化しCLIを自動生成へ切替、手書きlayoutを廃止"
```

---

## 完了条件

- Task 1–7 完了。`bun test`（circuit 全体）が緑。
- `bun run breadboard SERVO_DRIVE` / `FULL` / `LED_BUTTON` が各 `build/breadboard-<name>.svg` を生成し、autoLayout の実行時検証を通る（電気的に正しい）。
- 出力は決定的（seed 固定）。交差数・lane 数がログに出る。
- 手書き `servo-layout.ts` 系は削除。`model.ts`/`render.ts` は再利用。
- 実測確認（プラン外・完了後の目視）: 生成SVGを PNG化して、手結果と同等以上に交差が少ないか確認し、必要なら `config.ts` の `WEIGHTS` を調整（コード構造は変えない）。

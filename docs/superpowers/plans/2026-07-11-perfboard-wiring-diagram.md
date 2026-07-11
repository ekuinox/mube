# ユニバーサル基板 配線図ジェネレータ Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 実基板（ユニバーサル基板 P-03229）へはんだ付け実装するための配線図 SVG を、手置き配置＋自動配線で生成し、ブラウザで確認できるようにする。

**Architecture:** `circuit/perfboard/` に新サブシステムを作る。結線の正は既存 `circuit/parts.ts`（PARTS/NETS）を共有。Pico W は実測アンカー GP0=(3,2)・2列間隔7穴から全ピン座標を導出。利用者は `layout.ts` に `[x,y]` で部品を手置きし、ツールが検証・点対点配線・SVG 描画を行う。

**Tech Stack:** TypeScript / bun（`bun test`）。既存 `circuit/breadboard/` と同じ流儀（純関数＋SVG文字列生成）。ビューアは既存 `circuit/breadboard-serve.py` + `breadboard-viewer.html` を最小拡張。

## Global Constraints

- 座標系: `[x, y]` 整数ペア、**左上原点 (0,0)**、x=横（右+, 短辺）、y=縦（下+, 長辺）。
- 盤面既定: `width=18`（x: 0..17）、`height=28`（y: 0..27）。
- Pico 固定: `PICO_ANCHOR = [3, 2]`（GP0=物理ピン1）、`PICO_ROW_SPAN_HOLES = 7`。
- 結線の正は `circuit/parts.ts` の PARTS/NETS。**parts.ts は変更しない**（ERC が既存のまま通ること）。
- NET endpoint 表記は tscircuit セレクタ（例 `".U1 .VBUS"`）。正規化は `ep.replace(/\./g," ").trim().split(/\s+/).join(".")` で `"U1.VBUS"` にする。
- テストは `bun:test`。コマンドは `nix develop -c bun test circuit/perfboard/<file>.test.ts`（全体は `./test/erc.sh`）。
- コミットはこの機能ブランチ `feat/perfboard-wiring-diagram` に。各タスク末尾で commit。

---

## File Structure

```
circuit/
  perfboard/
    board.ts        # 格子モデル: XY型, BOARD寸法, PICO定数, inBounds/key/rotate
    pico.ts         # Pico 2×20: 物理ピン→XY, 信号名→XY, 全40ピン列挙
    footprints.ts   # 部品(U1以外11点)のピン相対オフセット＋極性/カソード帯メタ
    layout.ts       # 利用者編集の既定 PLACEMENT（[x,y]+rot）
    place.ts        # PLACEMENT+Pico を解決し "Ref.pin"→XY と検証(盤外/重複/未解決)
    wire.ts         # NETS→点対点配線セグメント（ネットごと MST）
    render.ts       # SVG 生成
    board.test.ts / pico.test.ts / footprints.test.ts / place.test.ts / wire.test.ts / render.test.ts
  perfboard.ts      # CLI: build/perfboard.svg 出力
```

---

### Task 1: 格子モデルと Pico ピン写像（board.ts / pico.ts）

correctness-critical。実測 2 点（GP0=(3,2), GP16=(10,21)）と一致することをテストで固定する。

**Files:**
- Create: `circuit/perfboard/board.ts`
- Create: `circuit/perfboard/pico.ts`
- Test: `circuit/perfboard/board.test.ts`, `circuit/perfboard/pico.test.ts`

**Interfaces:**
- Produces (board.ts):
  - `type XY = [number, number]`
  - `const BOARD = { width: number; height: number }`（18 / 28）
  - `const PICO_ANCHOR: XY`（[3,2]）、`const PICO_ROW_SPAN_HOLES: number`（7）
  - `function inBounds(p: XY): boolean`
  - `function key(p: XY): string`（`"x,y"`）
  - `function rotate(off: XY, rot: 0|90|180|270): XY`（時計回り, y下向き）
- Produces (pico.ts):
  - `function picoPinXY(pin: number): XY`（物理ピン 1..40）
  - `const PICO_PIN_NUMBER: Record<string, number>`（信号名→物理ピン）
  - `function picoSignalXY(signal: string): XY`
  - `function picoAllPinsXY(): XY[]`（全40）

- [ ] **Step 1: board.ts の失敗するテストを書く**

```ts
// circuit/perfboard/board.test.ts
import { expect, test } from "bun:test"
import { BOARD, PICO_ANCHOR, PICO_ROW_SPAN_HOLES, inBounds, key, rotate } from "./board"

test("盤面既定は 18 x 28、Pico 定数は実測値", () => {
  expect(BOARD).toEqual({ width: 18, height: 28 })
  expect(PICO_ANCHOR).toEqual([3, 2])
  expect(PICO_ROW_SPAN_HOLES).toBe(7)
})

test("inBounds は 0..width-1 / 0..height-1", () => {
  expect(inBounds([0, 0])).toBe(true)
  expect(inBounds([17, 27])).toBe(true)
  expect(inBounds([18, 0])).toBe(false)
  expect(inBounds([0, 28])).toBe(false)
  expect(inBounds([-1, 0])).toBe(false)
})

test("key は 'x,y'", () => {
  expect(key([3, 21])).toBe("3,21")
})

test("rotate は時計回り(y下向き)", () => {
  expect(rotate([3, 0], 0)).toEqual([3, 0])
  expect(rotate([3, 0], 90)).toEqual([0, 3])
  expect(rotate([3, 0], 180)).toEqual([-3, 0])
  expect(rotate([3, 0], 270)).toEqual([0, -3])
})
```

- [ ] **Step 2: 実行して失敗を確認**

Run: `nix develop -c bun test circuit/perfboard/board.test.ts`
Expected: FAIL（`Cannot find module './board'`）

- [ ] **Step 3: board.ts を実装**

```ts
// circuit/perfboard/board.ts
// ユニバーサル基板の格子モデル。左上原点 (0,0)、x=横(右+)、y=縦(下+)。
export type XY = [number, number]

export const BOARD = { width: 18, height: 28 }   // x: 0..17, y: 0..27（実基板の穴数で確定）
export const PICO_ANCHOR: XY = [3, 2]            // Pico GP0(物理ピン1)。利用者実測
export const PICO_ROW_SPAN_HOLES = 7             // Pico 2ピン列の x 間隔（実測一致）

export function inBounds([x, y]: XY): boolean {
  return x >= 0 && x < BOARD.width && y >= 0 && y < BOARD.height
}

export function key([x, y]: XY): string {
  return `${x},${y}`
}

// 部品ローカルオフセットを時計回りに回す（y 下向き画面座標）
export function rotate([dx, dy]: XY, rot: 0 | 90 | 180 | 270): XY {
  switch (rot) {
    case 0: return [dx, dy]
    case 90: return [-dy, dx]
    case 180: return [-dx, -dy]
    case 270: return [dy, -dx]
  }
}
```

- [ ] **Step 4: 実行して成功を確認**

Run: `nix develop -c bun test circuit/perfboard/board.test.ts`
Expected: PASS

- [ ] **Step 5: pico.ts の失敗するテストを書く**

```ts
// circuit/perfboard/pico.test.ts
import { expect, test } from "bun:test"
import { picoPinXY, picoSignalXY, picoAllPinsXY, PICO_PIN_NUMBER } from "./pico"

test("実測アンカーと一致: GP0=物理1=(3,2), GP15=物理20=(3,21)", () => {
  expect(picoPinXY(1)).toEqual([3, 2])
  expect(picoPinXY(20)).toEqual([3, 21])
})

test("右列: GP16=物理21=(10,21), VBUS=物理40=(10,2)", () => {
  expect(picoPinXY(21)).toEqual([10, 21])
  expect(picoPinXY(40)).toEqual([10, 2])
})

test("使用信号→穴（parts.ts の U1 ピン名）", () => {
  expect(PICO_PIN_NUMBER).toEqual({ VBUS: 40, GND: 23, GP15: 20, GP14: 19, GP16: 21, GP18: 24, GP17: 22 })
  expect(picoSignalXY("GP14")).toEqual([3, 20])
  expect(picoSignalXY("GP15")).toEqual([3, 21])
  expect(picoSignalXY("GP16")).toEqual([10, 21])
  expect(picoSignalXY("GP17")).toEqual([10, 20])
  expect(picoSignalXY("GP18")).toEqual([10, 18])
  expect(picoSignalXY("GND")).toEqual([10, 19])
  expect(picoSignalXY("VBUS")).toEqual([10, 2])
})

test("picoAllPinsXY は 40 個・重複なし", () => {
  const all = picoAllPinsXY()
  expect(all.length).toBe(40)
  expect(new Set(all.map((p) => p.join(","))).size).toBe(40)
})

test("未知信号は例外", () => {
  expect(() => picoSignalXY("GP99")).toThrow()
})
```

- [ ] **Step 6: 実行して失敗を確認**

Run: `nix develop -c bun test circuit/perfboard/pico.test.ts`
Expected: FAIL（`Cannot find module './pico'`）

- [ ] **Step 7: pico.ts を実装**

```ts
// circuit/perfboard/pico.ts
// Pico W(2×20, 2.54mm, ブレッドボード互換)のピン→盤面穴写像。
// 物理ピン番号は DIP 式（左列 上→下 1..20、右列 下→上 21..40）。
import { PICO_ANCHOR, PICO_ROW_SPAN_HOLES, type XY } from "./board"

// 物理ピン番号(1..40) → 盤面 XY
export function picoPinXY(pin: number): XY {
  const [ax, ay] = PICO_ANCHOR
  if (pin < 1 || pin > 40) throw new Error(`pico pin out of range: ${pin}`)
  if (pin <= 20) return [ax, ay + (pin - 1)]              // 左列 上→下
  return [ax + PICO_ROW_SPAN_HOLES, ay + (40 - pin)]      // 右列 下→上（21→+19, 40→+0）
}

// parts.ts の U1 ピン名 → 物理ピン番号（本回路で使う 7 本）
export const PICO_PIN_NUMBER: Record<string, number> = {
  VBUS: 40, GND: 23, GP15: 20, GP14: 19, GP16: 21, GP18: 24, GP17: 22,
}

export function picoSignalXY(signal: string): XY {
  const pin = PICO_PIN_NUMBER[signal]
  if (pin === undefined) throw new Error(`unknown Pico signal: ${signal}`)
  return picoPinXY(pin)
}

export function picoAllPinsXY(): XY[] {
  const out: XY[] = []
  for (let p = 1; p <= 40; p++) out.push(picoPinXY(p))
  return out
}
```

- [ ] **Step 8: 実行して成功を確認**

Run: `nix develop -c bun test circuit/perfboard/pico.test.ts`
Expected: PASS（全ケース。特に実測 2 点一致）

- [ ] **Step 9: Commit**

```bash
git add circuit/perfboard/board.ts circuit/perfboard/pico.ts circuit/perfboard/board.test.ts circuit/perfboard/pico.test.ts
git commit -m "feat(perfboard): 格子モデルと Pico ピン写像（実測 GP0=(3,2) 固定）"
```

---

### Task 2: 部品フットプリント（footprints.ts）

**Files:**
- Create: `circuit/perfboard/footprints.ts`
- Test: `circuit/perfboard/footprints.test.ts`

**Interfaces:**
- Consumes: `XY`（board.ts）
- Produces:
  - `interface PerfFootprint { pins: { name: string; off: XY }[]; label: string; value?: string; polarityPin?: string; stripePin?: string }`
  - `const FOOTPRINTS: Record<string, PerfFootprint>`（U1 以外の 11 部品）

- [ ] **Step 1: 失敗するテストを書く**

```ts
// circuit/perfboard/footprints.test.ts
import { expect, test } from "bun:test"
import { FOOTPRINTS } from "./footprints"

const NON_PICO = ["M1", "Q1", "Rg", "Rgs", "Rled", "Rled2", "D1", "SW1", "C1", "C2", "D2"]

test("U1 以外の 11 部品を網羅、U1 は含まない", () => {
  for (const r of NON_PICO) expect(FOOTPRINTS[r], `missing ${r}`).toBeDefined()
  expect(FOOTPRINTS["U1"]).toBeUndefined()
})

test("各フットプリントは pin1(=先頭)が原点[0,0]、ピン名は非重複", () => {
  for (const [ref, fp] of Object.entries(FOOTPRINTS)) {
    expect(fp.pins.length, `${ref} empty`).toBeGreaterThan(0)
    expect(fp.pins[0].off, `${ref} anchor`).toEqual([0, 0])
    const names = fp.pins.map((p) => p.name)
    expect(new Set(names).size, `${ref} dup pins`).toBe(names.length)
  }
})

test("極性/カソード帯メタは実在ピンを指す", () => {
  expect(FOOTPRINTS.C1.polarityPin).toBe("pin1")
  expect(FOOTPRINTS.D2.stripePin).toBe("cathode")
  expect(FOOTPRINTS.D2.pins.map((p) => p.name)).toContain("cathode")
})

test("parts.ts のピン名と一致（M1/D2）", () => {
  expect(FOOTPRINTS.M1.pins.map((p) => p.name)).toEqual(["SIG", "VPLUS", "GND"])
  expect(FOOTPRINTS.D2.pins.map((p) => p.name)).toEqual(["cathode", "anode"])
})
```

- [ ] **Step 2: 実行して失敗を確認**

Run: `nix develop -c bun test circuit/perfboard/footprints.test.ts`
Expected: FAIL（`Cannot find module './footprints'`）

- [ ] **Step 3: footprints.ts を実装**

```ts
// circuit/perfboard/footprints.ts
// U1 以外の部品フットプリント。pin1(先頭)をアンカー[0,0]とする相対オフセット。
// ピン名は parts.ts の NETS endpoint と一致させる（例 D2 は cathode/anode）。
import type { XY } from "./board"

export interface PerfFootprint {
  pins: { name: string; off: XY }[]
  label: string
  value?: string
  polarityPin?: string   // "+" を描くピン名
  stripePin?: string     // カソード帯を描くピン名
}

const line3 = (a: string, b: string, c: string): { name: string; off: XY }[] => [
  { name: a, off: [0, 0] }, { name: b, off: [1, 0] }, { name: c, off: [2, 0] },
]
const span = (a: string, b: string, n: number): { name: string; off: XY }[] => [
  { name: a, off: [0, 0] }, { name: b, off: [n, 0] },
]

export const FOOTPRINTS: Record<string, PerfFootprint> = {
  M1:    { pins: line3("SIG", "VPLUS", "GND"), label: "M1", value: "Servo" },
  Q1:    { pins: line3("G", "D", "S"), label: "Q1", value: "MOSFET(TO-92)" },
  Rg:    { pins: span("pin1", "pin2", 3), label: "Rg", value: "220Ω" },
  Rgs:   { pins: span("pin1", "pin2", 3), label: "Rgs", value: "10kΩ" },
  Rled:  { pins: span("pin1", "pin2", 3), label: "Rled", value: "330Ω" },
  Rled2: { pins: span("pin1", "pin2", 3), label: "Rled2", value: "330Ω" },
  D1:    { pins: line3("R", "G", "K"), label: "D1", value: "2色LED" },
  SW1:   { pins: span("pin1", "pin2", 2), label: "SW1", value: "Tact(対角)" },
  C1:    { pins: span("pin1", "pin2", 1), label: "C1", value: "470uF", polarityPin: "pin1" },
  C2:    { pins: span("pin1", "pin2", 1), label: "C2", value: "100nF" },
  D2:    { pins: span("cathode", "anode", 2), label: "D2", value: "フライバック", stripePin: "cathode" },
}
```

- [ ] **Step 4: 実行して成功を確認**

Run: `nix develop -c bun test circuit/perfboard/footprints.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add circuit/perfboard/footprints.ts circuit/perfboard/footprints.test.ts
git commit -m "feat(perfboard): 部品フットプリント(U1以外11点)"
```

---

### Task 3: 既定レイアウトと配置解決＋検証（layout.ts / place.ts）

**Files:**
- Create: `circuit/perfboard/layout.ts`
- Create: `circuit/perfboard/place.ts`
- Test: `circuit/perfboard/place.test.ts`

**Interfaces:**
- Consumes: `XY, inBounds, key, rotate`（board.ts）、`picoPinXY, picoSignalXY, PICO_PIN_NUMBER`（pico.ts）、`FOOTPRINTS`（footprints.ts）、`NETS`（../parts）
- Produces:
  - layout.ts: `type Place = { at: XY; rot: 0|90|180|270 }`、`const PLACEMENT: Record<string, Place>`（U1 は含めない。pico.ts が担当）
  - place.ts: `interface Placement { pinXY: Record<string, XY>; occupied: Set<string>; errors: string[] }`、`function resolvePlacement(placement?: Record<string, Place>): Placement`、`function normEndpoint(ep: string): string`

- [ ] **Step 1: 失敗するテストを書く**

```ts
// circuit/perfboard/place.test.ts
import { expect, test } from "bun:test"
import { resolvePlacement, normEndpoint } from "./place"
import { NETS } from "../parts"

test("normEndpoint はセレクタを正規化", () => {
  expect(normEndpoint(".U1 .VBUS")).toBe("U1.VBUS")
  expect(normEndpoint(".D2 .cathode")).toBe("D2.cathode")
})

test("既定 PLACEMENT は検証エラー無し（盤内・重複無し・全ネット解決）", () => {
  const p = resolvePlacement()
  expect(p.errors).toEqual([])
})

test("U1 の 7 信号が pico 由来の穴で入る", () => {
  const p = resolvePlacement()
  expect(p.pinXY["U1.GP15"]).toEqual([3, 21])
  expect(p.pinXY["U1.VBUS"]).toEqual([10, 2])
})

test("全 NET endpoint が穴に解決する", () => {
  const p = resolvePlacement()
  for (const net of NETS) {
    for (const ep of net.endpoints) {
      expect(p.pinXY[normEndpoint(ep)], `${ep} unresolved`).toBeDefined()
    }
  }
})

test("Pico の 40 穴＋部品ピンが occupied に載る（重複検出が効く）", () => {
  const p = resolvePlacement()
  expect(p.occupied.has("3,2")).toBe(true)   // Pico GP0
  expect(p.occupied.has("10,2")).toBe(true)  // Pico VBUS
})

test("盤外配置はエラーになる", () => {
  const bad = { M1: { at: [17, 27] as [number, number], rot: 0 as const } }  // SIG..GND が x=17,18,19 で盤外
  const p = resolvePlacement(bad)
  expect(p.errors.some((e) => e.includes("盤外"))).toBe(true)
})

test("Pico 穴と重なる配置はエラーになる", () => {
  const bad = { C2: { at: [3, 2] as [number, number], rot: 0 as const } }  // Pico GP0 と衝突
  const p = resolvePlacement(bad)
  expect(p.errors.some((e) => e.includes("重複"))).toBe(true)
})
```

- [ ] **Step 2: 実行して失敗を確認**

Run: `nix develop -c bun test circuit/perfboard/place.test.ts`
Expected: FAIL（`Cannot find module './place'`）

- [ ] **Step 3: layout.ts を実装（既定の手置きレイアウト）**

各 `at` は 1 番ピンの穴 `[x,y]`。Pico 占有(x=3,x=10 の y=2..21)と盤外を避け、全ピン重複無し。
実装後に place.test.ts の「検証エラー無し」で妥当性が保証される。座標を変えたいときはここだけ編集する。

```ts
// circuit/perfboard/layout.ts
// 利用者が編集する唯一のファイル。at=[x,y] は各部品の 1 番ピンの穴（左上原点）。
// U1(Pico) は pico.ts が固定配置するのでここには書かない。
import type { XY } from "./board"

export type Place = { at: XY; rot: 0 | 90 | 180 | 270 }

export const PLACEMENT: Record<string, Place> = {
  // 電源まわり（Pico 左の x=1,2 と下段）
  C1: { at: [1, 24], rot: 0 },   // 470uF  pin1(+),pin2
  C2: { at: [1, 26], rot: 0 },   // 100nF
  D2: { at: [4, 27], rot: 0 },   // フライバック cathode,anode
  // サーボ駆動（下段 x=4..8）
  M1: { at: [4, 23], rot: 0 },   // SIG,VPLUS,GND
  Q1: { at: [4, 25], rot: 0 },   // G,D,S
  Rg: { at: [8, 23], rot: 0 },   // GATE_DRV↔GATE
  Rgs: { at: [8, 25], rot: 0 },  // GATE↔GND
  // LED/ボタン（Pico 右 x=11..17）
  Rled: { at: [12, 20], rot: 0 },
  Rled2: { at: [12, 18], rot: 0 },
  D1: { at: [15, 22], rot: 0 },  // R,G,K
  SW1: { at: [13, 25], rot: 0 }, // pin1,pin2
}
```

- [ ] **Step 4: place.ts を実装**

```ts
// circuit/perfboard/place.ts
// PLACEMENT(手置き)＋Pico(固定)を解決し "Ref.pin"→XY を得る。盤外・穴重複・未解決を検証。
import { inBounds, key, rotate, type XY } from "./board"
import { picoPinXY, picoSignalXY, PICO_PIN_NUMBER } from "./pico"
import { FOOTPRINTS } from "./footprints"
import { PLACEMENT, type Place } from "./layout"
import { NETS } from "../parts"

export interface Placement {
  pinXY: Record<string, XY>
  occupied: Set<string>
  errors: string[]
}

// tscircuit セレクタ ".U1 .VBUS" → "U1.VBUS"
export function normEndpoint(ep: string): string {
  return ep.replace(/\./g, " ").trim().split(/\s+/).join(".")
}

export function resolvePlacement(placement: Record<string, Place> = PLACEMENT): Placement {
  const pinXY: Record<string, XY> = {}
  const occupied = new Set<string>()
  const errors: string[] = []

  // 1) Pico: 全40ピンを占有として登録、使用7信号を pinXY へ
  for (let p = 1; p <= 40; p++) occupied.add(key(picoPinXY(p)))
  for (const sig of Object.keys(PICO_PIN_NUMBER)) pinXY[`U1.${sig}`] = picoSignalXY(sig)

  // 2) 手置き部品
  for (const [ref, pl] of Object.entries(placement)) {
    const fp = FOOTPRINTS[ref]
    if (!fp) { errors.push(`フットプリント未定義: ${ref}`); continue }
    for (const pin of fp.pins) {
      const [rx, ry] = rotate(pin.off, pl.rot)
      const xy: XY = [pl.at[0] + rx, pl.at[1] + ry]
      const k = key(xy)
      if (!inBounds(xy)) errors.push(`盤外: ${ref}.${pin.name} @ [${xy}]`)
      if (occupied.has(k)) errors.push(`重複: ${ref}.${pin.name} が使用済み穴 [${xy}] と衝突`)
      occupied.add(k)
      pinXY[`${ref}.${pin.name}`] = xy
    }
  }

  // 3) 全ネット endpoint が解決するか
  for (const net of NETS) {
    for (const ep of net.endpoints) {
      const n = normEndpoint(ep)
      if (!pinXY[n]) errors.push(`未解決ネット端点: ${net.name} の ${n}`)
    }
  }

  return { pinXY, occupied, errors }
}
```

- [ ] **Step 5: 実行して成功を確認（既定レイアウトが妥当）**

Run: `nix develop -c bun test circuit/perfboard/place.test.ts`
Expected: PASS。もし「盤外/重複/未解決」で落ちたら **layout.ts の座標だけ**調整して再実行（部品数が多いので下段 y=22..27 と側面 x=0..2 / x=11..17 に散らす）。

- [ ] **Step 6: Commit**

```bash
git add circuit/perfboard/layout.ts circuit/perfboard/place.ts circuit/perfboard/place.test.ts
git commit -m "feat(perfboard): 既定レイアウトと配置解決＋検証"
```

---

### Task 4: 点対点配線（wire.ts）

**Files:**
- Create: `circuit/perfboard/wire.ts`
- Test: `circuit/perfboard/wire.test.ts`

**Interfaces:**
- Consumes: `XY`（board.ts）、`normEndpoint`（place.ts）、`NETS`（../parts）
- Produces:
  - `interface WireSeg { net: string; a: XY; b: XY }`
  - `function buildWires(pinXY: Record<string, XY>): WireSeg[]`

- [ ] **Step 1: 失敗するテストを書く**

```ts
// circuit/perfboard/wire.test.ts
import { expect, test } from "bun:test"
import { buildWires } from "./wire"
import { resolvePlacement } from "./place"
import { NETS } from "../parts"

test("k 端点のネットは k-1 本の配線になる（全ネット合計）", () => {
  const p = resolvePlacement()
  const segs = buildWires(p.pinXY)
  const expected = NETS.reduce((s, n) => s + (n.endpoints.length - 1), 0)
  expect(segs.length).toBe(expected)
})

test("各配線は解決済みの穴同士を結ぶ（同一点で無い）", () => {
  const p = resolvePlacement()
  for (const s of buildWires(p.pinXY)) {
    expect(s.a).not.toEqual(s.b)
  }
})

test("各ネットの配線は全端点を連結する（1 連結成分）", () => {
  const p = resolvePlacement()
  const segs = buildWires(p.pinXY)
  for (const net of NETS) {
    const nodes = new Set(net.endpoints.map((e) => e.replace(/\./g, " ").trim().split(/\s+/).join(".")))
    if (nodes.size < 2) continue
    const netSegs = segs.filter((s) => s.net === net.name)
    // union-find で連結数を数える
    const parent = new Map<string, string>()
    const find = (x: string): string => { const p = parent.get(x) ?? x; if (p === x) return x; const r = find(p); parent.set(x, r); return r }
    const uni = (a: string, b: string) => { parent.set(find(a), find(b)) }
    for (const s of netSegs) uni(s.a.join(","), s.b.join(","))
    const roots = new Set([...nodes].map((n) => {
      const xy = p.pinXY[n]; return find(xy.join(","))
    }))
    expect(roots.size, `${net.name} not fully connected`).toBe(1)
  }
})
```

- [ ] **Step 2: 実行して失敗を確認**

Run: `nix develop -c bun test circuit/perfboard/wire.test.ts`
Expected: FAIL（`Cannot find module './wire'`）

- [ ] **Step 3: wire.ts を実装（ネットごとに最小全域木）**

```ts
// circuit/perfboard/wire.ts
// 各ネットの端点穴を点対点はんだ配線で結ぶ。ネット内は最小全域木(Manhattan)で k-1 本に。
import type { XY } from "./board"
import { normEndpoint } from "./place"
import { NETS } from "../parts"

export interface WireSeg { net: string; a: XY; b: XY }

function mstEdges(pts: XY[]): [number, number][] {
  const n = pts.length
  if (n <= 1) return []
  const inTree = new Array(n).fill(false)
  const edges: [number, number][] = []
  inTree[0] = true
  for (let e = 0; e < n - 1; e++) {
    let best = Infinity, bi = -1, bj = -1
    for (let i = 0; i < n; i++) if (inTree[i]) {
      for (let j = 0; j < n; j++) if (!inTree[j]) {
        const d = Math.abs(pts[i][0] - pts[j][0]) + Math.abs(pts[i][1] - pts[j][1])
        if (d < best) { best = d; bi = i; bj = j }
      }
    }
    inTree[bj] = true
    edges.push([bi, bj])
  }
  return edges
}

export function buildWires(pinXY: Record<string, XY>): WireSeg[] {
  const segs: WireSeg[] = []
  for (const net of NETS) {
    const pts = net.endpoints.map(normEndpoint).map((n) => pinXY[n]).filter(Boolean) as XY[]
    for (const [i, j] of mstEdges(pts)) segs.push({ net: net.name, a: pts[i], b: pts[j] })
  }
  return segs
}
```

- [ ] **Step 4: 実行して成功を確認**

Run: `nix develop -c bun test circuit/perfboard/wire.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add circuit/perfboard/wire.ts circuit/perfboard/wire.test.ts
git commit -m "feat(perfboard): ネットごと MST の点対点配線"
```

---

### Task 5: SVG 描画（render.ts）

**Files:**
- Create: `circuit/perfboard/render.ts`
- Test: `circuit/perfboard/render.test.ts`

**Interfaces:**
- Consumes: `BOARD, XY`（board.ts）、`picoAllPinsXY, PICO_PIN_NUMBER, picoSignalXY`（pico.ts）、`FOOTPRINTS`（footprints.ts）、`Placement`（place.ts）、`WireSeg`（wire.ts）、`PLACEMENT`（layout.ts）
- Produces: `function renderPerfboardSvg(p: Placement, wires: WireSeg[]): string`

- [ ] **Step 1: 失敗するテストを書く**

```ts
// circuit/perfboard/render.test.ts
import { expect, test } from "bun:test"
import { renderPerfboardSvg } from "./render"
import { resolvePlacement } from "./place"
import { buildWires } from "./wire"

function svg() {
  const p = resolvePlacement()
  return renderPerfboardSvg(p, buildWires(p.pinXY))
}

test("妥当な SVG 文字列（root と viewBox）", () => {
  const s = svg()
  expect(s.startsWith("<svg")).toBe(true)
  expect(s).toContain("viewBox")
  expect(s.trimEnd().endsWith("</svg>")).toBe(true)
})

test("Pico 使用ピンの信号ラベルを含む", () => {
  const s = svg()
  expect(s).toContain("GP15")
  expect(s).toContain("VBUS")
})

test("部品 ref ラベルと配線 line を含む", () => {
  const s = svg()
  expect(s).toContain("M1")
  expect(s).toContain("D1")
  expect(s).toContain("<line")
})

test("軸目盛り（上=文字 A、左=数字 1）を含む", () => {
  const s = svg()
  expect(s).toContain(">A<")
  expect(s).toContain(">1<")
})
```

- [ ] **Step 2: 実行して失敗を確認**

Run: `nix develop -c bun test circuit/perfboard/render.test.ts`
Expected: FAIL（`Cannot find module './render'`）

- [ ] **Step 3: render.ts を実装**

```ts
// circuit/perfboard/render.ts
// ユニバーサル基板 配線図の SVG。上端=文字(x:A..)/左端=数字(y:1..)で実基板と突き合わせ可能に。
import { BOARD, type XY } from "./board"
import { picoAllPinsXY, PICO_PIN_NUMBER, picoSignalXY } from "./pico"
import { FOOTPRINTS } from "./footprints"
import type { Placement } from "./place"
import type { WireSeg } from "./wire"
import { PLACEMENT } from "./layout"

const PITCH = 18
const ML = 46, MT = 40, MR = 200, MB = 96

const NET_COLOR: Record<string, string> = {
  V5: "#d81e1e", GND: "#333333", SERVO_RTN: "#8a5a00", SERVO_SIG: "#e67a00",
  GATE_DRV: "#1e7ad8", GATE: "#1e7ad8", LED_DRV_R: "#c81e7a", LED_A_R: "#c81e7a",
  LED_DRV_G: "#1ea01e", LED_A_G: "#1ea01e", BTN: "#7a1ed8",
}
const netColor = (n: string) => NET_COLOR[n] ?? "#666"

function attrs(o: Record<string, string | number | undefined>): string {
  return Object.entries(o).filter(([, v]) => v !== undefined).map(([k, v]) => `${k}="${v}"`).join(" ")
}
const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
const circle = (cx: number, cy: number, r: number, e?: Record<string, string | number>) => `<circle ${attrs({ cx, cy, r, ...e })} />`
const line = (x1: number, y1: number, x2: number, y2: number, e?: Record<string, string | number>) => `<line ${attrs({ x1, y1, x2, y2, ...e })} />`
const rect = (x: number, y: number, w: number, h: number, e?: Record<string, string | number | undefined>) => `<rect ${attrs({ x, y, width: w, height: h, ...e })} />`
const text = (x: number, y: number, s: string, e?: Record<string, string | number>) => `<text ${attrs({ x, y, ...e })}>${esc(s)}</text>`

const px = ([x, y]: XY): [number, number] => [ML + x * PITCH, MT + y * PITCH]
const colLabel = (x: number) => String.fromCharCode(65 + x)  // 0->A

export function renderPerfboardSvg(p: Placement, wires: WireSeg[]): string {
  const W = ML + (BOARD.width - 1) * PITCH + MR
  const H = MT + (BOARD.height - 1) * PITCH + MB
  const out: string[] = []
  out.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" font-family="system-ui, sans-serif">`)
  out.push(rect(0, 0, W, H, { fill: "#f5f5f0" }))

  // 盤面枠
  const [bx0, by0] = px([0, 0]); const [bx1, by1] = px([BOARD.width - 1, BOARD.height - 1])
  out.push(rect(bx0 - PITCH / 2, by0 - PITCH / 2, (BOARD.width) * PITCH, (BOARD.height) * PITCH, { fill: "#d9e6c9", stroke: "#8aa06a", rx: 6 }))

  // 目盛り（上=文字, 左=数字）
  for (let x = 0; x < BOARD.width; x++) {
    const [cx] = px([x, 0])
    out.push(text(cx, MT - 18, colLabel(x), { "text-anchor": "middle", "font-size": 11, fill: "#556" }))
  }
  for (let y = 0; y < BOARD.height; y++) {
    const [, cy] = px([0, y])
    out.push(text(ML - 26, cy + 4, String(y + 1), { "font-size": 11, fill: "#556" }))
  }

  // 穴
  for (let x = 0; x < BOARD.width; x++) for (let y = 0; y < BOARD.height; y++) {
    const [cx, cy] = px([x, y]); out.push(circle(cx, cy, 2.2, { fill: "#fff", stroke: "#b7c4a3" }))
  }

  // Pico ゴースト（2×20 の外形）と使用ピン
  const picoPts = picoAllPinsXY()
  const gx = picoPts.map((q) => px(q))
  const minx = Math.min(...gx.map((q) => q[0])), maxx = Math.max(...gx.map((q) => q[0]))
  const miny = Math.min(...gx.map((q) => q[1])), maxy = Math.max(...gx.map((q) => q[1]))
  out.push(rect(minx - PITCH / 2, miny - PITCH / 2, maxx - minx + PITCH, maxy - miny + PITCH, { fill: "#c7d3e6", "fill-opacity": 0.5, stroke: "#7a8aa0", rx: 5 }))
  out.push(text((minx + maxx) / 2, (miny + maxy) / 2, "Pico W", { "text-anchor": "middle", "font-size": 12, fill: "#456", "font-weight": 600 }))
  for (const sig of Object.keys(PICO_PIN_NUMBER)) {
    const [cx, cy] = px(picoSignalXY(sig))
    out.push(circle(cx, cy, 4, { fill: "#2b3a55" }))
    out.push(text(cx, cy - 7, sig, { "text-anchor": "middle", "font-size": 9, fill: "#2b3a55", "font-weight": 600 }))
  }

  // 配線（点対点）
  for (const s of wires) {
    const [x1, y1] = px(s.a); const [x2, y2] = px(s.b)
    out.push(line(x1, y1, x2, y2, { stroke: netColor(s.net), "stroke-width": 2.4, "stroke-opacity": 0.85, "stroke-linecap": "round" }))
  }

  // 部品（ピン穴＋外形＋ラベル＋極性/カソード帯）
  for (const [ref, pl] of Object.entries(PLACEMENT)) {
    const fp = FOOTPRINTS[ref]; if (!fp) continue
    const pts = fp.pins.map((pin) => px(p.pinXY[`${ref}.${pin.name}`]))
    const minX = Math.min(...pts.map((q) => q[0])), maxX = Math.max(...pts.map((q) => q[0]))
    const minY = Math.min(...pts.map((q) => q[1])), maxY = Math.max(...pts.map((q) => q[1]))
    out.push(rect(minX - 6, minY - 6, maxX - minX + 12, maxY - minY + 12, { fill: "#fff", "fill-opacity": 0.65, stroke: "#c08a3a", rx: 4 }))
    for (const pin of fp.pins) { const [cx, cy] = px(p.pinXY[`${ref}.${pin.name}`]); out.push(circle(cx, cy, 3.2, { fill: "#c08a3a" })) }
    out.push(text((minX + maxX) / 2, minY - 9, `${fp.label} ${fp.value ?? ""}`.trim(), { "text-anchor": "middle", "font-size": 9.5, fill: "#8a5a1a", "font-weight": 600 }))
    if (fp.polarityPin) { const [cx, cy] = px(p.pinXY[`${ref}.${fp.polarityPin}`]); out.push(text(cx - 6, cy - 5, "+", { "font-size": 12, fill: "#b00", "font-weight": 700 })) }
    if (fp.stripePin) { const [cx, cy] = px(p.pinXY[`${ref}.${fp.stripePin}`]); out.push(line(cx - 5, cy - 6, cx - 5, cy + 6, { stroke: "#333", "stroke-width": 2 })) }
  }

  // 凡例
  let ly = MT
  const lx = ML + (BOARD.width - 1) * PITCH + 40
  out.push(text(lx, ly, "ネット配色", { "font-size": 12, fill: "#333", "font-weight": 700 })); ly += 18
  for (const [n, c] of Object.entries(NET_COLOR)) {
    out.push(line(lx, ly - 4, lx + 20, ly - 4, { stroke: c, "stroke-width": 3 }))
    out.push(text(lx + 26, ly, n, { "font-size": 10, fill: "#333" })); ly += 15
  }
  ly += 8
  out.push(text(lx, ly, "凡例: ●=Pico使用ピン ●=部品ピン", { "font-size": 9, fill: "#555" })); ly += 13
  out.push(text(lx, ly, "+ =コンデンサ極性 | =ダイオード帯", { "font-size": 9, fill: "#555" })); ly += 13

  // 注記
  const notes = [
    "手置き配置は circuit/perfboard/layout.ts で調整。",
    "配線は点対点のはんだジャンパ。電源/GNDはバス代わりに太線可。",
    "Pico の 2 列に挟まれた内側は Pico 本体上。部品は外側へ。",
  ]
  let ny = MT + (BOARD.height - 1) * PITCH + 30
  for (const t of notes) { out.push(text(ML, ny, t, { "font-size": 10, fill: "#555" })); ny += 15 }

  out.push("</svg>")
  return out.join("\n")
}
```

- [ ] **Step 4: 実行して成功を確認**

Run: `nix develop -c bun test circuit/perfboard/render.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add circuit/perfboard/render.ts circuit/perfboard/render.test.ts
git commit -m "feat(perfboard): SVG 描画（格子・Pico ゴースト・配線・凡例）"
```

---

### Task 6: CLI（perfboard.ts）と全テスト通し

**Files:**
- Create: `circuit/perfboard.ts`
- Modify: `circuit/package.json`（scripts に `"perfboard": "bun perfboard.ts"`）

**Interfaces:**
- Consumes: `resolvePlacement`（place.ts）、`buildWires`（wire.ts）、`renderPerfboardSvg`（render.ts）
- Produces: `build/perfboard.svg`

- [ ] **Step 1: perfboard.ts を実装**

```ts
// circuit/perfboard.ts
// 使い方: bun perfboard.ts  → build/perfboard.svg を出力
import { mkdirSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { resolvePlacement } from "./perfboard/place"
import { buildWires } from "./perfboard/wire"
import { renderPerfboardSvg } from "./perfboard/render"

const p = resolvePlacement()
if (p.errors.length) {
  for (const e of p.errors) console.error("ERROR:", e)
  process.exit(1)
}
const svg = renderPerfboardSvg(p, buildWires(p.pinXY))
const out = join(import.meta.dir, "..", "build", "perfboard.svg")
mkdirSync(dirname(out), { recursive: true })
writeFileSync(out, svg)
console.log(`wrote ${out} (holes used: ${p.occupied.size})`)
```

- [ ] **Step 2: package.json に script 追加**

`circuit/package.json` の `scripts` に 1 行足す（既存 `"breadboard"` の隣）:

```json
    "perfboard": "bun perfboard.ts",
```

- [ ] **Step 3: CLI を実行して SVG 生成を確認**

Run: `nix develop -c bash -c 'cd circuit && bun perfboard.ts'`
Expected: `wrote .../build/perfboard.svg (holes used: NN)`、exit 0。エラー行が出たら layout.ts を調整。

- [ ] **Step 4: perfboard 全テスト＋既存 ERC を通す**

Run: `./test/erc.sh`
Expected: 既存 ERC ＋ perfboard の全 test が PASS（parts.ts 不変なので ERC は不変）。

- [ ] **Step 5: 生成物を目視確認（SVG が妥当）**

Run: `nix develop -c bash -c 'head -c 200 build/perfboard.svg'`
Expected: `<svg ... viewBox=...` で始まる。

- [ ] **Step 6: Commit**

```bash
git add circuit/perfboard.ts circuit/package.json
git commit -m "feat(perfboard): CLI で build/perfboard.svg を生成"
```

---

### Task 7: ビューア統合と README

既存の配線図ビューアに「ユニバーサル基板」を足し、serve 時に `perfboard.svg` も生成する。

**Files:**
- Modify: `circuit/breadboard-serve.py`（perfboard 生成を追加）
- Modify: `circuit/breadboard-viewer.html`（プルダウンに選択肢追加）
- Modify: `README.md`（回路セクションに追記）

- [ ] **Step 1: serve スクリプトに perfboard 生成を追加**

`circuit/breadboard-serve.py` の `render_diagrams()` 末尾（`for preset ...` ループの後）に追記:

```python
    # ユニバーサル基板（実装用）配線図も生成
    print("rendering PERFBOARD -> build/perfboard.svg")
    proc = subprocess.run(
        ["bun", "perfboard.ts"],
        cwd=str(CIRCUIT), capture_output=True, text=True,
    )
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout)
        sys.stderr.write(proc.stderr)
        sys.exit("bun failed rendering perfboard")
```

- [ ] **Step 2: ビューア HTML に選択肢を追加**

`circuit/breadboard-viewer.html` の `PRESETS` オブジェクトに 1 行追加:

```js
  perfboard:   { file: 'perfboard.svg',           label: 'ユニバーサル基板 (実装用)' },
```

同ファイルの `<select id="preset">` に `<option>` を 1 つ追加（full の後）:

```html
    <option value="perfboard">ユニバーサル基板 (実装用)</option>
```

- [ ] **Step 3: ビューアをローカル起動して確認**

Run: `NO_TUNNEL=1 PORT=8766 ./circuit/breadboard.sh > /tmp/pb.log 2>&1 &`
その後:
Run: `for i in $(seq 1 40); do grep -q "Open in your browser" /tmp/pb.log && break; sleep 1; done; curl -s -o /dev/null -w "perfboard.svg -> %{http_code}\n" http://127.0.0.1:8766/perfboard.svg`
Expected: `perfboard.svg -> 200`。確認後 `pkill -f breadboard-serve` で停止。

- [ ] **Step 4: README に追記**

`README.md` の「### ブレッドボード配線図をブラウザで確認」節の末尾に段落を追加:

```markdown

実装用の**ユニバーサル基板（P-03229）配線図**も同じビューアで見られる（プルダウン「ユニバーサル基板 (実装用)」）。
配線図は `circuit/perfboard/` が生成し、部品の手置きは `circuit/perfboard/layout.ts` を編集して調整する
（`at: [x, y]` は左上原点・各部品の 1 番ピンの穴）。Pico は実測 GP0=(3,2) で固定配置される。
```

- [ ] **Step 5: Commit**

```bash
git add circuit/breadboard-serve.py circuit/breadboard-viewer.html README.md
git commit -m "feat(perfboard): ビューア統合と README 追記"
```

---

## Self-Review 結果

- **Spec coverage:** 座標系/Pico写像(T1)、フットプリント(T2)、手置き+検証(T3)、配線(T4)、描画(T5)、CLI(T6)、ビューア+README(T7) で spec 各節を網羅。
- **Placeholder scan:** 全ステップに実コード/実コマンド/期待値あり。TBD 無し。
- **Type consistency:** `XY`/`Placement.pinXY`/`WireSeg`/`normEndpoint`/`resolvePlacement`/`buildWires`/`renderPerfboardSvg` はタスク間で同一シグネチャ。`FOOTPRINTS` は U1 を含まず、U1 は pico.ts 経由（place.ts が注入）で一貫。
- **既知の運用ノート:** layout.ts の既定座標は place.test.ts の妥当性テストで担保。落ちたら座標のみ調整（T3 Step5 / T6 Step3 に明記）。

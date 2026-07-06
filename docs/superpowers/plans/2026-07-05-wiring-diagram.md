# 実装ガイド（配線図）生成 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 回路の正（tscircuit）を汚さずに、実物スルーホール部品の物理配置を隔離モジュールで足し、ユニバーサル基板（秋月Cタイプ 72×47）の実装ガイド（配線図）を生成できるようにする。まず②tscircuit の PCB ビューを出して評価し、足りなければ①穴グリッド付き自作SVGを追加する。

**Architecture:** 部品＋結線（ネット）の定義を `circuit/parts.ts` に共有データとして切り出し、`index.tsx`（回路図・SMD仮フット＋schX/schY）と `board.tsx`（物理・実物フット＋pcbX/pcbY）が同じ結線を消費する。物理配置は `placement.ts` に隔離。②は circuit JSON → `circuit-to-svg` で `build/wiring-pcb.svg`。①は circuit JSON を読んで穴グリッド付き SVG を自作。

**Tech Stack:** TypeScript / bun / tscircuit（RootCircuit, footprinter）/ circuit-to-svg。既存の ERC（`erc.ts` の `runErc`）を物理版でも流用。

## Global Constraints

- 回路の正 `circuit/index.tsx` の結線（trace＝ネット構成）は不変。リファクタ後も既存 ERC テストと結線特性テストが通ること。
- `build/` 配下は再生成できる派生物。コミットしない（`.gitignore` 済み）。SVG 出力はすべて `build/` へ。
- 物理フットプリントのピン間隔・寸法は推測で確定しない。`docs/parts-selection.md`／データシート由来の初期値を置き、footprinter がエラーを出したら正しい文法へ直す。不明値はユーザー確認。
- 対象ユニバーサル基板は秋月Cタイプ 72×47mm・2.54mm ピッチ。物理配置は基板中心を原点とし x∈[-36,36], y∈[-23.5,23.5] mm に収める。
- bun コマンドは nix devシェル前提。作業ディレクトリは `circuit/`。初回は `bun install`（node_modules 未取得のため）。
- SW1（タクトスイッチ）の未使用パッド `SW1.pin3` / `SW1.pin4` は意図的未接続。ERC の `ALLOW_UNCONNECTED` を物理版でも同じく渡す。

---

## ファイル構成

作成/変更するファイルと責務：

- `circuit/parts.ts`（新規） — 部品リスト `PARTS` と結線リスト `NETS` の共有データ。回路図/物理の両方が読む唯一のネット定義。
- `circuit/index.tsx`（変更） — `PARTS`/`NETS` を消費して回路図（SMD仮フット＋schX/schY）を描く。結線はインラインではなく `NETS` から生成。
- `circuit/schematic-layout.ts`（新規） — 回路図専用の per-ref レイアウト表（schX/schY/schRotation/フットプリント）。`index.tsx` からのみ使う。
- `circuit/render-parts.tsx`（新規） — `PARTS`→JSX / `NETS`→trace の共有レンダラ。回路図・物理で共通（配置系プロップは呼び出し側が注入）。
- `circuit/placement.ts`（新規） — 物理配置マップ `PLACEMENT`（ref → pcbX/pcbY/pcbRotation/実物フットプリント）。物理の手保守データを隔離。
- `circuit/board.tsx`（新規） — 物理版 board。`PARTS`/`NETS`/`PLACEMENT` を消費。物理版の circuit JSON を作る `buildBoardCircuitJson()` を提供。
- `circuit/wiring-pcb.ts`（新規） — ②：物理 circuit JSON → `circuit-to-svg` で `build/wiring-pcb.svg` を書く CLI。
- `circuit/wiring-svg.ts`（新規・条件付き） — ①：物理 circuit JSON を読み、2.54mm 穴グリッド付き `build/wiring.svg` を自作。②が不十分な場合のみ。
- テスト：`circuit/parts.test.ts`, `circuit/placement.test.ts`, `circuit/board.test.tsx`, `circuit/wiring-pcb.test.ts`（+ 条件付き `circuit/wiring-svg.test.ts`）。
- `circuit/package.json`（変更） — `circuit-to-svg` を devDependencies に明示追加、`wiring:pcb`（と条件付き `wiring`）スクリプト追加。

---

## Task 1: 回路図の結線特性テスト（リファクタの安全網）

現状の `index.tsx` の結線（ネット→接続ポート集合）を明示的にピン留めする特性テストを先に入れる。以後のリファクタでこのテストが通り続けることが、結線不変の保証になる。

**Files:**
- Test: `circuit/parts.test.ts`（新規）

**Interfaces:**
- Consumes: `buildCircuitJson()`（`circuit/netlist.tsx` の既存 export）, `runErc`（未使用だがここでは connectivity を直接見る）
- Produces: 期待ネットマップ `EXPECTED_NETS`（Task 2 以降の共有データの正解表）

- [ ] **Step 1: 特性テストを書く（現状 index.tsx に対して通る）**

```ts
// circuit/parts.test.ts
import { expect, test } from "bun:test"
import { buildCircuitJson } from "./netlist"

// 現行 index.tsx の結線を明示的にピン留め（ネット名 → 接続ポート "Ref.pin" のソート済み集合）。
// リファクタ後もこの写像が一致することを不変条件とする。
export const EXPECTED_NETS: Record<string, string[]> = {
  V5: ["C1.pin1", "C2.pin1", "D2.pin2", "M1.VPLUS", "U1.VBUS"],
  GND: ["C1.pin2", "C2.pin2", "D1.K", "Q1.S", "Rgs.pin2", "SW1.pin2", "U1.GND"],
  SERVO_RTN: ["D2.pin1", "M1.GND", "Q1.D"],
  SERVO_SIG: ["M1.SIG", "U1.GP15"],
  GATE_DRV: ["Rg.pin1", "U1.GP14"],
  GATE: ["Q1.G", "Rg.pin2", "Rgs.pin1"],
  LED_DRV_R: ["Rled.pin1", "U1.GP16"],
  LED_A_R: ["D1.R", "Rled.pin2"],
  LED_DRV_G: ["Rled2.pin1", "U1.GP18"],
  LED_A_G: ["D1.G", "Rled2.pin2"],
  BTN: ["SW1.pin1", "U1.GP17"],
}

// circuit JSON から「ネット名 → 接続ポート集合」を接続キー経由で復元するヘルパ。
function netMap(circuitJson: any[]): Record<string, string[]> {
  const compName: Record<string, string> = {}
  for (const e of circuitJson)
    if (e.type === "source_component") compName[e.source_component_id] = e.name
  const label = (p: any) =>
    `${compName[p.source_component_id] ?? p.source_component_id}.${p.name}`
  const ports = circuitJson.filter((e) => e.type === "source_port")
  const nets = circuitJson.filter((e) => e.type === "source_net")
  const portsByKey: Record<string, string[]> = {}
  for (const p of ports)
    if (p.subcircuit_connectivity_map_key != null)
      (portsByKey[p.subcircuit_connectivity_map_key] ??= []).push(label(p))
  const out: Record<string, string[]> = {}
  for (const n of nets)
    if (n.subcircuit_connectivity_map_key != null)
      out[n.name] = [...new Set(portsByKey[n.subcircuit_connectivity_map_key] ?? [])].sort()
  return out
}

test("index.tsx の結線が EXPECTED_NETS と一致", async () => {
  const cj = await buildCircuitJson()
  expect(netMap(cj)).toEqual(EXPECTED_NETS)
}, 30_000)
```

- [ ] **Step 2: 依存を取得してテストを流す（現状に対して通るはず）**

Run（`circuit/` で）: `bun install && bun test parts.test.ts`
Expected: PASS。もし `EXPECTED_NETS` が実際の結線と食い違って FAIL したら、**テスト側の期待値を実 circuit JSON に合わせて修正**する（現行 index.tsx が正）。ダイオードのピン名が `.anode/.cathode` ではなく `pin1/pin2` として source_port に出る点に注意（trace セレクタと source_port 名は異なりうる）。修正後 PASS を確認。

- [ ] **Step 3: コミット**

```bash
git add circuit/parts.test.ts
git commit -m "test(circuit): 回路図の結線特性テストを追加（リファクタ安全網）"
```

---

## Task 2: 共有データ `parts.ts` を切り出し、index.tsx を差し替え

結線とパーツ集合を `parts.ts` に移し、`index.tsx` はそれを消費して回路図を描く形へリファクタする。結線は `NETS` から生成する。

**Files:**
- Create: `circuit/parts.ts`
- Create: `circuit/schematic-layout.ts`
- Modify: `circuit/index.tsx`（全面的に置換：パーツ/結線をデータ駆動に）
- Test: `circuit/parts.test.ts`（Task 1、変更なしで通り続ける）

**Interfaces:**
- Produces:
  - `PARTS: PartSpec[]` — `PartSpec = { ref: string; kind: "chip"|"resistor"|"capacitor"|"diode"|"pushbutton"; pinLabels?: Record<string,string>; props?: Record<string,any> }`
  - `NETS: { name: string; endpoints: string[] }[]` — endpoints は tscircuit の trace セレクタ文字列（例 `".U1 .VBUS"`）
- Consumes（index.tsx が）: `SCH_LAYOUT: Record<string, { schX:number; schY:number; schRotation?:number; footprint:string }>`

- [ ] **Step 1: `parts.ts` を作る**

```ts
// circuit/parts.ts
// 部品と結線（ネット）の唯一の定義。回路図(index.tsx)と物理(board.tsx)が共有する。
export type PartKind = "chip" | "resistor" | "capacitor" | "diode" | "pushbutton"

export interface PartSpec {
  ref: string
  kind: PartKind
  pinLabels?: Record<string, string> // chip のみ
  props?: Record<string, any>        // resistance / capacitance / polarized など
}

export const PARTS: PartSpec[] = [
  { ref: "U1", kind: "chip", pinLabels: { pin1: "VBUS", pin2: "GND", pin3: "GP15", pin4: "GP14", pin5: "GP16", pin6: "GP18", pin7: "GP17" } },
  { ref: "M1", kind: "chip", pinLabels: { pin1: "SIG", pin2: "VPLUS", pin3: "GND" } },
  { ref: "Q1", kind: "chip", pinLabels: { pin1: "G", pin2: "D", pin3: "S" } },
  { ref: "Rg", kind: "resistor", props: { resistance: "220" } },
  { ref: "Rgs", kind: "resistor", props: { resistance: "10k" } },
  { ref: "Rled", kind: "resistor", props: { resistance: "330" } },
  { ref: "Rled2", kind: "resistor", props: { resistance: "330" } },
  { ref: "D1", kind: "chip", pinLabels: { pin1: "R", pin2: "G", pin3: "K" } },
  { ref: "SW1", kind: "pushbutton" },
  { ref: "C1", kind: "capacitor", props: { capacitance: "470uF", polarized: true } },
  { ref: "C2", kind: "capacitor", props: { capacitance: "100nF" } },
  { ref: "D2", kind: "diode" },
]

// ネット名 → 接続端点（tscircuit trace セレクタ）。結線の唯一の正。
export const NETS: { name: string; endpoints: string[] }[] = [
  { name: "V5", endpoints: [".U1 .VBUS", ".C1 .pin1", ".M1 .VPLUS", ".C2 .pin1", ".D2 .cathode"] },
  { name: "GND", endpoints: [".U1 .GND", ".C1 .pin2", ".Q1 .S", ".Rgs .pin2", ".D1 .K", ".SW1 .pin2", ".C2 .pin2"] },
  { name: "SERVO_RTN", endpoints: [".M1 .GND", ".Q1 .D", ".D2 .anode"] },
  { name: "SERVO_SIG", endpoints: [".U1 .GP15", ".M1 .SIG"] },
  { name: "GATE_DRV", endpoints: [".U1 .GP14", ".Rg .pin1"] },
  { name: "GATE", endpoints: [".Rg .pin2", ".Q1 .G", ".Rgs .pin1"] },
  { name: "LED_DRV_R", endpoints: [".U1 .GP16", ".Rled .pin1"] },
  { name: "LED_A_R", endpoints: [".Rled .pin2", ".D1 .R"] },
  { name: "LED_DRV_G", endpoints: [".U1 .GP18", ".Rled2 .pin1"] },
  { name: "LED_A_G", endpoints: [".Rled2 .pin2", ".D1 .G"] },
  { name: "BTN", endpoints: [".U1 .GP17", ".SW1 .pin1"] },
]
```

- [ ] **Step 2: 回路図レイアウト表 `schematic-layout.ts` を作る**

```ts
// circuit/schematic-layout.ts
// 回路図(index.tsx)専用の配置とSMD仮フットプリント。物理配置とは無関係。
export const SCH_LAYOUT: Record<
  string,
  { schX: number; schY: number; schRotation?: number; footprint: string }
> = {
  U1: { schX: 0, schY: 0, footprint: "pinrow7" },
  M1: { schX: -6, schY: 3, footprint: "pinrow3" },
  Q1: { schX: -8, schY: -5, footprint: "pinrow3" },
  Rg: { schX: -4, schY: -5, footprint: "0603" },
  Rgs: { schX: -6, schY: -6, schRotation: 90, footprint: "0603" },
  Rled: { schX: 4, schY: 2, footprint: "0603" },
  Rled2: { schX: 4, schY: -2, footprint: "0603" },
  D1: { schX: 8, schY: 0, footprint: "pinrow3" },
  SW1: { schX: 5, schY: -6, footprint: "pushbutton" },
  C1: { schX: -4, schY: 5, schRotation: 90, footprint: "1206" },
  C2: { schX: -7, schY: 5, schRotation: 90, footprint: "0603" },
  D2: { schX: -1, schY: 5, schRotation: 90, footprint: "sod123" },
}
```

- [ ] **Step 3: パーツ/結線からJSXを組む共有レンダラ `render-parts.tsx` を作る**

回路図・物理で `PARTS` → JSX と `NETS` → trace を共通化する（DRY）。配置系プロップ（footprint/schX/pcbX等）は呼び出し側が per-ref で差し込む。

```tsx
// circuit/render-parts.tsx
// PARTS/NETS を JSX へ変換する共有ヘルパ。配置系プロップは placementFor(ref) で注入する。
import type { PartSpec } from "./parts"
import { NETS } from "./parts"

export function renderParts(parts: PartSpec[], placementFor: (ref: string) => Record<string, any>) {
  return parts.map((p) => {
    const extra = placementFor(p.ref)
    const common = { key: p.ref, name: p.ref, ...extra }
    switch (p.kind) {
      case "chip":
        return <chip {...common} pinLabels={p.pinLabels} />
      case "resistor":
        return <resistor {...common} resistance={p.props!.resistance} />
      case "capacitor":
        return <capacitor {...common} capacitance={p.props!.capacitance} polarized={!!p.props?.polarized} />
      case "diode":
        return <diode {...common} />
      case "pushbutton":
        return <pushbutton {...common} />
    }
  })
}

export function renderTraces() {
  return NETS.flatMap((net) =>
    net.endpoints.map((ep, i) => <trace key={`${net.name}-${i}`} from={ep} to={`net.${net.name}`} />),
  )
}
```

- [ ] **Step 4: `index.tsx` をデータ駆動へ置換**

```tsx
// circuit/index.tsx
// smtlk 回路の正（回路図＝schematic）。部品・結線は parts.ts、回路図レイアウトは schematic-layout.ts。
import { PARTS } from "./parts"
import { SCH_LAYOUT } from "./schematic-layout"
import { renderParts, renderTraces } from "./render-parts"

export default () => (
  <board width="60mm" height="45mm" routingDisabled>
    {renderParts(PARTS, (ref) => {
      const l = SCH_LAYOUT[ref]
      return { footprint: l.footprint, schX: l.schX, schY: l.schY, ...(l.schRotation ? { schRotation: l.schRotation } : {}) }
    })}
    {renderTraces()}
  </board>
)
```

- [ ] **Step 5: 特性テストと既存ERCテストを流す**

Run（`circuit/`）: `bun test parts.test.ts netlist.test.tsx`
Expected: 両方 PASS（`index.tsx の結線が EXPECTED_NETS と一致` / `本番回路 (index.tsx) が ERC を通る`）。FAIL したらリファクタで結線が変わっている＝バグ。差分を circuit JSON で確認して直す。

- [ ] **Step 6: コミット**

```bash
git add circuit/parts.ts circuit/schematic-layout.ts circuit/render-parts.tsx circuit/index.tsx
git commit -m "refactor(circuit): 部品・結線を parts.ts に共有化し index.tsx をデータ駆動へ"
```

---

## Task 3: 物理配置マップ `placement.ts`

各部品の基板グリッド座標・向き・実物スルーホールフットプリントを1箇所に定義する。座標は秋月Cタイプ 72×47（原点=基板中心, mm）に収める初期レイアウト。

**Files:**
- Create: `circuit/placement.ts`
- Test: `circuit/placement.test.ts`

**Interfaces:**
- Produces: `PLACEMENT: Record<string, { pcbX:number; pcbY:number; pcbRotation?:number; footprint:string }>`
- Consumes: `PARTS`（全 ref を網羅していることをテストで保証）

- [ ] **Step 1: 網羅・境界のテストを書く**

```ts
// circuit/placement.test.ts
import { expect, test } from "bun:test"
import { PARTS } from "./parts"
import { PLACEMENT } from "./placement"

test("PLACEMENT は全部品を網羅する", () => {
  for (const p of PARTS) expect(PLACEMENT[p.ref], `missing placement for ${p.ref}`).toBeDefined()
})

test("配置は 72x47 基板（中心原点）内に収まる", () => {
  for (const [ref, pl] of Object.entries(PLACEMENT)) {
    expect(Math.abs(pl.pcbX), `${ref} x out of board`).toBeLessThanOrEqual(36)
    expect(Math.abs(pl.pcbY), `${ref} y out of board`).toBeLessThanOrEqual(23.5)
  }
})
```

- [ ] **Step 2: テストを流して落ちるのを確認**

Run（`circuit/`）: `bun test placement.test.ts`
Expected: FAIL（`Cannot find module './placement'`）。

- [ ] **Step 3: `placement.ts` を書く**

フットプリント文字列は `docs/parts-selection.md` の実商品由来の初期値。ピッチ表記は footprinter 文法に依存するため、Task 5 の初回レンダリングで検証・調整する（不明なら README/footprinter 文法を参照）。座標は 2.54mm グリッドにおおよそ載る初期レイアウト。

```ts
// circuit/placement.ts
// 物理版(board.tsx)の手保守データ：基板グリッド座標(mm, 原点=中心)・向き・実物フットプリント。
// 対象: 秋月Cタイプ 72x47mm・2.54mmピッチ。ピッチ表記は footprinter 文法に合わせ Task5 で確定。
export const PLACEMENT: Record<
  string,
  { pcbX: number; pcbY: number; pcbRotation?: number; footprint: string }
> = {
  // 中央ハブ：使用7ピンのヘッダとして表現（実機は2x20モジュール。ガイド上は使用ピン列）。
  U1: { pcbX: 0, pcbY: 0, footprint: "pinrow7" },
  // 左側：電源・サーボ・ゲート
  M1: { pcbX: -25, pcbY: 12, footprint: "pinrow3" },        // サーボ3線ヘッダ
  Q1: { pcbX: -25, pcbY: -8, footprint: "to220-3" },        // TO-220（要文法確認, 代替 pinrow3）
  Rg: { pcbX: -12, pcbY: -8, footprint: "axial_p7.62mm" },  // 1/4W カーボン抵抗
  Rgs: { pcbX: -12, pcbY: -14, pcbRotation: 90, footprint: "axial_p7.62mm" },
  C1: { pcbX: -8, pcbY: 14, footprint: "radial_p2.5_d6.3" }, // 470uF16V 電解
  C2: { pcbX: -16, pcbY: 14, footprint: "radial_p5.08" },    // 100nF 5mmピッチ
  D2: { pcbX: -2, pcbY: 14, pcbRotation: 90, footprint: "axial_p7.62mm" }, // 1N5819 DO-41
  // 右側：LED・ボタン
  Rled: { pcbX: 14, pcbY: 6, footprint: "axial_p7.62mm" },
  Rled2: { pcbX: 14, pcbY: -6, footprint: "axial_p7.62mm" },
  D1: { pcbX: 26, pcbY: 0, footprint: "pinrow3" },           // 5mm 2色LED 3リード
  SW1: { pcbX: 18, pcbY: -14, footprint: "pushbutton" },
}
```

- [ ] **Step 4: テストを流して通す**

Run（`circuit/`）: `bun test placement.test.ts`
Expected: PASS（網羅・境界とも）。境界超過が出たら座標を詰めて再実行。

- [ ] **Step 5: コミット**

```bash
git add circuit/placement.ts circuit/placement.test.ts
git commit -m "feat(circuit): 物理配置マップ placement.ts（秋月Cタイプ）を追加"
```

---

## Task 4: 物理版 board `board.tsx` と ERC 一致

物理フットプリント＋配置で board を描き、結線が回路図と同一で ERC も通ることを保証する。

**Files:**
- Create: `circuit/board.tsx`
- Test: `circuit/board.test.tsx`

**Interfaces:**
- Consumes: `PARTS`, `NETS`(via renderTraces), `PLACEMENT`, `renderParts`, `runErc`, `ALLOW_UNCONNECTED`, `EXPECTED_NETS`
- Produces:
  - `PhysicalBoard`（default export のコンポーネント）
  - `buildBoardCircuitJson(): Promise<any[]>`

- [ ] **Step 1: 物理版の結線一致・ERCテストを書く**

```tsx
// circuit/board.test.tsx
import { expect, test } from "bun:test"
import { buildBoardCircuitJson } from "./board"
import { runErc } from "./erc"
import { ALLOW_UNCONNECTED } from "./netlist"
import { EXPECTED_NETS } from "./parts.test"

function netMap(circuitJson: any[]): Record<string, string[]> {
  const compName: Record<string, string> = {}
  for (const e of circuitJson)
    if (e.type === "source_component") compName[e.source_component_id] = e.name
  const label = (p: any) => `${compName[p.source_component_id] ?? p.source_component_id}.${p.name}`
  const ports = circuitJson.filter((e) => e.type === "source_port")
  const nets = circuitJson.filter((e) => e.type === "source_net")
  const byKey: Record<string, string[]> = {}
  for (const p of ports)
    if (p.subcircuit_connectivity_map_key != null)
      (byKey[p.subcircuit_connectivity_map_key] ??= []).push(label(p))
  const out: Record<string, string[]> = {}
  for (const n of nets)
    if (n.subcircuit_connectivity_map_key != null)
      out[n.name] = [...new Set(byKey[n.subcircuit_connectivity_map_key] ?? [])].sort()
  return out
}

test("board.tsx の結線が回路図(EXPECTED_NETS)と一致", async () => {
  expect(netMap(await buildBoardCircuitJson())).toEqual(EXPECTED_NETS)
}, 60_000)

test("board.tsx が ERC を通る", async () => {
  expect(runErc(await buildBoardCircuitJson(), { allowUnconnected: ALLOW_UNCONNECTED })).toEqual([])
}, 60_000)
```

- [ ] **Step 2: テストを流して落ちるのを確認**

Run（`circuit/`）: `bun test board.test.tsx`
Expected: FAIL（`Cannot find module './board'`）。

- [ ] **Step 3: `board.tsx` を書く**

```tsx
// circuit/board.tsx
// 物理版 board（実装ガイド用）。結線は parts.ts と共有し、フットプリント/配置は placement.ts。
import { RootCircuit } from "tscircuit"
import { PARTS } from "./parts"
import { PLACEMENT } from "./placement"
import { renderParts, renderTraces } from "./render-parts"

export default function PhysicalBoard() {
  return (
    <board width="72mm" height="47mm" routingDisabled>
      {renderParts(PARTS, (ref) => {
        const p = PLACEMENT[ref]
        return { footprint: p.footprint, pcbX: p.pcbX, pcbY: p.pcbY, ...(p.pcbRotation ? { pcbRotation: p.pcbRotation } : {}) }
      })}
      {renderTraces()}
    </board>
  )
}

export async function buildBoardCircuitJson(): Promise<any[]> {
  const circuit = new RootCircuit()
  circuit.add(<PhysicalBoard />)
  await circuit.renderUntilSettled()
  return circuit.getCircuitJson() as any[]
}
```

- [ ] **Step 4: テストを流す（footprinter エラーはここで対処）**

Run（`circuit/`）: `bun test board.test.tsx`
Expected: 2件 PASS。
- `Unknown footprint` 等が出たら、その部品の `PLACEMENT[...].footprint` を footprinter が受け付ける文字列へ修正（例 `to220-3`→`to220`、`radial_p5.08`→`radial_p5.08_d4` 等）。`@tscircuit/footprinter` の文法に合わせる。修正は `placement.ts` のみ。
- 結線不一致なら `renderTraces` 共有が効いているか確認（board も同じ NETS を使う）。

- [ ] **Step 5: コミット**

```bash
git add circuit/board.tsx circuit/board.test.tsx
git commit -m "feat(circuit): 物理版 board.tsx（実物フット＋配置、結線は共有・ERC一致）"
```

---

## Task 5: ②tscircuit PCB ビュー生成 `wiring-pcb.ts`

物理 circuit JSON を PCB SVG に変換し `build/wiring-pcb.svg` へ出力する。これが評価対象。

**Files:**
- Create: `circuit/wiring-pcb.ts`
- Test: `circuit/wiring-pcb.test.ts`
- Modify: `circuit/package.json`（`circuit-to-svg` を devDependencies に、`wiring:pcb` スクリプト追加）

**Interfaces:**
- Consumes: `buildBoardCircuitJson()`, `convertCircuitJsonToPcbSvg`（`circuit-to-svg`）
- Produces: `generateWiringPcbSvg(): Promise<string>`（SVG 文字列を返し、副作用でファイルも書く CLI）

- [ ] **Step 1: `circuit-to-svg` を devDependency に追加**

`circuit/package.json` の `devDependencies` に `"circuit-to-svg": "latest"` を追加（tscircuit の transitive だが直接 import するため明示）。その後 `bun install`。

- [ ] **Step 2: 生成物の性質テストを書く**

```ts
// circuit/wiring-pcb.test.ts
import { expect, test } from "bun:test"
import { generateWiringPcbSvg } from "./wiring-pcb"

test("PCB SVG が生成され全部品の ref を含む", async () => {
  const svg = await generateWiringPcbSvg()
  expect(svg.startsWith("<svg") || svg.includes("<svg")).toBe(true)
  for (const ref of ["U1", "M1", "Q1", "Rg", "Rgs", "Rled", "Rled2", "D1", "SW1", "C1", "C2", "D2"])
    expect(svg, `svg should mention ${ref}`).toContain(ref)
}, 60_000)
```

- [ ] **Step 3: テストを流して落ちるのを確認**

Run（`circuit/`）: `bun test wiring-pcb.test.ts`
Expected: FAIL（`Cannot find module './wiring-pcb'`）。

- [ ] **Step 4: `wiring-pcb.ts` を書く**

```ts
// circuit/wiring-pcb.ts
// ②：物理版 board を PCB SVG（build/wiring-pcb.svg）にする。実装ガイドの評価用。
// `bun wiring-pcb.ts` で生成。build/ 配下は非コミットの派生物。
import { convertCircuitJsonToPcbSvg } from "circuit-to-svg"
import { mkdirSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { buildBoardCircuitJson } from "./board"

const OUT = join(import.meta.dir, "..", "build", "wiring-pcb.svg")

export async function generateWiringPcbSvg(): Promise<string> {
  const svg = convertCircuitJsonToPcbSvg(await buildBoardCircuitJson())
  mkdirSync(dirname(OUT), { recursive: true })
  writeFileSync(OUT, svg)
  return svg
}

if (import.meta.main) {
  await generateWiringPcbSvg()
  console.log(`wrote ${OUT}`)
}
```

- [ ] **Step 5: テストとCLIを流す**

Run（`circuit/`）: `bun test wiring-pcb.test.ts && bun wiring-pcb.ts`
Expected: テスト PASS、`wrote .../build/wiring-pcb.svg` 表示。`convertCircuitJsonToPcbSvg` が named export でなければ `circuit-to-svg` の export 名を確認して修正（`import { ... } from "circuit-to-svg"`）。SVG に ref が出ない場合は PCB シルク/ラベル描画のオプション有無を確認。

- [ ] **Step 6: `package.json` にスクリプト追加**

`circuit/package.json` の `scripts` に `"wiring:pcb": "bun wiring-pcb.ts"` を追加。

- [ ] **Step 7: コミット**

```bash
git add circuit/wiring-pcb.ts circuit/wiring-pcb.test.ts circuit/package.json circuit/bun.lock
git commit -m "feat(circuit): ②PCBビューで実装ガイド build/wiring-pcb.svg を生成"
```

---

## ✋ 評価チェックポイント（②で十分か判定）

`build/wiring-pcb.svg` を開いて、設計の合格ラインで判定する：

- 各部品の位置と向きが判別できる。
- どのピン同士を繋ぐか（ラッツネスト）が追える。
- 配置が 72×47mm に収まる（部品の重なりが無い）。

**十分なら**：ここで完了。Task 6 は実施しない（メンテが楽な②を採用）。
**不十分なら**（穴が数えられず組みにくい 等）：Task 6（①穴グリッド付き自作SVG）へ進む。この判定はユーザーと一緒に行う。

---

## Task 6（条件付き）: ①穴グリッド付き自作SVG `wiring-svg.ts`

②が不十分な場合のみ実装する。2.54mm 穴グリッドの上に部品ブロックを置き、ネットごとに色分けした点対点配線を引く、はんだ組み立て特化の図。

**Files:**
- Create: `circuit/wiring-svg.ts`
- Test: `circuit/wiring-svg.test.ts`
- Modify: `circuit/package.json`（`wiring` スクリプト追加）

**Interfaces:**
- Consumes: `PARTS`, `PLACEMENT`, `NETS`, `buildBoardCircuitJson()`（ポート座標の取得）
- Produces: `generateWiringSvg(): Promise<string>`

- [ ] **Step 1: 生成物の性質テストを書く**

```ts
// circuit/wiring-svg.test.ts
import { expect, test } from "bun:test"
import { generateWiringSvg } from "./wiring-svg"
import { NETS } from "./parts"

test("穴グリッドSVGが生成され、グリッドとネットを含む", async () => {
  const svg = await generateWiringSvg()
  expect(svg.includes("<svg")).toBe(true)
  // 28x18 の穴グリッド（72/2.54, 47/2.54）を circle で描く想定
  expect((svg.match(/<circle/g) ?? []).length).toBeGreaterThanOrEqual(28 * 18)
  // 各ネットのラベルが図中に出る
  for (const n of NETS) expect(svg, `svg should label net ${n.name}`).toContain(n.name)
}, 60_000)
```

- [ ] **Step 2: テストを流して落ちるのを確認**

Run（`circuit/`）: `bun test wiring-svg.test.ts`
Expected: FAIL（`Cannot find module './wiring-svg'`）。

- [ ] **Step 3: `wiring-svg.ts` を書く**

穴グリッドは基板中心原点→SVG 座標へ写像。部品は `PLACEMENT` の pcbX/pcbY を最寄り穴にスナップしてブロック描画。配線は `buildBoardCircuitJson()` の source_port を接続キーでグルーピングし、同ネットのポート座標間を色分けポリラインで結ぶ。ネット色は固定パレットを循環。

```ts
// circuit/wiring-svg.ts
// ①：2.54mm 穴グリッド付きのユニバーサル基板実装ガイド（build/wiring.svg）。
// 部品配置は placement.ts、結線は circuit JSON のポート接続から色分けで描く。
import { mkdirSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { PARTS } from "./parts"
import { PLACEMENT } from "./placement"
import { buildBoardCircuitJson } from "./board"

const OUT = join(import.meta.dir, "..", "build", "wiring.svg")
const PITCH = 2.54, W = 72, H = 47, M = 8 // margin px=mm 等倍
const COLS = Math.round(W / PITCH), ROWS = Math.round(H / PITCH)
const PALETTE = ["#e6194B","#3cb44b","#4363d8","#f58231","#911eb4","#42d4f4","#f032e6","#bfef45","#fabed4","#469990","#9A6324","#808000"]

// 基板中心原点(mm) → SVG 座標(px, y下向き)
const sx = (x: number) => M + (x + W / 2)
const sy = (y: number) => M + (H / 2 - y)

export async function generateWiringSvg(): Promise<string> {
  const cj = await buildBoardCircuitJson()
  const parts: string[] = []

  // 穴グリッド
  for (let c = 0; c < COLS; c++)
    for (let r = 0; r < ROWS; r++) {
      const x = -W / 2 + PITCH / 2 + c * PITCH
      const y = -H / 2 + PITCH / 2 + r * PITCH
      parts.push(`<circle cx="${sx(x).toFixed(2)}" cy="${sy(y).toFixed(2)}" r="0.5" fill="#ccc"/>`)
    }

  // 部品ブロック＋ラベル
  for (const p of PARTS) {
    const pl = PLACEMENT[p.ref]
    parts.push(
      `<rect x="${(sx(pl.pcbX) - 3).toFixed(2)}" y="${(sy(pl.pcbY) - 3).toFixed(2)}" width="6" height="6" fill="none" stroke="#333"/>` +
      `<text x="${sx(pl.pcbX).toFixed(2)}" y="${(sy(pl.pcbY) - 4).toFixed(2)}" font-size="2.5" text-anchor="middle">${p.ref}</text>`,
    )
  }

  // 結線：source_port を接続キーでグルーピングし、pcb_port 座標を線で結ぶ
  const compName: Record<string, string> = {}
  for (const e of cj) if (e.type === "source_component") compName[e.source_component_id] = e.name
  const pcbPortXY: Record<string, { x: number; y: number }> = {}
  for (const e of cj) if (e.type === "pcb_port") pcbPortXY[e.source_port_id] = { x: e.x, y: e.y }
  const keyOf: Record<string, string> = {}
  for (const e of cj) if (e.type === "source_port" && e.subcircuit_connectivity_map_key != null) keyOf[e.source_port_id] = e.subcircuit_connectivity_map_key
  const netName: Record<string, string> = {}
  for (const e of cj) if (e.type === "source_net" && e.subcircuit_connectivity_map_key != null) netName[e.subcircuit_connectivity_map_key] = e.name

  const byKey: Record<string, { x: number; y: number }[]> = {}
  for (const [portId, key] of Object.entries(keyOf)) {
    const xy = pcbPortXY[portId]
    if (xy) (byKey[key] ??= []).push(xy)
  }
  let ci = 0
  for (const [key, pts] of Object.entries(byKey)) {
    const color = PALETTE[ci++ % PALETTE.length]
    const name = netName[key] ?? key
    // スター配線：先頭ポートから各ポートへ直線（点対点の見取り図）
    const [hub, ...rest] = pts
    for (const q of rest)
      parts.push(`<line x1="${sx(hub.x).toFixed(2)}" y1="${sy(hub.y).toFixed(2)}" x2="${sx(q.x).toFixed(2)}" y2="${sy(q.y).toFixed(2)}" stroke="${color}" stroke-width="0.4"/>`)
    parts.push(`<text x="${sx(hub.x).toFixed(2)}" y="${sy(hub.y).toFixed(2)}" font-size="2" fill="${color}">${name}</text>`)
  }

  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W + 2 * M}mm" height="${H + 2 * M}mm" viewBox="0 0 ${W + 2 * M} ${H + 2 * M}">` +
    `<rect x="${M}" y="${M}" width="${W}" height="${H}" fill="#fdfdf5" stroke="#000"/>` +
    parts.join("") + `</svg>`
  mkdirSync(dirname(OUT), { recursive: true })
  writeFileSync(OUT, svg)
  return svg
}

if (import.meta.main) {
  await generateWiringSvg()
  console.log(`wrote ${OUT}`)
}
```

- [ ] **Step 4: テストとCLIを流す**

Run（`circuit/`）: `bun test wiring-svg.test.ts && bun wiring-svg.ts`
Expected: テスト PASS、`wrote .../build/wiring.svg`。`pcb_port` の座標フィールド名が `x/y` でなければ circuit JSON を確認して合わせる（`pcb_port` に `x`,`y` が無ければ該当要素名を調整）。

- [ ] **Step 5: `package.json` にスクリプト追加**

`circuit/package.json` の `scripts` に `"wiring": "bun wiring-svg.ts"` を追加。

- [ ] **Step 6: コミット**

```bash
git add circuit/wiring-svg.ts circuit/wiring-svg.test.ts circuit/package.json
git commit -m "feat(circuit): ①穴グリッド付き自作SVGで実装ガイド build/wiring.svg を生成"
```

---

## 完了条件

- Task 1–5 完了（②まで）。`bun test`（circuit 全体）が緑。`build/wiring-pcb.svg` が生成される。
- 評価チェックポイントで②の可否を判定。②不十分なら Task 6 まで完了し `build/wiring.svg` も生成。
- 回路の正（index.tsx）の結線が不変（特性テスト＋ERCテストが緑）。
- README に生成コマンド（`wiring:pcb` / 必要なら `wiring`）を1行追記（地の文で。コマンド例のブロック内に長いコメントを書かない）。

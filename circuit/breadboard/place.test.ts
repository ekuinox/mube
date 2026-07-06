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

test("placeParts は最適性を持つ: 繋がる2部品を隣接させ、非接続部品を端へ", () => {
  // Rg と Q1 だけを繋ぐネット。Rgs は非接続。
  // 入力順そのまま [Rg, Rgs, Q1] だと Rg-Q1 の span が広い。
  // 最適解は Rg と Q1 を隣接させる（span 最小）。n=3 は総当りで大域最適。
  // ソルバが入力順をそのまま返す退化バグならこのテストは落ちる。
  const refs = ["Rg", "Rgs", "Q1"]
  const nets = { LINK: ["Rg.pin1", "Q1.G"] }
  const pl = placeParts(refs, nets, 1)
  const iRg = pl.order.indexOf("Rg")
  const iQ1 = pl.order.indexOf("Q1")
  expect(Math.abs(iRg - iQ1)).toBe(1) // Rg と Q1 が隣接
})

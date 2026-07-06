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

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
  expect(p.pinXY["U1.GP16"]).toEqual([11, 22])  // SERVO_SIG
  expect(p.pinXY["U1.VBUS"]).toEqual([11, 3])
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
  expect(p.occupied.has("4,3")).toBe(true)    // Pico GP0=E4
  expect(p.occupied.has("11,3")).toBe(true)   // Pico VBUS
})

test("盤外配置はエラーになる", () => {
  const bad = { M1: { at: [14, 10] as [number, number], rot: 0 as const } }  // SIG..GND が x=14,15,16 → 15,16 が盤外
  const p = resolvePlacement(bad)
  expect(p.errors.some((e) => e.includes("盤外"))).toBe(true)
})

test("四隅への配置は使用不可エラーになる", () => {
  const bad = { C2: { at: [0, 0] as [number, number], rot: 0 as const } }  // 左上コーナー
  const p = resolvePlacement(bad)
  expect(p.errors.some((e) => e.includes("使用不可"))).toBe(true)
})

test("Pico 穴と重なる配置はエラーになる", () => {
  const bad = { C2: { at: [4, 3] as [number, number], rot: 0 as const } }  // Pico GP0=E4 と衝突
  const p = resolvePlacement(bad)
  expect(p.errors.some((e) => e.includes("重複"))).toBe(true)
})

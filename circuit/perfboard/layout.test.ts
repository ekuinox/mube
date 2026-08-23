// circuit/perfboard/layout.test.ts
import { expect, test } from "bun:test"
import { LAYOUT } from "./layout"
import { verifyLayout } from "./verify"

// 目的: 実際の配置データが NETS をすべて満たすこと。
// 未接続・ショート・穴の重複・割り当て漏れ・近接・交差・範囲外のいずれも無い状態を配線見本の合格条件とする。
test("配置データが全ネットを満たす", () => {
  expect(verifyLayout(LAYOUT)).toEqual([])
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

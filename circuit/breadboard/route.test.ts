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

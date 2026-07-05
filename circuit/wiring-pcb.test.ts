// circuit/wiring-pcb.test.ts
import { expect, test } from "bun:test"
import { generateWiringPcbSvg } from "./wiring-pcb"

test("PCB SVG が生成され全部品の ref を含む", async () => {
  const svg = await generateWiringPcbSvg()
  expect(svg.startsWith("<svg") || svg.includes("<svg")).toBe(true)

  // 全12部品の ref がシルクスクリーンに含まれること（Q1 含む）
  for (const ref of ["U1", "M1", "Q1", "Rg", "Rgs", "Rled", "Rled2", "D1", "SW1", "C1", "C2", "D2"])
    expect(svg, `svg should mention ${ref}`).toContain(ref)
}, 60_000)

test("PCB SVG にラッツネスト接続線が描画されている", async () => {
  const svg = await generateWiringPcbSvg()

  // data-type="pcb_rats_nest" はラッツネスト線に circuit-to-svg が付ける属性。
  // ネット数が ~11、うち多点スター接続があるため接続線は多数生成される。
  // 保守的な下限として 8 本以上を要求する。
  const ratsnestSegments = (svg.match(/data-type="pcb_rats_nest"/g) ?? []).length
  expect(ratsnestSegments, "ratsnest lines should be at least 8").toBeGreaterThanOrEqual(8)
}, 60_000)

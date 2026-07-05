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

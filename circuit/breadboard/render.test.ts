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

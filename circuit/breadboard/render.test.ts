// circuit/breadboard/render.test.ts
import { describe, test, expect } from "bun:test"
import { renderBreadboardSvg } from "./render"
import { JUMPERS } from "./servo-layout"

describe("renderBreadboardSvg", () => {
  let svg: string

  test("generates SVG string", () => {
    svg = renderBreadboardSvg()
    expect(svg).toContain("<svg")
  })

  test("contains all 8 component refs", () => {
    svg = renderBreadboardSvg()
    const refs = ["U1", "M1", "Q1", "Rg", "Rgs", "C1", "C2", "D2"]
    for (const ref of refs) {
      expect(svg).toContain(ref)
    }
  })

  test("contains all 6 net names", () => {
    svg = renderBreadboardSvg()
    const nets = ["V5", "GND", "SERVO_RTN", "SERVO_SIG", "GATE_DRV", "GATE"]
    for (const net of nets) {
      expect(svg).toContain(net)
    }
  })

  test("has at least JUMPERS.length <line or <path elements for wires", () => {
    svg = renderBreadboardSvg()
    // Count <line and <path elements (jumpers can be either)
    const lineMatches = (svg.match(/<line /g) ?? []).length
    const pathMatches = (svg.match(/<path /g) ?? []).length
    const wireCount = lineMatches + pathMatches
    expect(wireCount).toBeGreaterThanOrEqual(JUMPERS.length)
  })

  test("has at least 300 hole <circle elements", () => {
    svg = renderBreadboardSvg()
    const circleCount = (svg.match(/<circle /g) ?? []).length
    // 30 cols * 10 rows = 300 terminal strip holes, plus 30*4 rail holes = 420 total minimum
    // We assert a conservative 300
    expect(circleCount).toBeGreaterThanOrEqual(300)
  })
})

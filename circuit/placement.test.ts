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

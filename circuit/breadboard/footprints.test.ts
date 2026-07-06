// circuit/breadboard/footprints.test.ts
import { expect, test } from "bun:test"
import { FOOTPRINTS } from "./footprints"
import { RAIL_NETS } from "./config"

test("FOOTPRINTS が smtlk 全12部品を網羅", () => {
  const refs = ["U1","M1","Q1","Rg","Rgs","Rled","Rled2","D1","SW1","C1","C2","D2"]
  for (const r of refs) expect(FOOTPRINTS[r], `missing footprint ${r}`).toBeDefined()
})

test("各フットプリントの pinOrder が非空・重複なし", () => {
  for (const [ref, fp] of Object.entries(FOOTPRINTS)) {
    expect(fp.pinOrder.length, `${ref} empty pinOrder`).toBeGreaterThan(0)
    expect(new Set(fp.pinOrder).size, `${ref} dup pins`).toBe(fp.pinOrder.length)
  }
})

test("RAIL_NETS は V5→TP, GND→TN", () => {
  expect(RAIL_NETS).toEqual({ V5: "TP", GND: "TN" })
})

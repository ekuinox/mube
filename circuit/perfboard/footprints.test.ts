// circuit/perfboard/footprints.test.ts
import { expect, test } from "bun:test"
import { FOOTPRINTS } from "./footprints"

const NON_PICO = ["M1", "Q1", "Rg", "Rgs", "Rled", "Rled2", "D1", "SW1", "C1", "C2", "D2"]

test("U1 以外の 11 部品を網羅、U1 は含まない", () => {
  for (const r of NON_PICO) expect(FOOTPRINTS[r], `missing ${r}`).toBeDefined()
  expect(FOOTPRINTS["U1"]).toBeUndefined()
})

test("各フットプリントは pin1(=先頭)が原点[0,0]、ピン名は非重複", () => {
  for (const [ref, fp] of Object.entries(FOOTPRINTS)) {
    expect(fp.pins.length, `${ref} empty`).toBeGreaterThan(0)
    expect(fp.pins[0].off, `${ref} anchor`).toEqual([0, 0])
    const names = fp.pins.map((p) => p.name)
    expect(new Set(names).size, `${ref} dup pins`).toBe(names.length)
  }
})

test("極性/カソード帯メタは実在ピンを指す", () => {
  expect(FOOTPRINTS.C1.polarityPin).toBe("pin1")
  expect(FOOTPRINTS.D2.stripePin).toBe("cathode")
  expect(FOOTPRINTS.D2.pins.map((p) => p.name)).toContain("cathode")
})

test("parts.ts のピン名と一致（M1/Q1/D1/D2）", () => {
  expect(FOOTPRINTS.M1.pins.map((p) => p.name)).toEqual(["SIG", "VPLUS", "GND"])
  expect(FOOTPRINTS.Q1.pins.map((p) => p.name)).toEqual(["G", "D", "S"])
  expect(FOOTPRINTS.D1.pins.map((p) => p.name)).toEqual(["R", "G", "K"])
  expect(FOOTPRINTS.D2.pins.map((p) => p.name)).toEqual(["cathode", "anode"])
})

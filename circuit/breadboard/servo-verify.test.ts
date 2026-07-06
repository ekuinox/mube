// circuit/breadboard/servo-verify.test.ts
// TDD: Tests for breadboard connectivity model + servo-drive layout correctness.
// Write assertions FIRST, then author servo-layout.ts to make them pass.

import { expect, test } from "bun:test"
import { SERVO_NETS } from "./servo-nets"
import { nodeOf, buildConnectivity } from "./model"
import { PIN_HOLES, JUMPERS } from "./servo-layout"

// --- Expected servo-drive nets (source of truth snapshot) ---
// These MUST match exactly what servo-nets.ts derives from parts.ts.
// If parts.ts changes and this assertion fails, update intentionally.
const EXPECTED_SERVO_NETS: Record<string, string[]> = {
  V5: ["C1.pin1", "C2.pin1", "D2.cathode", "M1.VPLUS", "U1.VBUS"],
  GND: ["C1.pin2", "C2.pin2", "Q1.S", "Rgs.pin2", "U1.GND"],
  SERVO_RTN: ["D2.anode", "M1.GND", "Q1.D"],
  SERVO_SIG: ["M1.SIG", "U1.GP15"],
  GATE_DRV: ["Rg.pin1", "U1.GP14"],
  GATE: ["Q1.G", "Rg.pin2", "Rgs.pin1"],
}

// All servo-drive pins (every endpoint across all 6 nets)
const ALL_SERVO_PINS = Object.values(EXPECTED_SERVO_NETS).flat()

// Test 1: servo-nets.ts derives exactly the 6 expected nets from parts.ts
test("servo-nets derives exactly the 6 expected nets", () => {
  expect(Object.keys(SERVO_NETS).sort()).toEqual(Object.keys(EXPECTED_SERVO_NETS).sort())
  for (const [name, pins] of Object.entries(EXPECTED_SERVO_NETS)) {
    expect(SERVO_NETS[name]).toEqual(pins)
  }
})

// Test 2: every servo-drive pin has a hole in PIN_HOLES (no missing, no extras)
test("every servo-drive pin has a hole in PIN_HOLES", () => {
  const missingPins = ALL_SERVO_PINS.filter((pin) => PIN_HOLES[pin] == null)
  const extraPins = Object.keys(PIN_HOLES).filter((pin) => !ALL_SERVO_PINS.includes(pin))

  expect(missingPins).toEqual([])
  expect(extraPins).toEqual([])
})

// Test 3: layout realizes each net — all pins of a net map to the same connectivity group
test("layout realizes each net (no missing connections)", () => {
  const conn = buildConnectivity(JUMPERS)

  for (const [netName, pins] of Object.entries(EXPECTED_SERVO_NETS)) {
    const groups = pins.map((pin) => {
      const hole = PIN_HOLES[pin]
      if (hole == null) throw new Error(`Missing hole for pin ${pin} in net ${netName}`)
      return conn.groupOf(nodeOf(hole))
    })
    const unique = new Set(groups)
    expect(unique.size).toBe(1)
  }
})

// Test 4: no shorts between different nets — pins from different nets never share a group
test("no shorts between nets", () => {
  const conn = buildConnectivity(JUMPERS)

  // Build map: group → [net names that touch it]
  const groupNets: Record<string, Set<string>> = {}
  for (const [netName, pins] of Object.entries(EXPECTED_SERVO_NETS)) {
    for (const pin of pins) {
      const hole = PIN_HOLES[pin]
      if (hole == null) continue
      const g = conn.groupOf(nodeOf(hole))
      if (!groupNets[g]) groupNets[g] = new Set()
      groupNets[g].add(netName)
    }
  }

  const shorts: string[] = []
  for (const [group, nets] of Object.entries(groupNets)) {
    if (nets.size > 1) {
      shorts.push(`group ${group} spans nets: ${[...nets].sort().join(", ")}`)
    }
  }
  expect(shorts).toEqual([])
})

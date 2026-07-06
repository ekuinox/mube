// circuit/breadboard/servo-nets.ts
// Derives the servo-drive sub-circuit nets from the project's parts.ts source of truth.

import { NETS } from "../parts"

// Servo-drive parts and their relevant pins (by Ref).
export const SERVO_PARTS = new Set(["U1", "M1", "Q1", "Rg", "Rgs", "C1", "C2", "D2"])

/**
 * Normalise a tscircuit trace selector endpoint to "Ref.pin" form.
 * e.g. ".U1 .VBUS" → "U1.VBUS"
 *      ".D2 .cathode" → "D2.cathode"
 */
export function normaliseEndpoint(ep: string): string {
  // Strip all leading dots and collapse spaces:
  //   ".U1 .VBUS" → "U1 VBUS" → split on spaces → ["U1", "VBUS"] → "U1.VBUS"
  const stripped = ep.replace(/\./g, " ").trim()
  const parts = stripped.split(/\s+/)
  return parts.join(".")
}

/**
 * Servo-drive nets derived from parts.ts.
 * Keys are net names, values are sorted pin lists in "Ref.pin" form.
 * Only endpoints belonging to SERVO_PARTS are kept; nets with fewer than
 * 2 such endpoints are discarded.
 */
export const SERVO_NETS: Record<string, string[]> = (() => {
  const result: Record<string, string[]> = {}
  for (const net of NETS) {
    const filtered = net.endpoints
      .map(normaliseEndpoint)
      .filter((ep) => {
        const ref = ep.split(".")[0]
        return SERVO_PARTS.has(ref)
      })
      .sort()
    if (filtered.length >= 2) {
      result[net.name] = filtered
    }
  }
  return result
})()

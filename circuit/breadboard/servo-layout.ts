// circuit/breadboard/servo-layout.ts
// Hand-authored breadboard placement for the servo-drive sub-circuit.
//
// Layout overview (COLS = 30, columns 2-29 used):
//
// Top rail TP = V5 (+5V)  — short vertical stubs from row-b up to TP
// Top rail TN = GND (0V)  — short vertical stubs from row-b down to TN
// (Lower block f-j and bottom rails BP/BN are unused in this sub-circuit)
//
// Signal flow left → right:
//
//   U1 (Pico W)  →  Rg (220Ω)  →  Q1 (MOSFET)  →  D2 (Flyback)  →  M1 (Servo)
//   cols 2-5        cols 15,17      cols 17-20       cols 24-25       cols 27-29
//
// Column assignments:
//   2  : U1.VBUS   (upper row a)         — net V5      → stub to TP
//   3  : U1.GND    (upper row a)         — net GND     → stub to TN
//   4  : U1.GP15   (upper row a)         — net SERVO_SIG
//   5  : U1.GP14   (upper row a)         — net GATE_DRV
//   (cols 6-7: gap)
//   8  : C1.pin1   (upper row a)         — net V5      → stub to TP
//   9  : C1.pin2   (upper row a)         — net GND     → stub to TN
//   (col 10: gap)
//   11 : C2.pin1   (upper row a)         — net V5      → stub to TP
//   12 : C2.pin2   (upper row a)         — net GND     → stub to TN
//   (cols 13-14: gap)
//   15 : Rg.pin1   (upper row a)         — net GATE_DRV ← jumper from U1.GP14 (col5)
//   (col 16: gap)
//   17 : Rg.pin2   (upper row a)         — net GATE  ─┐ (col-tie: all U17)
//   17 : Q1.G      (upper row b)         — net GATE   │
//   17 : Rgs.pin1  (upper row c)         — net GATE  ─┘
//   (col 18: gap)
//   19 : Q1.D      (upper row a)         — net SERVO_RTN
//   20 : Q1.S      (upper row a)         — net GND     → stub to TN
//   (cols 21-22: gap)
//   22 : Rgs.pin2  (upper row a)         — net GND     → stub to TN
//   (col 23: gap)
//   24 : D2.anode  (upper row a)         — net SERVO_RTN ← jumper from Q1.D (col19)
//   25 : D2.cathode (upper row a)        — net V5      → stub to TP
//   (col 26: gap)
//   27 : M1.SIG    (upper row a)         — net SERVO_SIG ← jumper from U1.GP15 (col4)
//   28 : M1.VPLUS  (upper row a)         — net V5      → stub to TP
//   29 : M1.GND    (upper row a)         — net SERVO_RTN ← jumper chain Q1.D→D2.anode→M1.GND
//
// Jumpers — each long horizontal jumper uses its own row "lane" to avoid overlap:
//   V5  stubs:       col2→TP, col8→TP, col11→TP, col25→TP, col28→TP    (row-b → TP)
//   GND stubs:       col3→TN, col9→TN, col12→TN, col20→TN, col22→TN    (row-b → TN)
//   GATE_DRV:        col5(U1.GP14) ↔ col15(Rg.pin1)                     (row-c horizontal lane)
//   GATE:            no jumper needed — col17 rows a/b/c all share node U17
//   SERVO_RTN:       col19(Q1.D) ↔ col24(D2.anode), col24 ↔ col29(M1.GND)  (row-d lane)
//   SERVO_SIG:       col4(U1.GP15) ↔ col27(M1.SIG)                       (row-e horizontal lane, longest)
//
// Lane assignment (rows b-e used as horizontal wiring lanes):
//   row b — V5/GND short stubs only (nearly vertical, no horizontal run)
//   row c — GATE_DRV lane  (col5 → col15, medium length)
//   row d — SERVO_RTN lane (col19 → col24 → col29, medium)
//   row e — SERVO_SIG lane (col4 → col27, longest — gets deepest lane)

import type { Hole, Jumper } from "./model"

// Helper to create strip holes concisely
const s = (col: number, row: "a"|"b"|"c"|"d"|"e"|"f"|"g"|"h"|"i"|"j"): Hole =>
  ({ kind: "strip", col, row })
const r = (rail: "TP"|"TN"|"BP"|"BN", col: number): Hole =>
  ({ kind: "rail", rail, col })

// Every servo-drive component pin → the breadboard hole it occupies.
// Keys match normalised "Ref.pin" endpoints from parts.ts.
export const PIN_HOLES: Record<string, Hole> = {
  // U1 (Pico W) — cols 2-5 upper row a
  "U1.VBUS":    s(2,  "a"),   // V5
  "U1.GND":     s(3,  "a"),   // GND
  "U1.GP15":    s(4,  "a"),   // SERVO_SIG
  "U1.GP14":    s(5,  "a"),   // GATE_DRV

  // C1 (470µF bulk cap) — cols 8-9 upper row a
  "C1.pin1":    s(8,  "a"),   // V5
  "C1.pin2":    s(9,  "a"),   // GND

  // C2 (100nF bypass cap) — cols 11-12 upper row a
  "C2.pin1":    s(11, "a"),   // V5
  "C2.pin2":    s(12, "a"),   // GND

  // Rg (220Ω gate resistor) — pin1 col15, pin2 col17 (upper row a)
  "Rg.pin1":    s(15, "a"),   // GATE_DRV
  "Rg.pin2":    s(17, "a"),   // GATE

  // Q1 (MOSFET) — G col17 row b, D col19 row a, S col20 row a
  // Q1.G shares col17 with Rg.pin2 (col17a) and Rgs.pin1 (col17c) → node U17
  "Q1.G":       s(17, "b"),   // GATE (col-tied to U17)
  "Q1.D":       s(19, "a"),   // SERVO_RTN
  "Q1.S":       s(20, "a"),   // GND

  // Rgs (10kΩ gate-source pull-down) — pin1 col17 row c, pin2 col22 row a
  // pin1 shares col17 upper block with Rg.pin2 (17a) and Q1.G (17b) → node U17
  "Rgs.pin1":   s(17, "c"),   // GATE (col-tied to U17)
  "Rgs.pin2":   s(22, "a"),   // GND

  // D2 (flyback diode) — anode col24, cathode col25 upper row a
  "D2.anode":   s(24, "a"),   // SERVO_RTN
  "D2.cathode": s(25, "a"),   // V5

  // M1 (servo motor 3-pin header) — cols 27-29 upper row a
  "M1.SIG":     s(27, "a"),   // SERVO_SIG
  "M1.VPLUS":   s(28, "a"),   // V5
  "M1.GND":     s(29, "a"),   // SERVO_RTN
}

// Jumper wires — only jumpers create electrical connectivity.
// Components are LOADS; their two pin holes are NOT automatically bridged.
export const JUMPERS: Jumper[] = [
  // --- V5 net: short stubs from component columns (row-b) up to TP rail ---
  { from: s(2,  "b"), to: r("TP", 2),  net: "V5", color: "red" },  // U1.VBUS col2→TP
  { from: s(8,  "b"), to: r("TP", 8),  net: "V5", color: "red" },  // C1.pin1  col8→TP
  { from: s(11, "b"), to: r("TP", 11), net: "V5", color: "red" },  // C2.pin1  col11→TP
  { from: s(25, "b"), to: r("TP", 25), net: "V5", color: "red" },  // D2.cathode col25→TP
  { from: s(28, "b"), to: r("TP", 28), net: "V5", color: "red" },  // M1.VPLUS col28→TP

  // --- GND net: short stubs from component columns (row-b) down to TN rail ---
  { from: s(3,  "b"), to: r("TN", 3),  net: "GND", color: "black" }, // U1.GND   col3→TN
  { from: s(9,  "b"), to: r("TN", 9),  net: "GND", color: "black" }, // C1.pin2  col9→TN
  { from: s(12, "b"), to: r("TN", 12), net: "GND", color: "black" }, // C2.pin2  col12→TN
  { from: s(20, "b"), to: r("TN", 20), net: "GND", color: "black" }, // Q1.S     col20→TN
  { from: s(22, "b"), to: r("TN", 22), net: "GND", color: "black" }, // Rgs.pin2 col22→TN

  // --- GATE_DRV net: U1.GP14 (col5) → Rg.pin1 (col15), row-c lane ---
  // row-c is electrically same node as row-a in each column (U5, U15)
  { from: s(5,  "c"), to: s(15, "c"), net: "GATE_DRV", color: "#d0d0d0" },

  // --- GATE net: Rg.pin2 (17a), Q1.G (17b), Rgs.pin1 (17c) all share col17 node U17 ---
  // No jumper needed; column tie connects rows a-e within col 17.

  // --- SERVO_RTN net: Q1.D (col19) ↔ D2.anode (col24) ↔ M1.GND (col29), row-d lane ---
  { from: s(19, "d"), to: s(24, "d"), net: "SERVO_RTN", color: "orange" }, // Q1.D ↔ D2.anode
  { from: s(24, "d"), to: s(29, "d"), net: "SERVO_RTN", color: "orange" }, // D2.anode ↔ M1.GND

  // --- SERVO_SIG net: U1.GP15 (col4) ↔ M1.SIG (col27), row-e lane (longest wire) ---
  { from: s(4,  "e"), to: s(27, "e"), net: "SERVO_SIG", color: "gold" },
]

// Component metadata (for renderer, minimal for now)
export const COMPONENTS: Record<string, { label: string; value?: string; pins: string[] }> = {
  M1:  { label: "M1",  value: "Servo",    pins: ["M1.SIG", "M1.VPLUS", "M1.GND"] },
  C1:  { label: "C1",  value: "470uF",    pins: ["C1.pin1", "C1.pin2"] },
  C2:  { label: "C2",  value: "100nF",    pins: ["C2.pin1", "C2.pin2"] },
  D2:  { label: "D2",  value: "Flyback",  pins: ["D2.cathode", "D2.anode"] },
  Rg:  { label: "Rg",  value: "220Ω",     pins: ["Rg.pin1", "Rg.pin2"] },
  Q1:  { label: "Q1",  value: "MOSFET",   pins: ["Q1.G", "Q1.D", "Q1.S"] },
  Rgs: { label: "Rgs", value: "10kΩ",     pins: ["Rgs.pin1", "Rgs.pin2"] },
  U1:  { label: "U1",  value: "Pico W",   pins: ["U1.VBUS", "U1.GND", "U1.GP15", "U1.GP14"] },
}

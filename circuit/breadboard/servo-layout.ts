// circuit/breadboard/servo-layout.ts
// Hand-authored breadboard placement for the servo-drive sub-circuit.
//
// Layout overview (COLS = 30, columns 1-22 used):
//
// Top rail TP = V5 (+5V), Top rail TN = GND (0V)
//
// Column assignments:
//   1  : M1.SIG header (upper row a)           — net SERVO_SIG
//   2  : M1.VPLUS header (upper row a)         — net V5
//   3  : M1.GND header (upper row a)           — net SERVO_RTN
//   (col 4: gap/spare)
//   5  : C1.pin1 (upper row a)                 — net V5
//   6  : C1.pin2 (upper row a)                 — net GND
//   7  : C2.pin1 (upper row a)                 — net V5
//   8  : C2.pin2 (upper row a)                 — net GND
//   9  : D2.cathode (upper row a)              — net V5
//   10 : D2.anode (upper row a)                — net SERVO_RTN
//   11 : Rg.pin2, Q1.G, Rgs.pin1 (rows a,b,c) — net GATE (column-tie)
//   12 : Rg.pin1 (upper row a)                 — net GATE_DRV
//   13 : Q1.D (upper row a)                    — net SERVO_RTN
//   14 : Q1.S (upper row a)                    — net GND
//   15 : Rgs.pin2 (upper row a)                — net GND
//   16 : U1.VBUS (upper row a)                 — net V5
//   17 : U1.GND (upper row a)                  — net GND
//   18 : U1.GP15 (upper row a)                 — net SERVO_SIG
//   19 : U1.GP14 (upper row a)                 — net GATE_DRV
//
// Jumpers:
//   V5 rail:      U2→TP, U5→TP, U7→TP, U9→TP, U16→TP
//   GND rail:     U6→TN, U8→TN, U14→TN, U15→TN, U17→TN
//   SERVO_RTN:    U3↔U10 (M1.GND ↔ D2.anode), U10↔U13 (D2.anode ↔ Q1.D)
//   SERVO_SIG:    U1↔U18 (M1.SIG ↔ U1.GP15)
//   GATE_DRV:     U12↔U19 (Rg.pin1 ↔ U1.GP14)
//   GATE:         no jumper needed — Rg.pin2, Q1.G, Rgs.pin1 all in col 11 upper

import type { Hole, Jumper } from "./model"

// Helper to create strip holes concisely
const s = (col: number, row: "a"|"b"|"c"|"d"|"e"|"f"|"g"|"h"|"i"|"j"): Hole =>
  ({ kind: "strip", col, row })
const r = (rail: "TP"|"TN"|"BP"|"BN", col: number): Hole =>
  ({ kind: "rail", rail, col })

// Every servo-drive component pin → the breadboard hole it occupies.
// Keys match normalised "Ref.pin" endpoints from parts.ts.
export const PIN_HOLES: Record<string, Hole> = {
  // M1 (servo motor header) — col 1,2,3 upper row a
  "M1.SIG":    s(1, "a"),
  "M1.VPLUS":  s(2, "a"),
  "M1.GND":    s(3, "a"),

  // C1 (470uF bulk cap) — col 5,6 upper row a
  "C1.pin1":   s(5, "a"),
  "C1.pin2":   s(6, "a"),

  // C2 (100nF bypass cap) — col 7,8 upper row a
  "C2.pin1":   s(7, "a"),
  "C2.pin2":   s(8, "a"),

  // D2 (flyback diode) — col 9 cathode, col 10 anode
  "D2.cathode": s(9, "a"),
  "D2.anode":   s(10, "a"),

  // Rg (220Ω gate resistor) — pin1 at col12, pin2 at col11
  // pin2 shares col11 upper with Q1.G and Rgs.pin1 → GATE node
  "Rg.pin1":   s(12, "a"),
  "Rg.pin2":   s(11, "a"),

  // Q1 (MOSFET) — G=col11 row b, D=col13, S=col14
  "Q1.G":      s(11, "b"),
  "Q1.D":      s(13, "a"),
  "Q1.S":      s(14, "a"),

  // Rgs (10kΩ gate-source pull-down) — pin1=col11 row c, pin2=col15
  "Rgs.pin1":  s(11, "c"),
  "Rgs.pin2":  s(15, "a"),

  // U1 (Pico W) — only 4 pins used in servo drive
  "U1.VBUS":   s(16, "a"),
  "U1.GND":    s(17, "a"),
  "U1.GP15":   s(18, "a"),
  "U1.GP14":   s(19, "a"),
}

// Jumper wires — only jumpers create electrical connectivity.
// Components are LOADS; their two pin holes are NOT automatically bridged.
export const JUMPERS: Jumper[] = [
  // --- V5 net: fan out +5V rail (TP) to all V5 pins ---
  { from: s(2, "b"),  to: r("TP", 2),  net: "V5",  color: "red" },   // M1.VPLUS col2→TP
  { from: s(5, "b"),  to: r("TP", 5),  net: "V5",  color: "red" },   // C1.pin1 col5→TP
  { from: s(7, "b"),  to: r("TP", 7),  net: "V5",  color: "red" },   // C2.pin1 col7→TP
  { from: s(9, "b"),  to: r("TP", 9),  net: "V5",  color: "red" },   // D2.cathode col9→TP
  { from: s(16, "b"), to: r("TP", 16), net: "V5",  color: "red" },   // U1.VBUS col16→TP

  // --- GND net: fan out GND rail (TN) to all GND pins ---
  { from: s(6, "b"),  to: r("TN", 6),  net: "GND", color: "black" }, // C1.pin2 col6→TN
  { from: s(8, "b"),  to: r("TN", 8),  net: "GND", color: "black" }, // C2.pin2 col8→TN
  { from: s(14, "b"), to: r("TN", 14), net: "GND", color: "black" }, // Q1.S col14→TN
  { from: s(15, "b"), to: r("TN", 15), net: "GND", color: "black" }, // Rgs.pin2 col15→TN
  { from: s(17, "b"), to: r("TN", 17), net: "GND", color: "black" }, // U1.GND col17→TN

  // --- SERVO_RTN net: M1.GND(col3) ↔ D2.anode(col10) ↔ Q1.D(col13) ---
  { from: s(3, "b"),  to: s(10, "b"), net: "SERVO_RTN", color: "orange" }, // M1.GND ↔ D2.anode
  { from: s(10, "b"), to: s(13, "b"), net: "SERVO_RTN", color: "orange" }, // D2.anode ↔ Q1.D

  // --- SERVO_SIG net: M1.SIG(col1) ↔ U1.GP15(col18) ---
  { from: s(1, "b"),  to: s(18, "b"), net: "SERVO_SIG", color: "yellow" },

  // --- GATE_DRV net: Rg.pin1(col12) ↔ U1.GP14(col19) ---
  { from: s(12, "b"), to: s(19, "b"), net: "GATE_DRV", color: "white" },

  // --- GATE net: Rg.pin2, Q1.G, Rgs.pin1 all at col11 rows a,b,c → same node U11 ---
  // No jumper needed: column tie connects a-e within col 11.
  // (Rg.pin2=11a, Q1.G=11b, Rgs.pin1=11c all share node U11)
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

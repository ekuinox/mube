// circuit/breadboard/render.ts
// SVG renderer for the smtlk servo-drive breadboard wiring guide.

import { COLS, type Hole, type StripRow } from "./model"
import { PIN_HOLES, JUMPERS, COMPONENTS } from "./servo-layout"

// ──────────────────────────────────────────────────────────────────────────
// Coordinate system
// ──────────────────────────────────────────────────────────────────────────
const PITCH = 14         // px between adjacent holes
const MARGIN_LEFT = 52   // room for row labels
const MARGIN_TOP  = 48   // room for column numbers
const MARGIN_RIGHT  = 20
const MARGIN_BOTTOM = 60 // room for legend

// Row layout (y indices from top to bottom):
//   0: rail TP
//   1: rail TN
//   2: (gap 6px)
//   3: row a   (upper block row 0)
//   4: row b
//   5: row c
//   6: row d
//   7: row e
//   8: (center gap 18px)
//   9: row f   (lower block row 0)
//  10: row g
//  11: row h
//  12: row i
//  13: row j
//  14: (gap 6px)
//  15: rail BP
//  16: rail BN

const ROW_GAPS: Record<number, number> = {
  2:  6,  // gap between TN and strip-a
  8: 18,  // center gap between e and f
  14:  6, // gap between strip-j and BP
}

function yForIndex(idx: number): number {
  let y = MARGIN_TOP
  for (let i = 0; i < idx; i++) {
    y += PITCH + (ROW_GAPS[i + 1] ?? 0)
  }
  return y
}

const ROW_ORDER: Array<{ kind: "rail"; rail: string } | { kind: "strip"; row: StripRow }> = [
  { kind: "rail",  rail: "TP" },
  { kind: "rail",  rail: "TN" },
  { kind: "strip", row: "a" },
  { kind: "strip", row: "b" },
  { kind: "strip", row: "c" },
  { kind: "strip", row: "d" },
  { kind: "strip", row: "e" },
  { kind: "strip", row: "f" },
  { kind: "strip", row: "g" },
  { kind: "strip", row: "h" },
  { kind: "strip", row: "i" },
  { kind: "strip", row: "j" },
  { kind: "rail",  rail: "BP" },
  { kind: "rail",  rail: "BN" },
]

// Pre-compute y for each row entry
const ROW_Y: number[] = []
for (let i = 0; i < ROW_ORDER.length; i++) {
  // extra gap in specific positions
  let y = MARGIN_TOP
  for (let j = 0; j < i; j++) {
    y += PITCH
    const nextEntry = ROW_ORDER[j + 1]
    if (nextEntry) {
      // extra gap before upper strip block
      if (nextEntry.kind === "strip" && nextEntry.row === "a" &&
          ROW_ORDER[j].kind === "rail") {
        y += 6
      }
      // center gap between e and f
      if (nextEntry.kind === "strip" && nextEntry.row === "f" &&
          ROW_ORDER[j].kind === "strip" && ROW_ORDER[j].row === "e") {
        y += 18
      }
      // gap before lower rail
      if (nextEntry.kind === "rail" && nextEntry.rail === "BP" &&
          ROW_ORDER[j].kind === "strip" && ROW_ORDER[j].row === "j") {
        y += 6
      }
    }
  }
  ROW_Y.push(y)
}

function rowIndex(hole: Hole): number {
  if (hole.kind === "rail") {
    return ROW_ORDER.findIndex(r => r.kind === "rail" && r.rail === hole.rail)
  }
  return ROW_ORDER.findIndex(r => r.kind === "strip" && r.row === hole.row)
}

export function holeXY(hole: Hole): { x: number; y: number } {
  const x = MARGIN_LEFT + (hole.col - 1) * PITCH
  const idx = rowIndex(hole)
  const y = ROW_Y[idx]
  return { x, y }
}

// ──────────────────────────────────────────────────────────────────────────
// SVG primitive helpers
// ──────────────────────────────────────────────────────────────────────────
function attrs(obj: Record<string, string | number | undefined>): string {
  return Object.entries(obj)
    .filter(([, v]) => v !== undefined)
    .map(([k, v]) => `${k}="${v}"`)
    .join(" ")
}

function circle(cx: number, cy: number, r: number, extra?: Record<string, string | number>): string {
  return `<circle ${attrs({ cx, cy, r, ...extra })} />`
}

function rect(x: number, y: number, width: number, height: number, extra?: Record<string, string | number | undefined>): string {
  return `<rect ${attrs({ x, y, width, height, ...extra })} />`
}

function line(x1: number, y1: number, x2: number, y2: number, extra?: Record<string, string | number>): string {
  return `<line ${attrs({ x1, y1, x2, y2, ...extra })} />`
}

function text(x: number, y: number, content: string, extra?: Record<string, string | number>): string {
  return `<text ${attrs({ x, y, ...extra })}>${escapeXml(content)}</text>`
}

function escapeXml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// ──────────────────────────────────────────────────────────────────────────
// Colors
// ──────────────────────────────────────────────────────────────────────────
const NET_COLORS: Record<string, string> = {
  V5:        "red",
  GND:       "#222",
  SERVO_RTN: "orange",
  SERVO_SIG: "gold",
  GATE_DRV:  "#e0e0e0",  // white-ish (visible on light bg)
  GATE:      "purple",
}

function netColor(net: string | undefined): string {
  if (!net) return "#888"
  return NET_COLORS[net] ?? "#888"
}

// ──────────────────────────────────────────────────────────────────────────
// Main renderer
// ──────────────────────────────────────────────────────────────────────────
export function renderBreadboardSvg(): string {
  const totalWidth  = MARGIN_LEFT + COLS * PITCH + MARGIN_RIGHT
  const totalHeight = ROW_Y[ROW_Y.length - 1] + PITCH + MARGIN_BOTTOM

  const parts: string[] = []

  // ── 1. Background ──────────────────────────────────────────────────────
  parts.push(`<rect width="${totalWidth}" height="${totalHeight}" fill="#f5f5f0" />`)

  // ── 2. Rail strips ─────────────────────────────────────────────────────
  const railDefs: { rail: "TP" | "TN" | "BP" | "BN"; fill: string; label: string }[] = [
    { rail: "TP", fill: "#ffcccc", label: "TP (+5V)" },
    { rail: "TN", fill: "#ccccff", label: "TN (GND)" },
    { rail: "BP", fill: "#ffcccc", label: "BP (+5V)" },
    { rail: "BN", fill: "#ccccff", label: "BN (GND)" },
  ]
  for (const { rail, fill } of railDefs) {
    const idx = ROW_ORDER.findIndex(r => r.kind === "rail" && r.rail === rail)
    const y = ROW_Y[idx]
    parts.push(rect(MARGIN_LEFT - 4, y - 7, COLS * PITCH + 4, 14, {
      fill,
      rx: 3,
      opacity: "0.6",
    }))
  }

  // ── 3. Column tie groups (upper a-e and lower f-j) ─────────────────────
  const upperTopIdx = ROW_ORDER.findIndex(r => r.kind === "strip" && r.row === "a")
  const upperBotIdx = ROW_ORDER.findIndex(r => r.kind === "strip" && r.row === "e")
  const lowerTopIdx = ROW_ORDER.findIndex(r => r.kind === "strip" && r.row === "f")
  const lowerBotIdx = ROW_ORDER.findIndex(r => r.kind === "strip" && r.row === "j")

  for (let col = 1; col <= COLS; col++) {
    const x = MARGIN_LEFT + (col - 1) * PITCH
    const uy1 = ROW_Y[upperTopIdx] - 6
    const uy2 = ROW_Y[upperBotIdx] + 6
    parts.push(rect(x - 5, uy1, 10, uy2 - uy1, {
      fill: col % 2 === 0 ? "#e8f0e8" : "#e0ebe0",
      rx: 3,
      opacity: "0.5",
    }))
    const ly1 = ROW_Y[lowerTopIdx] - 6
    const ly2 = ROW_Y[lowerBotIdx] + 6
    parts.push(rect(x - 5, ly1, 10, ly2 - ly1, {
      fill: col % 2 === 0 ? "#e8f0e8" : "#e0ebe0",
      rx: 3,
      opacity: "0.5",
    }))
  }

  // ── 4. Column numbers ──────────────────────────────────────────────────
  for (let col = 1; col <= COLS; col++) {
    const x = MARGIN_LEFT + (col - 1) * PITCH
    parts.push(text(x, MARGIN_TOP - 6, String(col), {
      "text-anchor": "middle",
      "font-size": "8",
      fill: "#666",
    }))
  }

  // ── 5. Row labels ──────────────────────────────────────────────────────
  for (let i = 0; i < ROW_ORDER.length; i++) {
    const entry = ROW_ORDER[i]
    const y = ROW_Y[i]
    const label = entry.kind === "rail" ? entry.rail : entry.row
    parts.push(text(MARGIN_LEFT - 10, y + 4, label, {
      "text-anchor": "end",
      "font-size": "9",
      fill: entry.kind === "rail" ? "#c44" : "#444",
      "font-weight": entry.kind === "rail" ? "bold" : "normal",
    }))
  }

  // ── 6. All holes ───────────────────────────────────────────────────────
  for (let col = 1; col <= COLS; col++) {
    // Rail holes
    for (const railEntry of ROW_ORDER.filter(r => r.kind === "rail") as Array<{ kind: "rail"; rail: string }>) {
      const h: Hole = { kind: "rail", rail: railEntry.rail as "TP" | "TN" | "BP" | "BN", col }
      const { x, y } = holeXY(h)
      const isRail = railEntry.rail === "TP" || railEntry.rail === "BP"
      parts.push(circle(x, y, 3.5, {
        fill: "#c8b88a",
        stroke: "#7a5a20",
        "stroke-width": "0.8",
      }))
    }
    // Strip holes
    for (const row of ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"] as StripRow[]) {
      const h: Hole = { kind: "strip", col, row }
      const { x, y } = holeXY(h)
      parts.push(circle(x, y, 3.5, {
        fill: "#c8b88a",
        stroke: "#7a5a20",
        "stroke-width": "0.8",
      }))
    }
  }

  // ── 7. Jumper wires ────────────────────────────────────────────────────
  for (const j of JUMPERS) {
    const { x: x1, y: y1 } = holeXY(j.from)
    const { x: x2, y: y2 } = holeXY(j.to)
    const color = j.color ?? netColor(j.net)
    // Draw wire as a curved path for visual clarity when possible
    const dx = x2 - x1
    const dy = y2 - y1
    const isStraightH = dy === 0
    if (isStraightH) {
      // horizontal — arc above
      const mx = (x1 + x2) / 2
      const arcY = Math.min(y1, y2) - Math.abs(dx) * 0.18 - 6
      parts.push(`<path d="M ${x1} ${y1} Q ${mx} ${arcY} ${x2} ${y2}" ` +
        `fill="none" stroke="${color}" stroke-width="2.2" stroke-opacity="0.85" />`)
    } else {
      parts.push(line(x1, y1, x2, y2, {
        stroke: color,
        "stroke-width": "2.2",
        "stroke-opacity": "0.85",
        "stroke-linecap": "round",
      }))
    }
  }

  // ── 8. Component bodies ────────────────────────────────────────────────
  // helper: bounding box for a set of pin keys
  function pinsBBox(pinKeys: string[]): { x1: number; y1: number; x2: number; y2: number } | null {
    const coords = pinKeys.map(k => PIN_HOLES[k]).filter(Boolean).map(holeXY)
    if (coords.length === 0) return null
    const xs = coords.map(p => p.x)
    const ys = coords.map(p => p.y)
    return {
      x1: Math.min(...xs),
      y1: Math.min(...ys),
      x2: Math.max(...xs),
      y2: Math.max(...ys),
    }
  }

  const compPad = 7

  // M1: external 3-pin header
  {
    const bb = pinsBBox(["M1.SIG", "M1.VPLUS", "M1.GND"])!
    parts.push(rect(bb.x1 - compPad, bb.y1 - compPad, bb.x2 - bb.x1 + compPad * 2, bb.y2 - bb.y1 + compPad * 2, {
      fill: "#b3d9ff",
      stroke: "#2266aa",
      "stroke-width": "1.5",
      rx: 4,
      opacity: "0.7",
    }))
    parts.push(text((bb.x1 + bb.x2) / 2, bb.y1 - compPad - 3, "M1 SG90 (external)", {
      "text-anchor": "middle",
      "font-size": "8",
      fill: "#2266aa",
      "font-weight": "bold",
    }))
    // pin labels
    for (const [key, label] of [["M1.SIG", "SIG"], ["M1.VPLUS", "VPLUS"], ["M1.GND", "GND"]] as const) {
      const { x, y } = holeXY(PIN_HOLES[key])
      parts.push(text(x, y + 14, label, { "text-anchor": "middle", "font-size": "7", fill: "#2266aa" }))
    }
  }

  // C1: electrolytic, show + on pin1
  {
    const bb = pinsBBox(["C1.pin1", "C1.pin2"])!
    parts.push(rect(bb.x1 - compPad, bb.y1 - compPad, bb.x2 - bb.x1 + compPad * 2, bb.y2 - bb.y1 + compPad * 2, {
      fill: "#d4f0d4",
      stroke: "#2a8a2a",
      "stroke-width": "1.5",
      rx: 4,
      opacity: "0.75",
    }))
    parts.push(text((bb.x1 + bb.x2) / 2, bb.y1 - compPad - 3, "C1 470µF", {
      "text-anchor": "middle",
      "font-size": "8",
      fill: "#2a8a2a",
      "font-weight": "bold",
    }))
    // + mark on pin1
    const { x: px1, y: py1 } = holeXY(PIN_HOLES["C1.pin1"])
    parts.push(text(px1, py1 - 6, "+", { "text-anchor": "middle", "font-size": "10", fill: "#c00", "font-weight": "bold" }))
  }

  // C2: ceramic
  {
    const bb = pinsBBox(["C2.pin1", "C2.pin2"])!
    parts.push(rect(bb.x1 - compPad, bb.y1 - compPad, bb.x2 - bb.x1 + compPad * 2, bb.y2 - bb.y1 + compPad * 2, {
      fill: "#fff0c0",
      stroke: "#aa7700",
      "stroke-width": "1.5",
      rx: 4,
      opacity: "0.75",
    }))
    parts.push(text((bb.x1 + bb.x2) / 2, bb.y1 - compPad - 3, "C2 100nF", {
      "text-anchor": "middle",
      "font-size": "8",
      fill: "#aa7700",
      "font-weight": "bold",
    }))
  }

  // D2: diode, stripe on cathode end
  {
    const bb = pinsBBox(["D2.cathode", "D2.anode"])!
    parts.push(rect(bb.x1 - compPad, bb.y1 - compPad, bb.x2 - bb.x1 + compPad * 2, bb.y2 - bb.y1 + compPad * 2, {
      fill: "#ffd0d0",
      stroke: "#cc2222",
      "stroke-width": "1.5",
      rx: 4,
      opacity: "0.75",
    }))
    parts.push(text((bb.x1 + bb.x2) / 2, bb.y1 - compPad - 3, "D2 Flyback", {
      "text-anchor": "middle",
      "font-size": "8",
      fill: "#cc2222",
      "font-weight": "bold",
    }))
    // Stripe on cathode
    const { x: cx, y: cy } = holeXY(PIN_HOLES["D2.cathode"])
    parts.push(line(cx, cy - compPad + 1, cx, cy + compPad - 1, {
      stroke: "#aa0000",
      "stroke-width": "2.5",
    }))
    parts.push(text(cx, cy - compPad - 4, "▐ (cathode)", {
      "text-anchor": "middle",
      "font-size": "7",
      fill: "#aa0000",
    }))
  }

  // Rg: axial resistor
  {
    const bb = pinsBBox(["Rg.pin1", "Rg.pin2"])!
    parts.push(rect(bb.x1 - compPad, bb.y1 - compPad, bb.x2 - bb.x1 + compPad * 2, bb.y2 - bb.y1 + compPad * 2, {
      fill: "#ffe0a0",
      stroke: "#886600",
      "stroke-width": "1.5",
      rx: 4,
      opacity: "0.75",
    }))
    parts.push(text((bb.x1 + bb.x2) / 2, bb.y1 - compPad - 3, "Rg 220Ω", {
      "text-anchor": "middle",
      "font-size": "8",
      fill: "#886600",
      "font-weight": "bold",
    }))
  }

  // Q1: TO-92/220 MOSFET, G/D/S labels
  {
    const bb = pinsBBox(["Q1.G", "Q1.D", "Q1.S"])!
    parts.push(rect(bb.x1 - compPad, bb.y1 - compPad, bb.x2 - bb.x1 + compPad * 2, bb.y2 - bb.y1 + compPad * 2, {
      fill: "#e0d0ff",
      stroke: "#6633cc",
      "stroke-width": "1.5",
      rx: 4,
      opacity: "0.75",
    }))
    parts.push(text((bb.x1 + bb.x2) / 2, bb.y1 - compPad - 3, "Q1 MOSFET (low-side)", {
      "text-anchor": "middle",
      "font-size": "8",
      fill: "#6633cc",
      "font-weight": "bold",
    }))
    for (const [key, label] of [["Q1.G", "G"], ["Q1.D", "D"], ["Q1.S", "S"]] as const) {
      const { x, y } = holeXY(PIN_HOLES[key])
      parts.push(text(x, y + 14, label, { "text-anchor": "middle", "font-size": "7", fill: "#6633cc" }))
    }
  }

  // Rgs: axial resistor (pin1 at col11c, pin2 at col15a — spans rows)
  {
    const bb = pinsBBox(["Rgs.pin1", "Rgs.pin2"])!
    parts.push(rect(bb.x1 - compPad, bb.y1 - compPad, bb.x2 - bb.x1 + compPad * 2, bb.y2 - bb.y1 + compPad * 2, {
      fill: "#ffe0a0",
      stroke: "#886600",
      "stroke-width": "1.5",
      rx: 4,
      opacity: "0.75",
    }))
    parts.push(text((bb.x1 + bb.x2) / 2, bb.y1 - compPad - 3, "Rgs 10kΩ", {
      "text-anchor": "middle",
      "font-size": "8",
      fill: "#886600",
      "font-weight": "bold",
    }))
  }

  // U1: Pico W block spanning columns 16-19, single row a
  {
    const bb = pinsBBox(["U1.VBUS", "U1.GND", "U1.GP15", "U1.GP14"])!
    parts.push(rect(bb.x1 - compPad, bb.y1 - compPad, bb.x2 - bb.x1 + compPad * 2, bb.y2 - bb.y1 + compPad * 2, {
      fill: "#cce0ff",
      stroke: "#1144aa",
      "stroke-width": "1.5",
      rx: 4,
      opacity: "0.75",
    }))
    parts.push(text((bb.x1 + bb.x2) / 2, bb.y1 - compPad - 3, "U1 Pico W", {
      "text-anchor": "middle",
      "font-size": "8",
      fill: "#1144aa",
      "font-weight": "bold",
    }))
    for (const [key, label] of [
      ["U1.VBUS", "VBUS"], ["U1.GND", "GND"],
      ["U1.GP15", "GP15"], ["U1.GP14", "GP14"],
    ] as const) {
      const { x, y } = holeXY(PIN_HOLES[key])
      parts.push(text(x, y + 14, label, { "text-anchor": "middle", "font-size": "7", fill: "#1144aa" }))
    }
  }

  // ── 9. Pin marker circles (on top of holes) ────────────────────────────
  for (const [_key, hole] of Object.entries(PIN_HOLES)) {
    const { x, y } = holeXY(hole)
    parts.push(circle(x, y, 3, {
      fill: "none",
      stroke: "#444",
      "stroke-width": "1.2",
    }))
  }

  // ── 10. Legend ─────────────────────────────────────────────────────────
  const legendX = MARGIN_LEFT
  const legendY = ROW_Y[ROW_Y.length - 1] + PITCH + 8
  parts.push(rect(legendX - 4, legendY - 4, totalWidth - legendX - MARGIN_RIGHT + 4, MARGIN_BOTTOM - 10, {
    fill: "#fffff8",
    stroke: "#aaa",
    "stroke-width": "1",
    rx: 4,
  }))
  parts.push(text(legendX + 2, legendY + 9, "Net colors:", {
    "font-size": "8",
    fill: "#333",
    "font-weight": "bold",
  }))

  const netEntries = Object.entries(NET_COLORS)
  netEntries.forEach(([net, color], idx) => {
    const lx = legendX + 2 + idx * 86
    const ly = legendY + 20
    parts.push(rect(lx, ly, 14, 6, { fill: color, rx: 2 }))
    parts.push(text(lx + 17, ly + 6, net, { "font-size": "8", fill: "#333" }))
  })

  // Notes box
  const notesY = legendY + 33
  const notes = [
    "D2 cathode(stripe)=+5V側",
    "C1 +極性 (pin1=+)",
    "Q1 ローサイド(GND側)",
    "サーボ失速~1A→太め短めジャンパ推奨",
  ]
  notes.forEach((note, idx) => {
    parts.push(text(legendX + 2 + idx * 148, notesY, "■ " + note, {
      "font-size": "7.5",
      fill: "#555",
    }))
  })

  const svg = [
    `<svg xmlns="http://www.w3.org/2000/svg" width="${totalWidth}" height="${totalHeight}"`,
    `     viewBox="0 0 ${totalWidth} ${totalHeight}"`,
    `     font-family="monospace">`,
    ...parts,
    `</svg>`,
  ].join("\n")

  return svg
}

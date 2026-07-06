// circuit/breadboard/render.ts
// SVG renderer for breadboard wiring guides.

import { type Hole, type StripRow } from "./model"
import type { BreadboardLayout } from "./layout-types"

// ──────────────────────────────────────────────────────────────────────────
// Coordinate system
// ──────────────────────────────────────────────────────────────────────────
const PITCH = 14         // px between adjacent holes
const MARGIN_LEFT = 52   // room for row labels
const MARGIN_TOP  = 60   // room for column numbers + staggered component labels
const MARGIN_RIGHT  = 56  // 右端のレールラベル "TP (+5V)" 等がはみ出さない幅
const MARGIN_BOTTOM = 70 // room for legend + notes

// Row layout (y indices from top to bottom):
//   0: rail TP
//   1: rail TN
//   gap 6px
//   2: row a   (upper block row 0)
//   3: row b
//   4: row c
//   5: row d
//   6: row e
//   center gap 18px
//   7: row f   (lower block row 0)
//   8: row g
//   9: row h
//  10: row i
//  11: row j
//   gap 6px
//  12: rail BP
//  13: rail BN

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
          ROW_ORDER[j].kind === "strip" && (ROW_ORDER[j] as { row: StripRow }).row === "e") {
        y += 18
      }
      // gap before lower rail
      if (nextEntry.kind === "rail" && (nextEntry as { rail: string }).rail === "BP" &&
          ROW_ORDER[j].kind === "strip" && (ROW_ORDER[j] as { row: StripRow }).row === "j") {
        y += 6
      }
    }
  }
  ROW_Y.push(y)
}

function rowIndex(hole: Hole): number {
  if (hole.kind === "rail") {
    return ROW_ORDER.findIndex(r => r.kind === "rail" && (r as { rail: string }).rail === hole.rail)
  }
  return ROW_ORDER.findIndex(r => r.kind === "strip" && (r as { row: StripRow }).row === hole.row)
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
  GATE_DRV:  "#c0c0c0",  // silver-ish (visible on light bg)
  GATE:      "purple",
}

function netColor(net: string | undefined): string {
  if (!net) return "#888"
  return NET_COLORS[net] ?? "#888"
}

// ──────────────────────────────────────────────────────────────────────────
// Main renderer
// ──────────────────────────────────────────────────────────────────────────
export function renderBreadboardSvg(layout: BreadboardLayout): string {
  const { pinHoles: PIN_HOLES, jumpers: JUMPERS, components: COMPONENTS, notes } = layout

  // Dynamic column count: at least 30, but expand to fit all placed holes
  const maxCol = Math.max(
    30,
    ...Object.values(PIN_HOLES).map((h) => h.col),
    ...JUMPERS.flatMap((j) => [j.from, j.to].map((h) => h.col)),
  )

  const totalWidth  = MARGIN_LEFT + maxCol * PITCH + MARGIN_RIGHT
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
  for (const { rail, fill, label } of railDefs) {
    const idx = ROW_ORDER.findIndex(r => r.kind === "rail" && (r as { rail: string }).rail === rail)
    const y = ROW_Y[idx]
    parts.push(rect(MARGIN_LEFT - 4, y - 7, maxCol * PITCH + 4, 14, {
      fill,
      rx: 3,
      opacity: "0.6",
    }))
    // Rail label on the right edge
    parts.push(text(MARGIN_LEFT + maxCol * PITCH + 6, y + 4, label, {
      "font-size": "8",
      fill: rail === "TP" || rail === "BP" ? "#c00" : "#338",
      "font-weight": "bold",
    }))
  }

  // ── 3. Column tie groups (upper a-e and lower f-j) ─────────────────────
  const upperTopIdx = ROW_ORDER.findIndex(r => r.kind === "strip" && (r as { row: StripRow }).row === "a")
  const upperBotIdx = ROW_ORDER.findIndex(r => r.kind === "strip" && (r as { row: StripRow }).row === "e")
  const lowerTopIdx = ROW_ORDER.findIndex(r => r.kind === "strip" && (r as { row: StripRow }).row === "f")
  const lowerBotIdx = ROW_ORDER.findIndex(r => r.kind === "strip" && (r as { row: StripRow }).row === "j")

  for (let col = 1; col <= maxCol; col++) {
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
  for (let col = 1; col <= maxCol; col++) {
    const x = MARGIN_LEFT + (col - 1) * PITCH
    parts.push(text(x, MARGIN_TOP - 20, String(col), {
      "text-anchor": "middle",
      "font-size": "8",
      fill: "#666",
    }))
  }

  // ── 5. Row labels ──────────────────────────────────────────────────────
  for (let i = 0; i < ROW_ORDER.length; i++) {
    const entry = ROW_ORDER[i]
    const y = ROW_Y[i]
    const label = entry.kind === "rail" ? (entry as { rail: string }).rail : (entry as { row: StripRow }).row
    parts.push(text(MARGIN_LEFT - 10, y + 4, label, {
      "text-anchor": "end",
      "font-size": "9",
      fill: entry.kind === "rail" ? "#c44" : "#444",
      "font-weight": entry.kind === "rail" ? "bold" : "normal",
    }))
  }

  // ── 6. All holes ───────────────────────────────────────────────────────
  for (let col = 1; col <= maxCol; col++) {
    // Rail holes
    for (const railEntry of ROW_ORDER.filter(r => r.kind === "rail") as Array<{ kind: "rail"; rail: string }>) {
      const h: Hole = { kind: "rail", rail: railEntry.rail as "TP" | "TN" | "BP" | "BN", col }
      const { x, y } = holeXY(h)
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
  // Each long horizontal jumper now lives in its own row lane (c/d/e) so
  // wires sit at distinct y-coordinates and no arcing or staggering is needed.
  // Short V5/GND stubs (row-b → rail) remain nearly vertical and use straight lines.

  for (const j of JUMPERS) {
    const { x: x1, y: y1 } = holeXY(j.from)
    const { x: x2, y: y2 } = holeXY(j.to)
    const color = j.color ?? netColor(j.net)
    const dx = x2 - x1
    const dy = y2 - y1

    if (dy === 0 && dx !== 0) {
      // Horizontal wire on the same row — straight line along the lane row
      parts.push(line(x1, y1, x2, y2, {
        stroke: color,
        "stroke-width": "2.5",
        "stroke-opacity": "0.88",
        "stroke-linecap": "round",
      }))
    } else if (dx === 0 || Math.abs(dy) > Math.abs(dx)) {
      // Vertical or steep wire — straight line (rail stubs)
      parts.push(line(x1, y1, x2, y2, {
        stroke: color,
        "stroke-width": "2.5",
        "stroke-opacity": "0.88",
        "stroke-linecap": "round",
      }))
    } else {
      // Diagonal or angled — S-curve
      const mx = (x1 + x2) / 2
      parts.push(
        `<path d="M ${x1} ${y1} C ${mx} ${y1} ${mx} ${y2} ${x2} ${y2}" ` +
        `fill="none" stroke="${color}" stroke-width="2.5" stroke-opacity="0.88" />`
      )
    }

    // Draw dot at each end of the wire
    parts.push(circle(x1, y1, 2.5, { fill: color, opacity: "0.8" }))
    parts.push(circle(x2, y2, 2.5, { fill: color, opacity: "0.8" }))
  }

  // ── 8. Component bodies + staggered labels ─────────────────────────────
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

  // Component color table by type hint in label
  const COMP_COLORS: Array<{ test: (label: string) => boolean; fill: string; stroke: string }> = [
    { test: (l) => l.startsWith("U"),  fill: "#cce0ff", stroke: "#1144aa" },
    { test: (l) => l.startsWith("C"),  fill: "#d4f0d4", stroke: "#2a8a2a" },
    { test: (l) => l.startsWith("R"),  fill: "#ffe0a0", stroke: "#886600" },
    { test: (l) => l.startsWith("Q"),  fill: "#e0d0ff", stroke: "#6633cc" },
    { test: (l) => l.startsWith("D"),  fill: "#ffd0d0", stroke: "#cc2222" },
    { test: (l) => l.startsWith("M") || l.startsWith("SW"), fill: "#b3d9ff", stroke: "#2266aa" },
  ]
  function compColor(ref: string): { fill: string; stroke: string } {
    for (const c of COMP_COLORS) {
      if (c.test(ref)) return c
    }
    return { fill: "#e8e8e8", stroke: "#555" }
  }

  // Label stagger: alternate components get labels at different heights
  const STAGGER_STEP = 12
  let staggerIdx = 0

  // 空間的に隣り合うラベルが交互の高さになるよう、部品を x 中心でソートしてからスタガーする
  const sortedComps = Object.entries(COMPONENTS)
    .map(([ref, meta]) => ({ ref, meta, bb: pinsBBox(meta.pins) }))
    .sort((a, b) => (a.bb ? a.bb.x1 + a.bb.x2 : 0) - (b.bb ? b.bb.x1 + b.bb.x2 : 0))
  for (const { ref, meta, bb } of sortedComps) {
    if (!bb) continue
    const { fill, stroke } = compColor(ref)
    parts.push(rect(bb.x1 - compPad, bb.y1 - compPad, bb.x2 - bb.x1 + compPad * 2, bb.y2 - bb.y1 + compPad * 2, {
      fill,
      stroke,
      "stroke-width": "1.5",
      rx: 4,
      opacity: "0.75",
    }))
    const lOff = (staggerIdx % 2) * STAGGER_STEP
    staggerIdx++
    const labelStr = meta.value ? `${ref} ${meta.value}` : (meta.label ?? ref)
    parts.push(text((bb.x1 + bb.x2) / 2, bb.y1 - compPad - 3 - lOff, labelStr, {
      "text-anchor": "middle",
      "font-size": "8",
      fill: stroke,
      "font-weight": "bold",
    }))

    // Pin sub-labels (show all pins with their last segment as label)
    for (const pinKey of meta.pins) {
      const h = PIN_HOLES[pinKey]
      if (!h) continue
      const { x, y } = holeXY(h)
      const pinLabel = pinKey.split(".").slice(1).join(".")
      parts.push(text(x, y + 14, pinLabel, { "text-anchor": "middle", "font-size": "7", fill: stroke }))
    }
  }

  // ── 9. Polarity (+) markers — data-driven from COMPONENTS.polarityPin ──
  for (const c of Object.values(COMPONENTS)) {
    if (!c.polarityPin) continue
    const h = PIN_HOLES[c.polarityPin]; if (!h) continue
    const { x, y } = holeXY(h)
    parts.push(text(x, y - 6, "+", { "font-size": 9, "text-anchor": "middle", fill: "#c00" }))
  }

  // ── 10. Cathode stripe — data-driven from COMPONENTS.stripePin ─────────
  for (const c of Object.values(COMPONENTS)) {
    if (!c.stripePin) continue
    const h = PIN_HOLES[c.stripePin]; if (!h) continue
    const { x, y } = holeXY(h)
    parts.push(`<rect x="${x - 5}" y="${y - 5}" width="2" height="10" fill="#333"/>`)
  }

  // ── 11. Pin marker circles (on top of holes) ───────────────────────────
  for (const [_key, hole] of Object.entries(PIN_HOLES)) {
    const { x, y } = holeXY(hole)
    parts.push(circle(x, y, 3, {
      fill: "none",
      stroke: "#444",
      "stroke-width": "1.2",
    }))
  }

  // ── 12. Legend ─────────────────────────────────────────────────────────
  const legendX = MARGIN_LEFT
  const legendY = ROW_Y[ROW_Y.length - 1] + PITCH + 8
  const legendH = MARGIN_BOTTOM - 10
  parts.push(rect(legendX - 4, legendY - 4, totalWidth - legendX - MARGIN_RIGHT + 4, legendH, {
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

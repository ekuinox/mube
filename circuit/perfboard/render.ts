// circuit/perfboard/render.ts
// 配置データを SVG と結線表に落とす。方位の凡例は scripts/axes.ts の対応表から描く。

import { axisWithLabel, VIEWPOINT } from "../../scripts/axes"
import { COLS, PITCH, ROWS, holeId, parseHole } from "./board"
import type { Layout } from "./verify"

const MARGIN = 24
const SCALE = 6 // mm あたりの px

const NET_COLORS: Record<string, string> = {
  V5: "#e6194B",
  GND: "#222222",
  SERVO_RTN: "#9A6324",
  SERVO_SIG: "#4363d8",
  GATE_DRV: "#f58231",
  GATE: "#f58231",
  LED_DRV_R: "#e6194B",
  LED_A_R: "#e6194B",
  LED_DRV_G: "#3cb44b",
  LED_A_G: "#3cb44b",
  BTN: "#911eb4",
}

// 列 1 は +X（右）端なので、画面上は右へ行くほど列番号が小さい。
// 行 1（A）は −Y（下）端なので、画面上は下へ行くほど行番号が小さい。
function xy(id: string): { x: number; y: number } {
  const h = parseHole(id)
  return {
    x: MARGIN + (COLS - h.col) * PITCH * SCALE,
    y: MARGIN + (ROWS - h.row) * PITCH * SCALE,
  }
}

export function renderSvg(layout: Layout): string {
  const w = MARGIN * 2 + (COLS - 1) * PITCH * SCALE
  const h = MARGIN * 2 + (ROWS - 1) * PITCH * SCALE + 40 // 凡例のぶん
  const out: string[] = []
  out.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">`)
  out.push(`<rect width="${w}" height="${h}" fill="#f7f3e8"/>`)

  for (let col = 1; col <= COLS; col++)
    for (let row = 1; row <= ROWS; row++) {
      const p = xy(holeId({ col, row }))
      out.push(`<circle class="hole" cx="${p.x}" cy="${p.y}" r="2.2" fill="#fff" stroke="#c9b98f"/>`)
    }

  for (const [leg, hole] of Object.entries(layout.legs)) {
    const p = xy(hole)
    out.push(`<circle class="leg" cx="${p.x}" cy="${p.y}" r="3.4" fill="#8a7a4e"/>`)
    out.push(`<text class="leg-label" x="${p.x + 5}" y="${p.y - 4}" font-size="7">${leg}</text>`)
  }

  for (const wire of layout.wires) {
    const a = xy(wire.from)
    const b = xy(wire.to)
    const dash = wire.side === "solder" ? ` stroke-dasharray="4 3"` : ""
    const color = NET_COLORS[wire.net] ?? "#666"
    out.push(`<line class="wire" x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}" stroke="${color}" stroke-width="2"${dash}/>`)
  }

  // 方位の凡例。破線は裏面（はんだ面）を通る線。
  const legendY = h - 12
  out.push(`<text x="${MARGIN}" y="${legendY}" font-size="10">${VIEWPOINT}見て ${axisWithLabel("+X")} ${axisWithLabel("-X")} ${axisWithLabel("+Y")} ${axisWithLabel("-Y")} / 破線 = 裏面</text>`)
  out.push(`</svg>`)
  return out.join("\n")
}

export function renderTable(layout: Layout): string {
  const rows = layout.wires.map(
    (w) => `| ${w.from} | ${w.to} | ${w.net} | ${w.side === "solder" ? "裏" : "表"} |`)
  return [
    `<!-- circuit/perfboard-build.ts の生成物。手で編集しない。 -->`,
    ``,
    `# ユニバーサル基板の結線表`,
    ``,
    `方位は${VIEWPOINT}ドアを正面に見た向き。${axisWithLabel("+X")}が列 1、${axisWithLabel("-Y")}が行 A。`,
    `穴 ID は「行の letter + 列番号」。面の「裏」ははんだ面を通す線。`,
    ``,
    `| from | to | ネット | 面 |`,
    `| --- | --- | --- | --- |`,
    ...rows,
    ``,
  ].join("\n")
}

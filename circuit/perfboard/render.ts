// circuit/perfboard/render.ts
// ユニバーサル基板 配線図の SVG。上端=文字(x:A..)/左端=数字(y:1..)で実基板と突き合わせ可能に。
import { BOARD, type XY } from "./board"
import { picoAllPinsXY, PICO_PIN_NUMBER, picoSignalXY } from "./pico"
import { FOOTPRINTS } from "./footprints"
import type { Placement } from "./place"
import type { WireSeg } from "./wire"
import { PLACEMENT } from "./layout"

const PITCH = 18
const ML = 46, MT = 40, MR = 200, MB = 96

const NET_COLOR: Record<string, string> = {
  V5: "#d81e1e", GND: "#333333", SERVO_RTN: "#8a5a00", SERVO_SIG: "#e67a00",
  GATE_DRV: "#1e7ad8", GATE: "#1e7ad8", LED_DRV_R: "#c81e7a", LED_A_R: "#c81e7a",
  LED_DRV_G: "#1ea01e", LED_A_G: "#1ea01e", BTN: "#7a1ed8",
}
const netColor = (n: string) => NET_COLOR[n] ?? "#666"

function attrs(o: Record<string, string | number | undefined>): string {
  return Object.entries(o).filter(([, v]) => v !== undefined).map(([k, v]) => `${k}="${v}"`).join(" ")
}
const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
const circle = (cx: number, cy: number, r: number, e?: Record<string, string | number>) => `<circle ${attrs({ cx, cy, r, ...e })} />`
const line = (x1: number, y1: number, x2: number, y2: number, e?: Record<string, string | number>) => `<line ${attrs({ x1, y1, x2, y2, ...e })} />`
const rect = (x: number, y: number, w: number, h: number, e?: Record<string, string | number | undefined>) => `<rect ${attrs({ x, y, width: w, height: h, ...e })} />`
const text = (x: number, y: number, s: string, e?: Record<string, string | number>) => `<text ${attrs({ x, y, ...e })}>${esc(s)}</text>`

const px = ([x, y]: XY): [number, number] => [ML + x * PITCH, MT + y * PITCH]
const colLabel = (x: number) => String.fromCharCode(65 + x)  // 0->A

export function renderPerfboardSvg(p: Placement, wires: WireSeg[]): string {
  const W = ML + (BOARD.width - 1) * PITCH + MR
  const H = MT + (BOARD.height - 1) * PITCH + MB
  const out: string[] = []
  out.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" font-family="system-ui, sans-serif">`)
  out.push(rect(0, 0, W, H, { fill: "#f5f5f0" }))

  // 盤面枠
  const [bx0, by0] = px([0, 0]); const [bx1, by1] = px([BOARD.width - 1, BOARD.height - 1])
  out.push(rect(bx0 - PITCH / 2, by0 - PITCH / 2, (BOARD.width) * PITCH, (BOARD.height) * PITCH, { fill: "#d9e6c9", stroke: "#8aa06a", rx: 6 }))

  // 目盛り（上=文字, 左=数字）
  for (let x = 0; x < BOARD.width; x++) {
    const [cx] = px([x, 0])
    out.push(text(cx, MT - 18, colLabel(x), { "text-anchor": "middle", "font-size": 11, fill: "#556" }))
  }
  for (let y = 0; y < BOARD.height; y++) {
    const [, cy] = px([0, y])
    out.push(text(ML - 26, cy + 4, String(y + 1), { "font-size": 11, fill: "#556" }))
  }

  // 穴
  for (let x = 0; x < BOARD.width; x++) for (let y = 0; y < BOARD.height; y++) {
    const [cx, cy] = px([x, y]); out.push(circle(cx, cy, 2.2, { fill: "#fff", stroke: "#b7c4a3" }))
  }

  // Pico ゴースト（2×20 の外形）と使用ピン
  const picoPts = picoAllPinsXY()
  const gx = picoPts.map((q) => px(q))
  const minx = Math.min(...gx.map((q) => q[0])), maxx = Math.max(...gx.map((q) => q[0]))
  const miny = Math.min(...gx.map((q) => q[1])), maxy = Math.max(...gx.map((q) => q[1]))
  out.push(rect(minx - PITCH / 2, miny - PITCH / 2, maxx - minx + PITCH, maxy - miny + PITCH, { fill: "#c7d3e6", "fill-opacity": 0.5, stroke: "#7a8aa0", rx: 5 }))
  out.push(text((minx + maxx) / 2, (miny + maxy) / 2, "Pico W", { "text-anchor": "middle", "font-size": 12, fill: "#456", "font-weight": 600 }))
  for (const sig of Object.keys(PICO_PIN_NUMBER)) {
    const [cx, cy] = px(picoSignalXY(sig))
    out.push(circle(cx, cy, 4, { fill: "#2b3a55" }))
    out.push(text(cx, cy - 7, sig, { "text-anchor": "middle", "font-size": 9, fill: "#2b3a55", "font-weight": 600 }))
  }

  // 配線（点対点）
  for (const s of wires) {
    const [x1, y1] = px(s.a); const [x2, y2] = px(s.b)
    out.push(line(x1, y1, x2, y2, { stroke: netColor(s.net), "stroke-width": 2.4, "stroke-opacity": 0.85, "stroke-linecap": "round" }))
  }

  // 部品（ピン穴＋外形＋ラベル＋極性/カソード帯）
  for (const [ref, pl] of Object.entries(PLACEMENT)) {
    const fp = FOOTPRINTS[ref]; if (!fp) continue
    const pts = fp.pins.map((pin) => px(p.pinXY[`${ref}.${pin.name}`]))
    const minX = Math.min(...pts.map((q) => q[0])), maxX = Math.max(...pts.map((q) => q[0]))
    const minY = Math.min(...pts.map((q) => q[1])), maxY = Math.max(...pts.map((q) => q[1]))
    out.push(rect(minX - 6, minY - 6, maxX - minX + 12, maxY - minY + 12, { fill: "#fff", "fill-opacity": 0.65, stroke: "#c08a3a", rx: 4 }))
    for (const pin of fp.pins) { const [cx, cy] = px(p.pinXY[`${ref}.${pin.name}`]); out.push(circle(cx, cy, 3.2, { fill: "#c08a3a" })) }
    out.push(text((minX + maxX) / 2, minY - 9, `${fp.label} ${fp.value ?? ""}`.trim(), { "text-anchor": "middle", "font-size": 9.5, fill: "#8a5a1a", "font-weight": 600 }))
    if (fp.polarityPin) { const [cx, cy] = px(p.pinXY[`${ref}.${fp.polarityPin}`]); out.push(text(cx - 6, cy - 5, "+", { "font-size": 12, fill: "#b00", "font-weight": 700 })) }
    if (fp.stripePin) { const [cx, cy] = px(p.pinXY[`${ref}.${fp.stripePin}`]); out.push(line(cx - 5, cy - 6, cx - 5, cy + 6, { stroke: "#333", "stroke-width": 2 })) }
  }

  // 凡例
  let ly = MT
  const lx = ML + (BOARD.width - 1) * PITCH + 40
  out.push(text(lx, ly, "ネット配色", { "font-size": 12, fill: "#333", "font-weight": 700 })); ly += 18
  for (const [n, c] of Object.entries(NET_COLOR)) {
    out.push(line(lx, ly - 4, lx + 20, ly - 4, { stroke: c, "stroke-width": 3 }))
    out.push(text(lx + 26, ly, n, { "font-size": 10, fill: "#333" })); ly += 15
  }
  ly += 8
  out.push(text(lx, ly, "凡例: ●=Pico使用ピン ●=部品ピン", { "font-size": 9, fill: "#555" })); ly += 13
  out.push(text(lx, ly, "+ =コンデンサ極性 | =ダイオード帯", { "font-size": 9, fill: "#555" })); ly += 13

  // 注記
  const notes = [
    "手置き配置は circuit/perfboard/layout.ts で調整。",
    "配線は点対点のはんだジャンパ。電源/GNDはバス代わりに太線可。",
    "Pico の 2 列に挟まれた内側は Pico 本体上。部品は外側へ。",
  ]
  let ny = MT + (BOARD.height - 1) * PITCH + 30
  for (const t of notes) { out.push(text(ML, ny, t, { "font-size": 10, fill: "#555" })); ny += 15 }

  out.push("</svg>")
  return out.join("\n")
}

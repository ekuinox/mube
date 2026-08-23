// circuit/perfboard/render.ts
// 配置データを SVG と結線表に落とす。方位の凡例は scripts/axes.ts の対応表から描く。
//
// 図はハンダ付けをしながら見るものなので、結線表の穴 ID（M12 など）を図の上で引けることを
// 最優先にする。そのために四辺へ列番号と行 letter の目盛りを打つ。

import { axisWithLabel, VIEWPOINT } from "../../scripts/axes"
import {
  COLS, PICO_GND_PINS, PICO_PIN_OF_LABEL, PIN_ROW_HIGH, PIN_ROW_LOW, PITCH, ROWS,
  holeId, holeXY, parseHole, pinHole,
} from "./board"
import type { Layout } from "./verify"

const MARGIN = 110 // 目盛りと、盤外へ逃がすラベルのぶんを含む余白
const SCALE = 20 // mm あたりの px。ラベルが重ならない大きさを優先する
const FONT = 12
const RULER_FONT = 13

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

/**
 * 部品の胴体寸法（mm）。**BOM の型番から実寸が引けるものだけ**を載せる。
 * ここに無い部品（コネクタ類）は足を囲む外形を破線で描き、実寸ではないことが図から分かる
 * ようにする。胴体どうしの干渉はまだ機械検査していないので、目で見るための情報である。
 *
 * `stand` は縦置きの軸型部品。胴体はその足の穴の上に立ち、もう一方の足を折り返して
 * 隣の穴へ落とす。カーボン抵抗（1/4W, 本体 6.3×φ2.3）と 1N5819（DO-41, 本体 5.2×φ2.7）は
 * 同じ大きさの軸型なので、同じ 1 ピッチ（2.54mm）で扱う。胴体の径はどちらも 1 ピッチ未満
 * なので、隣の穴を塞がない。
 */
const BODIES: Record<string, { d?: number; w?: number; h?: number; stand?: string }> = {
  C1: { d: 8 }, // 電解 470µF φ8×11.5（docs/parts-selection.md）
  C2: { w: 4.5, h: 3.2 }, // 積層セラミック 0.1µF、BOM に 5mm ピッチと明記
  D1: { d: 5 }, // 二色 LED φ5×8.6（docs/parts-selection.md）
  Q1: { w: 10.2, h: 4.6 }, // TO-220 の標準的な胴体寸法
  Rled: { d: 2.3, stand: "pin1" }, // カーボン抵抗 1/4W（R-25331）
  Rled2: { d: 2.3, stand: "pin1" },
  Rg: { d: 2.3, stand: "pin1" }, // R-25221
  Rgs: { d: 2.3, stand: "pin1" }, // R-25103
  D2: { d: 2.7, stand: "cathode" }, // 1N5819 DO-41（I-17244）
}

type Point = { x: number; y: number }
type Box = { x1: number; y1: number; x2: number; y2: number }

// 列 1 は +X（右）端なので、画面上は右へ行くほど列番号が小さい。
// 行 1（A）は −Y（下）端なので、画面上は下へ行くほど行番号が小さい。
function xy(id: string): Point {
  const h = parseHole(id)
  return {
    x: MARGIN + (COLS - h.col) * PITCH * SCALE,
    y: MARGIN + (ROWS - h.row) * PITCH * SCALE,
  }
}

function overlaps(a: Box, b: Box): boolean {
  return a.x1 < b.x2 && b.x1 < a.x2 && a.y1 < b.y2 && b.y1 < a.y2
}

/** 部品 ref → その足が入る穴 ID。"D1.R" のような端点名から組み立てる。 */
function partsOf(layout: Layout): Map<string, string[]> {
  const parts = new Map<string, string[]>()
  for (const [leg, hole] of Object.entries(layout.legs)) {
    const ref = leg.split(".")[0]
    parts.set(ref, [...(parts.get(ref) ?? []), hole])
  }
  return parts
}

function centroid(holes: string[]): Point {
  const pts = holes.map(xy)
  return {
    x: pts.reduce((s, p) => s + p.x, 0) / pts.length,
    y: pts.reduce((s, p) => s + p.y, 0) / pts.length,
  }
}

/** 穴 ID → ヘッダピンの呼び名。ワイヤが降りる先が何のピンかを図に出すために使う。 */
function pinNames(): Map<string, string> {
  const names = new Map<string, string>()
  for (const pin of PICO_GND_PINS) names.set(holeId(pinHole(pin)), "GND")
  for (const [label, pin] of Object.entries(PICO_PIN_OF_LABEL))
    names.set(holeId(pinHole(pin)), label)
  return names
}

/**
 * 部品ラベルの位置を決める。重心の周囲 8 方向を近い順に試し、既に置いたラベルとも
 * 足の点とも部品の胴体とも重ならない場所を選ぶ。
 * ref のソート順で決めるので出力は決定的になる。
 */
function placeLabels(
  parts: Map<string, string[]>,
  obstacles: Box[],
  canvas: { w: number; h: number },
): Map<string, { at: Point; box: Box }> {
  const inCanvas = (b: Box) =>
    b.x1 >= 4 && b.y1 >= 4 && b.x2 <= canvas.w - 4 && b.y2 <= canvas.h - 4
  const legBoxes: Box[] = [...parts.values()].flat().map((hole) => {
    const p = xy(hole)
    return { x1: p.x - 6, y1: p.y - 6, x2: p.x + 6, y2: p.y + 6 }
  })
  const placed: Box[] = [...legBoxes, ...obstacles]
  const out = new Map<string, { at: Point; box: Box }>()
  const step = PITCH * SCALE
  // 16 方位 × 6 段。真上が塞がっている部品（最上段の D1 など）でも置き場が見つかる粒度。
  const dirs = Array.from({ length: 16 }, (_, i) => {
    const a = (i * Math.PI) / 8
    return [Math.sin(a), -Math.cos(a)] // 真上から時計回り
  })

  for (const ref of [...parts.keys()].sort()) {
    const c = centroid(parts.get(ref)!)
    const w = ref.length * FONT * 0.65 + 6
    const h = FONT + 4
    let chosen: { at: Point; box: Box } | null = null
    for (let ring = 1; ring <= 6 && !chosen; ring++)
      for (const [dx, dy] of dirs) {
        const at = { x: c.x + dx * step * ring * 0.8, y: c.y + dy * step * ring * 0.8 }
        const box = { x1: at.x - w / 2, y1: at.y - h / 2, x2: at.x + w / 2, y2: at.y + h / 2 }
        if (inCanvas(box) && !placed.some((b) => overlaps(b, box))) {
          chosen = { at, box }
          break
        }
      }
    // 置き場が見つからなければ重心の真下へ寄せる。キャンバス外へは出さない。
    const fy = Math.min(c.y + step, canvas.h - h)
    const fallback = {
      at: { x: c.x, y: fy },
      box: { x1: c.x - w / 2, y1: fy - h / 2, x2: c.x + w / 2, y2: fy + h / 2 },
    }
    const result = chosen ?? fallback
    placed.push(result.box)
    out.set(ref, result)
  }
  return out
}

export function renderSvg(layout: Layout): string {
  const boardW = (COLS - 1) * PITCH * SCALE
  const boardH = (ROWS - 1) * PITCH * SCALE
  const w = MARGIN * 2 + boardW
  const h = MARGIN * 2 + boardH + 56 // 凡例のぶん
  const out: string[] = []
  out.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">`)
  out.push(`<rect width="${w}" height="${h}" fill="#f7f3e8"/>`)
  out.push(`<g font-family="sans-serif">`)

  // 目盛り: 上下に列番号、左右に行 letter。結線表の穴 ID をこの図の上で引くためのもの。
  for (let col = 1; col <= COLS; col++) {
    const { x } = xy(holeId({ col, row: 1 }))
    for (const y of [MARGIN - 26, MARGIN + boardH + 34])
      out.push(`<text class="ruler" x="${x}" y="${y}" font-size="${RULER_FONT}" fill="#8a7a4e" text-anchor="middle">${col}</text>`)
  }
  for (let row = 1; row <= ROWS; row++) {
    const { y } = xy(holeId({ col: 1, row }))
    const letter = holeId({ col: 1, row }).replace(/\d+$/, "")
    for (const x of [MARGIN - 26, MARGIN + boardW + 26])
      out.push(`<text class="ruler" x="${x}" y="${y + 5}" font-size="${RULER_FONT}" fill="#8a7a4e" text-anchor="middle">${letter}</text>`)
  }

  // 穴
  for (let col = 1; col <= COLS; col++)
    for (let row = 1; row <= ROWS; row++) {
      const p = xy(holeId({ col, row }))
      out.push(`<circle class="hole" cx="${p.x}" cy="${p.y}" r="4" fill="#fff" stroke="#c9b98f"/>`)
    }

  // Pico のソケット。40 ピンが穴を占有していることと、USB がどちら端かを図に出す。
  const socketTL = xy(holeId({ col: 20, row: PIN_ROW_HIGH }))
  const socketBR = xy(holeId({ col: 1, row: PIN_ROW_LOW }))
  const pad = 0.32 * PITCH * SCALE
  const socketBox: Box = {
    x1: socketTL.x - pad, y1: socketTL.y - pad, x2: socketBR.x + pad, y2: socketBR.y + pad,
  }
  out.push(`<rect class="socket" x="${socketBox.x1}" y="${socketBox.y1}" width="${socketBox.x2 - socketBox.x1}" height="${socketBox.y2 - socketBox.y1}" rx="8" fill="#dfe6ef" fill-opacity="0.6" stroke="#7a8ba3"/>`)
  for (let pin = 1; pin <= 40; pin++) {
    const p = xy(holeId(pinHole(pin)))
    out.push(`<circle class="pin" cx="${p.x}" cy="${p.y}" r="5.5" fill="#7a8ba3"/>`)
  }
  const socketMid = { x: (socketBox.x1 + socketBox.x2) / 2, y: (socketBox.y1 + socketBox.y2) / 2 }
  out.push(`<text class="socket-label" x="${socketMid.x}" y="${socketMid.y}" font-size="15" text-anchor="middle" fill="#44546b">U1 Pico W（ソケット）</text>`)
  out.push(`<text class="socket-label" x="${socketBox.x2 - 10}" y="${socketMid.y + 20}" font-size="13" text-anchor="end" fill="#44546b">USB はこちら側 →</text>`)

  // ワイヤが降りるヘッダピンの呼び名。どのピンへ挿す線なのかを図の上で分かるようにする。
  const wireEnds = new Set(layout.wires.flatMap((w) => [w.from, w.to]))
  const pinLabelBoxes: Box[] = []
  for (const [hole, name] of pinNames()) {
    if (!wireEnds.has(hole)) continue
    const p = xy(hole)
    // ソケットの内側（空いている中央寄り）へ出す
    const dy = parseHole(hole).row === PIN_ROW_LOW ? -18 : 18
    out.push(`<text class="pin-label" x="${p.x}" y="${p.y + dy}" font-size="12" text-anchor="middle" fill="#44546b">${name}</text>`)
    pinLabelBoxes.push({ x1: p.x - 22, y1: p.y + dy - 14, x2: p.x + 22, y2: p.y + dy + 4 })
  }

  // 部品の胴体。実寸が分かるものは実線、分からないものは足を囲む外形を破線で描く。
  const parts = partsOf(layout)
  const bodyBoxes: Box[] = []
  for (const ref of [...parts.keys()].sort()) {
    const holes = parts.get(ref)!
    const body = BODIES[ref]
    // 縦置きの部品は胴体が片方の足の上に立つ。それ以外は足の重心に置く。
    const c = body?.stand ? xy(layout.legs[`${ref}.${body.stand}`]) : centroid(holes)
    if (body?.d) {
      bodyBoxes.push({
        x1: c.x - (body.d / 2) * SCALE, y1: c.y - (body.d / 2) * SCALE,
        x2: c.x + (body.d / 2) * SCALE, y2: c.y + (body.d / 2) * SCALE,
      })
      out.push(`<circle class="body" cx="${c.x}" cy="${c.y}" r="${(body.d / 2) * SCALE}" fill="#c9b98f" fill-opacity="0.35" stroke="#8a7a4e"/>`)
    } else if (body?.w && body?.h) {
      bodyBoxes.push({
        x1: c.x - (body.w / 2) * SCALE, y1: c.y - (body.h / 2) * SCALE,
        x2: c.x + (body.w / 2) * SCALE, y2: c.y + (body.h / 2) * SCALE,
      })
      out.push(`<rect class="body" x="${c.x - (body.w / 2) * SCALE}" y="${c.y - (body.h / 2) * SCALE}" width="${body.w * SCALE}" height="${body.h * SCALE}" fill="#c9b98f" fill-opacity="0.35" stroke="#8a7a4e"/>`)
    } else {
      const pts = holes.map(xy)
      const margin = 0.9 * SCALE
      const x1 = Math.min(...pts.map((p) => p.x)) - margin
      const y1 = Math.min(...pts.map((p) => p.y)) - margin
      const x2 = Math.max(...pts.map((p) => p.x)) + margin
      const y2 = Math.max(...pts.map((p) => p.y)) + margin
      bodyBoxes.push({ x1, y1, x2, y2 })
      out.push(`<rect class="body-est" x="${x1}" y="${y1}" width="${x2 - x1}" height="${y2 - y1}" rx="6" fill="none" stroke="#8a7a4e" stroke-dasharray="3 3"/>`)
    }
  }

  // ワイヤ。破線 = 裏面（はんだ面）。
  // 被覆線の白い縁取りは、あとから他の線を消さないように全部先に敷いてから本線を描く。
  for (const wire of layout.wires) {
    if (!wire.insulated) continue
    const a = xy(wire.from)
    const b = xy(wire.to)
    out.push(`<line class="sleeve" x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}" stroke="#fff" stroke-width="10" stroke-linecap="round" stroke-opacity="0.9"/>`)
  }
  for (const wire of layout.wires) {
    const a = xy(wire.from)
    const b = xy(wire.to)
    const color = NET_COLORS[wire.net] ?? "#666"
    const dash = wire.side === "solder" ? ` stroke-dasharray="7 5"` : ""
    out.push(`<line class="wire" x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}" stroke="${color}" stroke-width="3"${dash}/>`)
  }

  // 足
  for (const hole of Object.values(layout.legs)) {
    const p = xy(hole)
    out.push(`<circle class="leg" cx="${p.x}" cy="${p.y}" r="5.5" fill="#6b5d38"/>`)
  }

  // 部品ラベル。足ごとではなく部品ごとに 1 つ置き、引き出し線で結ぶ。
  // 足の識別は目盛りと結線表が担う。
  const rulerBoxes: Box[] = [
    { x1: 0, y1: MARGIN - 42, x2: w, y2: MARGIN - 12 },
    { x1: 0, y1: MARGIN + boardH + 20, x2: w, y2: MARGIN + boardH + 46 },
    { x1: MARGIN - 42, y1: 0, x2: MARGIN - 12, y2: h },
    { x1: MARGIN + boardW + 12, y1: 0, x2: MARGIN + boardW + 42, y2: h },
  ]
  const labelObstacles = [...bodyBoxes, ...pinLabelBoxes, ...rulerBoxes, socketBox]
  for (const [ref, { at }] of placeLabels(parts, labelObstacles, { w, h })) {
    const c = centroid(parts.get(ref)!)
    out.push(`<line class="leader" x1="${c.x}" y1="${c.y}" x2="${at.x}" y2="${at.y}" stroke="#8a7a4e" stroke-width="1"/>`)
    out.push(`<text class="part-label" x="${at.x}" y="${at.y + 4}" font-size="${FONT}" text-anchor="middle" fill="#3b3320">${ref}</text>`)
  }

  // 凡例。ネットの色見本も並べる（同じ色を持つネットがあるので名前と併記する）。
  const legendY = h - 56
  out.push(`<text x="${MARGIN}" y="${legendY}" font-size="13">${VIEWPOINT}見て ${axisWithLabel("+X")} ${axisWithLabel("-X")} ${axisWithLabel("+Y")} ${axisWithLabel("-Y")}</text>`)
  out.push(`<text x="${MARGIN}" y="${legendY + 18}" font-size="13">破線 = 裏面（はんだ面）を通る線 / 白縁 = 被覆線で引く区間 / 破線の枠 = 実寸未確認の部品外形</text>`)
  let swatchX = MARGIN
  for (const net of [...new Set(layout.wires.map((wire) => wire.net))].sort()) {
    const color = NET_COLORS[net] ?? "#666"
    out.push(`<line class="swatch" x1="${swatchX}" y1="${legendY + 34}" x2="${swatchX + 22}" y2="${legendY + 34}" stroke="${color}" stroke-width="3"/>`)
    out.push(`<text x="${swatchX + 27}" y="${legendY + 38}" font-size="12" fill="#3b3320">${net}</text>`)
    swatchX += 27 + net.length * 12 * 0.62 + 18
  }
  out.push(`</g></svg>`)
  return out.join("\n")
}

/** 部品ごとの占有穴とローカル mm。設計書が手で持っていた表を生成物へ移すためのもの。 */
function placementRows(layout: Layout): string[] {
  const parts = partsOf(layout)
  return [...parts.keys()].sort().map((ref) => {
    const holes = parts.get(ref)!
    const pts = holes.map((hole) => holeXY(parseHole(hole)))
    const x = pts.reduce((sum, p) => sum + p.x, 0) / pts.length
    const y = pts.reduce((sum, p) => sum + p.y, 0) / pts.length
    return `| ${ref} | ${holes.join(", ")} | (${x.toFixed(1)}, ${y.toFixed(1)}) |`
  })
}

export function renderTable(layout: Layout): string {
  const rows = layout.wires.map(
    (w) => `| ${w.from} | ${w.to} | ${w.net} | ${w.side === "solder" ? "裏" : "表"} | ${w.insulated ? "被覆" : "裸"} |`)
  return [
    `<!-- circuit/perfboard-build.ts の生成物。手で編集しない。 -->`,
    ``,
    `# ユニバーサル基板の結線表`,
    ``,
    `方位は${VIEWPOINT}ドアを正面に見た向き。${axisWithLabel("+X")}が列 1、${axisWithLabel("-Y")}が行 A。`,
    `穴 ID は「行の letter + 列番号」。面の「裏」ははんだ面を通す線。`,
    `線材の「被覆」は被覆線で引く区間（裸のすずめっき線だと他の線やランドに触れて短絡する）。`,
    ``,
    `| from | to | ネット | 面 | 線材 |`,
    `| --- | --- | --- | --- | --- |`,
    ...rows,
    ``,
    `## 部品の占有穴`,
    ``,
    `ローカル座標は基板中心が原点（${axisWithLabel("+X")}が列 1 側、${axisWithLabel("+Y")}が行 ${String.fromCharCode(64 + ROWS)} 側）。`,
    `複数の足を持つ部品は足の重心を書く。設計書はこの表を参照する（mm を手で書き写さない）。`,
    ``,
    `| 部品 | 穴 | ローカル mm |`,
    `| --- | --- | --- |`,
    ...placementRows(layout),
    ``,
  ].join("\n")
}

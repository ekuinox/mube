// circuit/perfboard/verify.ts
// 配置データ（layout.ts）が parts.ts の NETS を満たしているかを検証する。
// layout.ts は「どの穴に何を置いたか」しか主張しない。繋がっているかを言うのはここだけ。

import { NETS } from "../parts"
import { normaliseEndpoint } from "../breadboard/subcircuit"
import { UnionFind } from "../breadboard/model"
import { COLS, PICO_GND_PINS, PICO_PIN_OF_LABEL, ROWS, holeId, parseHole, pinHole, type Hole } from "./board"

export type Wire = {
  from: string
  to: string
  net: string
  side: "solder" | "component"
  /** 被覆線で引く。裸のすずめっき線と違い、他の線やランドに触れても短絡しない。 */
  insulated?: boolean
}

export type Layout = {
  /** "D1.R" → "O12"。U1 のピンは pinHole() から導くので書かない。 */
  legs: Record<string, string>
  wires: Wire[]
}

/** 端点 "Ref.pin" → 穴 ID。U1 だけはヘッダのピン配置から導く。 */
function holeOf(layout: Layout, endpoint: string): string | undefined {
  const [ref, pin] = endpoint.split(".")
  if (ref === "U1") {
    const number = PICO_PIN_OF_LABEL[pin]
    return number === undefined ? undefined : holeId(pinHole(number))
  }
  return layout.legs[endpoint]
}

/** 穴の中心と線分の距離（グリッド単位）。 */
function holeDistance(h: Hole, from: Hole, to: Hole): number {
  const vx = to.col - from.col, vy = to.row - from.row
  const wx = h.col - from.col, wy = h.row - from.row
  const len2 = vx * vx + vy * vy
  const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, (wx * vx + wy * vy) / len2))
  const dx = wx - t * vx, dy = wy - t * vy
  return Math.sqrt(dx * dx + dy * dy)
}

/** 2 つの線分が端点を共有せずに交差するか。 */
function segmentsCross(a1: Hole, a2: Hole, b1: Hole, b2: Hole): boolean {
  const key = (h: Hole) => `${h.col},${h.row}`
  const ends = new Set([key(a1), key(a2), key(b1), key(b2)])
  if (ends.size < 4) return false // 端点を共有する線は交差扱いしない
  const cross = (p: Hole, q: Hole, r: Hole) =>
    (q.col - p.col) * (r.row - p.row) - (q.row - p.row) * (r.col - p.col)
  const d1 = cross(b1, b2, a1), d2 = cross(b1, b2, a2)
  const d3 = cross(a1, a2, b1), d4 = cross(a1, a2, b2)
  return ((d1 > 0) !== (d2 > 0)) && ((d3 > 0) !== (d4 > 0))
}

export function verifyLayout(layout: Layout): string[] {
  const problems: string[] = []
  const uf = new UnionFind()

  // Pico の GND ピンは基板内部で繋がっている。ここだけは配線が無くても同一ノード。
  const gndHoles = PICO_GND_PINS.map((p) => holeId(pinHole(p)))
  for (const h of gndHoles.slice(1)) uf.union(gndHoles[0], h)

  for (const w of layout.wires) uf.union(w.from, w.to)

  // 穴の重複。ヘッダピンの穴も占有済みとして数える。
  const occupied: Record<string, string> = {}
  for (let pin = 1; pin <= 40; pin++) occupied[holeId(pinHole(pin))] = `U1.pin${pin}`
  for (const [leg, hole] of Object.entries(layout.legs)) {
    if (occupied[hole]) problems.push(`穴の重複: ${hole} に ${occupied[hole]} と ${leg}`)
    else occupied[hole] = leg
  }

  // 範囲外。書いた穴の列・行が今のグリッド仮定（COLS × ROWS）の外に出ていないか。
  // 実測前の仮定なので、行数・列数が違えば存在しない穴を指してしまいうる。
  const allHoleIds = [...Object.values(layout.legs), ...layout.wires.flatMap((w) => [w.from, w.to])]
  for (const id of allHoleIds) {
    const h = parseHole(id)
    if (h.col < 1 || h.col > COLS || h.row < 1 || h.row > ROWS)
      problems.push(`範囲外: ${id} は列 1〜${COLS}、行 A〜${String.fromCharCode(64 + ROWS)} の外`)
  }

  // 近接。ワイヤが両端以外で使用済みの穴の 0.5 グリッド単位未満まで近づくと、単面基板の
  // 裸線ではそこに乗っている別ネットとぶつかる。被覆線（insulated）は触れても短絡しないので対象外。
  for (const w of layout.wires) {
    if (w.insulated) continue
    const from = parseHole(w.from), to = parseHole(w.to)
    for (const [id, occupant] of Object.entries(occupied)) {
      if (id === w.from || id === w.to) continue
      // 同じ電気ノードのランドなら、裸線が触れても短絡にならない。
      if (uf.groupOf(id) === uf.groupOf(w.from)) continue
      if (holeDistance(parseHole(id), from, to) < 0.5)
        problems.push(`近接: ${w.net} (${w.from}→${w.to}) が ${id} の ${occupant} に近すぎる`)
    }
  }

  // 交差。裏面（同じ side）で異なるネットの裸線同士が端点を共有せずに交差すると、
  // その交点で短絡する。片方でも被覆線なら対象外。
  for (let i = 0; i < layout.wires.length; i++) {
    for (let j = i + 1; j < layout.wires.length; j++) {
      const a = layout.wires[i], b = layout.wires[j]
      if (a.side !== b.side || a.net === b.net) continue
      if (a.insulated || b.insulated) continue
      if (segmentsCross(parseHole(a.from), parseHole(a.to), parseHole(b.from), parseHole(b.to)))
        problems.push(`交差: ${a.net} (${a.from}→${a.to}) と ${b.net} (${b.from}→${b.to}) が交差`)
    }
  }

  // ネットごとの導通。
  const groupNets: Record<string, Set<string>> = {}
  for (const net of NETS) {
    const endpoints = net.endpoints.map(normaliseEndpoint)
    const groups: string[] = []
    for (const e of endpoints) {
      const hole = holeOf(layout, e)
      if (!hole) {
        problems.push(`穴が無い: ${net.name} の ${e}`)
        continue
      }
      const g = uf.groupOf(hole)
      groups.push(g)
      ;(groupNets[g] ??= new Set()).add(net.name)
    }
    if (groups.length > 1 && new Set(groups).size > 1) {
      problems.push(`未接続: ${net.name} の端点が ${new Set(groups).size} 個の島に分かれている`)
    }
  }

  // ショート。同じ島に 2 つ以上のネットが乗ったら配線ミス。
  for (const [group, nets] of Object.entries(groupNets)) {
    if (nets.size > 1) problems.push(`ショート: ${[...nets].join(" と ")} が同じ島（${group}）`)
  }

  return problems
}

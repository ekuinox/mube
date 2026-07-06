// circuit/breadboard/route.ts
import { type Hole, type Jumper } from "./model"
import type { Placement, RouteResult } from "./layout-types"
import { RAIL_NETS, SIGNAL_LANES, RAIL_STUB_ROW } from "./config"

// ネット名 → 安定した色（信号用パレット）
const PALETTE = ["#4363d8", "#f58231", "#911eb4", "#3cb44b", "#e6194B", "#42d4f4", "#f032e6", "#9A6324", "#808000", "#469990"]
function colorForNet(name: string, idx: number): string {
  if (name === "V5") return "red"
  if (name === "GND") return "black"
  return PALETTE[idx % PALETTE.length]
}

export function routeNets(pl: Placement, nets: Record<string, string[]>): RouteResult {
  const jumpers: Jumper[] = []
  const colOf = (pinKey: string) => pl.pinHoles[pinKey]?.col

  // 1) レールネット: 各ピン列 → レールへの短スタブ（row RAIL_STUB_ROW）
  const railNetNames = new Set(Object.keys(RAIL_NETS))
  for (const [name, pins] of Object.entries(nets)) {
    if (!railNetNames.has(name)) continue
    const rail = RAIL_NETS[name]
    for (const pin of pins) {
      const col = colOf(pin)
      if (col == null) continue
      jumpers.push({
        from: { kind: "strip", col, row: RAIL_STUB_ROW } as Hole,
        to: { kind: "rail", rail, col } as Hole,
        net: name, color: colorForNet(name, 0),
      })
    }
  }

  // 2) 信号ネット: 相異なる列をチェーンで連結。各セグメントを lane に割付。
  type Seg = { lo: number; hi: number; net: string; colorIdx: number }
  const segments: Seg[] = []
  let netIdx = 0
  for (const [name, pins] of Object.entries(nets)) {
    if (railNetNames.has(name)) continue
    const cols = [...new Set(pins.map(colOf).filter((c): c is number => c != null))].sort((a, b) => a - b)
    for (let i = 0; i + 1 < cols.length; i++) {
      segments.push({ lo: cols[i], hi: cols[i + 1], net: name, colorIdx: netIdx })
    }
    netIdx++
  }

  // left-edge 法: 左端でソート、各セグメントを重ならない最下トラックへ。空き無ければ交差許容で最小衝突トラックへ。
  segments.sort((a, b) => a.lo - b.lo || a.hi - b.hi)
  const lanePlaced: Array<Array<[number, number]>> = SIGNAL_LANES.map(() => [])
  let crossings = 0
  const usedLanes = new Set<number>()

  const overlaps = (placed: Array<[number, number]>, lo: number, hi: number) =>
    placed.some(([l, h]) => lo < h && l < hi)

  for (const seg of segments) {
    let lane = SIGNAL_LANES.findIndex((_, li) => !overlaps(lanePlaced[li], seg.lo, seg.hi))
    if (lane === -1) {
      // 交差許容: 最も衝突の少ない lane へ
      let bestLi = 0, bestConf = Infinity
      SIGNAL_LANES.forEach((_, li) => {
        const conf = lanePlaced[li].filter(([l, h]) => seg.lo < h && l < seg.hi).length
        if (conf < bestConf) { bestConf = conf; bestLi = li }
      })
      lane = bestLi
      crossings += bestConf
    }
    lanePlaced[lane].push([seg.lo, seg.hi])
    usedLanes.add(lane)
    const row = SIGNAL_LANES[lane]
    jumpers.push({
      from: { kind: "strip", col: seg.lo, row } as Hole,
      to: { kind: "strip", col: seg.hi, row } as Hole,
      net: seg.net, color: colorForNet(seg.net, seg.colorIdx),
    })
  }

  return { jumpers, stats: { crossings, tracksUsed: usedLanes.size } }
}

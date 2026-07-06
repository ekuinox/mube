// circuit/breadboard/place.ts
import type { Hole } from "./model"
import type { Placement } from "./layout-types"
import { FOOTPRINTS } from "./footprints"
import { RAIL_NETS, WEIGHTS } from "./config"

// ref → 使用ピン（footprint pinOrder 順、サブ回路ネットに現れるものだけ）
export function usedPinsByPart(refs: string[], nets: Record<string, string[]>): Record<string, string[]> {
  const usedSet: Record<string, Set<string>> = {}
  for (const r of refs) usedSet[r] = new Set()
  for (const pins of Object.values(nets)) {
    for (const p of pins) {
      const [ref, pin] = p.split(".")
      if (usedSet[ref]) usedSet[ref].add(pin)
    }
  }
  const out: Record<string, string[]> = {}
  for (const r of refs) {
    const order = FOOTPRINTS[r]?.pinOrder ?? [...usedSet[r]]
    out[r] = order.filter((p) => usedSet[r].has(p))
  }
  return out
}

// 順序 → 列割付。部品iを連続列、部品間に1列の隙間。pin は row a。
export function assignColumns(order: string[], usedPins: Record<string, string[]>): Placement {
  const partColumns: Record<string, number[]> = {}
  const pinHoles: Record<string, Hole> = {}
  let col = 1
  for (const ref of order) {
    const pins = usedPins[ref]
    const cols: number[] = []
    for (const pin of pins) {
      cols.push(col)
      pinHoles[`${ref}.${pin}`] = { kind: "strip", col, row: "a" }
      col++
    }
    partColumns[ref] = cols
    col++ // gap
  }
  return { order, cols: Math.max(0, col - 2), partColumns, pinHoles }
}

// 信号ネット（レールネット除外）だけでコスト算出。
export function placementCost(pl: Placement, nets: Record<string, string[]>): number {
  const colOf = (pinKey: string) => pl.pinHoles[pinKey]?.col ?? 0
  const signalNets = Object.entries(nets).filter(([name]) => !(name in RAIL_NETS))

  // span
  let span = 0
  const intervals: Array<[number, number]> = []
  for (const [, pins] of signalNets) {
    const cs = pins.map(colOf).filter((c) => c > 0)
    if (cs.length < 2) continue
    const lo = Math.min(...cs), hi = Math.max(...cs)
    span += hi - lo
    intervals.push([lo, hi])
  }
  // crossing: 区間が重なるペア数
  let cross = 0
  for (let i = 0; i < intervals.length; i++)
    for (let j = i + 1; j < intervals.length; j++) {
      const [a1, a2] = intervals[i], [b1, b2] = intervals[j]
      if (a1 < b2 && b1 < a2) cross++
    }
  // edge affinity
  let edge = 0
  for (const ref of pl.order) {
    const aff = FOOTPRINTS[ref]?.edgeAffinity
    if (!aff) continue
    const cols = pl.partColumns[ref]
    if (aff === "left") edge += Math.min(...cols) - 1
    else edge += pl.cols - Math.max(...cols)
  }
  return WEIGHTS.span * span + WEIGHTS.cross * cross + WEIGHTS.edge * edge + WEIGHTS.width * pl.cols
}

// seed 付き決定的乱数（mulberry32）
function rng(seed: number) {
  let a = seed >>> 0
  return () => {
    a |= 0; a = (a + 0x6D2B79F5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function permutations<T>(arr: T[]): T[][] {
  if (arr.length <= 1) return [arr]
  const out: T[][] = []
  for (let i = 0; i < arr.length; i++) {
    const rest = [...arr.slice(0, i), ...arr.slice(i + 1)]
    for (const p of permutations(rest)) out.push([arr[i], ...p])
  }
  return out
}

// n≤8 総当り、それ超は seed 付き 2-opt（近傍=2部品スワップ）で山登り＋再スタート。
export function placeParts(refs: string[], nets: Record<string, string[]>, seed = 1): Placement {
  const used = usedPinsByPart(refs, nets)
  const evalOrder = (order: string[]): { pl: Placement; cost: number } => {
    const pl = assignColumns(order, used)
    return { pl, cost: placementCost(pl, nets) }
  }

  if (refs.length <= 8) {
    let best = evalOrder(refs)
    for (const perm of permutations(refs)) {
      const cand = evalOrder(perm)
      if (cand.cost < best.cost) best = cand
    }
    return best.pl
  }

  const rand = rng(seed)
  let best = evalOrder(refs)
  for (let restart = 0; restart < 20; restart++) {
    // ランダム初期順
    const order = [...refs]
    for (let i = order.length - 1; i > 0; i--) {
      const j = Math.floor(rand() * (i + 1));
      [order[i], order[j]] = [order[j], order[i]]
    }
    let cur = evalOrder(order)
    let improved = true
    while (improved) {
      improved = false
      for (let i = 0; i < order.length; i++)
        for (let j = i + 1; j < order.length; j++) {
          const cand = [...cur.pl.order];
          [cand[i], cand[j]] = [cand[j], cand[i]]
          const e = evalOrder(cand)
          if (e.cost < cur.cost) { cur = e; improved = true }
        }
    }
    if (cur.cost < best.cost) best = cur
  }
  return best.pl
}

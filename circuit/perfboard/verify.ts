// circuit/perfboard/verify.ts
// 配置データ（layout.ts）が parts.ts の NETS を満たしているかを検証する。
// layout.ts は「どの穴に何を置いたか」しか主張しない。繋がっているかを言うのはここだけ。

import { NETS } from "../parts"
import { normaliseEndpoint } from "../breadboard/subcircuit"
import { UnionFind } from "../breadboard/model"
import { PICO_GND_PINS, PICO_PIN_OF_LABEL, holeId, parseHole, pinHole, type Hole } from "./board"

export type Wire = {
  from: string
  to: string
  net: string
  side: "solder" | "component"
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

/** 両端以外に穴の中心を通る座標。行・列・45 度の直線だけが中心を通る。 */
function holesOnSegment(from: Hole, to: Hole): Hole[] {
  const dc = to.col - from.col
  const dr = to.row - from.row
  if (dc !== 0 && dr !== 0 && Math.abs(dc) !== Math.abs(dr)) return []
  const steps = Math.max(Math.abs(dc), Math.abs(dr))
  const out: Hole[] = []
  for (let i = 1; i < steps; i++)
    out.push({ col: from.col + (dc / steps) * i, row: from.row + (dr / steps) * i })
  return out
}

export function verifyLayout(layout: Layout, allowUnconnected: string[] = []): string[] {
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

  // またぎ。ワイヤが両端以外で使用済みの穴の中心を通ると、単面基板の裸線では
  // そこに乗っている別ネットとぶつかる。行・列・45 度の直線だけを対象にする。
  for (const w of layout.wires) {
    const crossed = holesOnSegment(parseHole(w.from), parseHole(w.to))
    for (const h of crossed) {
      const id = holeId(h)
      if (occupied[id]) problems.push(`またぎ: ${w.net} (${w.from}→${w.to}) が ${id} の ${occupied[id]} をまたぐ`)
    }
  }

  // ネットごとの導通。
  const groupNets: Record<string, Set<string>> = {}
  for (const net of NETS) {
    const endpoints = net.endpoints.map(normaliseEndpoint).filter((e) => !allowUnconnected.includes(e))
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

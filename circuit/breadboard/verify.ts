// circuit/breadboard/verify.ts
import { type Hole, type Jumper, nodeOf, buildConnectivity } from "./model"

// 網羅・全結線・ショート無しを検査。エラー文字列配列（空＝合格）。
export function verifyLayout(
  nets: Record<string, string[]>,
  pinHoles: Record<string, Hole>,
  jumpers: Jumper[],
): string[] {
  const errors: string[] = []
  const conn = buildConnectivity(jumpers)

  // group 代表 → その group に属するネット名の集合（ショート検出用）
  const groupNets = new Map<string, Set<string>>()

  for (const [netName, pins] of Object.entries(nets)) {
    const groups = new Set<string>()
    for (const pin of pins) {
      const hole = pinHoles[pin]
      if (!hole) { errors.push(`pin ${pin} (net ${netName}) has no hole`); continue }
      const g = conn.groupOf(nodeOf(hole))
      groups.add(g)
      if (!groupNets.has(g)) groupNets.set(g, new Set())
      groupNets.get(g)!.add(netName)
    }
    if (groups.size > 1) errors.push(`net ${netName} not fully connected (${groups.size} groups)`)
  }

  for (const [g, netSet] of groupNets) {
    if (netSet.size > 1) errors.push(`short: nets ${[...netSet].sort().join(", ")} share group ${g}`)
  }
  return errors
}

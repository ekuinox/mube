// circuit/perfboard/wire.ts
// 各ネットの端点穴を点対点はんだ配線で結ぶ。ネット内は最小全域木(Manhattan)で k-1 本に。
import type { XY } from "./board"
import { normEndpoint } from "./place"
import { NETS } from "../parts"

export interface WireSeg { net: string; a: XY; b: XY }

function mstEdges(pts: XY[]): [number, number][] {
  const n = pts.length
  if (n <= 1) return []
  const inTree = new Array(n).fill(false)
  const edges: [number, number][] = []
  inTree[0] = true
  for (let e = 0; e < n - 1; e++) {
    let best = Infinity, bi = -1, bj = -1
    for (let i = 0; i < n; i++) if (inTree[i]) {
      for (let j = 0; j < n; j++) if (!inTree[j]) {
        const d = Math.abs(pts[i][0] - pts[j][0]) + Math.abs(pts[i][1] - pts[j][1])
        if (d < best) { best = d; bi = i; bj = j }
      }
    }
    inTree[bj] = true
    edges.push([bi, bj])
  }
  return edges
}

export function buildWires(pinXY: Record<string, XY>): WireSeg[] {
  const segs: WireSeg[] = []
  for (const net of NETS) {
    const pts = net.endpoints.map(normEndpoint).map((n) => pinXY[n]).filter(Boolean) as XY[]
    for (const [i, j] of mstEdges(pts)) segs.push({ net: net.name, a: pts[i], b: pts[j] })
  }
  return segs
}

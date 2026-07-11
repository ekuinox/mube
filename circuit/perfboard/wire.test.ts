// circuit/perfboard/wire.test.ts
import { expect, test } from "bun:test"
import { buildWires } from "./wire"
import { resolvePlacement } from "./place"
import { NETS } from "../parts"

test("k 端点のネットは k-1 本の配線になる（全ネット合計）", () => {
  const p = resolvePlacement()
  const segs = buildWires(p.pinXY)
  const expected = NETS.reduce((s, n) => s + (n.endpoints.length - 1), 0)
  expect(segs.length).toBe(expected)
})

test("各配線は解決済みの穴同士を結ぶ（同一点で無い）", () => {
  const p = resolvePlacement()
  for (const s of buildWires(p.pinXY)) {
    expect(s.a).not.toEqual(s.b)
  }
})

test("各ネットの配線は全端点を連結する（1 連結成分）", () => {
  const p = resolvePlacement()
  const segs = buildWires(p.pinXY)
  for (const net of NETS) {
    const nodes = new Set(net.endpoints.map((e) => e.replace(/\./g, " ").trim().split(/\s+/).join(".")))
    if (nodes.size < 2) continue
    const netSegs = segs.filter((s) => s.net === net.name)
    // union-find で連結数を数える
    const parent = new Map<string, string>()
    const find = (x: string): string => { const p = parent.get(x) ?? x; if (p === x) return x; const r = find(p); parent.set(x, r); return r }
    const uni = (a: string, b: string) => { parent.set(find(a), find(b)) }
    for (const s of netSegs) uni(s.a.join(","), s.b.join(","))
    const roots = new Set([...nodes].map((n) => {
      const xy = p.pinXY[n]; return find(xy.join(","))
    }))
    expect(roots.size, `${net.name} not fully connected`).toBe(1)
  }
})

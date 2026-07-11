// circuit/perfboard/wire.test.ts
import { expect, test } from "bun:test"
import { buildWires } from "./wire"
import { resolvePlacement, normEndpoint } from "./place"
import { picoPinXY } from "./pico"
import type { XY } from "./board"
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
    // GND は Pico 内部で全 GND ピンが導通しており、図の配線は複数成分に分かれる（別途検証）。
    if (net.name === "GND") continue
    const nodes = new Set(net.endpoints.map(normEndpoint))
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

test("GND: 指定端点は指定の Pico GND ピンへ直結する", () => {
  const p = resolvePlacement()
  const segs = buildWires(p.pinXY)
  const gnd = segs.filter((s) => s.net === "GND")
  const has = (a: XY, b: XY) => gnd.some((s) =>
    (s.a.join() === a.join() && s.b.join() === b.join()) ||
    (s.a.join() === b.join() && s.b.join() === a.join()))
  expect(has(p.pinXY["D1.K"], picoPinXY(3))).toBe(true)       // LED → pin3
  expect(has(p.pinXY["SW1.pin2"], picoPinXY(8))).toBe(true)   // ボタン → pin8
})

test("解決済みピンが無ければ配線ゼロ（filter 経路）", () => {
  expect(buildWires({})).toEqual([])
})

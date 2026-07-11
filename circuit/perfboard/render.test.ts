// circuit/perfboard/render.test.ts
import { expect, test } from "bun:test"
import { renderPerfboardSvg } from "./render"
import { resolvePlacement } from "./place"
import { buildWires } from "./wire"

function svg() {
  const p = resolvePlacement()
  return renderPerfboardSvg(p, buildWires(p.pinXY))
}

test("妥当な SVG 文字列（root と viewBox）", () => {
  const s = svg()
  expect(s.startsWith("<svg")).toBe(true)
  expect(s).toContain("viewBox")
  expect(s.trimEnd().endsWith("</svg>")).toBe(true)
})

test("Pico 使用ピンの信号ラベルを含む", () => {
  const s = svg()
  expect(s).toContain("GP15")
  expect(s).toContain("VBUS")
})

test("部品 ref ラベルと配線 line を含む", () => {
  const s = svg()
  expect(s).toContain("M1")
  expect(s).toContain("D1")
  expect(s).toContain("<line")
})

test("軸目盛り（上=文字 A、左=数字 1）を含む", () => {
  const s = svg()
  expect(s).toContain(">A<")
  expect(s).toContain(">1<")
})

test("未解決ピンがあっても NaN 属性を出さない", () => {
  const p = resolvePlacement()
  delete p.pinXY["M1.SIG"]            // 故意に1ピン欠損
  const s = renderPerfboardSvg(p, [])
  expect(s).not.toContain("NaN")
})

test("極性(+)とカソード帯を描画する（既定配置）", () => {
  const p = resolvePlacement()
  const s = renderPerfboardSvg(p, buildWires(p.pinXY))
  expect(s).toContain(">+<")                    // C1 の +
  expect(s).toContain('stroke="#333"')          // D2 のカソード帯 line
})

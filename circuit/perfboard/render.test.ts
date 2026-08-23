// circuit/perfboard/render.test.ts
import { expect, test } from "bun:test"
import { COLS, ROWS } from "./board"
import { LAYOUT } from "./layout"
import { renderSvg, renderTable } from "./render"

// 目的: グリッドの穴が全部描かれること。描き漏らすと現物と数が合わなくなる。
test("SVG に全ての穴が描かれる", () => {
  const svg = renderSvg(LAYOUT)
  expect(svg.match(/class="hole"/g)?.length).toBe(COLS * ROWS)
})

// 目的: 配線が 1 本残らず描かれること。
test("SVG に全てのワイヤが描かれる", () => {
  const svg = renderSvg(LAYOUT)
  expect(svg.match(/class="wire"/g)?.length).toBe(LAYOUT.wires.length)
})

// 目的: 方位の凡例が対応表から描かれること。図だけ見て向きが分かる状態にする。
test("SVG に方位の凡例が入る", () => {
  const svg = renderSvg(LAYOUT)
  for (const word of ["右", "左", "上", "下"]) expect(svg).toContain(word)
  expect(svg).toContain("室内側から")
})

// 目的: 結線表が全ワイヤを穴 ID で並べること。半田付けはこの表を見て進める。
test("結線表に全てのワイヤが並ぶ", () => {
  const table = renderTable(LAYOUT)
  for (const w of LAYOUT.wires) expect(table).toContain(`| ${w.from} | ${w.to} |`)
})

// 目的: コミット済みの結線表が生成結果と一致すること。
// 配置を変えて再生成し忘れると、現物と文書がずれるのでここで落とす。
test("コミット済みの結線表が最新である", async () => {
  const committed = await Bun.file("../docs/perfboard-wiring.md").text()
  expect(committed).toBe(renderTable(LAYOUT))
})

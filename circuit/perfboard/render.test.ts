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

// 目的: 四辺の目盛りが全ての列と行に打たれること。
// 結線表は穴 ID（M12 など）で指示するので、目盛りが無いと図の上で場所を特定できない。
test("SVG に列と行の目盛りが入る", () => {
  const svg = renderSvg(LAYOUT)
  // 上下に列番号、左右に行 letter なので、それぞれ 2 本ずつ
  expect(svg.match(/class="ruler"/g)?.length).toBe((COLS + ROWS) * 2)
  expect(svg).toContain(`>${COLS}</text>`)
  expect(svg).toContain(`>${String.fromCharCode(64 + ROWS)}</text>`)
})

// 目的: 部品ラベルが互いに重ならないこと。
// 足ごとにラベルを振っていた版は密集地帯で読めなくなっていた。ここが落ちたら、
// 配置が詰まってラベルの置き場所が無くなったということ。
test("部品ラベルが重ならない", () => {
  const svg = renderSvg(LAYOUT)
  const boxes = [...svg.matchAll(
    /<text class="part-label" x="([\d.]+)" y="([\d.]+)" font-size="(\d+)"[^>]*>([^<]+)<\/text>/g)]
    .map((m) => {
      const [x, y, font, ref] = [Number(m[1]), Number(m[2]), Number(m[3]), m[4]]
      const w = ref.length * font * 0.65 + 6
      return { x1: x - w / 2, y1: y - font - 4, x2: x + w / 2, y2: y + 4 }
    })
  const parts = new Set(Object.keys(LAYOUT.legs).map((leg) => leg.split(".")[0]))
  expect(boxes.length).toBe(parts.size)
  for (let i = 0; i < boxes.length; i++)
    for (let j = i + 1; j < boxes.length; j++) {
      const [a, b] = [boxes[i], boxes[j]]
      expect(a.x1 < b.x2 && b.x1 < a.x2 && a.y1 < b.y2 && b.y1 < a.y2).toBe(false)
    }
})

// 目的: 被覆線が図の上で裸線と区別できること。表とだけ突き合わせずに済むようにする。
test("被覆線に縁取りが描かれる", () => {
  const svg = renderSvg(LAYOUT)
  const insulated = LAYOUT.wires.filter((w) => w.insulated).length
  expect(insulated).toBeGreaterThan(0)
  expect(svg.match(/class="sleeve"/g)?.length).toBe(insulated)
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

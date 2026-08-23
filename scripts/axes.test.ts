// scripts/axes.test.ts
import { expect, test } from "bun:test"
import { readdirSync, readFileSync, statSync } from "node:fs"
import { join } from "node:path"
import { AXIS_LABELS, VIEWPOINT, axisLabel, axisWithLabel, normaliseAxis } from "./axes"

// 目的: 全角マイナス（U+2212）と ASCII ハイフンを同じ軸として扱えること。
test("軸記号の表記ゆれを正規化する", () => {
  expect(normaliseAxis("−X")).toBe("-X")
  expect(axisLabel("−X")).toBe("左")
  expect(axisLabel("-X")).toBe("左")
})

// 目的: 併記の形（+X（右））を対応表から組み立てられること。
test("併記の文字列を組み立てる", () => {
  expect(axisWithLabel("+X")).toBe("+X（右）")
  expect(axisWithLabel("−Y")).toBe("−Y（下）")
})

// 目的: 未知の軸を黙って通さないこと。対応表に無い軸は綴り間違いなので落とす。
test("未知の軸は例外", () => {
  expect(() => axisLabel("+W")).toThrow()
})

// 併記のパターン。軸記号の直後に全角括弧が続くもの。
const ANNOTATION = /([+\-−±])([XYZ])（([^）]*)）/g
const DIRECTION_WORDS = new Set(Object.values(AXIS_LABELS))

function walk(dir: string, out: string[] = []): string[] {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name)
    if (statSync(p).isDirectory()) walk(p, out)
    else if (p.endsWith(".md") || p.endsWith(".scad")) out.push(p)
  }
  return out
}

const TARGETS = [...walk("docs"), ...walk("enclosure/models"), "README.md", "CLAUDE.md"]

// 目的: 文書に書かれた併記が対応表と一致すること。方向語を書いた併記だけを見る。
// 「+X（ヒンジ側）」のように方向語でない補足は、方位の主張ではないので対象外。
test("文書の方位の併記が対応表と一致する", () => {
  const wrong: string[] = []
  for (const file of TARGETS) {
    const text = readFileSync(file, "utf8")
    for (const m of text.matchAll(ANNOTATION)) {
      const [whole, sign, axis, inner] = m
      const head = inner.split("、")[0].trim()
      if (!DIRECTION_WORDS.has(head)) continue
      const expected = AXIS_LABELS[normaliseAxis(`${sign}${axis}`)]
      if (head !== expected) wrong.push(`${file}: ${whole} は ${expected} のはず`)
    }
  }
  expect(wrong).toEqual([])
})

// 目的: 併記のある文書が視点を宣言していること。視点が無いと左右が反転して読める。
test("方位を併記する文書は視点を宣言している", () => {
  const missing: string[] = []
  for (const file of TARGETS) {
    const text = readFileSync(file, "utf8")
    const hasDirection = [...text.matchAll(ANNOTATION)].some((m) =>
      DIRECTION_WORDS.has(m[3].split("、")[0].trim()))
    if (hasDirection && !text.includes(VIEWPOINT)) missing.push(file)
  }
  expect(missing).toEqual([])
})

// 目的: 対応表の根拠が params.scad に残っていること。
// 筐体の向きを変える改修が入ったら、ここが落ちて対応表の見直しを促す。
test("params.scad が −X と −Y の意味を保っている", () => {
  const scad = readFileSync("enclosure/models/params.scad", "utf8")
  expect(scad).toMatch(/clear_left\s*=\s*\d+;\s*\/\/\s*-X to door edge\/frame/)
  expect(scad).toMatch(/clear_down\s*=\s*\d+;\s*\/\/\s*-Y to door handle/)
})

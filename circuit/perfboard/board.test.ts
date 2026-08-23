// circuit/perfboard/board.test.ts
import { expect, test } from "bun:test"
import {
  COLS, ROWS, PIN_ROW_HIGH, PIN_ROW_LOW,
  holeId, holeXY, parseHole, pinHole, PICO_PIN_OF_LABEL,
} from "./board"

// 目的: ソケットの 2 列が 7 ピッチ離れ、かつ実在する行に乗ること。
test("ピン列は 7 ピッチ離れた実在の行に乗る", () => {
  expect(PIN_ROW_HIGH - PIN_ROW_LOW).toBe(7)
  for (const row of [PIN_ROW_LOW, PIN_ROW_HIGH]) {
    expect(Number.isInteger(row)).toBe(true)
    expect(row >= 1 && row <= ROWS).toBe(true)
  }
})

// 目的: 実測したグリッドの寸法を固定すること。最上段は O 行で、P 行は無い。
// ここが変わったら決定 2 の座標と #90 の高さ予算をすべて引き直す必要がある。
test("グリッドは実測どおり 25 列 15 行", () => {
  expect([COLS, ROWS]).toEqual([25, 15])
  expect(holeId({ col: 1, row: ROWS })).toBe("O1")
})

// 目的: 行数が奇数なので Pico が中心から半ピッチずれること自体を記録する。
// このずれは #90 の「ソケット列は y = ±8.89」という記述を無効にしている。
test("Pico はグリッド中心から半ピッチ +Y へ寄る", () => {
  const low = holeXY(pinHole(21)).y
  const high = holeXY(pinHole(1)).y
  expect(low).toBeCloseTo(-7.62, 2)
  expect(high).toBeCloseTo(10.16, 2)
  expect((low + high) / 2).toBeCloseTo(1.27, 2)
})

// 目的: 40 ピンすべてがグリッドの内側に収まること。
test("全ヘッダピンがグリッドに収まる", () => {
  for (let pin = 1; pin <= 40; pin++) {
    const h = pinHole(pin)
    expect(h.col >= 1 && h.col <= COLS).toBe(true)
    expect(h.row >= 1 && h.row <= ROWS).toBe(true)
  }
})

// 目的: pin1 と pin40 が同じ列（USB 側の端）に、pin20 と pin21 が同じ列に来ること。
test("向かい合うピンが同じ列に来る", () => {
  expect(pinHole(1).col).toBe(pinHole(40).col)
  expect(pinHole(20).col).toBe(pinHole(21).col)
})

// 目的: 新しい割当のピンが設計書どおりの穴に来ること。
test("割当済みのピンが設計書の穴に一致する", () => {
  expect(holeId(pinHole(PICO_PIN_OF_LABEL.GP9))).toBe("L12")
  expect(holeId(pinHole(PICO_PIN_OF_LABEL.GP10))).toBe("L14")
  expect(holeId(pinHole(PICO_PIN_OF_LABEL.GP5))).toBe("L7")
  expect(holeId(pinHole(PICO_PIN_OF_LABEL.GP22))).toBe("E12")
  expect(holeId(pinHole(PICO_PIN_OF_LABEL.GP20))).toBe("E15")
  expect(holeId(pinHole(PICO_PIN_OF_LABEL.VBUS))).toBe("E1")
})

// 目的: 穴 ID と座標の往復が壊れないこと。
test("穴 ID の往復と mm 変換", () => {
  expect(parseHole("L12")).toEqual({ col: 12, row: 12 })
  expect(holeId({ col: 12, row: 12 })).toBe("L12")
  const { x, y } = holeXY(pinHole(29))
  expect(x).toBeCloseTo(2.54, 2)
  expect(y).toBeCloseTo(-7.62, 2)
})

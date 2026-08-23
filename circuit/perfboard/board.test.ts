// circuit/perfboard/board.test.ts
import { expect, test } from "bun:test"
import {
  COLS, ROWS, PIN_ROW_HIGH, PIN_ROW_LOW,
  holeId, holeXY, parseHole, pinHole, PICO_PIN_OF_LABEL,
} from "./board"

// 目的: ソケットの 2 列が 7 ピッチ離れ、かつ穴の上に乗ること。
// 行数が奇数だとこの条件を満たせないので、グリッドの仮定が壊れたらここで落ちる。
test("ピン列は 7 ピッチ離れた整数行に乗る", () => {
  expect(PIN_ROW_HIGH - PIN_ROW_LOW).toBe(7)
  expect(Number.isInteger(PIN_ROW_LOW)).toBe(true)
  expect(Number.isInteger(PIN_ROW_HIGH)).toBe(true)
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
  expect(y).toBeCloseTo(-8.89, 2)
})

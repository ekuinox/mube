// circuit/perfboard/board.test.ts
import { expect, test } from "bun:test"
import { BOARD, PICO_ANCHOR, PICO_ROW_SPAN_HOLES, inBounds, key, rotate } from "./board"

test("盤面既定は 18 x 28、Pico 定数は実測値", () => {
  expect(BOARD).toEqual({ width: 18, height: 28 })
  expect(PICO_ANCHOR).toEqual([3, 2])
  expect(PICO_ROW_SPAN_HOLES).toBe(7)
})

test("inBounds は 0..width-1 / 0..height-1", () => {
  expect(inBounds([0, 0])).toBe(true)
  expect(inBounds([17, 27])).toBe(true)
  expect(inBounds([18, 0])).toBe(false)
  expect(inBounds([0, 28])).toBe(false)
  expect(inBounds([-1, 0])).toBe(false)
})

test("key は 'x,y'", () => {
  expect(key([3, 21])).toBe("3,21")
})

test("rotate は時計回り(y下向き)", () => {
  expect(rotate([3, 0], 0)).toEqual([3, 0])
  expect(rotate([3, 0], 90)).toEqual([0, 3])
  expect(rotate([3, 0], 180)).toEqual([-3, 0])
  expect(rotate([3, 0], 270)).toEqual([0, -3])
})

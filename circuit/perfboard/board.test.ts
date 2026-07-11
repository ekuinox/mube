// circuit/perfboard/board.test.ts
import { expect, test } from "bun:test"
import { BOARD, PICO_ANCHOR, PICO_ROW_SPAN_HOLES, inBounds, isUnusable, key, rotate } from "./board"

test("盤面既定は 15 x 25(O25)、Pico 定数は実測値", () => {
  expect(BOARD).toEqual({ width: 15, height: 25 })
  expect(PICO_ANCHOR).toEqual([4, 3])
  expect(PICO_ROW_SPAN_HOLES).toBe(7)
})

test("inBounds は 0..width-1 / 0..height-1", () => {
  expect(inBounds([0, 0])).toBe(true)
  expect(inBounds([14, 24])).toBe(true)
  expect(inBounds([15, 0])).toBe(false)
  expect(inBounds([0, 25])).toBe(false)
  expect(inBounds([-1, 0])).toBe(false)
})

test("四隅は使用不可、それ以外は使用可", () => {
  expect(isUnusable([0, 0])).toBe(true)
  expect(isUnusable([14, 0])).toBe(true)
  expect(isUnusable([0, 24])).toBe(true)
  expect(isUnusable([14, 24])).toBe(true)
  expect(isUnusable([1, 0])).toBe(false)
  expect(isUnusable([4, 3])).toBe(false)   // Pico GP0=E4
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

// circuit/perfboard/pico.test.ts
import { expect, test } from "bun:test"
import { picoPinXY, picoSignalXY, picoAllPinsXY, PICO_PIN_NUMBER } from "./pico"

test("実測アンカーと一致: GP0=物理1=(4,3)=E4, 左列末=物理20=(4,22)", () => {
  expect(picoPinXY(1)).toEqual([4, 3])
  expect(picoPinXY(20)).toEqual([4, 22])
})

test("右列: GP16=物理21=(11,22), VBUS=物理40=(11,3)", () => {
  expect(picoPinXY(21)).toEqual([11, 22])
  expect(picoPinXY(40)).toEqual([11, 3])
})

test("使用信号→穴（parts.ts の U1 ピン名）", () => {
  expect(PICO_PIN_NUMBER).toEqual({ VBUS: 40, GND: 23, GP16: 21, GP17: 22, GP2: 4, GP5: 7, GP3: 5 })
  expect(picoSignalXY("GP2")).toEqual([4, 6])    // LED_DRV_R
  expect(picoSignalXY("GP3")).toEqual([4, 7])    // BTN
  expect(picoSignalXY("GP5")).toEqual([4, 9])    // LED_DRV_G
  expect(picoSignalXY("GP16")).toEqual([11, 22]) // SERVO_SIG
  expect(picoSignalXY("GP17")).toEqual([11, 21]) // GATE_DRV
  expect(picoSignalXY("GND")).toEqual([11, 20])
  expect(picoSignalXY("VBUS")).toEqual([11, 3])
})

test("picoAllPinsXY は 40 個・重複なし", () => {
  const all = picoAllPinsXY()
  expect(all.length).toBe(40)
  expect(new Set(all.map((p) => p.join(","))).size).toBe(40)
})

test("未知信号は例外", () => {
  expect(() => picoSignalXY("GP99")).toThrow()
})

// circuit/perfboard/pico.test.ts
import { expect, test } from "bun:test"
import { picoPinXY, picoSignalXY, picoAllPinsXY, PICO_PIN_NUMBER } from "./pico"

test("実測アンカーと一致: GP0=物理1=(3,2)=D3, 左列末=物理20=(3,21)", () => {
  expect(picoPinXY(1)).toEqual([3, 2])
  expect(picoPinXY(20)).toEqual([3, 21])
})

test("右列: GP16=物理21=(10,21), VBUS=物理40=(10,2)", () => {
  expect(picoPinXY(21)).toEqual([10, 21])
  expect(picoPinXY(40)).toEqual([10, 2])
})

test("使用信号→穴（parts.ts の U1 ピン名）", () => {
  expect(PICO_PIN_NUMBER).toEqual({ VBUS: 40, GND: 23, GP16: 21, GP17: 22, GP2: 4, GP5: 7, GP3: 5 })
  expect(picoSignalXY("GP2")).toEqual([3, 5])    // LED_DRV_R
  expect(picoSignalXY("GP3")).toEqual([3, 6])    // BTN
  expect(picoSignalXY("GP5")).toEqual([3, 8])    // LED_DRV_G
  expect(picoSignalXY("GP16")).toEqual([10, 21]) // SERVO_SIG
  expect(picoSignalXY("GP17")).toEqual([10, 20]) // GATE_DRV
  expect(picoSignalXY("GND")).toEqual([10, 19])
  expect(picoSignalXY("VBUS")).toEqual([10, 2])
})

test("picoAllPinsXY は 40 個・重複なし", () => {
  const all = picoAllPinsXY()
  expect(all.length).toBe(40)
  expect(new Set(all.map((p) => p.join(","))).size).toBe(40)
})

test("未知信号は例外", () => {
  expect(() => picoSignalXY("GP99")).toThrow()
})

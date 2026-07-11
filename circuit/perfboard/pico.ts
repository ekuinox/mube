// circuit/perfboard/pico.ts
// Pico W(2×20, 2.54mm, ブレッドボード互換)のピン→盤面穴写像。
// 物理ピン番号は DIP 式（左列 上→下 1..20、右列 下→上 21..40）。
import { PICO_ANCHOR, PICO_ROW_SPAN_HOLES, type XY } from "./board"

// 物理ピン番号(1..40) → 盤面 XY
export function picoPinXY(pin: number): XY {
  const [ax, ay] = PICO_ANCHOR
  if (pin < 1 || pin > 40) throw new Error(`pico pin out of range: ${pin}`)
  if (pin <= 20) return [ax, ay + (pin - 1)]              // 左列 上→下
  return [ax + PICO_ROW_SPAN_HOLES, ay + (40 - pin)]      // 右列 下→上（21→+19, 40→+0）
}

// parts.ts の U1 ピン名 → 物理ピン番号（本回路で使う 7 本）
// LED/ボタン=左列(GP2/GP3/GP5)、サーボ=右列(GP16/GP17)。GND は代表を pin23 とし、
// 実配線では最寄り/指定の GND ピンへ落とす（Pico 内部で全 GND ピンは導通）。
export const PICO_PIN_NUMBER: Record<string, number> = {
  VBUS: 40, GND: 23, GP16: 21, GP17: 22, GP2: 4, GP5: 7, GP3: 5,
}

// Pico の全 GND 物理ピン（内部で相互導通）。個別 GND 落とし先の検証に使う。
export const PICO_GND_PINS: number[] = [3, 8, 13, 18, 23, 28, 38]

export function picoSignalXY(signal: string): XY {
  const pin = PICO_PIN_NUMBER[signal]
  if (pin === undefined) throw new Error(`unknown Pico signal: ${signal}`)
  return picoPinXY(pin)
}

export function picoAllPinsXY(): XY[] {
  const out: XY[] = []
  for (let p = 1; p <= 40; p++) out.push(picoPinXY(p))
  return out
}

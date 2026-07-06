// circuit/breadboard/autolayout.test.ts
import { expect, test } from "bun:test"
import { autoLayout } from "./autolayout"
import { PRESETS } from "./subcircuit"

for (const name of ["SERVO_DRIVE", "LED_BUTTON", "FULL"]) {
  test(`${name}: 自動レイアウトが電気検証を通る`, () => {
    const layout = autoLayout(PRESETS[name])
    // autoLayout 内部で verify 済み（失敗なら throw）。ここでは形の健全性を確認。
    expect(Object.keys(layout.components).length).toBeGreaterThan(0)
    expect(layout.jumpers.length).toBeGreaterThan(0)
    expect(layout.stats.cols).toBeGreaterThan(0)
  })
}

test("決定的: 同入力・同seedで同一出力", () => {
  const a = autoLayout(PRESETS.SERVO_DRIVE, 7)
  const b = autoLayout(PRESETS.SERVO_DRIVE, 7)
  expect(JSON.stringify(a)).toBe(JSON.stringify(b))
})

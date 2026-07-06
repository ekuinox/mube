// circuit/breadboard/subcircuit.test.ts
import { expect, test } from "bun:test"
import { normaliseEndpoint, subcircuitNets, PRESETS } from "./subcircuit"

test("normaliseEndpoint", () => {
  expect(normaliseEndpoint(".U1 .VBUS")).toBe("U1.VBUS")
  expect(normaliseEndpoint(".D2 .cathode")).toBe("D2.cathode")
  expect(normaliseEndpoint(".Rg .pin1")).toBe("Rg.pin1")
})

test("SERVO_DRIVE サブ回路が期待の6ネットを抽出", () => {
  const nets = subcircuitNets(new Set(PRESETS.SERVO_DRIVE))
  expect(nets).toEqual({
    V5:        ["C1.pin1", "C2.pin1", "D2.cathode", "M1.VPLUS", "U1.VBUS"],
    GND:       ["C1.pin2", "C2.pin2", "Q1.S", "Rgs.pin2", "U1.GND"],
    SERVO_RTN: ["D2.anode", "M1.GND", "Q1.D"],
    SERVO_SIG: ["M1.SIG", "U1.GP15"],
    GATE_DRV:  ["Rg.pin1", "U1.GP14"],
    GATE:      ["Q1.G", "Rg.pin2", "Rgs.pin1"],
  })
})

test("FULL は全12部品を含む", () => {
  expect(new Set(PRESETS.FULL)).toEqual(
    new Set(["U1","M1","Q1","Rg","Rgs","Rled","Rled2","D1","SW1","C1","C2","D2"]))
  // LED/ボタン系ネットも現れる（例: BTN は SW1+U1.GP17）
  const nets = subcircuitNets(new Set(PRESETS.FULL))
  expect(nets.BTN.sort()).toEqual(["SW1.pin1", "U1.GP17"])
})

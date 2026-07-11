// circuit/parts.ts
// 部品と結線（ネット）の唯一の定義。回路図(index.tsx)とブレッドボードツール(breadboard/)が共有する。
export type PartKind = "chip" | "resistor" | "capacitor" | "diode" | "pushbutton"

export interface PartSpec {
  ref: string
  kind: PartKind
  pinLabels?: Record<string, string> // chip のみ
  props?: Record<string, any>        // resistance / capacitance / polarized など
}

export const PARTS: PartSpec[] = [
  { ref: "U1", kind: "chip", pinLabels: { pin1: "VBUS", pin2: "GND", pin3: "GP16", pin4: "GP17", pin5: "GP2", pin6: "GP3", pin7: "GP5" } },
  { ref: "M1", kind: "chip", pinLabels: { pin1: "SIG", pin2: "VPLUS", pin3: "GND" } },
  { ref: "Q1", kind: "chip", pinLabels: { pin1: "G", pin2: "D", pin3: "S" } },
  { ref: "Rg", kind: "resistor", props: { resistance: "220" } },
  { ref: "Rgs", kind: "resistor", props: { resistance: "10k" } },
  { ref: "Rled", kind: "resistor", props: { resistance: "330" } },
  { ref: "Rled2", kind: "resistor", props: { resistance: "330" } },
  { ref: "D1", kind: "chip", pinLabels: { pin1: "R", pin2: "G", pin3: "K" } },
  { ref: "SW1", kind: "pushbutton" },
  { ref: "C1", kind: "capacitor", props: { capacitance: "470uF", polarized: true } },
  { ref: "C2", kind: "capacitor", props: { capacitance: "100nF" } },
  { ref: "D2", kind: "diode" },
]

// ネット名 → 接続端点（tscircuit trace セレクタ）。結線の唯一の正。
export const NETS: { name: string; endpoints: string[] }[] = [
  { name: "V5", endpoints: [".U1 .VBUS", ".C1 .pin1", ".M1 .VPLUS", ".C2 .pin1", ".D2 .cathode"] },
  { name: "GND", endpoints: [".U1 .GND", ".C1 .pin2", ".Q1 .S", ".Rgs .pin2", ".D1 .K", ".SW1 .pin2", ".C2 .pin2"] },
  { name: "SERVO_RTN", endpoints: [".M1 .GND", ".Q1 .D", ".D2 .anode"] },
  { name: "SERVO_SIG", endpoints: [".U1 .GP16", ".M1 .SIG"] },
  { name: "GATE_DRV", endpoints: [".U1 .GP17", ".Rg .pin1"] },
  { name: "GATE", endpoints: [".Rg .pin2", ".Q1 .G", ".Rgs .pin1"] },
  { name: "LED_DRV_R", endpoints: [".U1 .GP2", ".Rled .pin1"] },
  { name: "LED_A_R", endpoints: [".Rled .pin2", ".D1 .R"] },
  { name: "LED_DRV_G", endpoints: [".U1 .GP3", ".Rled2 .pin1"] },
  { name: "LED_A_G", endpoints: [".Rled2 .pin2", ".D1 .G"] },
  { name: "BTN", endpoints: [".U1 .GP5", ".SW1 .pin1"] },
]

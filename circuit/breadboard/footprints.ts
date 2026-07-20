// circuit/breadboard/footprints.ts
export type EdgeAffinity = "left" | "right" | null

export interface Footprint {
  pinOrder: string[]       // 正規ピン順（pin名のみ、refは付けない）
  edgeAffinity: EdgeAffinity
  label: string
  value?: string
  polarityPin?: string     // pin名（"+"を描く）
  stripePin?: string       // pin名（カソード帯）
}

// ref → Footprint。mube 全12部品を網羅。
export const FOOTPRINTS: Record<string, Footprint> = {
  U1:   { pinOrder: ["VBUS", "GND", "GP15", "GP14", "GP16", "GP18", "GP17"], edgeAffinity: "left",  label: "U1",  value: "Pico W" },
  M1:   { pinOrder: ["SIG", "VPLUS", "GND"], edgeAffinity: "right", label: "M1",  value: "Servo" },
  Q1:   { pinOrder: ["G", "D", "S"], edgeAffinity: null, label: "Q1",  value: "MOSFET" },
  Rg:   { pinOrder: ["pin1", "pin2"], edgeAffinity: null, label: "Rg",  value: "220Ω" },
  Rgs:  { pinOrder: ["pin1", "pin2"], edgeAffinity: null, label: "Rgs", value: "10kΩ" },
  Rled: { pinOrder: ["pin1", "pin2"], edgeAffinity: null, label: "Rled", value: "330Ω" },
  Rled2:{ pinOrder: ["pin1", "pin2"], edgeAffinity: null, label: "Rled2", value: "330Ω" },
  D1:   { pinOrder: ["R", "G", "K"], edgeAffinity: "right", label: "D1",  value: "2-LED" },
  SW1:  { pinOrder: ["pin1", "pin2"], edgeAffinity: "right", label: "SW1", value: "Tact" },
  C1:   { pinOrder: ["pin1", "pin2"], edgeAffinity: null, label: "C1",  value: "470uF", polarityPin: "pin1" },
  C2:   { pinOrder: ["pin1", "pin2"], edgeAffinity: null, label: "C2",  value: "100nF" },
  D2:   { pinOrder: ["cathode", "anode"], edgeAffinity: null, label: "D2", value: "Flyback", stripePin: "cathode" },
}

// circuit/perfboard/footprints.ts
// U1 以外の部品フットプリント。pin1(先頭)をアンカー[0,0]とする相対オフセット。
// ピン名は parts.ts の NETS endpoint と一致させる（例 D2 は cathode/anode）。
import type { XY } from "./board"

export interface PerfFootprint {
  pins: { name: string; off: XY }[]
  label: string
  value?: string
  polarityPin?: string   // "+" を描くピン名
  stripePin?: string     // カソード帯を描くピン名
}

const line3 = (a: string, b: string, c: string): { name: string; off: XY }[] => [
  { name: a, off: [0, 0] }, { name: b, off: [1, 0] }, { name: c, off: [2, 0] },
]
const span = (a: string, b: string, n: number): { name: string; off: XY }[] => [
  { name: a, off: [0, 0] }, { name: b, off: [n, 0] },
]

export const FOOTPRINTS: Record<string, PerfFootprint> = {
  M1:    { pins: line3("SIG", "VPLUS", "GND"), label: "M1", value: "Servo" },
  Q1:    { pins: line3("G", "D", "S"), label: "Q1", value: "MOSFET(TO-92)" },
  Rg:    { pins: span("pin1", "pin2", 3), label: "Rg", value: "220Ω" },
  Rgs:   { pins: span("pin1", "pin2", 3), label: "Rgs", value: "10kΩ" },
  Rled:  { pins: span("pin1", "pin2", 3), label: "Rled", value: "330Ω" },
  Rled2: { pins: span("pin1", "pin2", 3), label: "Rled2", value: "330Ω" },
  // 二色コモンカソード: カソード(K)が中央。実配置は G-K-R の並び。
  D1:    { pins: line3("G", "K", "R"), label: "D1", value: "2色LED" },
  // タクトは対角の 2 端子を使用。実配置は 2 列 x 3 行ずれた対角。
  SW1:   { pins: [{ name: "pin1", off: [0, 0] }, { name: "pin2", off: [2, 3] }], label: "SW1", value: "Tact(対角)" },
  C1:    { pins: span("pin1", "pin2", 1), label: "C1", value: "470uF", polarityPin: "pin1" },
  C2:    { pins: span("pin1", "pin2", 1), label: "C2", value: "100nF" },
  D2:    { pins: span("cathode", "anode", 2), label: "D2", value: "フライバック", stripePin: "cathode" },
}

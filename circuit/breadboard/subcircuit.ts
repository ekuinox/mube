// circuit/breadboard/subcircuit.ts
import { NETS } from "../parts"

export function normaliseEndpoint(ep: string): string {
  return ep.replace(/\./g, " ").trim().split(/\s+/).join(".")
}

// 部品ref集合 → ネット名→ソート済み "Ref.pin" 配列。選択部品の端点のみ、端点2未満は除外。
export function subcircuitNets(parts: Set<string>): Record<string, string[]> {
  const result: Record<string, string[]> = {}
  for (const net of NETS) {
    const filtered = net.endpoints
      .map(normaliseEndpoint)
      .filter((ep) => parts.has(ep.split(".")[0]))
      .sort()
    if (filtered.length >= 2) result[net.name] = filtered
  }
  return result
}

export const PRESETS: Record<string, string[]> = {
  SERVO_DRIVE: ["U1", "M1", "Q1", "Rg", "Rgs", "C1", "C2", "D2"],
  LED_BUTTON:  ["U1", "Rled", "Rled2", "D1", "SW1"],
  FULL:        ["U1", "M1", "Q1", "Rg", "Rgs", "Rled", "Rled2", "D1", "SW1", "C1", "C2", "D2"],
}

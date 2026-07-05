// circuit/parts.test.ts
import { expect, test } from "bun:test"
import { buildCircuitJson } from "./netlist"

// 現行 index.tsx の結線を明示的にピン留め（ネット名 → 接続ポート "Ref.pin" のソート済み集合）。
// リファクタ後もこの写像が一致することを不変条件とする。
export const EXPECTED_NETS: Record<string, string[]> = {
  V5: ["C1.pin1", "C2.pin1", "D2.pin2", "M1.VPLUS", "U1.VBUS"],
  GND: ["C1.pin2", "C2.pin2", "D1.K", "Q1.S", "Rgs.pin2", "SW1.pin2", "U1.GND"],
  SERVO_RTN: ["D2.pin1", "M1.GND", "Q1.D"],
  SERVO_SIG: ["M1.SIG", "U1.GP15"],
  GATE_DRV: ["Rg.pin1", "U1.GP14"],
  GATE: ["Q1.G", "Rg.pin2", "Rgs.pin1"],
  LED_DRV_R: ["Rled.pin1", "U1.GP16"],
  LED_A_R: ["D1.R", "Rled.pin2"],
  LED_DRV_G: ["Rled2.pin1", "U1.GP18"],
  LED_A_G: ["D1.G", "Rled2.pin2"],
  BTN: ["SW1.pin1", "U1.GP17"],
}

// circuit JSON から「ネット名 → 接続ポート集合」を接続キー経由で復元するヘルパ。
function netMap(circuitJson: any[]): Record<string, string[]> {
  const compName: Record<string, string> = {}
  for (const e of circuitJson)
    if (e.type === "source_component") compName[e.source_component_id] = e.name
  const label = (p: any) =>
    `${compName[p.source_component_id] ?? p.source_component_id}.${p.name}`
  const ports = circuitJson.filter((e) => e.type === "source_port")
  const nets = circuitJson.filter((e) => e.type === "source_net")
  const portsByKey: Record<string, string[]> = {}
  for (const p of ports)
    if (p.subcircuit_connectivity_map_key != null)
      (portsByKey[p.subcircuit_connectivity_map_key] ??= []).push(label(p))
  const out: Record<string, string[]> = {}
  for (const n of nets)
    if (n.subcircuit_connectivity_map_key != null)
      out[n.name] = [...new Set(portsByKey[n.subcircuit_connectivity_map_key] ?? [])].sort()
  return out
}

test("index.tsx の結線が EXPECTED_NETS と一致", async () => {
  const cj = await buildCircuitJson()
  expect(netMap(cj)).toEqual(EXPECTED_NETS)
}, 30_000)

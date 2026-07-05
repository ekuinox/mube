// circuit/board.test.tsx
import { expect, test } from "bun:test"
import { buildBoardCircuitJson } from "./board"
import { runErc } from "./erc"
import { ALLOW_UNCONNECTED } from "./netlist"
import { EXPECTED_NETS } from "./parts.test"

function netMap(circuitJson: any[]): Record<string, string[]> {
  const compName: Record<string, string> = {}
  for (const e of circuitJson)
    if (e.type === "source_component") compName[e.source_component_id] = e.name
  const label = (p: any) => `${compName[p.source_component_id] ?? p.source_component_id}.${p.name}`
  const ports = circuitJson.filter((e) => e.type === "source_port")
  const nets = circuitJson.filter((e) => e.type === "source_net")
  const byKey: Record<string, string[]> = {}
  for (const p of ports)
    if (p.subcircuit_connectivity_map_key != null)
      (byKey[p.subcircuit_connectivity_map_key] ??= []).push(label(p))
  const out: Record<string, string[]> = {}
  for (const n of nets)
    if (n.subcircuit_connectivity_map_key != null)
      out[n.name] = [...new Set(byKey[n.subcircuit_connectivity_map_key] ?? [])].sort()
  return out
}

test("board.tsx の結線が回路図(EXPECTED_NETS)と一致", async () => {
  expect(netMap(await buildBoardCircuitJson())).toEqual(EXPECTED_NETS)
}, 60_000)

test("board.tsx が ERC を通る", async () => {
  expect(runErc(await buildBoardCircuitJson(), { allowUnconnected: ALLOW_UNCONNECTED })).toEqual([])
}, 60_000)

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

test("board.tsx に無効フットプリント等のエラーが無い", async () => {
  // source_invalid_component_property_error: フットプリント文字列が footprinter に
  // 受け入れられないと発生し、部品が PCB から無言で消える。これをガードする。
  const cj = await buildBoardCircuitJson()
  const errs = cj.filter(
    (e) => typeof e.type === "string" && e.type === "source_invalid_component_property_error",
  )
  expect(errs.map((e: any) => e.type + ": " + (e.message ?? ""))).toEqual([])
}, 60_000)

test("board.tsx に courtyard 重なりが無い", async () => {
  // pcb_courtyard_overlap_error: 部品の courtyard が重なると発生する。
  // 物理実装ガイドとして重なりは許容できないため、ゼロを保証する。
  const cj = await buildBoardCircuitJson()
  const errs = cj.filter(
    (e) => typeof e.type === "string" && e.type === "pcb_courtyard_overlap_error",
  )
  expect(errs.map((e: any) => e.message ?? e.pcb_error_id)).toEqual([])
}, 60_000)

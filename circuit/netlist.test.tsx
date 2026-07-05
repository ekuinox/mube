import { expect, test } from "bun:test"
import { buildCircuitJson } from "./netlist"
import { runErc } from "./erc"

test("本番回路 (index.tsx) が ERC を通る", async () => {
  const cj = await buildCircuitJson()
  expect(runErc(cj)).toEqual([])
}, 30_000)

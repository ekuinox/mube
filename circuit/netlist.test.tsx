import { expect, test } from "bun:test"
import { ercRealBoard } from "./netlist"

test("本番回路 (index.tsx) が ERC を通る", async () => {
  expect(await ercRealBoard()).toEqual([])
}, 30_000)

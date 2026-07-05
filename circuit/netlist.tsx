import { RootCircuit } from "tscircuit"
import Board from "./index"
import { runErc } from "./erc"

// index.tsx の本番配線を circuit JSON へ描画する。
export async function buildCircuitJson(): Promise<any[]> {
  const circuit = new RootCircuit()
  circuit.add(<Board />)
  await circuit.renderUntilSettled()
  return circuit.getCircuitJson() as any[]
}

// 直接実行時は ERC を回し、違反があれば exit 1。
if (import.meta.main) {
  const errors = runErc(await buildCircuitJson())
  if (errors.length) {
    for (const e of errors) console.error(`ERC: ${e}`)
    process.exit(1)
  }
  console.log("ERC passed: 導通 OK / ショート無し")
}

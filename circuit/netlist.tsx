import { RootCircuit } from "tscircuit"
import Board from "./index"
import { runErc } from "./erc"

// 本番配線で意図的に未接続のピン（tactile switch SW1 の未使用重複パッド）。
export const ALLOW_UNCONNECTED = ["SW1.pin3", "SW1.pin4"]

// index.tsx の本番配線を circuit JSON へ描画する。
export async function buildCircuitJson(): Promise<any[]> {
  const circuit = new RootCircuit()
  circuit.add(<Board />)
  await circuit.renderUntilSettled()
  return circuit.getCircuitJson() as any[]
}

// 本番配線を描画して ERC を回す（盤固有の未接続許容ピンを渡す）。
export async function ercRealBoard(): Promise<string[]> {
  return runErc(await buildCircuitJson(), { allowUnconnected: ALLOW_UNCONNECTED })
}

// 直接実行時は ERC を回し、違反があれば exit 1。
if (import.meta.main) {
  const errors = await ercRealBoard()
  if (errors.length) {
    for (const e of errors) console.error(`ERC: ${e}`)
    process.exit(1)
  }
  console.log("ERC passed: 導通 OK / ショート無し")
}

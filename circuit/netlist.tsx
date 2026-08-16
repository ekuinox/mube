import { RootCircuit } from "tscircuit"
import Board from "./index"
import { runErc } from "./erc"

// 本番配線で意図的に未接続のピン。SW1 の実物はパネル取付の PS21B-1（2 端子）で
// 基板外に付き、基板とは 2pin コネクタで繋がる。それでもネットリスト上のシンボルは
// 4 パッドの押しボタンのまま意図的に据え置いてある（tscircuit の ERC が見るのは
// 導通だけなので、フットプリントを差し替えても検証結果は 1 ビットも変わらない。
// 設計書の Ruling 15）。よって pin3/pin4 は未接続のまま許容する。
export const ALLOW_UNCONNECTED = ["SW1.pin3", "SW1.pin4"]

// index.tsx の本番配線を circuit JSON へ描画する。
export async function buildCircuitJson(): Promise<any[]> {
  const circuit = new RootCircuit()
  circuit.add(<Board />)
  await circuit.renderUntilSettled()
  return circuit.getCircuitJson() as any[]
}

// 本番配線を描画して ERC を回す（盤固有の未接続許容ピンを渡す）。
// CLI 実行部（bun 直接実行の判定）は check.ts に分離してある。そのモジュール判定構文を
// ここに置くと tscircuit のブラウザビューア（tsci dev）の eval が
// "Cannot use ... outside a module" で落ちるため、本ファイルは副作用の無い純モジュールに保つ。
export async function ercRealBoard(): Promise<string[]> {
  return runErc(await buildCircuitJson(), { allowUnconnected: ALLOW_UNCONNECTED })
}

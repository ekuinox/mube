// circuit/wiring-pcb.ts
// ②：物理版 board を PCB SVG（build/wiring-pcb.svg）にする。実装ガイドの評価用。
// `bun wiring-pcb.ts` で生成。build/ 配下は非コミットの派生物。
import { convertCircuitJsonToPcbSvg } from "circuit-to-svg"
import { mkdirSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { buildBoardCircuitJson } from "./board"

const OUT = join(import.meta.dir, "..", "build", "wiring-pcb.svg")

export async function generateWiringPcbSvg(): Promise<string> {
  const svg = convertCircuitJsonToPcbSvg(await buildBoardCircuitJson())
  mkdirSync(dirname(OUT), { recursive: true })
  writeFileSync(OUT, svg)
  return svg
}

if (import.meta.main) {
  await generateWiringPcbSvg()
  console.log(`wrote ${OUT}`)
}

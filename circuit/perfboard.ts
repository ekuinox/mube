// circuit/perfboard.ts
// 使い方: bun perfboard.ts  → build/perfboard.svg を出力
import { mkdirSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { resolvePlacement } from "./perfboard/place"
import { buildWires } from "./perfboard/wire"
import { renderPerfboardSvg } from "./perfboard/render"

const p = resolvePlacement()
if (p.errors.length) {
  for (const e of p.errors) console.error("ERROR:", e)
  process.exit(1)
}
const svg = renderPerfboardSvg(p, buildWires(p.pinXY))
const out = join(import.meta.dir, "..", "build", "perfboard.svg")
mkdirSync(dirname(out), { recursive: true })
writeFileSync(out, svg)
console.log(`wrote ${out} (holes used: ${p.occupied.size})`)

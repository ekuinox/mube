// circuit/breadboard-auto.ts
// 使い方: bun breadboard-auto.ts <PRESET名 | ref,ref,...>  （既定 SERVO_DRIVE）
import { mkdirSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { autoLayout } from "./breadboard/autolayout"
import { renderBreadboardSvg } from "./breadboard/render"
import { PRESETS } from "./breadboard/subcircuit"

const arg = process.argv[2] ?? "SERVO_DRIVE"
const refs = PRESETS[arg] ?? arg.split(",").map((s) => s.trim()).filter(Boolean)
const name = arg in PRESETS ? arg.toLowerCase() : "custom"

const layout = autoLayout(refs)
const svg = renderBreadboardSvg(layout)
const out = join(import.meta.dir, "build", "breadboard-" + name + ".svg")
mkdirSync(dirname(out), { recursive: true })
writeFileSync(out, svg)
console.log(`wrote ${out} (crossings=${layout.stats.crossings}, lanes=${layout.stats.tracksUsed}, cols=${layout.stats.cols})`)

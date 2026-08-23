// circuit/perfboard-build.ts
// 配線見本を書き出す。SVG は派生物（非コミット）、結線表はコミットする。
import { mkdirSync, writeFileSync } from "node:fs"
import { LAYOUT } from "./perfboard/layout"
import { renderSvg, renderTable } from "./perfboard/render"
import { verifyLayout } from "./perfboard/verify"

const problems = verifyLayout(LAYOUT)
if (problems.length) {
  console.error(problems.join("\n"))
  process.exit(1)
}

mkdirSync("build", { recursive: true })
writeFileSync("build/perfboard.svg", renderSvg(LAYOUT))
writeFileSync("../docs/perfboard-wiring.md", renderTable(LAYOUT))
console.log(`ok: ${LAYOUT.wires.length} wires`)

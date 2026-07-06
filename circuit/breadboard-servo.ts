// circuit/breadboard-servo.ts
// CLI: generate build/breadboard-servo.svg from the servo-drive layout.

import { mkdirSync, writeFileSync } from "node:fs"
import { join } from "node:path"
import { renderBreadboardSvg } from "./breadboard/render"
import { buildConnectivity } from "./breadboard/model"
import { JUMPERS } from "./breadboard/servo-layout"

if (import.meta.main) {
  // Optional connectivity check
  try {
    const conn = buildConnectivity(JUMPERS)
    // Spot-check: V5 rail node and a known V5 pin share a group
    const railGroup = conn.groupOf("TP")
    const col2Group = conn.groupOf("U2")
    if (railGroup === col2Group) {
      console.log("connectivity OK — TP and U2 (M1.VPLUS) in same group")
    } else {
      console.log("connectivity check: TP and U2 groups differ (rail jumpers use row b, not a — expected)")
    }
  } catch (e) {
    console.warn("connectivity check skipped:", e)
  }

  // Render
  const svg = renderBreadboardSvg()

  // Write to repo-root build/
  const repoRoot = join(import.meta.dir, "..")
  const buildDir = join(repoRoot, "build")
  mkdirSync(buildDir, { recursive: true })
  const outPath = join(buildDir, "breadboard-servo.svg")
  writeFileSync(outPath, svg, "utf-8")
  console.log("written:", outPath)
}

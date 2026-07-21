#!/usr/bin/env bun
// 全プリント部品を enclosure/build/ にレンダリングする（旧 build.sh の置き換え）。
// smartlock.scad の part 切り替え部品と、単体 scad のゲージ類の 2 系統を回す。
import { dirname, join } from "node:path";
import { renderScad } from "./openscad.ts";

const scriptsDir = import.meta.dir;
const enclosureRoot = dirname(scriptsDir);
const modelsDir = join(enclosureRoot, "models");
const buildDir = join(enclosureRoot, "build");
const smartlock = join(modelsDir, "smartlock.scad");

// smartlock.scad から -D part= で切り出す部品（asm_* は組立プレビュー）
const parts = [
  "body", "pedestal", "socket", "tray",
  "asm_body", "asm_pedestal", "asm_socket", "asm_tray",
];
// 単体 scad の実測補助ゲージ・テストクーポン
const gauges = ["tray_pilot_gauge", "pilot_gauge", "spline_gauge", "horn_snap_coupon"];

for (const p of parts) {
  console.log(`== building ${p} ==`);
  try {
    await renderScad(smartlock, join(buildDir, `${p}.stl`), { part: p });
  } catch (err) {
    console.error(`FAIL: ${p} — ${err instanceof Error ? err.message : err}`);
    process.exit(1);
  }
}
for (const g of gauges) {
  console.log(`== building ${g} ==`);
  try {
    await renderScad(join(modelsDir, `${g}.scad`), join(buildDir, `${g}.stl`));
  } catch (err) {
    console.error(`FAIL: ${g} — ${err instanceof Error ? err.message : err}`);
    process.exit(1);
  }
}
console.log("All parts built to enclosure/build/");

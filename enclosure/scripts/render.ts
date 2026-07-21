#!/usr/bin/env bun
// 単発レンダリング CLI。
// 出力先の拡張子が .png なら PNG 用フラグを自動で付ける。追加フラグはそのまま openscad へ渡す。
import { basename, join } from "node:path";
import { PNG_ARGS, renderScad } from "./openscad.ts";

const [scad, outArg, ...extra] = process.argv.slice(2);
if (!scad) {
  console.error("usage: bun scad/render.ts <scad> [out] [extra openscad flags...]");
  process.exit(1);
}
const out = outArg ?? join("/tmp", `${basename(scad, ".scad")}.stl`);
const extraArgs = out.endsWith(".png") ? [...PNG_ARGS, ...extra] : extra;

try {
  await renderScad(scad, out, {}, extraArgs);
} catch (err) {
  console.error(`FAIL: ${err instanceof Error ? err.message : err}`);
  process.exit(1);
}
console.log(`OK: ${out}`);

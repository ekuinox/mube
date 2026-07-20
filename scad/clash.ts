#!/usr/bin/env bun
// 部品間の体積干渉チェック。
// clash_check.scad は干渉体積だけを出力するモデルなので、レンダリング結果が
// 空（"top level object is empty"）なら干渉なし=PASS、形状が出たら FAIL。
// 空エクスポートで openscad が警告と非ゼロ終了することがあるため、先に空判定する。
import { join } from "node:path";
import { runOpenscad } from "./openscad.ts";

const scad = join(import.meta.dir, "clash_check.scad");
const { exitCode, log } = await runOpenscad(scad, "/tmp/clash_check.stl");
if (log) process.stdout.write(log);

if (log.includes("top level object is empty")) {
  console.log("OK: no interference (empty intersection)");
  process.exit(0);
}
if (exitCode !== 0) {
  console.error(`FAIL: openscad exit ${exitCode}`);
  process.exit(1);
}
if (/WARNING:|ERROR:/.test(log)) {
  console.error("FAIL: warnings/errors present");
  process.exit(1);
}
const facets = [...log.matchAll(/Facets: +(\d+)/g)].at(-1)?.[1] ?? "unknown";
console.error(`FAIL: interference detected (facets=${facets})`);
process.exit(1);

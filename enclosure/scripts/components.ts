#!/usr/bin/env bun
// カバー STL が単一の連結ソリッドであることを確認する回帰チェック。
// Task 3 で「固定耳が裾とウェブで繋がっておらず、STL の連結成分が複数（実測5個）に
// 割れる」バグを、clash.ts も assert も検出できずに見逃した反省から追加。
//
// 判定方法: STL の頂点座標を丸め誤差 1e-5mm でキー化し、三角形が共有する頂点を
// Union-Find で連結する。三角形同士が頂点を共有していれば同一ソリッドとみなせるので、
// 連結成分数がそのまま STL 中の独立したソリッド片の数になる。1 個なら単一ソリッド=PASS。
//
// OpenSCAD が --render 時に出す Genus（種数）ではなく連結成分数で判定する理由:
// カバーの m2_sleeve_cuts() の各貫通ボアは、自己サポート・ファンネルの上端径
// （d2 = tray_screw_clear = 2.4）がネジ通し throat の径（d = tray_screw_clear = 2.4）と
// ちょうど一致する縮退を持ち、Manifold はこれを独立した種数 1 ではなく 0 として数える
// （params.scad 参照）。種数の期待値は開口の追加/削除のたびに変わるので回帰チェックの
// 基準としては脆く、ここでは使わない（既知の値: 現行カバー単体で Genus=3。内訳は
// 概念上の貫通穴7個 [M2 耳4 + LED窓1 + スイッチ窓1 + USB切欠き1] のうち M2 耳4個が
// 上記の縮退で種数0にカウントされるため 7-4=3）。
import { dirname, join } from "node:path";
import { runOpenscad } from "./openscad.ts";

export interface ComponentStats {
  triangles: number;
  vertices: number;
  components: number;
}

/**
 * ASCII STL の頂点座標を丸め誤差 1e-5mm でキー化して Union-Find にかけ、三角形が共有する
 * 頂点を連結する。openscad の STL エクスポートは同一頂点に対して常に同じ浮動小数表現を
 * 出すため、この丸めで十分一致する。戻り値の components がそのまま STL 中の独立した
 * ソリッド片の数になる。
 */
export function countComponents(stlText: string): ComponentStats {
  const parent = new Map<string, string>();
  function find(x: string): string {
    let root = parent.get(x) ?? x;
    while (parent.get(root) !== undefined && parent.get(root) !== root) {
      root = parent.get(root)!;
    }
    parent.set(x, root);
    return root;
  }
  function union(a: string, b: string): void {
    const ra = find(a);
    const rb = find(b);
    if (ra !== rb) parent.set(ra, rb);
  }

  let triangles = 0;
  let cur: string[] = [];
  for (const line of stlText.split("\n")) {
    const t = line.trim();
    if (!t.startsWith("vertex")) continue;
    const nums = t.split(/\s+/).slice(1, 4).map(Number);
    const key = nums.map((n) => n.toFixed(5)).join(",");
    if (!parent.has(key)) parent.set(key, key);
    cur.push(key);
    if (cur.length === 3) {
      union(cur[0], cur[1]);
      union(cur[1], cur[2]);
      triangles++;
      cur = [];
    }
  }

  const roots = new Set([...parent.keys()].map(find));
  return { triangles, vertices: parent.size, components: roots.size };
}

// このモジュールが直接実行された場合のみ CLI として動く（components.test.ts からの
// import では openscad を呼ばない）。
if (import.meta.main) {
  const modelsDir = join(dirname(import.meta.dir), "models");
  const smartlock = join(modelsDir, "smartlock.scad");
  const outPath = "/tmp/cover_components_check.stl";

  const { exitCode, log } = await runOpenscad(smartlock, outPath, { part: "cover" });
  if (log) process.stdout.write(log);
  if (exitCode !== 0) {
    console.error(`FAIL: openscad exit ${exitCode}`);
    process.exit(1);
  }
  if (/WARNING:|ERROR:/.test(log)) {
    console.error("FAIL: warnings/errors present");
    process.exit(1);
  }

  const text = await Bun.file(outPath).text();
  const stats = countComponents(text);
  if (stats.triangles === 0) {
    console.error("FAIL: STL に三角形が見つからない（空メッシュ）");
    process.exit(1);
  }
  console.log(`triangles=${stats.triangles} vertices=${stats.vertices} components=${stats.components}`);
  if (stats.components === 1) {
    console.log("OK: cover STL is a single connected solid");
    process.exit(0);
  }
  console.error(`FAIL: cover STL has ${stats.components} disconnected components (expected 1)`);
  process.exit(1);
}

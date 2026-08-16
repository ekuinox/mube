import { test, expect } from "bun:test";
import { countComponents } from "./components.ts";

// 1枚の三角形（頂点3個・面1枚）
const oneTriangle = `
solid t
  facet normal 0 0 1
    outer loop
      vertex 0 0 0
      vertex 1 0 0
      vertex 0 1 0
    endloop
  endfacet
endsolid t
`;

// 辺を共有する2枚の三角形（正方形1枚 = 単一連結成分）
const twoTrianglesConnected = `
solid sq
  facet normal 0 0 1
    outer loop
      vertex 0 0 0
      vertex 1 0 0
      vertex 1 1 0
    endloop
  endfacet
  facet normal 0 0 1
    outer loop
      vertex 0 0 0
      vertex 1 1 0
      vertex 0 1 0
    endloop
  endfacet
endsolid sq
`;

// 頂点を一切共有しない2枚の三角形（離れた2ソリッド = Task 3 の「耳が裾から浮く」再現）
const twoTrianglesDisjoint = `
solid pair
  facet normal 0 0 1
    outer loop
      vertex 0 0 0
      vertex 1 0 0
      vertex 0 1 0
    endloop
  endfacet
  facet normal 0 0 1
    outer loop
      vertex 100 100 100
      vertex 101 100 100
      vertex 100 101 100
    endloop
  endfacet
endsolid pair
`;

test("countComponents: 三角形1枚は単一成分", () => {
  const stats = countComponents(oneTriangle);
  expect(stats.triangles).toBe(1);
  expect(stats.components).toBe(1);
});

test("countComponents: 辺を共有する2枚は単一成分に連結される", () => {
  const stats = countComponents(twoTrianglesConnected);
  expect(stats.triangles).toBe(2);
  expect(stats.vertices).toBe(4); // 正方形の頂点4個（対角線の2頂点を共有）
  expect(stats.components).toBe(1);
});

test("countComponents: 頂点を共有しない2枚は2成分（Task 3 の分離バグ相当）", () => {
  const stats = countComponents(twoTrianglesDisjoint);
  expect(stats.triangles).toBe(2);
  expect(stats.components).toBe(2);
});

test("countComponents: 空メッシュは三角形0", () => {
  const stats = countComponents("solid empty\nendsolid empty\n");
  expect(stats.triangles).toBe(0);
});

// vertex 行が3の倍数でない（バイナリ STL の誤読・途中で切れたファイル等）場合、
// 末尾を黙って落として false PASS 方向に劣化させず、確実に throw する（Minor 6）。
test("countComponents: vertex 行が3の倍数でないと throw する", () => {
  const malformed = `
solid broken
  facet normal 0 0 1
    outer loop
      vertex 0 0 0
      vertex 1 0 0
    endloop
  endfacet
endsolid broken
`;
  expect(() => countComponents(malformed)).toThrow();
});

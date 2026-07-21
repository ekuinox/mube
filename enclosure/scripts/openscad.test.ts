import { test, expect } from "bun:test";
import { openscadArgs, assertRenderOk, PNG_ARGS } from "./openscad.ts";

test("openscadArgs: defines 無し", () => {
  expect(openscadArgs("a.scad", "out.stl")).toEqual(["-o", "out.stl", "a.scad"]);
});

test("openscadArgs: defines を -D key=\"value\" に展開", () => {
  expect(openscadArgs("a.scad", "out.stl", { part: "tray" })).toEqual([
    "-D", 'part="tray"', "-o", "out.stl", "a.scad",
  ]);
});

test("openscadArgs: extraArgs を -o の前に挿入", () => {
  expect(openscadArgs("a.scad", "out.png", {}, ["--render"])).toEqual([
    "--render", "-o", "out.png", "a.scad",
  ]);
});

test("PNG_ARGS: Manifold バックエンドで全体を描画する", () => {
  expect(PNG_ARGS).toEqual([
    "--backend", "Manifold", "--render", "--viewall", "--autocenter",
    "--imgsize", "2400,1800",
  ]);
});

test("assertRenderOk: 正常終了は throw しない", () => {
  expect(() => assertRenderOk(0, "rendering finished")).not.toThrow();
});

test("assertRenderOk: 非ゼロ終了で throw", () => {
  expect(() => assertRenderOk(1, "")).toThrow("openscad exit 1");
});

test("assertRenderOk: WARNING を含むと throw", () => {
  expect(() => assertRenderOk(0, "WARNING: something odd")).toThrow("warnings/errors present");
});

test("assertRenderOk: ERROR を含むと throw", () => {
  expect(() => assertRenderOk(0, "ERROR: bad geometry")).toThrow("warnings/errors present");
});

test("assertRenderOk: Manifold の Status: NoError は誤検知しない", () => {
  expect(() => assertRenderOk(0, "Status: NoError")).not.toThrow();
});

test("assertRenderOk: nix の小文字 warning は誤検知しない", () => {
  expect(() => assertRenderOk(0, "warning: Git tree is dirty")).not.toThrow();
});

import { test, expect } from "bun:test";
import { mkdtemp, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { BLOBS, missingBlobs, isValidSize } from "./fetch-cyw43.ts";

test("isValidSize: 最低値以上は true、未満は false", () => {
  expect(isValidSize(100_000, 100_000)).toBe(true);
  expect(isValidSize(100_001, 100_000)).toBe(true);
  expect(isValidSize(99_999, 100_000)).toBe(false);
});

test("missingBlobs: 空ディレクトリは全ブロブ名を返す", async () => {
  const dir = await mkdtemp(join(tmpdir(), "cyw43-"));
  try {
    expect((await missingBlobs(dir)).sort()).toEqual(BLOBS.map((b) => b.name).sort());
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("missingBlobs: 一部だけ存在すると残りを返す", async () => {
  const dir = await mkdtemp(join(tmpdir(), "cyw43-"));
  try {
    await writeFile(join(dir, "43439A0.bin"), "x");
    expect((await missingBlobs(dir)).sort()).toEqual(
      ["43439A0_clm.bin", "nvram_rp2040.bin"].sort(),
    );
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("missingBlobs: 3 つ揃っていれば空配列", async () => {
  const dir = await mkdtemp(join(tmpdir(), "cyw43-"));
  try {
    for (const { name } of BLOBS) await writeFile(join(dir, name), "x");
    expect(await missingBlobs(dir)).toEqual([]);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

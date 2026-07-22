// openscad CLI 呼び出しの共通ヘルパ。build.ts / render.ts / clash.ts / viewer/serve.ts が共有する。
// 成否判定は「非ゼロ終了 or ログに WARNING:/ERROR:（コロン付き・case-sensitive）」。
// 小文字マッチにすると Manifold の "Status: NoError" や nix の "warning: Git tree ... dirty"
// を誤検知するため、i フラグは付けない。
import { mkdir } from "node:fs/promises";
import { dirname } from "node:path";

export type Defines = Record<string, string>;

/** PNG レンダリング用フラグ。Mesa ソフトウェアレンダラで GPU/X 無しに描画できる。 */
export const PNG_ARGS = [
  "--backend", "Manifold", "--render", "--viewall", "--autocenter",
  "--imgsize", "2400,1800",
];

/** openscad の CLI 引数配列を組み立てる。 */
export function openscadArgs(
  scadPath: string,
  outPath: string,
  defines: Defines = {},
  extraArgs: string[] = [],
): string[] {
  const args: string[] = [];
  for (const [key, value] of Object.entries(defines)) {
    args.push("-D", `${key}="${value}"`);
  }
  args.push(...extraArgs, "-o", outPath, scadPath);
  return args;
}

/** 終了コードとログから成否を判定し、失敗なら throw する。 */
export function assertRenderOk(exitCode: number, log: string): void {
  if (exitCode !== 0) {
    throw new Error(`openscad exit ${exitCode}`);
  }
  if (/WARNING:|ERROR:/.test(log)) {
    throw new Error("warnings/errors present");
  }
}

/** openscad を実行し、成否判定せず終了コードとログを返す（clash.ts の逆セマンティクス判定用）。 */
export async function runOpenscad(
  scadPath: string,
  outPath: string,
  defines: Defines = {},
  extraArgs: string[] = [],
): Promise<{ exitCode: number; log: string }> {
  await mkdir(dirname(outPath), { recursive: true });
  let proc: ReturnType<typeof Bun.spawn>;
  try {
    proc = Bun.spawn(["openscad", ...openscadArgs(scadPath, outPath, defines, extraArgs)], {
      stdout: "pipe",
      stderr: "pipe",
    });
  } catch {
    throw new Error("openscad not found on PATH — run inside `nix develop`");
  }
  const [out, err] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const exitCode = await proc.exited;
  return { exitCode, log: out + err };
}

/** scadPath を outPath にレンダリングする。ログは標準出力へ流し、失敗時は throw。 */
export async function renderScad(
  scadPath: string,
  outPath: string,
  defines: Defines = {},
  extraArgs: string[] = [],
): Promise<void> {
  const { exitCode, log } = await runOpenscad(scadPath, outPath, defines, extraArgs);
  if (log) process.stdout.write(log);
  assertRenderOk(exitCode, log);
}

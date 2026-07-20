# プロジェクト整理（komorebi 流ツーリング統一＋ドキュメント再編）実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** bash/Python に分散したツーリングを bun TS に統一して `test/`・`build.sh`・uv を廃し、README を約 60 行にスリム化して詳細を `docs/firmware.md` に退避し、ドキュメントの陳腐化・矛盾を修正する。

**Architecture:** 姉妹プロジェクト [ekuinox/komorebi](https://github.com/ekuinox/komorebi) と同じ形に寄せる。openscad 呼び出しを `scad/openscad.ts` に集約し、build/render/clash の各 CLI と viewer/breadboard の配信スクリプトがそれを共有する。cloudflared トンネルと静的配信は `viewer/tunnel.ts` / `viewer/static.ts` に共通化する。

**Tech Stack:** bun（TS スクリプト＋ bun test）、OpenSCAD（Manifold バックエンド）、cloudflared、Nix devShell、Rust/cargo（変更なし・回帰確認のみ）。

**Spec:** `docs/superpowers/specs/2026-07-20-project-reorg-design.md`

## Global Constraints

- ソースコメント・コミットメッセージは日本語。コメントは十分に説明を書く。
- openscad の成否判定は「非ゼロ終了 or ログに `WARNING:` / `ERROR:`（大文字・コロン付きの完全一致、case-sensitive）」。`Status: NoError` や nix の `warning: Git tree ... dirty` を誤検知しないため、`/WARNING:|ERROR:/`（`i` フラグ無し）を使う。
- bun スクリプトは `circuit/` 以外では外部依存を持たない（node 標準 API と Bun API のみ。package.json 不要）。
- STL 等の派生物の出力先は `scad/build/`（筐体）と `circuit/build/`（配線図 SVG）。トップレベル `build/` は廃止。`.gitignore` の `build/` パターン（先頭スラッシュ無し）は任意階層の build/ にマッチするので変更不要。
- `lockctl.sh` は運用クライアントとして bash のまま存続させる（廃止対象ではない）。
- `docs/superpowers/` の plan/spec 履歴は変更しない。
- Rust には触らない。ただし最終検証で `nix develop -c cargo host-test` の通過を確認する。
- コマンドは nix devShell 前提（`nix develop -c <cmd>`）。素の PATH に bun/openscad は無い。
- README のコマンド例はコードブロック内に長いコメントを書かず、説明は地の文に書く。

---

### Task 1: scad/openscad.ts ヘルパ（bun 単体テスト付き）

openscad 呼び出しの共通ヘルパ。komorebi の `scad/openscad.ts` をベースに、PNG レンダリング用の追加引数と、clash 判定用に exit コード＋ログを生で返す `runOpenscad` を加える。

**Files:**
- Create: `scad/openscad.ts`
- Test: `scad/openscad.test.ts`

**Interfaces:**
- Produces:
  - `type Defines = Record<string, string>`
  - `openscadArgs(scadPath: string, outPath: string, defines?: Defines, extraArgs?: string[]): string[]`
  - `assertRenderOk(exitCode: number, log: string): void`（失敗で throw）
  - `runOpenscad(scadPath: string, outPath: string, defines?: Defines, extraArgs?: string[]): Promise<{ exitCode: number; log: string }>`（成否判定しない）
  - `renderScad(scadPath: string, outPath: string, defines?: Defines, extraArgs?: string[]): Promise<void>`（ログを標準出力へ流し、失敗で throw）
  - `PNG_ARGS: string[]`（PNG 用の openscad フラグ）

- [ ] **Step 1: 失敗するテストを書く**

`scad/openscad.test.ts`:

```ts
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
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `nix develop -c bun test scad/`
Expected: FAIL（`./openscad.ts` が無く module 解決エラー）

- [ ] **Step 3: 実装を書く**

`scad/openscad.ts`:

```ts
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
```

- [ ] **Step 4: テストが通ることを確認**

Run: `nix develop -c bun test scad/`
Expected: PASS（10 tests）

- [ ] **Step 5: コミット**

```bash
git add scad/openscad.ts scad/openscad.test.ts
git commit -m "feat(scad): openscad 呼び出しの bun 共通ヘルパを追加（komorebi 移植＋PNG/clash 対応）"
```

---

### Task 2: scad/build.ts（build.sh 廃止）

**Files:**
- Create: `scad/build.ts`
- Delete: `build.sh`

**Interfaces:**
- Consumes: `renderScad`（Task 1）
- Produces: `nix develop -c bun scad/build.ts` で `scad/build/` に body/pedestal/socket/tray/asm_*.stl とゲージ 4 種の STL

- [ ] **Step 1: build.ts を書く**

```ts
#!/usr/bin/env bun
// 全プリント部品を scad/build/ にレンダリングする（旧 build.sh の置き換え）。
// smartlock.scad の part 切り替え部品と、単体 scad のゲージ類の 2 系統を回す。
import { join } from "node:path";
import { renderScad } from "./openscad.ts";

const scadDir = import.meta.dir;
const buildDir = join(scadDir, "build");
const smartlock = join(scadDir, "smartlock.scad");

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
    await renderScad(join(scadDir, `${g}.scad`), join(buildDir, `${g}.stl`));
  } catch (err) {
    console.error(`FAIL: ${g} — ${err instanceof Error ? err.message : err}`);
    process.exit(1);
  }
}
console.log("All parts built to scad/build/");
```

- [ ] **Step 2: 新旧の成果物一致を確認**

Run: `nix develop -c bun scad/build.ts && ls scad/build/`
Expected: `body.stl pedestal.stl socket.stl tray.stl asm_body.stl asm_pedestal.stl asm_socket.stl asm_tray.stl tray_pilot_gauge.stl pilot_gauge.stl spline_gauge.stl horn_snap_coupon.stl`（旧 `./build.sh` が build/ に出していた 12 点と同じ一覧）

- [ ] **Step 3: build.sh を削除してコミット**

```bash
git rm build.sh
git add scad/build.ts
git commit -m "feat(scad): 筐体ビルドを bun scad/build.ts へ移行し build.sh を廃止（出力先 scad/build/）"
```

---

### Task 3: scad/render.ts（render.sh / render_png.sh 廃止、テスト scad の移動）

拡張子で STL/PNG を切り替える単発レンダリング CLI。同時に `test/*_test.scad` を `scad/` へ移して include パスを直す。

**Files:**
- Create: `scad/render.ts`
- Move: `test/params_test.scad` `test/body_test.scad` `test/hardware_test.scad` `test/pedestal_test.scad` `test/socket_test.scad` → `scad/`（同名）
- Delete: `test/render.sh`, `test/render_png.sh`

**Interfaces:**
- Consumes: `renderScad`, `PNG_ARGS`（Task 1）
- Produces: `bun scad/render.ts <scad> [out] [extra flags...]`。out 省略時は `/tmp/<basename>.stl`。out が `.png` なら PNG_ARGS を自動付与

- [ ] **Step 1: render.ts を書く**

```ts
#!/usr/bin/env bun
// 単発レンダリング CLI（旧 test/render.sh と test/render_png.sh の置き換え）。
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
```

- [ ] **Step 2: テスト scad を移動して include パスを直す**

```bash
git mv test/params_test.scad test/body_test.scad test/hardware_test.scad test/pedestal_test.scad test/socket_test.scad scad/
```

移動した 5 ファイルの先頭にある `include <../scad/params.scad>` → `include <params.scad>`、`use <../scad/xxx.scad>` → `use <xxx.scad>` に一括修正する（`scad/` 内からの相対参照になるため）。

```bash
sed -i 's#<../scad/#<#' scad/params_test.scad scad/body_test.scad scad/hardware_test.scad scad/pedestal_test.scad scad/socket_test.scad
```

- [ ] **Step 3: 移動後の全テスト scad と本体をレンダリングして確認**

Run:

```bash
nix develop -c bash -euo pipefail -c '
  for f in scad/smartlock.scad scad/smoke.scad scad/*_test.scad; do
    bun scad/render.ts "$f"
  done
'
```

Expected: 各ファイルについて `OK: /tmp/<basename>.stl`、非ゼロ終了なし

- [ ] **Step 4: PNG モードの確認**

Run: `nix develop -c bun scad/render.ts scad/smartlock.scad /tmp/smartlock.png`
Expected: `OK: /tmp/smartlock.png`（PNG ファイルが生成される）

- [ ] **Step 5: 旧スクリプトを削除してコミット**

```bash
git rm test/render.sh test/render_png.sh
git add scad/render.ts
git commit -m "feat(scad): 単発レンダを bun scad/render.ts に統合（STL/PNG）し test/ の scad を scad/ へ移動"
```

---

### Task 4: scad/clash.ts（clash.sh 廃止、clash_check.scad の移動）

「空出力＝干渉なし＝PASS」の逆セマンティクス判定を TS 移植する。

**Files:**
- Create: `scad/clash.ts`
- Move: `test/clash_check.scad` → `scad/clash_check.scad`（include パス修正込み）
- Delete: `test/clash.sh`

**Interfaces:**
- Consumes: `runOpenscad`（Task 1。assertRenderOk は使わない — 空出力の WARNING を FAIL 扱いしないため）
- Produces: `bun scad/clash.ts` — 干渉なしで exit 0、干渉ありや openscad 失敗で exit 1

- [ ] **Step 1: clash_check.scad を移動してパスを直す**

```bash
git mv test/clash_check.scad scad/clash_check.scad
sed -i 's#<../scad/#<#' scad/clash_check.scad
```

ファイル内コメントの「clash.sh」への言及 2 箇所を「clash.ts」に書き換える（判定は必ず clash.ts 経由、の注意書きを維持する）。

- [ ] **Step 2: clash.ts を書く**

```ts
#!/usr/bin/env bun
// 部品間の体積干渉チェック（旧 test/clash.sh の置き換え）。
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
```

- [ ] **Step 3: 動作確認**

Run: `nix develop -c bun scad/clash.ts; echo "exit=$?"`
Expected: `OK: no interference (empty intersection)` と `exit=0`（現行 master は干渉なしの状態）

- [ ] **Step 4: 旧スクリプトを削除してコミット**

```bash
git rm test/clash.sh
git add scad/clash.ts scad/clash_check.scad
git commit -m "feat(scad): 体積干渉チェックを bun scad/clash.ts へ移行し test/clash.sh を廃止"
```

---

### Task 5: viewer/serve.ts（serve.py 廃止、tunnel/static 共通ヘルパ新設)

**Files:**
- Create: `viewer/tunnel.ts`, `viewer/static.ts`, `viewer/serve.ts`
- Delete: `viewer/serve.py`

**Interfaces:**
- Consumes: `renderScad`（Task 1）
- Produces:
  - `startTunnel(port: number): Promise<{ proc: ReturnType<typeof Bun.spawn>; url: string }>`（`viewer/tunnel.ts`。cloudflared 未検出・60 秒タイムアウトで throw）
  - `serveDir(dir: string, port: number): ReturnType<typeof Bun.serve>`（`viewer/static.ts`。パストラバーサル防止付き静的配信）
  - `nix develop -c bun viewer/serve.ts` — 全パーツレンダ→`scad/build/` 配信→公開 URL 表示。`NO_TUNNEL=1` でローカルのみ、`PORT` で変更（既定 8765）

- [ ] **Step 1: tunnel.ts を書く**

```ts
// cloudflared quick tunnel を張って公開 URL を返す共通ヘルパ。
// viewer/serve.ts と circuit/breadboard-serve.ts が共有する。
// cloudflared は起動ログを stderr に流すので、そこから trycloudflare の URL を拾う。
const URL_RE = /https:\/\/[a-z0-9-]+\.trycloudflare\.com/;

export async function startTunnel(
  port: number,
): Promise<{ proc: ReturnType<typeof Bun.spawn>; url: string }> {
  let proc: ReturnType<typeof Bun.spawn>;
  try {
    proc = Bun.spawn(
      ["cloudflared", "tunnel", "--no-autoupdate", "--url", `http://127.0.0.1:${port}`],
      { stdout: "ignore", stderr: "pipe" },
    );
  } catch {
    throw new Error("cloudflared not found on PATH — run inside `nix develop`");
  }
  const url = await new Promise<string | null>((resolve) => {
    // 60 秒で URL が取れなければ諦める（トンネル起動失敗・ネットワーク断など）
    const timer = setTimeout(() => resolve(null), 60_000);
    (async () => {
      const decoder = new TextDecoder();
      let buf = "";
      for await (const chunk of proc.stderr as ReadableStream<Uint8Array>) {
        buf += decoder.decode(chunk);
        const m = URL_RE.exec(buf);
        if (m) {
          clearTimeout(timer);
          resolve(m[0]);
          return;
        }
      }
      // URL を出さないままストリームが閉じた場合も待ち手を解放する
      clearTimeout(timer);
      resolve(null);
    })();
  });
  if (!url) {
    proc.kill();
    throw new Error("cloudflared did not produce a tunnel URL within 60s");
  }
  return { proc, url };
}
```

- [ ] **Step 2: static.ts を書く**

```ts
// 指定ディレクトリを配信する静的 HTTP サーバの共通ヘルパ。
// viewer/serve.ts と circuit/breadboard-serve.ts が共有する。
import { join } from "node:path";

export function serveDir(dir: string, port: number): ReturnType<typeof Bun.serve> {
  return Bun.serve({
    hostname: "127.0.0.1",
    port,
    async fetch(req) {
      const url = new URL(req.url);
      const path = url.pathname === "/" ? "/index.html" : url.pathname;
      const resolved = join(dir, path);
      // join の正規化を利用したパストラバーサル（../ 等）防止
      if (resolved !== dir && !resolved.startsWith(dir + "/")) {
        return new Response("Forbidden", { status: 403 });
      }
      const file = Bun.file(resolved);
      if (await file.exists()) return new Response(file);
      return new Response("Not Found", { status: 404 });
    },
  });
}
```

- [ ] **Step 3: serve.ts を書く**

```ts
#!/usr/bin/env bun
// 筐体パーツを STL にレンダリングし、ブラウザビューアを配信して cloudflared quick tunnel で
// 公開する（旧 viewer/serve.py の置き換え）。NO_TUNNEL=1 でローカル配信のみ。
import { copyFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { renderScad } from "../scad/openscad.ts";
import { serveDir } from "./static.ts";
import { startTunnel } from "./tunnel.ts";

const root = dirname(import.meta.dir); // viewer/ の親 = リポジトリルート
const scadDir = join(root, "scad");
const buildDir = join(scadDir, "build");
const smartlock = join(scadDir, "smartlock.scad");
const port = Number(process.env.PORT ?? "8765");
// assembly は smartlock.scad が未知の part 名を全体アセンブリとして描く仕様を利用している
const parts = [
  "body", "pedestal", "socket", "tray", "assembly",
  "asm_body", "asm_pedestal", "asm_socket", "asm_tray",
];

for (const part of parts) {
  console.log(`rendering ${part} -> scad/build/${part}.stl`);
  try {
    await renderScad(smartlock, join(buildDir, `${part}.stl`), { part });
  } catch (err) {
    console.error(`FAIL rendering ${part} — ${err instanceof Error ? err.message : err}`);
    process.exit(1);
  }
}
await copyFile(join(root, "viewer", "index.html"), join(buildDir, "index.html"));

const server = serveDir(buildDir, port);
console.log(`serving scad/build/ at http://127.0.0.1:${port}`);

let tunnelProc: ReturnType<typeof Bun.spawn> | null = null;
let url = `http://127.0.0.1:${port}`;
if (!process.env.NO_TUNNEL) {
  const t = await startTunnel(port);
  tunnelProc = t.proc;
  url = t.url;
}

console.log("\n" + "=".repeat(60));
console.log(`  Open in your browser:  ${url}`);
console.log("=".repeat(60) + "\n  Ctrl-C to stop.\n");

const stop = () => {
  console.log("\nstopping…");
  tunnelProc?.kill();
  server.stop();
  process.exit(0);
};
process.on("SIGINT", stop);
process.on("SIGTERM", stop);
```

- [ ] **Step 4: NO_TUNNEL でスモークテスト**

Run（バックグラウンド起動して確認後 kill）:

```bash
nix develop -c bash -c 'NO_TUNNEL=1 bun viewer/serve.ts & pid=$!; sleep 90; curl -sf -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8765/index.html; curl -sf -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8765/body.stl; kill $pid'
```

Expected: `200` が 2 行（レンダリングに時間がかかるため sleep は長め。全パーツの `rendering ...` ログの後に配信開始）

- [ ] **Step 5: serve.py を削除してコミット**

```bash
git rm viewer/serve.py
git add viewer/tunnel.ts viewer/static.ts viewer/serve.ts
git commit -m "feat(viewer): 3D ビューア配信を bun viewer/serve.ts へ移行（uv/Python 廃止、NO_TUNNEL 対応）"
```

---

### Task 6: circuit/breadboard-serve.ts（breadboard.sh / breadboard-serve.py / test/erc.sh 廃止）

SVG 出力先を `circuit/build/` に変更し、生成→配信→トンネルを bun に一本化する。これで `test/` が空になるので削除する。

**Files:**
- Modify: `circuit/breadboard-auto.ts:15`（出力先 `../build` → `build`）
- Create: `circuit/breadboard-serve.ts`
- Modify: `circuit/breadboard-viewer.html:66` 周辺のコメント（`build/` → `circuit/build/` の言及に修正）
- Delete: `circuit/breadboard.sh`, `circuit/breadboard-serve.py`, `test/erc.sh`（これで test/ は空）

**Interfaces:**
- Consumes: `serveDir`（Task 5）, `startTunnel`（Task 5）
- Produces: `nix develop -c bun circuit/breadboard-serve.ts` — 依存インストール→全プリセット SVG 生成→`circuit/build/` 配信→`<URL>/breadboard.html` 表示。`NO_TUNNEL=1` / `PORT`（既定 8766）対応

- [ ] **Step 1: breadboard-auto.ts の出力先を変更**

`circuit/breadboard-auto.ts` 15 行目:

```ts
const out = join(import.meta.dir, "build", "breadboard-" + name + ".svg")
```

（旧: `join(import.meta.dir, "..", "build", ...)`。トップレベル build/ 廃止のため circuit/build/ へ）

- [ ] **Step 2: breadboard-serve.ts を書く**

```ts
#!/usr/bin/env bun
// ブレッドボード配線図（全プリセット）を SVG に生成し、ビューアを配信して cloudflared
// quick tunnel で公開する（旧 breadboard.sh + breadboard-serve.py の置き換え）。
// NO_TUNNEL=1 でローカル配信のみ。ポートは viewer/serve.ts（8765）との衝突を避けて 8766。
import { copyFile, mkdir } from "node:fs/promises";
import { join } from "node:path";
import { serveDir } from "../viewer/static.ts";
import { startTunnel } from "../viewer/tunnel.ts";

const circuitDir = import.meta.dir;
const buildDir = join(circuitDir, "build");
const port = Number(process.env.PORT ?? "8766");
// breadboard-auto.ts が知っているプリセットキーと揃える
const presets = ["SERVO_DRIVE", "LED_BUTTON", "FULL"];

// tscircuit 依存を lockfile 固定で用意する（旧 breadboard.sh の bun install 相当）
const install = Bun.spawnSync(["bun", "install", "--frozen-lockfile"], {
  cwd: circuitDir, stdout: "inherit", stderr: "inherit",
});
if (install.exitCode !== 0) {
  console.error("FAIL: bun install --frozen-lockfile");
  process.exit(1);
}

await mkdir(buildDir, { recursive: true });
for (const preset of presets) {
  const out = join(buildDir, `breadboard-${preset.toLowerCase()}.svg`);
  console.log(`rendering ${preset} -> circuit/build/breadboard-${preset.toLowerCase()}.svg`);
  const proc = Bun.spawnSync(["bun", "breadboard-auto.ts", preset], {
    cwd: circuitDir, stdout: "inherit", stderr: "inherit",
  });
  if (proc.exitCode !== 0) {
    console.error(`FAIL: bun breadboard-auto.ts ${preset}`);
    process.exit(1);
  }
  // 戻り値 0 でも SVG が出ていなければ異常として扱う
  if (!(await Bun.file(out).exists())) {
    console.error(`FAIL: expected ${out} was not produced`);
    process.exit(1);
  }
}
// ビューア HTML を build/ にコピーし、SVG と同一オリジンで配信する
await copyFile(join(circuitDir, "breadboard-viewer.html"), join(buildDir, "breadboard.html"));

const server = serveDir(buildDir, port);
console.log(`serving circuit/build/ at http://127.0.0.1:${port}`);

let tunnelProc: ReturnType<typeof Bun.spawn> | null = null;
let url = `http://127.0.0.1:${port}`;
if (!process.env.NO_TUNNEL) {
  const t = await startTunnel(port);
  tunnelProc = t.proc;
  url = t.url;
}

console.log("\n" + "=".repeat(60));
console.log(`  Open in your browser:  ${url}/breadboard.html`);
console.log("=".repeat(60) + "\n  Ctrl-C to stop.\n");

const stop = () => {
  console.log("\nstopping…");
  tunnelProc?.kill();
  server.stop();
  process.exit(0);
};
process.on("SIGINT", stop);
process.on("SIGTERM", stop);
```

- [ ] **Step 3: NO_TUNNEL でスモークテスト**

```bash
nix develop -c bash -c 'NO_TUNNEL=1 bun circuit/breadboard-serve.ts & pid=$!; sleep 60; curl -sf -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8766/breadboard.html; curl -sf -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8766/breadboard-full.svg; kill $pid'
```

Expected: `200` が 2 行

- [ ] **Step 4: circuit の ERC テストが引き続き通ることを確認**

```bash
nix develop -c bash -euo pipefail -c 'cd circuit && bun install --frozen-lockfile && bun test'
```

Expected: PASS（テスト自体は無変更）

- [ ] **Step 5: 旧スクリプトと test/ を削除してコミット**

```bash
git rm circuit/breadboard.sh circuit/breadboard-serve.py test/erc.sh
git add circuit/breadboard-auto.ts circuit/breadboard-serve.ts circuit/breadboard-viewer.html
git commit -m "feat(circuit): 配線図ビューアを bun circuit/breadboard-serve.ts へ一本化（test/ 廃止完了）"
```

（`test/` はこの時点で空ディレクトリになり git 管理から消える）

---

### Task 7: flake.nix（uv 除去）と CI の追随

**Files:**
- Modify: `flake.nix`（`pkgs.uv` の行を削除）
- Modify: `.github/workflows/ci.yml`（render ジョブの 3 ステップ）

- [ ] **Step 1: flake.nix から uv を外す**

`flake.nix` の packages から次の 1 行を削除する:

```nix
            pkgs.uv           # runs viewer/serve.py (PEP 723), provisions its own Python
```

（openscad-unstable / cloudflared / rustup / bun / librsvg / mesa / libglvnd / probe-rs-tools / cargo-host-test はそのまま）

- [ ] **Step 2: devShell が壊れていないことを確認**

Run: `nix develop -c bash -c 'command -v openscad && command -v bun && command -v cloudflared && ! command -v uv'`
Expected: openscad / bun / cloudflared のパスが出て、uv が見つからず全体が exit 0

- [ ] **Step 3: CI の render ジョブを更新**

`.github/workflows/ci.yml` の render ジョブのステップを次に置き換える（checkout / nix-installer はそのまま）:

```yaml
      - name: bun test (scad — openscad ヘルパ単体テスト)
        run: nix develop --command bun test scad/

      - name: Render SCAD models to STL (fails on WARNING/ERROR)
        run: |
          nix develop --command bash -euo pipefail -c '
            # clash_check.scad は「空出力が正解」の干渉検査フィクスチャなので
            # *_test.scad グロブに含まれず、次の専用ステップで判定する
            for f in scad/smartlock.scad scad/smoke.scad scad/*_test.scad; do
              echo "::group::render $f"
              bun scad/render.ts "$f"
              echo "::endgroup::"
            done
          '

      - name: Part clash check (組立位置での部品間体積干渉が無いこと)
        run: nix develop --command bun scad/clash.ts
```

- [ ] **Step 4: ローカルで CI 相当を通す**

```bash
nix develop -c bun test scad/
nix develop -c bash -euo pipefail -c 'for f in scad/smartlock.scad scad/smoke.scad scad/*_test.scad; do bun scad/render.ts "$f"; done'
nix develop -c bun scad/clash.ts
```

Expected: すべて exit 0

- [ ] **Step 5: コミット**

```bash
git add flake.nix .github/workflows/ci.yml
git commit -m "chore: devShell から uv を除去し CI を bun ツーリングへ追随"
```

---

### Task 8: CLAUDE.md と viewer-preview スキルの追随

**Files:**
- Modify: `CLAUDE.md`（リポジトリ地図・コマンド表・注意）
- Modify: `.claude/skills/viewer-preview/SKILL.md`

- [ ] **Step 1: CLAUDE.md を更新**

変更点:

1. リポジトリ地図から `test/` の行を削除し、`build/` の行を「`scad/build/`, `circuit/build/` — 派生物（STL/SVG 出力。非コミット）」に変更。`viewer/` の説明を「STL ブラウザビューア（Three.js + cloudflared quick tunnel。bun）」にする。
2. 「コマンドの打ち方（落とし穴）」を次の内容に書き換える:

```markdown
## コマンドの打ち方（落とし穴）

`openscad` / `cargo` / `bun` / `cloudflared` は nix dev シェルの中にしか無い。
すべてのコマンドは **`nix develop -c <cmd>`** 経由で実行する（`.sh` の自動再突入は廃止済み）。

| やりたいこと | コマンド |
| --- | --- |
| 筐体ビルド（STL を scad/build/ へ） | `nix develop -c bun scad/build.ts` |
| SCAD レンダリングテスト（STL/PNG） | `nix develop -c bun scad/render.ts <scad> [out]` |
| 部品間の体積干渉チェック | `nix develop -c bun scad/clash.ts` |
| scad ツールの単体テスト | `nix develop -c bun test scad/` |
| 回路 ERC（導通・ショート） | `nix develop -c bash -c 'cd circuit && bun install --frozen-lockfile && bun test'` |
| ファームビルド（既定ターゲット thumbv6m） | `nix develop -c cargo build --locked` |
| ロジックの host テスト（実機不要） | `nix develop -c cargo host-test` |
| 3D ビューア公開 | `nix develop -c bun viewer/serve.ts` |
| ブレッドボード配線図ビューア | `nix develop -c bun circuit/breadboard-serve.ts` |
```

3. 「触る時の注意」の `build/` 言及を `scad/build/` / `circuit/build/` に更新。

- [ ] **Step 2: viewer-preview スキルを更新**

`.claude/skills/viewer-preview/SKILL.md` の変更点:

- `viewer/serve.py` への言及（3 箇所）を `viewer/serve.ts` に変更。
- 実行コマンドを `nix develop -c bun viewer/serve.ts` に変更（`uv run --script` を廃止）。
- 「`openscad` / `uv` / `cloudflared` は…」を「`openscad` / `bun` / `cloudflared` は…」に変更。
- 「事前に `./build.sh` を回す必要はない」→「事前に `bun scad/build.ts` を回す必要はない」。
- STL の出力先言及 `build/` → `scad/build/`。
- 注意点の「pip 版 cloudflared…`uv run --script` の shebang でも PATH は devShell 前提」の項は uv 廃止に合わせて「cloudflared は必ず nix devShell のバイナリを使う」に簡素化。
- `NO_TUNNEL=1` でローカルのみ配信できることを追記。

- [ ] **Step 3: コミット**

```bash
git add CLAUDE.md .claude/skills/viewer-preview/SKILL.md
git commit -m "docs: CLAUDE.md と viewer-preview スキルを bun ツーリングへ追随"
```

---

### Task 9: README スリム化と docs/firmware.md 新設

**Files:**
- Rewrite: `README.md`
- Create: `docs/firmware.md`

- [ ] **Step 1: docs/firmware.md を書く**

現 README の詳細セクションの退避先。内容は現 README の記述をベースに、「実機 TCP は次サイクル」系の記述を実態（検証済み）へ更新する。

```markdown
# ファームウェア詳細（セットアップ・書き込み・キャリブ・TCP）

README から退避したファームウェアの詳細手順。全体像とコマンド表は [README](../README.md) を参照。

## セットアップ

`nix develop` が rustup を用意する（rust-toolchain.toml が stable + thumbv6m を自動導入）。ほかに手動の準備が 2 つある。

- CYW43 ファームウェアブロブを取得する。ライセンス物のため未コミット。詳細は `crates/firmware/cyw43-firmware/README.md`。
- WiFi 認証をビルド時環境変数で渡す: `WIFI_SSID=... WIFI_PASSWORD=... nix develop -c cargo build --release --locked`。
  未設定でもビルドは通るが、プレースホルダのままなので実機では WiFi に接続できない（`crates/firmware/src/config.rs`）。

direnv を使う場合はリポジトリ直下に `.env.local`（dotenv 形式、`WIFI_SSID=値`）か
`.envrc.local`（bash、`export WIFI_SSID=値`）を作れば `.envrc` が自動で環境変数に載せる
（どちらも gitignore 済み。`direnv allow` を忘れずに）。`.envrc` は `use flake` を使うので
direnv に加えて **nix-direnv** が必要（未導入なら環境変数の読込だけ手動で行う）。

## ビルド

    nix develop -c cargo build --locked

ターゲットは thumbv6m-none-eabi（.cargo/config.toml で既定指定済み）。
依存の Embassy / cyw43 は crates.io 公開バージョンに固定済み。`Cargo.lock` をコミットしているため、`cargo build --locked` で完全に再現できる。

## ロジックの host テスト（実機不要）

    nix develop -c cargo host-test

ロック・コマンド（LOCK/UNLOCK/STATUS）の解釈と状態機械、および TCP serve ループ
（行分割・接続ライフサイクル・エラー処理・長すぎ行の棄却）を host でモック通しテストする。
内部的には `cargo test -p smtlk-core --target <host-triple>` を実行する外部サブコマンド（`cargo-host-test`）で実装しており、`uname -m` でホストトリプルを動的に解決する。x86_64 / aarch64 のどちらの環境でも同じコマンドで動く。

## 書き込み・実行

- デバッグプローブあり: `cargo run --release`（runner = `probe-rs run --chip RP2040`、defmt ログが出る）
- プローブなし: BOOTSEL ボタンを押しながら USB 接続 → UF2 を生成して書き込む

```
cargo install elf2uf2-rs
elf2uf2-rs -d target/thumbv6m-none-eabi/release/smtlk-firmware
```

## 遠隔操作（TCP）

WiFi 接続後、TCP ポート 6000 で 1 接続ずつコマンドを受け付ける。1 行 1 コマンド（`\n` 区切り）。
接続中はオンボード LED が点灯する。ブレッドボード実機でサーボ・LED・スイッチ全部載せの
同時動作を検証済み。

ロック状態は外付けの二色 LED（D1）で表示する（施錠=赤 GP16 / 解錠=黄緑 GP18、コモンカソード）。
オンボード LED（CYW43）は TCP 接続状態の表示で、役割を分担する。
GP17 のタクトスイッチを押すと施錠⇄解錠をトグルできる（室内側の手動操作）。ボタンは
Pico W の内部プルアップを使う（外付けプルアップ抵抗は付けない）。ボタン操作も TCP STATUS に反映される。

| コマンド | 応答 | 動作 |
| -------- | ------ | ------------ |
| UNLOCK   | UNLOCKED | 解錠 |
| LOCK     | LOCKED   | 施錠 |
| STATUS   | LOCKED / UNLOCKED | 現在の状態を返す |
| （不正）  | ERR    | 無視して次の行へ |

日常の操作はリポジトリ直下の `lockctl.sh` を使う（bash の /dev/tcp のみ使用、nc 不要）。
接続先 IP は環境変数 `TARGET_IP`（`.envrc.local` で定義 → direnv がロード）。

```
./lockctl.sh            # 現在と逆に切り替え（トグル）
./lockctl.sh lock       # 施錠（赤）
./lockctl.sh unlock     # 解錠（緑）
./lockctl.sh status     # 現在状態を問い合わせ（駆動しない）
```

serve ループ自体（行分割・接続終了・エラー処理）は `smtlk_core::serve::serve_connection` に
実装され、`nix develop -c cargo host-test` でモックにより通しテスト済み。

## サーボ動作確認とキャリブレーション

probe-rs か BOOTSEL+UF2 で焼くと、起動・WiFi 接続後に約 3 秒ごとに施錠⇄解錠を繰り返す
（オンボード LED がハートビート）。サーボ給電は動作時だけ ON（GP14 の電源ゲート）。

実機合わせはキャリブ定数だけを調整する。角度→パルス変換の 4 つ（SERVO_MIN_US / SERVO_MAX_US /
LOCK_DEG / UNLOCK_DEG）は `crates/smtlk-core/src/servo_math.rs` に集約、整定待ち SETTLE_MS は
`crates/firmware/src/servo.rs` にある。SG90 は個体差が大きいので、
まず安全側（狭い MIN/MAX）で焼き、唸らない・突き当てない範囲を実測で広げること。
初回はサムターンを手で止められる状態で投入する（突き当て保護）。
```

- [ ] **Step 2: README.md を書き換える**

全文を次に置き換える（約 60 行。旧 README の詳細は Task 9 Step 1 の docs/firmware.md へ退避済み）:

```markdown
# smtlk — スマートロック

既存ドアのサムターンに後付けする SG90 サーボ式スマートロック。
筐体（OpenSCAD）＋ 回路（tscircuit / TS）＋ Pico W ファーム（Rust / Embassy）の monorepo。

## システム全体像

Pico W が WiFi 接続後に TCP ポート 6000 でコマンドを受け、サーボがサムターンを回して施錠/解錠する。
室内側のタクトスイッチでも手動でトグルでき、状態は外付けの二色 LED（施錠=赤/解錠=黄緑）で表示する。

| サブシステム | ディレクトリ | 役割 |
| --- | --- | --- |
| 筐体 | `scad/` | ドアに貼るベースプレート＋ボルトオンのサーボ台座・電子部品トレイ・サムターン受け |
| 回路 | `circuit/` | tscircuit で回路を記述し導通・ショート ERC で検証 |
| ファーム | `crates/` | WiFi / TCP / サーボ制御（firmware）＋ ハード非依存ロジック（smtlk-core） |
| ビューア | `viewer/` | STL をブラウザで確認（cloudflared quick tunnel で共有可） |

ロジック部（コマンド解釈・状態機械・serve ループ・角度変換）はハード非依存で、実機なしに host テストできる。
回路はブレッドボード実機でサーボ・LED・スイッチ全部載せの同時動作を検証済み。

## 開発環境（Nix）

`openscad` / `cargo` / `bun` / `cloudflared` は nix devShell の中にしか無い。

    nix develop

| やりたいこと | コマンド |
| --- | --- |
| 筐体ビルド（STL を scad/build/ へ） | `nix develop -c bun scad/build.ts` |
| SCAD レンダリングテスト（STL/PNG） | `nix develop -c bun scad/render.ts <scad> [out]` |
| 部品間の体積干渉チェック | `nix develop -c bun scad/clash.ts` |
| scad ツールの単体テスト | `nix develop -c bun test scad/` |
| 回路 ERC（導通・ショート） | `cd circuit && bun install --frozen-lockfile && bun test` |
| ファームビルド（thumbv6m） | `nix develop -c cargo build --locked` |
| ロジックの host テスト（実機不要） | `nix develop -c cargo host-test` |
| 3D ビューアを公開 | `nix develop -c bun viewer/serve.ts` |
| ブレッドボード配線図ビューア | `nix develop -c bun circuit/breadboard-serve.ts` |

回路 ERC は devShell 内で実行する。ビューア 2 種は `NO_TUNNEL=1` を付けるとトンネル無しの
ローカル配信になる。`scad/build/`・`circuit/build/`・`*.stl` は派生物なのでコミットしない（.gitignore 済み）。

## 配線と GPIO

配線の唯一の正は `circuit/index.tsx`（tscircuit）。GPIO 割り当てはファームと一致:
サーボ PWM GP15 / サーボ電源ゲート GP14 / LED 赤 GP16・黄緑 GP18（コモンカソード）/
タクトスイッチ GP17（内部プルアップ）。

## ファームウェア

セットアップ（WiFi 認証・CYW43 ブロブ）・書き込み・サーボキャリブ・TCP プロトコルの詳細は
[docs/firmware.md](docs/firmware.md) を参照。日常の遠隔操作は `./lockctl.sh lock|unlock|toggle|status`。

## 未確定（積み残し）

- 筐体: ドア固定の突っ張り先（mount_plate で隔離）。サムターン実寸の最終合わせ（socket パラメータで隔離）。
- ファーム: 省電力運用 / 手回し後の状態再同期。
```

- [ ] **Step 3: リンクと記述の整合を確認**

Run: `grep -n 'firmware.md' README.md && ls docs/firmware.md`
Expected: README にリンクがあり、docs/firmware.md が存在する

- [ ] **Step 4: コミット**

```bash
git add README.md docs/firmware.md
git commit -m "docs: README を全体像＋コマンド表に絞り、ファーム詳細を docs/firmware.md へ退避"
```

---

### Task 10: 現役ドキュメントの陳腐化修正

**Files:**
- Modify: `docs/measurements-checklist.md`（冒頭に完了状態を明記）
- Modify: `docs/parts-selection.md`（BOM 参照先の修正）

- [ ] **Step 1: measurements-checklist.md の冒頭に状態を明記**

タイトル直後（`## 目的` の前）に追記:

```markdown
> **状態（2026-07-20）:** サーボ系（A）・ドア系（B）とも実測済みで `params.scad` に反映済み。
> このチェックリストは実測記録のアーカイブとして残す。新たな未実測寸法が出たらここに追記する。
```

- [ ] **Step 2: parts-selection.md の BOM 参照先を修正**

`## 概要` の目的行を修正:

旧: `- 目的: \`circuit/netlist.py\` の BOM を日本のネット通販で発注できる実商品へ対応づけ、購入先をまとめて 1 台分の概算を出す。`

新: `- 目的: 回路記述（\`circuit/index.tsx\`、tscircuit）の部品を日本のネット通販で発注できる実商品へ対応づけ、購入先をまとめて 1 台分の概算を出す。`

- [ ] **Step 3: 他に netlist.py / 旧スクリプトへの言及が現役文書に残っていないか確認**

Run: `grep -rn -E 'netlist\.py|build\.sh|serve\.py|erc\.sh|render\.sh|clash\.sh|breadboard\.sh|test/' README.md CLAUDE.md docs/measurements-checklist.md docs/parts-selection.md docs/firmware.md .claude/skills/`
Expected: ヒットなし（`docs/superpowers/` の履歴は対象外なので検索に含めない）

- [ ] **Step 4: コミット**

```bash
git add docs/measurements-checklist.md docs/parts-selection.md
git commit -m "docs: 実測チェックリストの完了状態を明記し BOM 参照先を tscircuit に修正"
```

---

### Task 11: 最終検証スイープ

**Files:** なし（検証のみ。問題が出たら該当タスクに戻って修正）

- [ ] **Step 1: 全コマンドを通しで実行**

```bash
nix develop -c bun test scad/
nix develop -c bun scad/build.ts
nix develop -c bun scad/render.ts scad/smoke.scad
nix develop -c bun scad/clash.ts
nix develop -c bash -euo pipefail -c 'cd circuit && bun install --frozen-lockfile && bun test'
nix develop -c cargo build --locked
nix develop -c cargo host-test
```

Expected: すべて exit 0

- [ ] **Step 2: ビューア 2 種を NO_TUNNEL でスモーク**

Task 5 Step 4 / Task 6 Step 3 のコマンドを再実行。
Expected: いずれも `200` が 2 行

- [ ] **Step 3: 廃止物への残参照が無いことを横断確認**

```bash
git grep -n -E '\./build\.sh|test/render|test/erc|test/clash|serve\.py|breadboard-serve\.py|breadboard\.sh|uv run' -- ':!docs/superpowers' ':!Cargo.lock' ':!circuit/bun.lock'
```

Expected: ヒットなし

- [ ] **Step 4: README のコマンド表と実ファイルの突き合わせ**

README のコマンド表の各行を目視で確認し、参照するファイル（`scad/build.ts` 等）がすべて存在することを確認:

```bash
ls scad/build.ts scad/render.ts scad/clash.ts scad/openscad.ts viewer/serve.ts circuit/breadboard-serve.ts lockctl.sh docs/firmware.md
```

Expected: 全ファイル存在

- [ ] **Step 5: 仕上がり確認コミット（残変更があれば）**

```bash
git status --short
```

Expected: クリーン（残変更があれば内容を確認してから適切なタスクの修正としてコミット）

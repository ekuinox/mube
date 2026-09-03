#!/usr/bin/env bun
// ユニバーサル基板の配線見本を生成し、SVG をブラウザへ配信して cloudflared quick tunnel で
// 公開する。NO_TUNNEL=1 でローカル配信のみ。
// ポートは viewer/serve.ts（8765）と circuit/breadboard-serve.ts（8766）との衝突を避けて 8767。
//
// perfboard-build.ts は検証に落ちると SVG を書かずに終了するので、
// 「検証を通っていない図を公開してしまう」ことは起きない。
import { join } from "node:path";
import { serveDir } from "../viewer/static.ts";
import { startTunnel } from "../viewer/tunnel.ts";

const circuitDir = import.meta.dir;
const buildDir = join(circuitDir, "build");
const port = Number(process.env.PORT ?? "8767");

const build = Bun.spawnSync(["bun", "perfboard-build.ts"], {
  cwd: circuitDir, stdout: "inherit", stderr: "inherit",
});
if (build.exitCode !== 0) {
  console.error("FAIL: bun perfboard-build.ts");
  process.exit(1);
}
// 戻り値 0 でも SVG が出ていなければ異常として扱う
const svg = join(buildDir, "perfboard.svg");
if (!(await Bun.file(svg).exists())) {
  console.error(`FAIL: expected ${svg} was not produced`);
  process.exit(1);
}

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
console.log(`  Open in your browser:  ${url}/perfboard.svg`);
console.log("=".repeat(60) + "\n  Ctrl-C to stop.\n");

const stop = () => {
  console.log("\nstopping…");
  tunnelProc?.kill();
  server.stop();
  process.exit(0);
};
process.on("SIGINT", stop);
process.on("SIGTERM", stop);

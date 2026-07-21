#!/usr/bin/env bun
// 筐体パーツを STL にレンダリングし、ブラウザビューアを配信して cloudflared quick tunnel で
// 公開する。NO_TUNNEL=1 でローカル配信のみ。
import { copyFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { renderScad } from "../enclosure/scripts/openscad.ts";
import { serveDir } from "./static.ts";
import { startTunnel } from "./tunnel.ts";

const root = dirname(import.meta.dir); // viewer/ の親 = リポジトリルート
const modelsDir = join(root, "enclosure", "models");
const buildDir = join(root, "enclosure", "build");
const smartlock = join(modelsDir, "smartlock.scad");
const port = Number(process.env.PORT ?? "8765");
// assembly は smartlock.scad が未知の part 名を全体アセンブリとして描く仕様を利用している
const parts = [
  "body", "pedestal", "socket", "tray", "assembly",
  "asm_body", "asm_pedestal", "asm_socket", "asm_tray",
];

for (const part of parts) {
  console.log(`rendering ${part} -> enclosure/build/${part}.stl`);
  try {
    await renderScad(smartlock, join(buildDir, `${part}.stl`), { part });
  } catch (err) {
    console.error(`FAIL rendering ${part} — ${err instanceof Error ? err.message : err}`);
    process.exit(1);
  }
}
await copyFile(join(root, "viewer", "index.html"), join(buildDir, "index.html"));

const server = serveDir(buildDir, port);
console.log(`serving enclosure/build/ at http://127.0.0.1:${port}`);

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

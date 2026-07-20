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

#!/usr/bin/env bun
// スマートロックの施錠/解錠を HTTP で操作するクライアント。
//   赤 = 施錠 (LOCKED) / 緑 = 解錠 (UNLOCKED)
//
// 接続先は環境変数 TARGET_IP（.envrc.local で定義 → direnv がロード）。ポートは 80 既定（PORT env で上書き可）。
//
// 使い方:
//   bun lockctl.ts            # トグル（引数なし）
//   bun lockctl.ts toggle     # 同上
//   bun lockctl.ts lock       # 施錠（赤）
//   bun lockctl.ts unlock     # 解錠（緑）
//   bun lockctl.ts status     # 現在状態を問い合わせ（駆動しない）

/** {"state":"LOCKED"|"UNLOCKED"} から状態文字列を取り出す。想定外は null。 */
export function parseState(body: string): "LOCKED" | "UNLOCKED" | null {
  try {
    const s = JSON.parse(body)?.state;
    return s === "LOCKED" || s === "UNLOCKED" ? s : null;
  } catch {
    return null;
  }
}

/** 状態を人間向けの表示にする。想定外は null。 */
export function formatReply(state: string): string | null {
  if (state === "LOCKED") return "施錠 (LOCKED) / 赤";
  if (state === "UNLOCKED") return "解錠 (UNLOCKED) / 緑";
  return null;
}

/** コマンドを 1 つ実行して人間向けの結果メッセージを返す。異常は Error を投げる。 */
export async function runLockctl(
  cmd: "toggle" | "lock" | "unlock" | "status",
  base: string,
  timeoutMs = 5000,
): Promise<string> {
  const route =
    cmd === "status" ? "/api/status" : cmd === "toggle" ? "/api/toggle" : `/api/${cmd}`;
  const method = cmd === "status" ? "GET" : "POST";
  let resp: Response;
  try {
    resp = await fetch(base + route, { method, signal: AbortSignal.timeout(timeoutMs) });
  } catch {
    throw new Error(`${base} に接続できない。IP・電源・WiFi 接続を確認してね`);
  }
  if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
  const state = parseState(await resp.text());
  if (state === null) throw new Error("応答の JSON が想定外");
  const msg = formatReply(state);
  if (msg === null) throw new Error(`応答: '${state}'`);
  return msg;
}

const USAGE = "usage: bun lockctl.ts [toggle|lock|unlock|status]";

if (import.meta.main) {
  const cmd = process.argv[2] ?? "toggle";
  if (cmd === "-h" || cmd === "--help" || cmd === "help") {
    console.log(USAGE);
    console.log("  toggle  現在と逆に切り替え（引数なしと同じ）");
    console.log("  lock    施錠（赤）");
    console.log("  unlock  解錠（緑）");
    console.log("  status  現在状態を問い合わせ（駆動しない）");
    process.exit(0);
  }
  if (cmd !== "toggle" && cmd !== "lock" && cmd !== "unlock" && cmd !== "status") {
    console.error(USAGE);
    process.exit(2);
  }
  const host = process.env.TARGET_IP;
  if (!host) {
    console.error("error: TARGET_IP が未設定。.envrc.local を定義して 'direnv allow' したか確認してね");
    process.exit(1);
  }
  const port = process.env.PORT ?? "80";
  const base = `http://${host}:${port}`;
  const timeoutMs = Number(process.env.CONNECT_TIMEOUT ?? "5") * 1000;
  try {
    console.log(await runLockctl(cmd, base, timeoutMs));
  } catch (err) {
    console.error(`error: ${err instanceof Error ? err.message : err}`);
    process.exit(1);
  }
}

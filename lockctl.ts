#!/usr/bin/env bun
// スマートロックの施錠/解錠を TCP で切り替えるクライアント。
//   赤 = 施錠 (LOCKED) / 緑 = 解錠 (UNLOCKED)
//
// 接続先 IP は環境変数 TARGET_IP（.envrc.local で定義 → direnv がロード）。
// ポートは firmware の LOCK_PORT=6000 固定（LOCK_PORT env で上書き可）。
//
// 使い方:
//   bun lockctl.ts            # 現在と逆に切り替え（トグル）
//   bun lockctl.ts toggle     # 同上
//   bun lockctl.ts lock       # 施錠（赤）
//   bun lockctl.ts unlock     # 解錠（緑）
//   bun lockctl.ts status     # 現在状態を問い合わせ（駆動しない）

/** 受信チャンクを行に分割するバッファ。改行未満の端切れは持ち越し、末尾 CR は除去する。 */
export class LineBuffer {
  private buf = "";

  push(chunk: string): string[] {
    this.buf += chunk;
    const lines = this.buf.split("\n");
    this.buf = lines.pop() ?? "";
    return lines.map((line) => line.replace(/\r$/, ""));
  }
}

/** STATUS 応答から、トグルで送るべきコマンドを決める。想定外の応答は null。 */
export function toggleTarget(status: string): "LOCK" | "UNLOCK" | null {
  if (status === "LOCKED") return "UNLOCK"; // 赤→緑
  if (status === "UNLOCKED") return "LOCK"; // 緑→赤
  return null;
}

/** 応答を人間向けの表示にする。想定外の応答は null。 */
export function formatReply(reply: string): string | null {
  if (reply === "LOCKED") return "施錠 (LOCKED) / 赤";
  if (reply === "UNLOCKED") return "解錠 (UNLOCKED) / 緑";
  return null;
}

type Conn = {
  send: (cmd: string) => Promise<string>;
  close: () => void;
};

// ファームは同時 1 接続しか捌けず、接続を閉じた直後の再接続を RST で蹴ることがある。
// 到達性のプリフライトはせず、接続は 1 回だけ張って全コマンドを流す（旧 lockctl.sh と同じ方針）。
async function openConn(
  host: string,
  port: number,
  connectTimeoutMs: number,
  replyTimeoutMs: number,
): Promise<Conn> {
  const lineBuf = new LineBuffer();
  const pending: string[] = [];
  let waiter: ((line: string | null) => void) | null = null;
  // 受信行は待ち手がいれば直接渡し、いなければ次の send まで貯めておく。
  // null はストリーム終了（切断・エラー）の合図。
  const deliver = (line: string | null) => {
    if (waiter) {
      const w = waiter;
      waiter = null;
      w(line);
    } else if (line !== null) {
      pending.push(line);
    }
  };

  let socket: Awaited<ReturnType<typeof Bun.connect>>;
  try {
    socket = await Promise.race([
      Bun.connect({
        hostname: host,
        port,
        socket: {
          data(_s, chunk) {
            for (const line of lineBuf.push(chunk.toString())) deliver(line);
          },
          close() {
            deliver(null);
          },
          error() {
            deliver(null);
          },
        },
      }),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error("connect timeout")), connectTimeoutMs),
      ),
    ]);
  } catch {
    throw new Error(`${host}:${port} に接続できない。IP・電源・WiFi 接続を確認してね`);
  }

  return {
    async send(cmd: string): Promise<string> {
      socket.write(cmd + "\n");
      const line = await new Promise<string | null>((resolve) => {
        if (pending.length > 0) return resolve(pending.shift()!);
        waiter = resolve;
        setTimeout(() => {
          if (waiter === resolve) {
            waiter = null;
            resolve(null);
          }
        }, replyTimeoutMs);
      });
      if (line === null) {
        throw new Error(`${host}:${port} から応答なし（${replyTimeoutMs / 1000}秒タイムアウト）`);
      }
      return line;
    },
    close() {
      socket.end();
    },
  };
}

/** コマンドを 1 つ実行して人間向けの結果メッセージを返す。異常は Error を投げる。 */
export async function runLockctl(
  cmd: "toggle" | "lock" | "unlock" | "status",
  host: string,
  port: number,
  connectTimeoutMs = 5000,
  replyTimeoutMs = 5000,
): Promise<string> {
  const conn = await openConn(host, port, connectTimeoutMs, replyTimeoutMs);
  try {
    let result: string;
    if (cmd === "lock") result = await conn.send("LOCK");
    else if (cmd === "unlock") result = await conn.send("UNLOCK");
    else if (cmd === "status") result = await conn.send("STATUS");
    else {
      const cur = await conn.send("STATUS");
      const next = toggleTarget(cur);
      if (next === null) throw new Error(`STATUS の応答が想定外: '${cur}'`);
      result = await conn.send(next);
    }
    if (result === "ERR") throw new Error("ロックが ERR を返した（不正コマンド）");
    const msg = formatReply(result);
    if (msg === null) throw new Error(`応答: '${result}'`);
    return msg;
  } finally {
    conn.close();
  }
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
  const port = Number(process.env.LOCK_PORT ?? "6000");
  const connectTimeoutMs = Number(process.env.CONNECT_TIMEOUT ?? "5") * 1000;
  try {
    console.log(await runLockctl(cmd, host, port, connectTimeoutMs));
  } catch (err) {
    console.error(`error: ${err instanceof Error ? err.message : err}`);
    process.exit(1);
  }
}

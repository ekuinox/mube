import { test, expect } from "bun:test";
import { LineBuffer, toggleTarget, formatReply, runLockctl } from "./lockctl.ts";

test("LineBuffer: 改行で行に分割し、途中のチャンクは持ち越す", () => {
  const buf = new LineBuffer();
  expect(buf.push("LOC")).toEqual([]);
  expect(buf.push("KED\nUNLO")).toEqual(["LOCKED"]);
  expect(buf.push("CKED\n")).toEqual(["UNLOCKED"]);
});

test("LineBuffer: 末尾 CR を除去する（CRLF 応答対策）", () => {
  const buf = new LineBuffer();
  expect(buf.push("LOCKED\r\n")).toEqual(["LOCKED"]);
});

test("toggleTarget: LOCKED なら UNLOCK、UNLOCKED なら LOCK", () => {
  expect(toggleTarget("LOCKED")).toBe("UNLOCK");
  expect(toggleTarget("UNLOCKED")).toBe("LOCK");
});

test("toggleTarget: 想定外の応答は null", () => {
  expect(toggleTarget("ERR")).toBeNull();
  expect(toggleTarget("")).toBeNull();
});

test("formatReply: 応答を人間向け表示に変換する", () => {
  expect(formatReply("LOCKED")).toBe("施錠 (LOCKED) / 赤");
  expect(formatReply("UNLOCKED")).toBe("解錠 (UNLOCKED) / 緑");
  expect(formatReply("HUH")).toBeNull();
});

// ファームの TCP プロトコル（1 行 1 コマンド、LOCK/UNLOCK/STATUS）を模したモックサーバ。
function startMock(initialLocked: boolean) {
  const state = { locked: initialLocked };
  const bufs = new Map<unknown, LineBuffer>();
  const server = Bun.listen({
    hostname: "127.0.0.1",
    port: 0,
    socket: {
      open(s) {
        bufs.set(s, new LineBuffer());
      },
      data(s, chunk) {
        for (const line of bufs.get(s)!.push(chunk.toString())) {
          let reply: string;
          if (line === "STATUS") reply = state.locked ? "LOCKED" : "UNLOCKED";
          else if (line === "LOCK") {
            state.locked = true;
            reply = "LOCKED";
          } else if (line === "UNLOCK") {
            state.locked = false;
            reply = "UNLOCKED";
          } else reply = "ERR";
          s.write(reply + "\n");
        }
      },
      close(s) {
        bufs.delete(s);
      },
    },
  });
  return { server, state };
}

test("runLockctl: モックサーバ相手に status / toggle / lock が通る", async () => {
  const m = startMock(true);
  const port = m.server.port;
  expect(await runLockctl("status", "127.0.0.1", port)).toBe("施錠 (LOCKED) / 赤");
  expect(await runLockctl("toggle", "127.0.0.1", port)).toBe("解錠 (UNLOCKED) / 緑");
  expect(m.state.locked).toBe(false);
  expect(await runLockctl("lock", "127.0.0.1", port)).toBe("施錠 (LOCKED) / 赤");
  expect(m.state.locked).toBe(true);
  m.server.stop();
});

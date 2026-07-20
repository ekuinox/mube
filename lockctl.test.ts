import { test, expect } from "bun:test";
import { parseState, formatReply, runLockctl } from "./lockctl.ts";

test("parseState: JSON から状態を取り出す", () => {
  expect(parseState('{"state":"LOCKED"}')).toBe("LOCKED");
  expect(parseState('{"state":"UNLOCKED"}')).toBe("UNLOCKED");
});

test("parseState: 想定外は null", () => {
  expect(parseState('{"state":"HUH"}')).toBeNull();
  expect(parseState("not json")).toBeNull();
});

test("formatReply: 応答を人間向け表示に変換する", () => {
  expect(formatReply("LOCKED")).toBe("施錠 (LOCKED) / 赤");
  expect(formatReply("UNLOCKED")).toBe("解錠 (UNLOCKED) / 緑");
  expect(formatReply("HUH")).toBeNull();
});

// firmware の HTTP API を模したモックサーバ。
function startMock(initialLocked: boolean) {
  const state = { locked: initialLocked };
  const body = () => JSON.stringify({ state: state.locked ? "LOCKED" : "UNLOCKED" });
  const server = Bun.serve({
    port: 0,
    fetch(req) {
      const url = new URL(req.url);
      if (req.method === "POST" && url.pathname === "/api/lock") state.locked = true;
      else if (req.method === "POST" && url.pathname === "/api/unlock") state.locked = false;
      else if (req.method === "POST" && url.pathname === "/api/toggle") state.locked = !state.locked;
      // GET /api/status は状態を変えない。
      return new Response(body(), { headers: { "content-type": "application/json" } });
    },
  });
  return { server, state };
}

test("runLockctl: モック HTTP 相手に status / toggle / lock が通る", async () => {
  const m = startMock(true);
  const base = `http://127.0.0.1:${m.server.port}`;
  expect(await runLockctl("status", base)).toBe("施錠 (LOCKED) / 赤");
  expect(await runLockctl("toggle", base)).toBe("解錠 (UNLOCKED) / 緑");
  expect(m.state.locked).toBe(false);
  expect(await runLockctl("lock", base)).toBe("施錠 (LOCKED) / 赤");
  expect(m.state.locked).toBe(true);
  m.server.stop();
});

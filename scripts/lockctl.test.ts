import { test, expect } from "bun:test";
import { parseState, formatReply, runLockctl, crc32, buildOtaHeader, parseOtaReply } from "./lockctl.ts";

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

// ---- OTA（ワイヤ形式は crates/mube-core/src/ota.rs と同一契約）----

test("crc32: IEEE 標準テストベクタ（mube-core 側テストと同一）", () => {
  expect(crc32(new TextEncoder().encode("123456789"))).toBe(0xcbf43926);
});

test("crc32: 空入力は 0", () => {
  expect(crc32(new Uint8Array(0))).toBe(0);
});

test("buildOtaHeader: マジック + u32 LE ×2 の 16 バイト", () => {
  const h = buildOtaHeader(0x0102, 0xdeadbeef);
  expect(h.length).toBe(16);
  expect(new TextDecoder().decode(h.slice(0, 8))).toBe("MUBEOTA1");
  // length u32 LE
  expect([...h.slice(8, 12)]).toEqual([0x02, 0x01, 0x00, 0x00]);
  // crc32 u32 LE
  expect([...h.slice(12, 16)]).toEqual([0xef, 0xbe, 0xad, 0xde]);
});

test("parseOtaReply: OK / ERR / 想定外", () => {
  expect(parseOtaReply("OK 12345\n")).toEqual({ ok: true, detail: "12345" });
  expect(parseOtaReply("ERR crc mismatch\n")).toEqual({ ok: false, detail: "crc mismatch" });
  expect(parseOtaReply("garbage")).toBeNull();
});

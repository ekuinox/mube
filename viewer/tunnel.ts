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
      let found = false;
      for await (const chunk of proc.stderr as ReadableStream<Uint8Array>) {
        if (!found) {
          buf += decoder.decode(chunk);
          const m = URL_RE.exec(buf);
          if (m) {
            found = true;
            buf = ""; // URL 確定後はバッファ不要なので解放
            clearTimeout(timer);
            resolve(m[0]);
          }
        }
        // URL 取得後も読み捨てを続け、cloudflared がパイプ詰まりで
        // ブロックしないようにする（旧 Python 版の常駐 drain と同等）
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

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
      // STL はモデル編集のたびに再生成される。キャッシュヘッダ無しだとブラウザの
      // 発見的キャッシュに掴まれて古い形状が表示され続けるため、明示的に無効化する
      if (await file.exists())
        return new Response(file, { headers: { "Cache-Control": "no-store" } });
      return new Response("Not Found", { status: 404 });
    },
  });
}

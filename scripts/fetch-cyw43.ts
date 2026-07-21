#!/usr/bin/env bun
// CYW43439 ファームウェアブロブ（firmware / NVRAM / CLM）を取得する（旧 fetch.sh の置き換え）。
// curl/wget の代わりに bun 内蔵の fetch() を使う。crate と同じ rev（cyw43-v0.7.0 タグ）から
// 取ってバージョンを揃える。ライセンス物で .gitignore 済み。詳細は
// crates/mube-firmware/cyw43-firmware/README.md を参照。
import { rename } from "node:fs/promises";
import { dirname, join } from "node:path";

/** cyw43 crate と同じ rev。 */
export const TAG = "cyw43-v0.7.0";
const BASE = `https://raw.githubusercontent.com/embassy-rs/embassy/${TAG}/cyw43-firmware`;

/** ブロブ仕様。minBytes は HTML エラーページ・空ファイルを弾く sanity check の最低バイト数。 */
export const BLOBS: { name: string; minBytes: number }[] = [
  { name: "43439A0.bin", minBytes: 100_000 }, // WiFi ファームウェア（実測 ~225KB）
  { name: "43439A0_clm.bin", minBytes: 500 }, // 国別 CLM（実測 984 bytes）
  { name: "nvram_rp2040.bin", minBytes: 100 }, // 基板 NVRAM（実測 ~0.6KB）
];

/** サイズ sanity check 失敗。リトライしても無駄なので即失敗させるための型付きエラー。 */
class BlobTooSmallError extends Error {}

/** ブロブの保存先ディレクトリ（リポジトリルート基準で cwd 非依存）。 */
export function blobDir(): string {
  const repoRoot = dirname(import.meta.dir); // scripts/ の親 = リポジトリルート
  return join(repoRoot, "crates", "mube-firmware", "cyw43-firmware");
}

/** dir 内に存在しないブロブ名の配列を返す。3 つ揃っていれば空配列。存在判定のみ（サイズは見ない）。 */
export async function missingBlobs(dir: string): Promise<string[]> {
  const missing: string[] = [];
  for (const { name } of BLOBS) {
    if (!(await Bun.file(join(dir, name)).exists())) missing.push(name);
  }
  return missing;
}

/** バイト長が最低値以上か。 */
export function isValidSize(bytes: number, minBytes: number): boolean {
  return bytes >= minBytes;
}

/** 1 つのブロブを取得して dir に原子的に書き込み、書き込んだバイト数を返す。失敗は throw。 */
async function fetchBlob(dir: string, name: string, minBytes: number): Promise<number> {
  const url = `${BASE}/${name}`;
  let lastErr: unknown;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const buf = new Uint8Array(await res.arrayBuffer());
      if (!isValidSize(buf.byteLength, minBytes)) {
        // サイズ不正はリトライしても無駄なので即失敗
        throw new BlobTooSmallError(`${name} が小さすぎる (${buf.byteLength} < ${minBytes} bytes)。URL/タグを確認して`);
      }
      const out = join(dir, name);
      const tmp = `${out}.tmp`;
      await Bun.write(tmp, buf);
      await rename(tmp, out);
      return buf.byteLength;
    } catch (err) {
      lastErr = err;
      if (err instanceof BlobTooSmallError) throw err;
      // HTTP・ネットワークエラーは最大 3 回までリトライ
      if (attempt < 3) await Bun.sleep(2000);
    }
  }
  throw lastErr instanceof Error ? lastErr : new Error(String(lastErr));
}

/** メイン: 欠けているブロブだけ取得する。 */
async function main(): Promise<void> {
  const dir = blobDir();
  const missing = await missingBlobs(dir);
  if (missing.length === 0) {
    console.log("cyw43 blobs already present");
    return;
  }
  console.log(`CYW43 ブロブを取得: tag=${TAG}`);
  console.log(`  保存先: ${dir}`);
  for (const { name, minBytes } of BLOBS) {
    if (!missing.includes(name)) continue;
    console.log(`  - ${name} ...`);
    const size = await fetchBlob(dir, name, minBytes);
    console.log(`    ok (${size} bytes)`);
  }
  console.log("完了。ブロブを配置したよ。");
}

if (import.meta.main) {
  try {
    await main();
  } catch (err) {
    console.error(`error: ${err instanceof Error ? err.message : err}`);
    process.exit(1);
  }
}

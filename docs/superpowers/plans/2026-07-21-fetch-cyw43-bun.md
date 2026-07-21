# CYW43 ブロブ取得の bun 化 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `fetch.sh`（bash）を `scripts/fetch-cyw43.ts`（bun）へ移植し、Justfile の `blobs` レシピを一行化して bash を排除する。

**Architecture:** bun 内蔵の `fetch()` でブロブを取得する単一 TS スクリプトを新設。「揃っていればスキップ」判定と retry・サイズ sanity check・原子的書き込みをスクリプト側に内包し、純粋ロジック（`missingBlobs` / `isValidSize`）を分離して bun test で守る。Justfile の `blobs` は `bun scripts/fetch-cyw43.ts` を呼ぶだけにする。

**Tech Stack:** bun（TS スクリプト・`fetch()`・bun:test）、just、Nix devShell。

## Global Constraints

- 開発機の非対話シェルには `bun` / `cargo` / `trunk` / `just` が PATH に無い。Claude が実行するコマンドは各々 `nix develop -c` を前置する。
- ブロブのバージョン（`cyw43-v0.7.0` タグ）・取得元 URL・最低バイト数は `fetch.sh` と同値を保つ。変更しない。
- 対象外（今回触らない）: `flake.nix` の `writeShellScriptBin`（`backlog` / `cargo-host-test`）、CI のインライン `bash -c` ステップ。shell 排除は `fetch.sh` と Justfile の `blobs` レシピに限る。
- CI は変更しない（実ブロブを取得せず `touch` でダミーを置くため無関係）。
- `firmware: blobs webui` の依存は変更しない。
- Cargo.lock はコミット済み。この計画では Rust コードを変更しない。
- コミットメッセージ末尾に `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` を付ける。

---

## ファイル構成

```
scripts/fetch-cyw43.ts        （新規。bun 取得スクリプト）
scripts/fetch-cyw43.test.ts   （新規。純粋ロジックの bun test）
Justfile                      （blobs レシピを一行化）
crates/mube-firmware/cyw43-firmware/fetch.sh   （削除）
crates/mube-firmware/cyw43-firmware/README.md  （手動 curl の前に just blobs を追記）
docs/firmware.md              （ブロブ取得に just blobs を一言）
```

---

### Task 1: scripts/fetch-cyw43.ts（bun 取得スクリプト）＋ 単体テスト

**Files:**
- Create: `scripts/fetch-cyw43.ts`
- Test: `scripts/fetch-cyw43.test.ts`

**Interfaces:**
- Produces: `BLOBS`（`{ name: string; minBytes: number }[]`）、`blobDir(): string`、`missingBlobs(dir: string): Promise<string[]>`、`isValidSize(bytes: number, minBytes: number): boolean`。Justfile（Task 2）は `bun scripts/fetch-cyw43.ts` として実行する。

- [ ] **Step 1: 失敗するテストを書く**

`scripts/fetch-cyw43.test.ts` を作成する:

```ts
import { test, expect } from "bun:test";
import { mkdtemp, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { BLOBS, missingBlobs, isValidSize } from "./fetch-cyw43.ts";

test("isValidSize: 最低値以上は true、未満は false", () => {
  expect(isValidSize(100_000, 100_000)).toBe(true);
  expect(isValidSize(100_001, 100_000)).toBe(true);
  expect(isValidSize(99_999, 100_000)).toBe(false);
});

test("missingBlobs: 空ディレクトリは全ブロブ名を返す", async () => {
  const dir = await mkdtemp(join(tmpdir(), "cyw43-"));
  try {
    expect((await missingBlobs(dir)).sort()).toEqual(BLOBS.map((b) => b.name).sort());
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("missingBlobs: 一部だけ存在すると残りを返す", async () => {
  const dir = await mkdtemp(join(tmpdir(), "cyw43-"));
  try {
    await writeFile(join(dir, "43439A0.bin"), "x");
    expect((await missingBlobs(dir)).sort()).toEqual(
      ["43439A0_clm.bin", "nvram_rp2040.bin"].sort(),
    );
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test("missingBlobs: 3 つ揃っていれば空配列", async () => {
  const dir = await mkdtemp(join(tmpdir(), "cyw43-"));
  try {
    for (const { name } of BLOBS) await writeFile(join(dir, name), "x");
    expect(await missingBlobs(dir)).toEqual([]);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});
```

- [ ] **Step 2: テストが失敗することを確認する**

Run: `nix develop -c bun test scripts/fetch-cyw43.test.ts`
Expected: FAIL（`Cannot find module './fetch-cyw43.ts'` 相当。実装がまだ無い）

- [ ] **Step 3: スクリプトを実装する**

`scripts/fetch-cyw43.ts` を作成する:

```ts
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
        throw new Error(`${name} が小さすぎる (${buf.byteLength} < ${minBytes} bytes)。URL/タグを確認して`);
      }
      const out = join(dir, name);
      const tmp = `${out}.tmp`;
      await Bun.write(tmp, buf);
      await rename(tmp, out);
      return buf.byteLength;
    } catch (err) {
      lastErr = err;
      if (err instanceof Error && err.message.includes("小さすぎる")) throw err;
      // HTTP・ネットワークエラーは最大 3 回までリトライ
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
```

- [ ] **Step 4: テストが通ることを確認する**

Run: `nix develop -c bun test scripts/fetch-cyw43.test.ts`
Expected: PASS（4 tests）

- [ ] **Step 5: スクリプトが実行できることを確認する（ブロブは既に配置済み）**

Run: `nix develop -c bun scripts/fetch-cyw43.ts`
Expected: `cyw43 blobs already present`（3 ブロブが既にあるためスキップ。非ゼロ終了しない）

- [ ] **Step 6: コミット**

```bash
git add scripts/fetch-cyw43.ts scripts/fetch-cyw43.test.ts
git commit -m "feat: CYW43 ブロブ取得を bun スクリプト化（fetch.sh の置き換え）

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Justfile 一行化・fetch.sh 削除・ドキュメント追随

**Files:**
- Modify: `Justfile`（`blobs` レシピ）
- Delete: `crates/mube-firmware/cyw43-firmware/fetch.sh`
- Modify: `crates/mube-firmware/cyw43-firmware/README.md`, `docs/firmware.md`

**Interfaces:**
- Consumes: `scripts/fetch-cyw43.ts`（Task 1。`bun scripts/fetch-cyw43.ts` で実行）。

- [ ] **Step 1: Justfile の blobs レシピを一行化する**

`Justfile` の `blobs` レシピ（bash シェバングレシピ）を次へ置き換える。

置換対象（現状）:

```
# CYW43 ブロブを取得（3 ファイル揃ってなければ fetch.sh）
blobs:
    #!/usr/bin/env bash
    set -euo pipefail
    dir=crates/mube-firmware/cyw43-firmware
    if [ -f "$dir/43439A0.bin" ] && [ -f "$dir/43439A0_clm.bin" ] && [ -f "$dir/nvram_rp2040.bin" ]; then
      echo "cyw43 blobs already present"
    else
      "$dir/fetch.sh"
    fi
```

置換後:

```
# CYW43 ブロブを取得（3 ファイル揃っていなければ取得）
blobs:
    bun scripts/fetch-cyw43.ts
```

- [ ] **Step 2: fetch.sh を削除する**

```bash
git rm crates/mube-firmware/cyw43-firmware/fetch.sh
```

- [ ] **Step 3: cyw43-firmware/README.md に just blobs を追記する**

`crates/mube-firmware/cyw43-firmware/README.md` の次の 2 行（手動 curl の導入文）を差し替える。

置換対象（現状。13-14 行目）:

```
ビルド前に embassy リポジトリから取得してこのディレクトリに置くこと。**crate と同じ rev**
（`cyw43-v0.7.0` タグ）から取ってバージョンを揃える:
```

置換後:

```
ビルド前にこのディレクトリへ配置する。推奨はリポジトリルートで `just blobs`（内部で
`bun scripts/fetch-cyw43.ts` を実行し、欠けているブロブだけを取得する）。

手動で取る場合は **crate と同じ rev**（`cyw43-v0.7.0` タグ）から取ってバージョンを揃える:
```

- [ ] **Step 4: docs/firmware.md にブロブ取得コマンドを一言添える**

`docs/firmware.md` の 13 行目を差し替える。

置換対象（現状）:

```
- CYW43 ファームウェアブロブを取得する。ライセンス物のため未コミット。詳細は `crates/mube-firmware/cyw43-firmware/README.md`。
```

置換後:

```
- CYW43 ファームウェアブロブを取得する（リポジトリルートで `just blobs`）。ライセンス物のため未コミット。詳細は `crates/mube-firmware/cyw43-firmware/README.md`。
```

- [ ] **Step 5: 旧参照が残っていないことを確認する**

Run: `grep -rn "fetch\.sh" Justfile crates docs | grep -v docs/superpowers/ || echo NO_HITS`
Expected: `NO_HITS`

- [ ] **Step 6: blobs レシピが動くことを確認する（既に配置済み → スキップ）**

Run: `nix develop -c just blobs`
Expected: `cyw43 blobs already present`

- [ ] **Step 7: 取得パスがネット越しに動くことを確認する（1 ファイル退避 → 再取得 → 復元）**

```bash
mv crates/mube-firmware/cyw43-firmware/nvram_rp2040.bin /tmp/nvram_rp2040.bin.bak
nix develop -c just blobs
```
Expected: `- nvram_rp2040.bin ...` と `ok (<bytes>)` が出て、退避した 1 ファイルだけ再取得される（ネットアクセスを含む）。取得後 `crates/mube-firmware/cyw43-firmware/nvram_rp2040.bin` が復活する。
もしネット制限で取得できない場合は、その旨を明示し、退避ファイルを手動で戻す:
```bash
mv -f /tmp/nvram_rp2040.bin.bak crates/mube-firmware/cyw43-firmware/nvram_rp2040.bin
```

- [ ] **Step 8: firmware 一発ビルドが引き続き通ることを確認する**

Run: `nix develop -c just firmware`
Expected: `blobs`（already present）→ `webui`（trunk build）→ `cargo build` が順に通り、非ゼロ終了しない。

- [ ] **Step 9: コミット**

```bash
git add Justfile crates/mube-firmware/cyw43-firmware/README.md docs/firmware.md
git commit -m "chore: Justfile の blobs を bun 呼び出しに一行化し fetch.sh を削除

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review メモ

- **Spec coverage:** 新規スクリプト（Task 1）／純粋ロジックのテスト（Task 1）／Justfile 一行化（Task 2 Step 1）／fetch.sh 削除（Task 2 Step 2）／README・firmware.md 追随（Task 2 Step 3-4）／旧参照確認（Task 2 Step 5）を各タスクでカバー。spec の検証項目（テスト緑・just blobs の present/fetch・just firmware）を Task 1 Step 4-5・Task 2 Step 6-8 で実行。
- **Placeholder:** 具体コード・具体コマンド・期待出力を各 Step に明記。曖昧語なし。
- **Type consistency:** `BLOBS` / `missingBlobs` / `isValidSize` / `blobDir` の名前と型は Task 1 で定義し、テスト（Task 1 Step 1）と一致。Justfile（Task 2）はスクリプトを実行するだけで型の受け渡しは無い。
- **対象範囲:** Nix ラッパと CI bash は Global Constraints で対象外と明記。

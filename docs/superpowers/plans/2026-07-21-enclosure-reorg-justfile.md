# enclosure 化ディレクトリ再編 + Justfile 導入 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `scad/` を `enclosure/`（`models/` + `scripts/` 分割）へ再編し、`lockctl` をトップレベル `scripts/` に移し、ルート `Justfile` で clone 後 `just firmware` 一発でファームビルドまで到達できるようにする。

**Architecture:** 主にファイル移動（`git mv`）とパス参照の追随修正。`.scad` は同一ディレクトリへまとめて動くので相対 include は不変。TS スクリプトは `import.meta.dir` 基準のパス組み立てだけ修正。ビルド入口を `Justfile` に集約し、`just firmware` は `blobs`（CYW43 取得）→ `webui`（trunk build）→ `cargo build` を依存で連鎖させる。

**Tech Stack:** bun（TS スクリプト・テスト）、OpenSCAD、Rust/Cargo（Embassy ファーム）、trunk（yew WASM）、just、Nix flake devShell。

## Global Constraints

- 開発機の非対話シェルには `openscad` / `cargo` / `bun` / `cloudflared` / `just` が PATH に無い。Claude が実行するコマンドは各々 `nix develop -c` を前置する（例: `nix develop -c bun test enclosure/scripts/`）。
- Rust を変更したらコミット前に `nix develop -c cargo host-test` を通す（本計画では Rust コードは変更しないが、ビルド確認は行う）。
- `enclosure/build/` / `circuit/build/` と `*.stl` は派生物。コミットしない（`.gitignore` の `build/` と `*.stl` で既にカバー。gitignore 変更不要）。
- `.scad` 同士の相対参照（`include <params.scad>` / `use <body.scad>`）は全ファイルが `enclosure/models/` へ一緒に動くため修正不要。
- `git mv` を使い、履歴を保つ。移動とパス修正は同一コミットにまとめる（中間状態でテストが壊れるため）。
- コミットメッセージ末尾に `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` を付ける。

---

## ファイル構成（変更後）

```
enclosure/models/*.scad          （旧 scad/*.scad）
enclosure/scripts/build.ts       （旧 scad/build.ts、パス修正）
enclosure/scripts/render.ts      （旧 scad/render.ts、修正なし）
enclosure/scripts/clash.ts       （旧 scad/clash.ts、パス修正）
enclosure/scripts/openscad.ts    （旧 scad/openscad.ts、修正なし）
enclosure/scripts/openscad.test.ts（旧 scad/openscad.test.ts、修正なし）
scripts/lockctl.ts               （旧 lockctl.ts、修正なし）
scripts/lockctl.test.ts          （旧 lockctl.test.ts、修正なし）
viewer/serve.ts                  （import と scad パス参照を修正）
Justfile                         （新設）
flake.nix                        （devShell に just 追加）
.github/workflows/ci.yml         （パス更新）
README.md / CLAUDE.md            （コマンド表・地図更新）
.claude/skills/viewer-preview/SKILL.md（scad パス更新）
docs/firmware.md / docs/measurements-checklist.md（現役参照のみ更新）
```

---

### Task 1: scad/ を enclosure/（models + scripts）へ移動しパスを修正

**Files:**
- Move: `scad/*.scad` → `enclosure/models/*.scad`
- Move: `scad/build.ts` `scad/render.ts` `scad/clash.ts` `scad/openscad.ts` `scad/openscad.test.ts` → `enclosure/scripts/`
- Modify: `enclosure/scripts/build.ts`, `enclosure/scripts/clash.ts`

**Interfaces:**
- Produces: `enclosure/scripts/openscad.ts`（`renderScad` / `runOpenscad` / `openscadArgs` / `assertRenderOk` / `PNG_ARGS` を export。viewer/serve.ts が Task 3 で import）。
- Produces: モデル配置 `enclosure/models/`、出力先 `enclosure/build/`。

- [ ] **Step 1: ディレクトリを作り git mv で移動する**

```bash
mkdir -p enclosure/models enclosure/scripts
git mv scad/*.scad enclosure/models/
git mv scad/build.ts scad/render.ts scad/clash.ts scad/openscad.ts scad/openscad.test.ts enclosure/scripts/
rmdir scad 2>/dev/null || true
```

- [ ] **Step 2: build.ts のパス組み立てを修正する**

`enclosure/scripts/build.ts` の import 行と先頭のパス定義を差し替える。

import 行（`join` のみ → `dirname` を追加）:

```ts
import { dirname, join } from "node:path";
```

パス定義（`scadDir` 基準 → `modelsDir` / `buildDir` 基準）:

```ts
const scriptsDir = import.meta.dir;
const enclosureRoot = dirname(scriptsDir);
const modelsDir = join(enclosureRoot, "models");
const buildDir = join(enclosureRoot, "build");
const smartlock = join(modelsDir, "smartlock.scad");
```

gauge のレンダリング行（`scadDir` → `modelsDir`）:

```ts
    await renderScad(join(modelsDir, `${g}.scad`), join(buildDir, `${g}.stl`));
```

最終ログ行（表示だけ。実体に合わせる）:

```ts
console.log("All parts built to enclosure/build/");
```

- [ ] **Step 3: clash.ts のモデルパスを修正する**

`enclosure/scripts/clash.ts` の import とパス定義を差し替える。

```ts
import { dirname, join } from "node:path";
```

```ts
const scad = join(dirname(import.meta.dir), "models", "clash_check.scad");
```

- [ ] **Step 4: ヘルパ単体テストが通ることを確認する**

Run: `nix develop -c bun test enclosure/scripts/`
Expected: PASS（openscad.test.ts の全 8+ ケース。openscad バイナリ不要）

- [ ] **Step 5: 実レンダリングが通ることを確認する**

Run: `nix develop -c bun enclosure/scripts/build.ts`
Expected: 全パーツが `enclosure/build/` に出力され、最後に `All parts built to enclosure/build/`。非ゼロ終了しない。

Run: `nix develop -c bun enclosure/scripts/clash.ts`
Expected: `OK: no interference (empty intersection)`

Run: `nix develop -c bun enclosure/scripts/render.ts enclosure/models/tray.scad /tmp/tray.stl`
Expected: `OK: /tmp/tray.stl`

- [ ] **Step 6: コミット**

```bash
git add -A
git commit -m "refactor: scad/ を enclosure/(models+scripts) へ再編しパス修正

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: lockctl をトップレベル scripts/ へ移動

**Files:**
- Move: `lockctl.ts` `lockctl.test.ts` → `scripts/`

**Interfaces:**
- Consumes: なし（`lockctl.test.ts` は `./lockctl.ts` を相対 import。両者が一緒に動くため修正不要）。
- Produces: `scripts/lockctl.ts`（`bun scripts/lockctl.ts <sub>` で実行。Task 4 の Justfile が呼ぶ）。

- [ ] **Step 1: git mv で移動する**

```bash
mkdir -p scripts
git mv lockctl.ts lockctl.test.ts scripts/
```

- [ ] **Step 2: テストが通ることを確認する**

Run: `nix develop -c bun test scripts/lockctl.test.ts`
Expected: PASS（`runLockctl: モック HTTP 相手に status / toggle / lock が通る` 他）

- [ ] **Step 3: コミット**

```bash
git add -A
git commit -m "refactor: lockctl をトップレベル scripts/ へ移動

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: viewer/serve.ts の参照パスを更新

**Files:**
- Modify: `viewer/serve.ts`

**Interfaces:**
- Consumes: `renderScad`（`../enclosure/scripts/openscad.ts` から。Task 1 が提供）。

- [ ] **Step 1: import 行を更新する**

`viewer/serve.ts` の import を差し替える:

```ts
import { renderScad } from "../enclosure/scripts/openscad.ts";
```

- [ ] **Step 2: scad パス定義を更新する**

`scadDir` 系（`join(root, "scad")` 基準）を enclosure 基準に差し替える:

```ts
const root = dirname(import.meta.dir); // viewer/ の親 = リポジトリルート
const modelsDir = join(root, "enclosure", "models");
const buildDir = join(root, "enclosure", "build");
const smartlock = join(modelsDir, "smartlock.scad");
```

- [ ] **Step 3: ログ文言を実体に合わせる（表示のみ）**

`rendering ${part} -> scad/build/...` と `serving scad/build/ at ...` の 2 行を `enclosure/build/` 表記に更新する:

```ts
  console.log(`rendering ${part} -> enclosure/build/${part}.stl`);
```

```ts
console.log(`serving enclosure/build/ at http://127.0.0.1:${port}`);
```

- [ ] **Step 4: ローカル配信でレンダリングと起動を確認する**

Run: `NO_TUNNEL=1 nix develop -c bun viewer/serve.ts`
Expected: 全パーツが `enclosure/build/` にレンダリングされ、`Open in your browser: http://127.0.0.1:8765` が表示される。エラーで落ちない。確認できたら Ctrl-C で停止。

- [ ] **Step 5: コミット**

```bash
git add viewer/serve.ts
git commit -m "refactor: viewer/serve.ts の scad 参照を enclosure へ追随

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Justfile 新設 + flake devShell に just 追加

**Files:**
- Create: `Justfile`
- Modify: `flake.nix`（`packages` リストに `pkgs.just`）

**Interfaces:**
- Consumes: `enclosure/scripts/*.ts`（Task 1）、`scripts/lockctl.ts`（Task 2）。

- [ ] **Step 1: flake.nix の devShell に just を追加する**

`flake.nix` の `packages = [` リスト内、`pkgs.bun` の行の直後に追加する:

```nix
            pkgs.just         # ルート Justfile のタスクランナー
```

- [ ] **Step 2: ルートに Justfile を作成する**

`Justfile` を新規作成する:

```just
# 既定: レシピ一覧を表示
default:
    @just --list

# 筐体を STL に一括ビルド → enclosure/build/
enclosure:
    bun enclosure/scripts/build.ts

# 単発レンダリング（例: just render enclosure/models/tray.scad /tmp/tray.png）
render scad *rest:
    bun enclosure/scripts/render.ts {{scad}} {{rest}}

# 部品間の体積干渉チェック
clash:
    bun enclosure/scripts/clash.ts

# enclosure スクリプトの単体テスト（openscad 不要）
test-enclosure:
    bun test enclosure/scripts/

# 回路 ERC（導通・ショート）
erc:
    cd circuit && bun install --frozen-lockfile && bun test

# WebUI ビルド（yew → crates/mube-webui/dist）
webui:
    cd crates/mube-webui && trunk build --release

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

# ファームビルド一発（blob 取得 → WebUI → cargo build）。clone 後これだけでOK
firmware: blobs webui
    cargo build

# ロジックの host テスト（実機不要）
host-test:
    cargo host-test

# 3D ビューアを公開（cloudflared quick tunnel）
viewer:
    bun viewer/serve.ts

# ブレッドボード配線図ビューア
breadboard:
    bun circuit/breadboard-serve.ts

# 施錠/解錠クライアント（例: just lockctl status）
lockctl *args:
    bun scripts/lockctl.ts {{args}}
```

- [ ] **Step 3: レシピが解決することを確認する**

Run: `nix develop -c just --list`
Expected: 上記の全レシピが列挙される（just が PATH に入り、Justfile が構文エラー無く読める）。

Run: `nix develop -c just test-enclosure`
Expected: PASS（Task 1 のヘルパテストがレシピ経由でも通る）

Run: `nix develop -c just clash`
Expected: `OK: no interference (empty intersection)`

- [ ] **Step 4: firmware 一発ビルドを確認する**

Run: `nix develop -c just firmware`
Expected: `blobs`（既存なら `cyw43 blobs already present`、無ければ fetch）→ `webui`（trunk build --release で dist 生成）→ `cargo build` が順に走り、thumbv6m ターゲットのファームがビルドされる。非ゼロ終了しない。

- [ ] **Step 5: コミット**

```bash
git add Justfile flake.nix
git commit -m "feat: ルート Justfile 導入 + devShell に just（just firmware 一発ビルド）

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: CI のパスを更新

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: render ジョブのテスト・レンダリング・clash パスを更新する**

`.github/workflows/ci.yml` の `render` ジョブ内、3 箇所を差し替える。

テストステップ:

```yaml
      - name: bun test (enclosure ヘルパ + lockctl)
        run: nix develop --command bun test enclosure/scripts/ scripts/lockctl.test.ts
```

レンダリングステップのループ対象:

```yaml
            for f in enclosure/models/smartlock.scad enclosure/models/smoke.scad enclosure/models/*_test.scad; do
              echo "::group::render $f"
              bun enclosure/scripts/render.ts "$f"
              echo "::endgroup::"
            done
```

clash ステップ:

```yaml
      - name: Part clash check (組立位置での部品間体積干渉が無いこと)
        run: nix develop --command bun enclosure/scripts/clash.ts
```

- [ ] **Step 2: ワークフローの YAML が壊れていないか確認する**

Run: `nix develop -c bash -c 'python3 -c "import yaml,sys; yaml.safe_load(open(\".github/workflows/ci.yml\"))" && echo YAML_OK'`
Expected: `YAML_OK`（構文が壊れていない。パス解決は Task 1〜2 で実体確認済み）

- [ ] **Step 3: コミット**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: enclosure/scripts と scripts/lockctl の新パスへ更新

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: README / CLAUDE.md / スキル / docs の追随

**Files:**
- Modify: `README.md`, `CLAUDE.md`, `.claude/skills/viewer-preview/SKILL.md`, `docs/firmware.md`, `docs/measurements-checklist.md`

- [ ] **Step 1: README.md のコマンド表を just 主体へ書き換える**

「開発環境」のコマンド表を、`just <recipe>` を主・素コマンドを従にした表へ差し替える:

```markdown
| やりたいこと | コマンド（just） | 素のコマンド |
| --- | --- | --- |
| 筐体ビルド（STL を enclosure/build/ へ） | `just enclosure` | `bun enclosure/scripts/build.ts` |
| SCAD 単発レンダリング | `just render <scad> [out]` | `bun enclosure/scripts/render.ts <scad> [out]` |
| 部品間の体積干渉チェック | `just clash` | `bun enclosure/scripts/clash.ts` |
| enclosure ツールの単体テスト | `just test-enclosure` | `bun test enclosure/scripts/` |
| 回路 ERC（導通・ショート） | `just erc` | `cd circuit && bun install --frozen-lockfile && bun test` |
| WebUI ビルド（yew→dist） | `just webui` | `cd crates/mube-webui && trunk build --release` |
| ファームビルド一発（blob→webui→cargo build） | `just firmware` | — |
| ロジックの host テスト（実機不要） | `just host-test` | `cargo host-test` |
| 3D ビューアを公開 | `just viewer` | `bun viewer/serve.ts` |
| ブレッドボード配線図ビューア | `just breadboard` | `bun circuit/breadboard-serve.ts` |
| 施錠/解錠クライアント | `just lockctl <sub>` | `bun scripts/lockctl.ts <sub>` |
```

「必要なツール」リストに `just` を追記し、「無ければ nix develop が使える」の直前/直後に
「clone 後は `nix develop -c just firmware` の一発でファームまでビルドできる」旨を 1 行足す。

- [ ] **Step 2: README.md のサブシステム表と lockctl 行を更新する**

サブシステム表の筐体行のディレクトリを `` `enclosure/` `` に、ビューア行を据え置き（`viewer/`）のまま確認。
「ファームウェア」節の日常操作の記述を `bun scripts/lockctl.ts lock|unlock|toggle|status` に更新する。

- [ ] **Step 3: CLAUDE.md のリポジトリ地図とコマンド表を更新する**

リポジトリ地図:

```markdown
- `enclosure/` — 筐体（OpenSCAD）。`models/` に *.scad、`scripts/` に build/render/clash/openscad ヘルパ
- `scripts/` — トップレベルの運用スクリプト（lockctl）
```

（旧 `scad/` 行、`scad/build/` 行を上記に置換。`circuit/build/` の記述は残す。）

「コマンドの打ち方」の表を README と同様に `just` 主体へ更新し、`bun scad/*` の記述を
`bun enclosure/scripts/*` へ、`bun test scad/` を `bun test enclosure/scripts/` へ差し替える。
`nix develop -c` 前置の説明に `just`（`nix develop -c just <recipe>`）を含める。
「触る時の注意」の派生物の記述を `scad/build/` → `enclosure/build/` に更新する。

- [ ] **Step 4: viewer-preview スキルの scad パスを更新する**

`.claude/skills/viewer-preview/SKILL.md` 内の `scad/` パス参照（`scad/build/`、`bun viewer/serve.ts` 前後の
scad ビルド言及、`bun scad/*` 等）を新パス（`enclosure/models/` / `enclosure/build/` / `bun enclosure/scripts/*` / `just viewer`）へ更新する。

Run（対象箇所の洗い出し）: `grep -n "scad" .claude/skills/viewer-preview/SKILL.md`

- [ ] **Step 5: docs の現役参照を更新する**

`docs/firmware.md` と `docs/measurements-checklist.md` 内の `scad/` / `lockctl.ts`（ルート）参照を
新パス（`enclosure/...` / `scripts/lockctl.ts`）へ更新する。`docs/superpowers/` の plan/spec は履歴として触らない。

Run（洗い出し）: `grep -n "scad/\|lockctl" docs/firmware.md docs/measurements-checklist.md`

- [ ] **Step 6: 旧パスの取りこぼしが無いか全体確認する**

Run: `grep -rn "scad/build\|scad/render\|scad/clash\|bun scad/\|bun test scad\|\./lockctl\.ts\|bun lockctl\.ts" README.md CLAUDE.md .github .claude/skills docs/firmware.md docs/measurements-checklist.md`
Expected: ヒット無し（`docs/superpowers/` の履歴は対象外）。ヒットしたら該当箇所を修正する。

- [ ] **Step 7: コミット**

```bash
git add README.md CLAUDE.md .claude/skills/viewer-preview/SKILL.md docs/firmware.md docs/measurements-checklist.md
git commit -m "docs: enclosure/scripts 再編と just 導入に合わせてドキュメント・スキルを更新

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review メモ

- **Spec coverage:** 移動一覧（Task 1,2）／コード内パス修正（Task 1,3）／Justfile（Task 4）／CI（Task 5）／ドキュメント・スキル（Task 6）／gitignore 変更不要（Global Constraints に明記）を各タスクでカバー。viewer 据え置き＋参照更新のみ（Task 3）も spec 通り。
- **検証:** spec の検証項目（enclosure/scripts テスト、just enclosure/clash/render/host-test/firmware）を Task 1・4 の Step で実行。
- **Placeholder:** 具体コード・具体コマンド・期待出力を各 Step に明記。曖昧語なし。
- **Type consistency:** `renderScad` の export 名は Task 1 産出→Task 3 消費で一致。`modelsDir`/`buildDir`/`enclosureRoot` の命名は Task 1・3 で一貫。

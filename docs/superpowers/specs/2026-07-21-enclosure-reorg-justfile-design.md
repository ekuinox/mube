# ディレクトリ再編（enclosure 化）＋ Justfile 導入 設計

日付: 2026-07-21

## 背景と目的

トップレベルの `scad/` は `.scad`（モデル本体）と `.ts`（build/render/clash とその共通ヘルパ・
テスト）が混在しており、「ガワの 3D モデル」という役割が名前・構造から読み取りにくい。
また運用クライアント `lockctl.ts` はリポジトリルート直下に散っている。ビルド・テストの
入口も README／CLAUDE.md のコマンド表に散在し、clone 直後にファームまで到達する単一手順が無い。

本再編では次を行う:

1. `scad/` を `enclosure/` にリネームし、中身を `models/`（`.scad`）と `scripts/`（`.ts`）に分割する。
2. `lockctl.ts` / `lockctl.test.ts` をトップレベル `scripts/` に移す。
3. ルートに `Justfile` を導入し、各ビルド／テスト操作をレシピ化する。
   とくに `just firmware` を「clone 後これ一発でファームビルドまで」到達できる単一入口にする。

## ゴール / 非ゴール

やること:

- `scad/` → `enclosure/`（`models/` + `scripts/` 分割）、出力先 `enclosure/build/`。
- `lockctl.{ts,test.ts}` → `scripts/`。
- `Justfile` 新設と flake devShell への `just` 追加。
- 上記に伴うコード内パス参照・CI・ドキュメント・スキルの追随修正。

やらないこと:

- `viewer/` の移動・リネーム（`static.ts` / `tunnel.ts` が `circuit/breadboard-serve.ts` と
  共有されており、共有ヘルパの置き場所を先に決める必要がある。本再編では **参照パスの更新のみ**
  行い、ディレクトリ自体はトップレベルに据え置く）。
- 共有ヘルパ（`viewer/static.ts` / `viewer/tunnel.ts`）の抽出・再配置（別途検討）。
- Rust クレート構成・回路・筐体形状の変更。
- `docs/superpowers/` の plan/spec 履歴の変更（履歴として保持）。

## 新ディレクトリ構成

```
enclosure/
  models/     *.scad（params/body/hardware/tray/socket/pedestal/smartlock/smoke/
              *_test.scad/clash_check.scad/各 gauge）
  scripts/    build.ts / render.ts / clash.ts / openscad.ts（共通ヘルパ）
              openscad.test.ts（ヘルパの bun 単体テスト。openscad 不要）
  build/      ← STL/プレビュー出力先（旧 scad/build/。.gitignore の `build/` で自動カバー）
scripts/      lockctl.ts / lockctl.test.ts（トップレベルの運用ヘルパ）
viewer/       据え置き（参照パスのみ更新）
circuit/      変更なし
crates/       変更なし
Justfile      ← 新設
```

## 移動一覧

| 移動元 | 移動先 |
| --- | --- |
| `scad/*.scad` | `enclosure/models/*.scad` |
| `scad/build.ts` | `enclosure/scripts/build.ts` |
| `scad/render.ts` | `enclosure/scripts/render.ts` |
| `scad/clash.ts` | `enclosure/scripts/clash.ts` |
| `scad/openscad.ts` | `enclosure/scripts/openscad.ts` |
| `scad/openscad.test.ts` | `enclosure/scripts/openscad.test.ts` |
| `lockctl.ts` | `scripts/lockctl.ts` |
| `lockctl.test.ts` | `scripts/lockctl.test.ts` |
| `scad/build/`（派生物） | `enclosure/build/` |

## コード内パス修正

`.scad` 同士の相対参照（`include <params.scad>` / `use <body.scad>` 等）は、全ファイルが
`enclosure/models/` へ一緒に動くため **修正不要**（相対解決のまま効く）。

TS 側で修正が要る箇所:

- `enclosure/scripts/build.ts`
  - 現状 `scadDir = import.meta.dir` を前提に `build/` と `smartlock.scad` を組み立てている。
    `import.meta.dir` が `enclosure/scripts/` になるため、モデルは `../models`、
    出力は `../build` を指すよう修正する（例: `enclosureRoot = dirname(import.meta.dir)`、
    `modelsDir = join(enclosureRoot, "models")`、`buildDir = join(enclosureRoot, "build")`）。
    gauge 群のパスも `modelsDir` 基準にする。
- `enclosure/scripts/clash.ts`
  - `clash_check.scad` を `../models/` から読むよう修正
    （`join(dirname(import.meta.dir), "models", "clash_check.scad")`）。
- `enclosure/scripts/render.ts` / `enclosure/scripts/openscad.ts`
  - モデルパスの直書きは無く、`./openscad.ts` の相対 import は同居のため不変。実質修正なし。
- `enclosure/scripts/openscad.test.ts`
  - ヘルパの純粋な単体テスト想定。ハードコードされたモデルパスがあれば `../models` 基準へ修正。
- `scripts/lockctl.test.ts`
  - `./lockctl.ts` を import。両者が `scripts/` へ一緒に動くため相対 import は不変。
- `viewer/serve.ts`（ディレクトリは据え置くが import 先が動くため参照更新が必須）
  - `../scad/openscad.ts` → `../enclosure/scripts/openscad.ts`。
  - `scadDir = join(root, "scad")` 系を `enclosure/models`・出力 `enclosure/build` に更新。
    `root = dirname(import.meta.dir)`（viewer の親＝リポジトリルート）は据え置きのため不変。

## Justfile

ルートに `Justfile` を置く。レシピは **`nix develop` 内（ツールが PATH にある前提）** で書き、
レシピ自身は `nix develop` を二重に噛まない。実行は `nix develop -c just <recipe>`、
または `nix develop` に入ってから `just <recipe>`。flake devShell に `pkgs.just` を追加する。

レシピ一覧:

| レシピ | 内容 |
| --- | --- |
| `default` | `@just --list`（既定） |
| `enclosure` | `bun enclosure/scripts/build.ts` |
| `render scad *rest` | `bun enclosure/scripts/render.ts {{scad}} {{rest}}` |
| `clash` | `bun enclosure/scripts/clash.ts` |
| `test-enclosure` | `bun test enclosure/scripts/` |
| `erc` | `cd circuit && bun install --frozen-lockfile && bun test` |
| `webui` | `cd crates/mube-webui && trunk build --release` |
| `blobs` | 3 ファイル揃ってなければ `crates/mube-firmware/cyw43-firmware/fetch.sh` |
| `firmware` | `blobs` と `webui` に依存 → `cargo build` |
| `host-test` | `cargo host-test` |
| `viewer` | `bun viewer/serve.ts` |
| `breadboard` | `bun circuit/breadboard-serve.ts` |
| `lockctl *args` | `bun scripts/lockctl.ts {{args}}` |

`blobs` は bash レシピで 3 ブロブ（`43439A0.bin` / `43439A0_clm.bin` / `nvram_rp2040.bin`）の
存在を確認し、揃っていなければ `fetch.sh` を実行する（既存なら再取得しない）。

`firmware: blobs webui` の依存により、**ブロブ取得 → WebUI ビルド → cargo build** が順に走る。
これにより clone 後 `nix develop -c just firmware` の一発でファームビルドまで到達する。
WiFi 認証（`WIFI_SSID` / `WIFI_PASSWORD`）は `option_env!` のため未設定でもビルドは通る
（実機接続だけできない）。

## ドキュメント・CI・スキルの追随

- `.github/workflows/ci.yml`
  - `bun test scad/ lockctl.test.ts` → `bun test enclosure/scripts/ scripts/lockctl.test.ts`。
  - render ループのモデルパス `scad/smartlock.scad scad/smoke.scad scad/*_test.scad` →
    `enclosure/models/...`、`bun scad/render.ts` → `bun enclosure/scripts/render.ts`。
  - `bun scad/clash.ts` → `bun enclosure/scripts/clash.ts`。
  - CI はレシピ経由にせず直パス更新にとどめる（render ステップはファイル毎の `::group::`
    出力があり `just` 化すると表現が崩れるため。最小リスク優先）。
- `README.md`
  - コマンド表を `just <recipe>` 主体へ書き換え（素の `bun ...` を併記）。
  - サブシステム表の `scad/` → `enclosure/`、lockctl のパスを `scripts/lockctl.ts` に。
- `CLAUDE.md`
  - リポジトリ地図（`scad/` → `enclosure/`、lockctl の位置）、コマンド表、
    `nix develop -c` の説明に `just` を追記。
- `.gitignore`
  - 変更不要。`build/`（先頭スラッシュ無し）が任意階層の `build/` にマッチし、
    `enclosure/build/` を自動でカバーする。
- `.claude/skills/viewer-preview/SKILL.md`
  - scad パス参照を新パスへ更新。
- `docs/firmware.md` / `docs/measurements-checklist.md`
  - 現役文書のうち scad/viewer/lockctl パスに触れる箇所のみ更新。
  - `docs/superpowers/` の plan/spec は履歴として据え置き。

## 検証

- `nix develop -c bun test enclosure/scripts/ scripts/lockctl.test.ts`（ヘルパ・lockctl 単体テスト）。
- `nix develop -c just enclosure`（STL 一括ビルドが `enclosure/build/` へ通る）。
- `nix develop -c just clash`（干渉なし PASS）。
- `nix develop -c just render enclosure/models/tray.scad /tmp/tray.stl`（単発レンダリング）。
- `nix develop -c just host-test`（mube-core host テスト）。
- `nix develop -c just firmware`（ブロブ→webui→cargo build が順に通る。ネット取得を含む）。
- CI 相当のパスが更新後も解決することを目視確認。

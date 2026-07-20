# プロジェクト整理（komorebi 流ツーリング統一＋ドキュメント再編）設計

日付: 2026-07-20
参考: [ekuinox/komorebi](https://github.com/ekuinox/komorebi)（同スタックの姉妹プロジェクト。bun TS ツーリングに統一済み）

## 背景と目的

smtlk のドキュメントには陳腐化・矛盾が蓄積している。README は 182 行と過剰で、
セットアップ詳細・キャリブ手順・TCP 運用が全部盛りになっている。また、ビルド・テストの
ツーリングが bash（`build.sh`, `test/*.sh`）と Python/uv（`viewer/serve.py`,
`circuit/breadboard-serve.py`）と bun（`circuit/`）に分散している。

komorebi は同じ構成要素（scad + circuit + crates + viewer + Nix）を bun TS スクリプトに
統一し、テストを各サブシステムに同居させ、README を 50 行弱に収めている。本整理では
smtlk を同じ形に寄せる。

### 確認済みの陳腐化・矛盾（修正対象）

- README が「実機での実 TCP 確認は次サイクル」と 3 箇所で述べているが、実際には
  ブレッドボード実機でサーボ・LED・スイッチ全部載せの同時動作を TCP 経由で検証済み
  （サーボ実機キャリブ #75 も完了）。
- `lockctl.sh`（TCP 運用クライアント）が README に載っておらず、`nc` 直叩きの例だけがある。
- CLAUDE.md のコマンド表にある `./test/clash.sh` が README のコマンド表に無い。
- `docs/parts-selection.md` が BOM の出所を `circuit/netlist.py` と記述（現在は
  `circuit/index.tsx` / tscircuit）。
- `docs/measurements-checklist.md` は大半がチェック済みで、完了状態が明記されていない。

## ゴール / 非ゴール

やること:

1. ツーリングを bun TS に統一し、`test/` ディレクトリと bash/Python スクリプトを解体する。
2. README を komorebi 並（±60 行）にスリム化し、詳細は `docs/` の専用文書へ退避する。
3. 上記の陳腐化・矛盾を修正する。

やらないこと:

- `docs/superpowers/` の plan/spec 履歴の削除（履歴として保持）。
- Rust クレート構成・回路・筐体形状の変更。
- `lockctl.sh` の TS 化（ビルドツールではなく運用クライアント。依存ゼロの bash のまま存続）。

## 新ディレクトリ構成

```
scad/       *.scad ＋ *_test.scad（test/ から移動）
            build.ts / render.ts / clash.ts / openscad.ts（共通ヘルパ）
            openscad.test.ts（ヘルパの bun 単体テスト。openscad 不要）
            build/  ← STL/プレビュー出力先（旧トップレベル build/。gitignore）
circuit/    既存 TS はそのまま。test/erc.sh 廃止 → `bun test` を直接叩く
            breadboard.sh + breadboard-serve.py → breadboard-serve.ts（bun）
viewer/     serve.py → serve.ts（bun。cloudflared quick tunnel と NO_TUNNEL は維持）
crates/     変更なし
docs/       firmware.md 新設（README から退避した詳細）＋現役文書の更新
            superpowers/ は履歴としてそのまま
test/       廃止（*_test.scad と clash_check.scad は scad/ へ、erc.sh は bun test へ）
build.sh    廃止（→ nix develop -c bun scad/build.ts）
lockctl.sh  存続（README に記載を追加）
```

STL 出力先は komorebi と同じ `scad/build/` とし、トップレベル `build/` を廃止する。
`.gitignore` を追随させる。

## ツーリング移行の詳細

- `scad/openscad.ts`: komorebi の実装をベースに移植。CLI 引数組み立て（`-D key="value"`）、
  終了コードと WARNING/ERROR ログ検査での fail、出力先ディレクトリの自動作成。
- `scad/build.ts`: body / pedestal / socket / tray ＋ asm プレビューを一括レンダリング
  （現行 `build.sh` と同じ成果物を `scad/build/` に出す）。
- `scad/render.ts`: 引数の出力拡張子（.stl / .png）で挙動を切り替え、現行
  `test/render.sh` と `test/render_png.sh` の両方を置き換える。
- `scad/clash.ts`: `clash_check.scad` を openscad で評価する現行 `test/clash.sh` の
  ロジックを TS 移植。
- `viewer/serve.ts`: komorebi の serve.ts をベースに、smtlk の複数パーツレンダリングと
  cloudflared quick tunnel（公開 URL 表示）・`NO_TUNNEL=1` でのローカル配信を移植。
- `circuit/breadboard-serve.ts`: SVG 生成（既存 `breadboard-auto.ts`）→配信→tunnel を
  bun に一本化し、`breadboard.sh` と `breadboard-serve.py` を廃止。
- `flake.nix`: devShell から `uv` を外す（openscad / bun / cloudflared は残す）。
- 「`.sh` が自動で nix develop に再突入する」利便は廃止し、komorebi と同じく
  `nix develop -c bun <script>` を正式コマンドとする。

## ドキュメント再編の詳細

- README（±60 行）: 全体像とサブシステム表／開発環境（Nix）とコマンド表／配線・GPIO の
  要点／書き込みの 1 行案内／`lockctl.sh` の紹介／未確定リスト。
- `docs/firmware.md` 新設: WiFi 認証（ビルド時環境変数・direnv/nix-direnv）、CYW43 ブロブ、
  書き込み手順（probe-rs / BOOTSEL+UF2）、サーボキャリブ手順（定数の場所と安全側からの
  合わせ方）、TCP プロトコル表と運用（lockctl.sh 詳細）。
- 矛盾修正: 「実機 TCP は次サイクル」を実態（検証済み）に更新。コマンド表を新ツーリングに
  全面更新。`measurements-checklist.md` 冒頭に完了状態を明記。`parts-selection.md` の
  BOM 参照先を tscircuit（`circuit/index.tsx`）に修正（価格スナップショット日付の注記は維持）。
- 追随修正: CLAUDE.md のコマンド表・リポジトリ地図、`.claude/skills/viewer-preview/SKILL.md`、
  CI（`.github/workflows/`。circuit の `bun test` に加えて scad の `bun test` を追加、
  erc.sh 経由をやめる）。

## テスト戦略

- `scad/openscad.test.ts`: 引数組み立て・ログ判定の単体テスト（openscad 不要、CI 可）。
- 移行の等価確認: `nix develop -c bun scad/build.ts` で現行 build.sh と同じパーツ一覧が
  `scad/build/` に生成されること。`bun scad/render.ts` で STL / PNG レンダリング、
  `bun scad/clash.ts` で干渉チェックが現行スクリプトと同判定になること。
- `circuit/`: `bun test` が現行 erc.sh と同じテストを通すこと（テスト自体は変更なし）。
- `viewer/serve.ts` / `breadboard-serve.ts`: `NO_TUNNEL=1` でローカル起動し配信を確認。
- Rust: `nix develop -c cargo host-test` が変更なしで通ること（触らないが回帰確認）。
- ドキュメント: 仕上げにコマンド表の各行を実際に叩いて実ファイルと突き合わせる。

## 段階（コミット単位の目安）

1. scad ツーリング移行（openscad.ts / build.ts / render.ts / clash.ts、test/ の scad を移動、
   build.sh・test/*.sh 廃止、.gitignore 更新）
2. viewer / circuit の bun 化（serve.ts / breadboard-serve.ts、Python・sh 廃止、flake から uv 除去）
3. CI・CLAUDE.md・viewer-preview スキルの追随
4. ドキュメント再編（README スリム化、docs/firmware.md 新設、矛盾修正）

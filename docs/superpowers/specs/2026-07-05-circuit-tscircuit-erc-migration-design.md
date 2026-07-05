# circuit を netlist.py から tscircuit へ移行（導通・ショート ERC）設計

## 背景・目的

回路の正（ソースオブトゥルース）を `circuit/netlist.py`（Python）から tscircuit（TypeScript の回路 as code）へ移す。
本番の配線図はすでに `tscircuit/index.tsx` にミラーされている。これを唯一の正とし、そこから
「導通してるか・ショートしてないか」を pass/fail で判定する最低限の ERC チェックを回せるようにする。

netlist.py が兼ねていた from-to.md / bom.md の生成は廃止する。現状これらの生成物はほぼ参照されておらず、
手配線ガイド（from-to）は不要、部品表は `docs/parts-selection.md` に調達用の詳細版があるため。

「シミュレーション」は SPICE ではなく**静的ルールチェック**として実装する。理由: 「導通・ショートしないか」という
pass/fail ゲートには静的な結線解析が直接対応し、決定的で速く CI で安定する。SPICE（既存 sim-full.tsx）は
ngspice 依存で壊れやすく、汎用モデルの数値も当てにならず、ショート検出器としても本来向かない。

## スコープ

### 作るもの
- `circuit/index.tsx` の本番配線から、①導通（未接続ピン・未解決結線が無い）②ショート（電源レール等の意図しない橋絡みが無い）を判定する ERC チェック。違反があれば exit 1。

### やめる・消すもの
- `circuit/netlist.py`、`test/netlist_test.py` を削除
- from-to.md / bom.md の生成を廃止（生成物ゼロ）
- `tscircuit/sim.tsx`、`tscircuit/sim-full.tsx`（SPICE デモ）を削除。git 履歴に残るため必要時に復元可能
- `tscircuit/` ディレクトリを廃止し、中身を `circuit/` に集約

### 触らないもの
- `viewer/`（`serve.py` が uv を使うため flake の uv は維持）
- ファーム・SCAD

## ディレクトリ集約

`circuit/` を Python netlist から TypeScript の tscircuit プロジェクトに置き換える。

移動:
- `tscircuit/index.tsx` → `circuit/index.tsx`
- `tscircuit/package.json` → `circuit/package.json`
- `tscircuit/bun.lock` → `circuit/bun.lock`

削除:
- `circuit/netlist.py`
- `tscircuit/sim.tsx`, `tscircuit/sim-full.tsx`
- `tscircuit/`（空になったディレクトリ）

移動後の `circuit/` の構成:

| ファイル | 役割 |
| --- | --- |
| `circuit/index.tsx` | 本番配線。`export default () => (...)` を名前付き export（例 `export const Board = () => (...)` と `export default Board`）に変更し、netlist.ts / テストから import 可能にする。結線内容は不変 |
| `circuit/netlist.ts` | Board を circuit JSON に描画 → `runErc()` で判定 → 違反を stderr に出力し exit 1、無ければ PASS を出力し exit 0。生成物の書き出しは無し |
| `circuit/netlist.test.ts` | `bun test`。ERC の各ケースを移植 |
| `circuit/package.json` | bun 管理。`test` / `check` スクリプトを追加 |
| `circuit/bun.lock` | 依存ロック |

## ERC の実装方針

`@tscircuit/core` の `RootCircuit` で `index.tsx` の Board を circuit JSON に描画し、
各 `source_port` / `source_net` が持つ `subcircuit_connectivity_map_key`（電気的に繋がった
ポート・ネットが共有する接続グループのキー）でグループ化して解析する。以下は circuit JSON を
入力に取り、エラー文字列の配列を返す純関数 `runErc(circuitJson, options?)` として実装する
（空配列＝合格。netlist.py の `check()` と同じ設計でテストしやすくする）。

ルール（netlist.py の ERC を移植し、ショート検査を明確化）:

1. **導通（未接続ピン）** — `subcircuit_connectivity_map_key` を持たない `source_port` は
   「どこにも繋がっていない」ピン。これを未接続として検出する。ただしフットプリント上の未使用パッド等、
   意図的に未接続でよいピンは `runErc` の `options.allowUnconnected`（"Comp.pin" 形式）で除外する
   （本番配線では tactile switch の `SW1.pin3` / `SW1.pin4`。盤固有なので `netlist.tsx` から渡す）。
   （旧「pin is not connected to any net」。当初は「1 ポートかつネット無しのグループ」で判定する想定
   だったが、実測で未接続ピンは接続キー自体を持たないと判明したためキー無しで判定する。）
2. **導通（解決）** — circuit JSON にエラー要素（未解決の trace セレクタ等、`*_error` / `source_trace` の未接続）が無い。
3. **ショート** — ひとつの結線グループに、異なる名前付きネット `net.X` のラベルが 2 つ以上入らない。
   `net.V5` と `net.GND` が同一グループに落ちたらショートとして検出。
   （旧「pin is connected to multiple nets」＋電源レール橋絡み）
4. **必須ネット** — `net.V5` / `net.GND` / `net.SERVO_RTN` が存在する。（旧 REQUIRED）
5. **孤立ネット** — 各名前付きネット `net.X` は 2 端点以上を持つ。（旧「fewer than 2 endpoints」）

ネット名は netlist.py の `+5V` に対応する tscircuit 側の `V5`（`+` が使えないため）を含め、`index.tsx` の現行ラベルに合わせる。

### ショート検出が成立する理由
tscircuit は trace で繋いだポートを自動的に同一の結線グループへまとめる。`index.tsx` では各電源・信号を
`net.V5` / `net.GND` などと明示ラベルで区別している。配線ミスで別ラベルのポートが同じグループに混ざれば、
「1 グループに複数ラベル」という不変条件が破れて検出できる。単一ソース（trace のみ）でショートが判定できる。

## テスト（TDD）

`circuit/netlist.test.ts` を先に書いてから `runErc()` を実装する。netlist_test.py のケースを移植:

- 正常なネットリストは合格（エラー 0）
- 未接続ポートを検出
- 孤立ネット（端点 1 つ）を検出
- ショート（1 グループに 2 ラベル）を検出
- 必須ネット欠落を検出
- 本番回路（`index.tsx` の Board）が ERC を通る

小さな合成回路（数部品）を組んで各失敗ケースを再現する。BOM / from-to 生成のテストは対象外（廃止のため）。

## 実行手段の組み込み

`circuit/` は node_modules を持たない（`bun.lock` のみコミット）。実行前に `bun install --frozen-lockfile` が要る。
リポジトリの「`.sh` は自分で nix dev シェルに再突入する」流儀（`test/render.sh` と同じ）に合わせ、ラッパースクリプトを置く。

- **`test/erc.sh`** — bun が無ければ nix dev シェルに再突入 → `circuit/` で `bun install --frozen-lockfile` → `bun test`。`bun test` は「本番回路が ERC を通る」検査も含むためゲートとして十分。exit code をそのまま返す。

`circuit/package.json` の scripts:
- `check` — `bun netlist.ts`（ERC を回して pass/fail、exit code）
- `test` — `bun test`（netlist.test.ts）

## 参照・ドキュメントの更新

- **build.sh** — `uv run --script circuit/netlist.py` の生成ステップを削除（生成物が無くなるため STL ビルドのみに）。
- **README.md** — 「回路 = Python netlist」を「回路 = tscircuit（TS 回路 as code ＋ 導通・ショート ERC）」へ更新。
  コマンド表の「回路ネットリストテスト（`nix develop -c ./test/netlist_test.py`）」を「回路 ERC チェック（`./test/erc.sh`）」に差し替え。
  netlist.py の説明段落を tscircuit の説明に書き換え。GPIO 割り当ての記述は `index.tsx` を参照先にする。
- **CLAUDE.md** — リポジトリ地図の `circuit/`（Python）を tscircuit プロジェクトに書き換え、重複する `tscircuit/` の行を削除。
  コマンド表の「回路ネットリストテスト」を「回路 ERC チェック（`./test/erc.sh`）」に差し替え。
- **docs/parts-selection.md** — netlist.py への参照は歴史的経緯として残す（本タスクでは変更しない）。

## 非目標（YAGNI）

- SPICE による動作点・過渡解析（削除する既存デモの範囲）
- from-to.md / bom.md の生成
- 旧 netlist.py 出力とのピン名・並び順の完全一致
- 意図した結線と実際の結線を突き合わせる「意図ネットリスト spec」の二重管理（単一ソース＝index.tsx の trace で足りる）
- PCB レイアウト・オートルーティング（`routingDisabled` のまま）

## 完了条件

- `./test/erc.sh` が本番回路で PASS し、意図的な配線ミス（テスト内合成回路）で該当エラーを出す。
- `circuit/netlist.py`、`test/netlist_test.py`、`tscircuit/`、SPICE デモが削除されている。
- build.sh・README.md・CLAUDE.md が tscircuit ベースに更新され、netlist.py への参照が残っていない（docs/parts-selection.md の歴史記述を除く）。

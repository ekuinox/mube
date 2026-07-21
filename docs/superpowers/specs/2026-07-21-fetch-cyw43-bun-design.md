# CYW43 ブロブ取得の bun 化（fetch.sh 廃止・Justfile 脱 bash）設計

日付: 2026-07-21

## 背景と目的

ツーリングは bun TS へ統一する方針だが、CYW43 ブロブ取得だけが bash に残っている:

- `crates/mube-firmware/cyw43-firmware/fetch.sh`（curl/wget でブロブをダウンロード）。
- `Justfile` の `blobs` レシピが bash シェバングレシピで「3 ファイル揃っているか判定 →
  無ければ `fetch.sh` 実行」を行っている。

これらを bun へ移植し、外部ダウンローダ（curl/wget）依存と Justfile の bash を排除する。
移植後は Justfile の全レシピが bun / cargo / cd の一行になる。

## ゴール / 非ゴール

やること:

- `scripts/fetch-cyw43.ts`（bun）を新設し、`fetch.sh` の機能（pinned タグからの取得・サイズ
  sanity check・原子的書き込み）と、Justfile が担っていた「揃っていればスキップ」判定を担う。
- 純粋ロジックの単体テスト `scripts/fetch-cyw43.test.ts` を追加する。
- `Justfile` の `blobs` レシピを `bun scripts/fetch-cyw43.ts` の一行にする（bash 排除）。
- `fetch.sh` を削除する。
- ブロブ取得に触れるドキュメントを新コマンドへ更新する。

やらないこと:

- ブロブのバージョン（`cyw43-v0.7.0` タグ）・取得元 URL・最低バイト数の変更。
- `firmware` レシピの依存関係（`firmware: blobs webui`）の変更。
- CI の変更（CI は実ブロブを取得せず `touch` でダミーを置くため無関係）。
- WiFi 認証や他クレートの変更。
- `flake.nix` の `writeShellScriptBin`（`backlog` / `cargo-host-test`）と CI の
  インライン `bash -c` ステップの bun 化。これらは Nix devShell のツール提供と GitHub
  Actions のオーケストレーション層に適した形であり、bun 化は複雑化を招く（`cargo-host-test`
  は PATH 上の実行ファイルであることが cargo 外部サブコマンドの条件、CI ステップは本質的に
  shell）。今回は対象外とし、shell の排除は `fetch.sh` と Justfile の `blobs` レシピに限る。

## 新規スクリプト `scripts/fetch-cyw43.ts`

bun スクリプト。curl/wget の代わりに bun 内蔵の `fetch()` を使う。

定数（`fetch.sh` と同値）:

- `TAG = "cyw43-v0.7.0"`
- `BASE = "https://raw.githubusercontent.com/embassy-rs/embassy/" + TAG + "/cyw43-firmware"`
- ブロブ仕様 `BLOBS`: 名前と最低バイト数の配列
  - `43439A0.bin` : 100000
  - `43439A0_clm.bin` : 500
  - `nvram_rp2040.bin` : 100

保存先ディレクトリ:

- `import.meta.dir`（= `scripts/`）の親をリポジトリルートとし、
  `join(root, "crates", "mube-firmware", "cyw43-firmware")` を保存先にする。cwd 非依存。

テスト可能にするための構造（純粋ロジックを分離）:

- `BLOBS`: エクスポートするブロブ仕様配列（`{ name: string; minBytes: number }`）。
- `missingBlobs(dir: string): string[]`: `dir` 内に存在しないブロブ名の配列を返す純粋関数
  （`Bun.file(path).exists()` で判定）。3 つ揃っていれば空配列。
- サイズ検証: `isValidSize(bytes: number, minBytes: number): boolean`（`bytes >= minBytes`）。
- ネットワーク取得部（`fetchBlob` 等）は分離し、単体テスト対象外とする（`build.ts` の openscad
  呼び出しが未テストなのと同じ扱い）。

実行フロー（`import.meta.main` ガード下のメイン処理）:

1. `missingBlobs(dir)` を求める。空なら `cyw43 blobs already present` を出力して exit 0。
2. 欠けているブロブごとに:
   - `${BASE}/${name}` を `fetch()` で取得。失敗時は最大 3 回までリトライ（`fetch.sh` の
     `curl --retry 3` 相当）。
   - レスポンスのバイト列を得て、長さが `minBytes` 未満なら「小さすぎる」と stderr に出して
     exit 1（HTML エラーページ・空ファイルを弾く sanity check）。
   - `${dir}/${name}.tmp` に書き、`${dir}/${name}` へ rename する（原子的書き込み）。成功ログを出す。
3. すべて成功したら完了ログを出して exit 0。

エラー時は非ゼロ終了し、`just blobs` / `just firmware` がその時点で失敗する。

## 単体テスト `scripts/fetch-cyw43.test.ts`

`bun:test` で純粋ロジックのみ検証（ネットワークアクセスなし）:

- `missingBlobs`: 一時ディレクトリを作り、
  - 3 ファイルとも無し → 3 名全部を返す。
  - 一部だけ最低サイズ以上のダミーを置く → 残りだけを返す。
  - 3 ファイルとも置く → 空配列。
- `isValidSize`: `minBytes` 以上は `true`、未満は `false`。

一時ディレクトリはテスト内で作成し、後片付けする。

## Justfile 変更

`blobs` レシピを次へ置き換える（bash シェバング recipe を廃止）:

```
# CYW43 ブロブを取得（3 ファイル揃っていなければ取得）
blobs:
    bun scripts/fetch-cyw43.ts
```

`firmware: blobs webui` の依存はそのまま。これで Justfile に bash 由来の recipe は無くなる。

## 削除・ドキュメント更新

- `crates/mube-firmware/cyw43-firmware/fetch.sh` を削除する。
- `crates/mube-firmware/cyw43-firmware/README.md`: 手動 curl ブロックの前に、推奨手順として
  `just blobs`（内部で `bun scripts/fetch-cyw43.ts` を実行）を追記する。手動 curl は
  ネット制限環境などのフォールバックとして残す。
- `docs/firmware.md`: ブロブ取得の記述に `just blobs` を一言添える。
- `crates/mube-firmware/src/main.rs` の「README の取得手順を参照」コメントは README を指したまま
  でよい（変更不要）。

## 検証

- `nix develop -c bun test scripts/fetch-cyw43.test.ts`（純粋ロジックのテストが緑）。
- `nix develop -c just blobs`:
  - 3 ファイルが既にある状態 → `cyw43 blobs already present`。
  - 1 ファイルを退避して再実行 → その 1 つだけ取得され、サイズ検証を通る（ネット取得を含む）。
- `nix develop -c just firmware`（blobs → webui → cargo build が引き続き一発で通る）。
- `grep -rn "fetch\.sh" Justfile crates docs` などで旧参照が残っていないこと（`docs/superpowers/`
  の履歴は対象外）。

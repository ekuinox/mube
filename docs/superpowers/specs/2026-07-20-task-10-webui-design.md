# 簡単な WebUI（yew SPA を Pico W から HTTP 配信）設計仕様

- 日付: 2026-07-20
- ステータス: 確定
- 対象: ブラウザから施錠/解錠と現在状態(LockState)を操作・確認できる最小 WebUI を、Pico W 上の HTTP サーバから直接提供する
- 関連タスク: TASK-10（`backlog/tasks/task-10-simple-webui.md`）
- 関連: `2026-06-25-tcp-listener-design.md`（廃止する生 TCP serve ループ）、`2026-06-25-testable-core-design.md`（host テスト可能な純ロジック）、`docs/firmware.md`（現行プロトコル）

## 1. 背景と目的

現状、施錠/解錠は Pico W の生 TCP（ポート6000・1行1コマンド `LOCK`/`UNLOCK`/`STATUS`）でしか操作できず、スマホやブラウザから手軽に扱えない。ブラウザは生の TCP ソケットを開けず fetch/WebSocket＝HTTP しか喋れないため、「ブラウザから Pico W へ直接アクセス」を成立させるには **Pico W 側に HTTP サーバを設ける**のが前提になる。

本サイクルでは、yew(WASM SPA) をビルドして firmware に埋め込み、Pico W 上の HTTP サーバ（picoserve）から SPA と JSON API を配信する。ブラウザは `http://<pico-ip>/` を開くだけで、現在状態の表示と施錠/解錠ボタン操作ができる。

### 設計判断

- **UI は yew(WASM) を Pico W に埋め込む。** ストレージは制約にならない（`memory.x`: FLASH 2048K / RAM 256K。既に CYW43 ブロブ約224KB を `include_bytes!` 済みで、yew の最小アプリは最適化＋gzip で 50〜80KB 程度）。埋め込んだ WASM は `&'static [u8]` としてフラッシュ上に置き、XIP でそこから直接 TCP へ流すため RAM 256K に丸ごと載せる必要はない。UI 側も極力 Rust で書きたいという方針に沿う。
- **生 TCP(6000) は廃止し、HTTP に一本化する。** プロトコルを1つに揃える。host テスト済みだった `serve_connection`（生 TCP 行ループ）と text コマンド解釈は役目を終えるため撤去する。ただし状態の単一ソースと純ロジックの host テスト方針は維持する（§3）。
- **HTTP 実装は picoserve を採用する。** embassy ネイティブの no_std HTTP サーバ crate。ルーティング・メソッド・レスポンス・複数コネクション捌きを担い、静的アセット配信＋JSON API を簡潔に書ける。手書き HTTP パースを避け、ブラウザの並行アセット取得にも対応する。
- **状態の単一ソースは不変。** `LOCK_STATE`＋`apply_target`＋`SERVO_CMD` と、GP17 物理ボタン・`servo_task`・二色ステータス LED・WiFi 土台はそのまま。差し替えるのは「TCP 行ループ」→「picoserve HTTP ルータ」の部分だけにする。

## 2. スコープ

- 作るもの:
  - `crates/webui/`（新規）: yew SPA（wasm32-unknown-unknown）。現在状態の表示＋Lock/Unlock/Toggle ボタン。読込時と操作後に `/api/*` を fetch。trunk で `dist/` にビルド（`--filehash false` で固定ファイル名、`dist/` は非コミットの派生物）。
  - `crates/mube-core/`: 新規 `webapi` モジュール（状態⇄JSON 文字列、HTTP ルート→目標 `LockState` のマッピング）を host テスト付きで追加。`lock.rs`(`LockState` 等) は維持。text プロトコル専用の `serve.rs`＋`command.rs` は撤去。
  - `crates/firmware/`: TCP-6000 の accept/serve ループを撤去し、picoserve を port 80 で起動。ルータは埋め込み `dist` アセット（`/`, `/webui.js`, `/webui_bg.wasm`）＋JSON API（`/api/status`, `/api/lock`, `/api/unlock`, `/api/toggle`）を配信。ハンドラは `LOCK_STATE`/`apply_target` を叩く。`build.rs` が `crates/webui/dist/` を `include_bytes!`（未生成なら明快にエラー）。並行接続用に picoserve worker を数本 spawn。
  - `lockctl.ts`: fetch ベースに書き換え。サブコマンド（lock/unlock/status/toggle）は据え置き、宛先は port 80（`TARGET_IP`）。
  - `flake.nix` devShell: `trunk` と `wasm32-unknown-unknown` ターゲットを追加。`trunk build → cargo build` を束ねるビルド手順（bun スクリプト or devShell コマンド）。
  - ドキュメント: `docs/firmware.md`／README のプロトコル節を HTTP に更新。
- 作らないもの（非目標）:
  - 認証・暗号化・TLS・HTTPS。まずは平文 HTTP の最小構成（LAN 内前提）。
  - 複数クライアント間の状態プッシュ（WebSocket/SSE 等）。状態同期はブラウザ側の `/api/status` ポーリング/操作後再取得で足りる。
  - サーボ・キャリブ定数・WiFi 認証まわりの変更。無変更。
  - yew UI の自動テスト作り込み（ビルドが通ること＋実機/ブラウザ目視で足りる）。

## 3. `crates/mube-core` の設計

text プロトコルの解釈が不要になる代わりに、HTTP エンドポイントに紐づく純ロジックを host テスト可能な形で持つ。firmware は薄いアダプタに留める。

### 3.1 維持するもの

- `lock.rs` の `LockState`（`Locked`/`Unlocked`・`toggled()` 等）は状態の単一ソースの型として維持する。
- `servo_math.rs` は無変更。

### 3.2 撤去するもの

- `serve.rs`（`serve_connection`＝生 TCP 行ループ）と `command.rs`（text コマンド `LOCK`/`UNLOCK`/`STATUS` の解釈）。HTTP 一本化で不要。関連 host テストも撤去。
- `lib.rs` の再エクスポートを追随修正。

### 3.3 新規 `webapi` モジュール（host テスト付き）

HTTP の細部（パース・ソケット）は firmware/picoserve 側に置き、core には「状態⇄表現」と「ルート→目標状態」の純関数だけを置く。

- 状態の JSON 表現: `fn state_json(state: LockState) -> &'static str`（例: `Locked → "{\"state\":\"LOCKED\"}"`）。API レスポンスボディに使う。firmware から呼ぶ。
- ルート→目標状態のマッピング: `/api/lock → Locked`、`/api/unlock → Unlocked`、`/api/toggle → current.toggled()`、`/api/status → 駆動なし`。マッピングを純関数（例: `fn target_for(action: Action, current: LockState) -> Option<LockState>`）として置き、firmware ハンドラはこれを呼んで `apply_target` するか否かを決める。
- host テスト: 各ルートが期待する目標状態を返すこと（status は `None`＝駆動なし）、`state_json` の整形、toggle の反転を検証。

## 4. `crates/webui`（yew SPA）の設計

- クレート種別: `cdylib`（wasm32-unknown-unknown）。yew + `gloo-net`（fetch）等の最小依存。
- 画面: 現在状態のラベル（施錠/解錠、色分け）＋「施錠」「解錠」ボタン（＋任意でトグル）。読込時に `GET /api/status` で初期表示、ボタン押下で `POST /api/lock`｜`/api/unlock`、応答の状態で表示更新。失敗時はエラー表示。
- 通信先: 同一オリジン相対パス（`/api/*`）。Pico W が SPA も API も配信するので CORS 不要。
- ビルド: `trunk build --release --filehash false` で `crates/webui/dist/` に `index.html`／`webui.js`／`webui_bg.wasm` を固定名出力。`index.html` から相対でアセットを参照。`dist/` は `.gitignore`（派生物）。任意最適化として `opt-level=z` / wasm-opt / gzip 事前圧縮（§5 参照）は実装プランで判断。

## 5. `crates/firmware` の配線

- 依存追加: `picoserve`（embassy 機能）。既存の `embassy-net`/`TcpSocket` 上で動かす。
- ポート: `const HTTP_PORT: u16 = 80;`（ファイル先頭に隔離）。生 TCP の `LOCK_PORT = 6000` と accept/serve ループは撤去。
- ルータ:
  - `GET /` → 埋め込み `index.html`（Content-Type: text/html）。
  - `GET /webui.js` → 埋め込み JS glue（application/javascript）。
  - `GET /webui_bg.wasm` → 埋め込み WASM（application/wasm）。任意で `Content-Encoding: gzip`。
  - `GET /api/status` → `state_json(LOCK_STATE)`（application/json）。駆動なし。
  - `POST /api/lock`｜`/api/unlock`｜`/api/toggle` → `webapi::target_for` で目標状態を決め、`Some` なら `apply_target` → 更新後状態を `state_json` で返す。
- 埋め込み: `build.rs` が `crates/webui/dist/{index.html,webui.js,webui_bg.wasm}` を `include_bytes!`。未生成なら「先に trunk build（または束ねビルド）を実行せよ」と `cargo:warning`＋コンパイルエラーで明示。
- 並行性: picoserve の worker を数本（例: 2〜3）spawn し、ブラウザの並行アセット取得を捌く。各 worker が自前の `TcpSocket`＋バッファを持つ（RAM 256K に収まる範囲）。
- 状態共有: ハンドラから `LOCK_STATE`/`apply_target`/`SERVO_CMD` を参照。picoserve の state 機構で共有ハンドルを渡す。`FwLockPort` は HTTP 経路では不要になるが、`apply_target` は据え置き。
- 不変: `servo_task`・`button_task`・二色 LED・CYW43/WiFi/DHCP 土台・サーボ駆動とキャリブ定数。オンボード LED は接続/生存インジケータとして流用（詳細は実装プラン）。

## 6. `lockctl.ts` の移行

- 生 TCP ソケット接続を廃し、`fetch` に書き換える。
- サブコマンドは据え置き: `lock`（POST /api/lock）、`unlock`（POST /api/unlock）、`status`（GET /api/status）、引数なし/`toggle`（POST /api/toggle）。
- 宛先: `http://${TARGET_IP}/api/...`（port 80）。`TARGET_IP` は従来通り環境変数。
- 応答の `{"state":...}` を見て現在状態を表示。

## 7. ビルド統合

- `flake.nix` devShell に `trunk` と rust の `wasm32-unknown-unknown` ターゲットを追加。
- 束ねビルド: `trunk build（webui）→ cargo build（firmware）` の順で走る手順を用意（既存の bun ツーリング＝`scad/build.ts` 等に倣った `crates/webui/build.ts` 相当、または devShell のコマンド/alias）。firmware 単体ビルド前に `dist/` が要ることを README/docs に明記。
- `dist/` と `crates/webui/target/` は `.gitignore`。

## 8. 検証方法

- `nix develop -c cargo host-test`: `webapi`（ルート→状態マッピング・`state_json`・toggle 反転）と既存 core テストが緑。撤去した `serve.rs`/`command.rs` のテスト削除後も全体緑。
- `nix develop -c trunk build`（webui）: yew が wasm32 でビルド緑、`dist/` に固定名アセット出力。
- `nix develop -c cargo build`（thumbv6m）: firmware が緑（`dist/` 埋め込み込み）。
- 実機/ブラウザ目視: Pico W を焼き、`http://<pico-ip>/` を開いて状態表示・施錠/解錠ボタン・GP17 物理ボタンとの状態一致を確認（既存の実機確認フローに乗せる）。
- ⚠️ 実機での HTTP 実接続・サーボ動作は最終確認が実機依存。host で検証できるのは core の純ロジックまで。

## 9. リスクと留意

- **picoserve の版・API 差**: embassy 各 crate（`embassy-net`/`embassy-time` 等）のバージョン整合が要る。firmware 既存版に合う picoserve を選び、`TcpSocket` のトレイト境界・ライフタイム（`'static` 借用）が満たせることを実装初期に確認する。満たせない場合は配線側で調整（core テストには影響しない）。
- **WASM バンドルサイズ**: 想定 50〜80KB(gzip) だがフラッシュ残（1MB 超）に対し十分。肥大時は `opt-level=z`/wasm-opt/gzip で圧縮。gzip 配信時は `Content-Encoding` ヘッダ整合に注意。
- **並行接続と RAM**: worker 本数×ソケットバッファが RAM 256K を圧迫しないよう本数とバッファ長を控えめに。まず 2〜3 本・512B 前後から。
- **ビルド順序の落とし穴**: `dist/` 未生成での firmware 単体ビルドは失敗させ、メッセージで束ねビルドへ誘導する（黙って古い埋め込みを使わない）。
- **セキュリティ**: 平文 HTTP・無認証。LAN 内前提であることを docs に明記。公開網に晒さない。

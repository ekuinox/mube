# smtlk — スマートロック

既存ドアのサムターンに後付けする SG90 サーボ式スマートロック。
筐体（OpenSCAD）＋ 回路（Python netlist）＋ Pico W ファーム（Rust / Embassy）の monorepo。

## システム全体像

Pico W が WiFi 接続後に TCP ポート 6000 でコマンドを受け、サーボがサムターンを回して施錠/解錠する。
室内側のタクトスイッチでも手動でトグルでき、状態は外付けの二色 LED で表示する。

| サブシステム | ディレクトリ | 役割 | 状態 |
| --- | --- | --- | --- |
| 筐体 | `scad/` | ドアに後付けする本体・蓋・サムターン受け | 採寸反映済み（v2）／トルク対策は現物合わせ待ち |
| 回路 | `circuit/` | 手配線用のネットリスト／BOM をコードから生成 | ファームと同じ GPIO 割り当てで BOM 更新済み |
| ファーム | `crates/` | WiFi / TCP / サーボ制御 ＋ ハード非依存ロジック | serve ループは host テスト済み／実機 TCP は次サイクル |
| ビューア | `viewer/` | STL をブラウザで確認 | 稼働 |

動作の流れは、TCP で受けた 1 行コマンドを `smtlk_core::serve` のループが解釈し、
`LockController` が施錠/解錠状態を決め、サーボ角度→PWM パルスへ変換して SG90 を駆動する、という一本道。
ロジック部（コマンド解釈・状態機械・serve ループ・角度変換）はハード非依存で、実機なしに host テストできる。

## 開発環境（Nix）

`openscad` / `cargo` / `uv` / `cloudflared` は nix devShell の中にしか無い。

    nix develop

`.sh` 系（`./build.sh`, `./test/render.sh`）は自分で nix develop に再突入するのでそのまま実行できる。
素の `cargo` / `uv` / `openscad` / `./test/netlist_test.py` は `nix develop -c <cmd>` 経由で実行する。

| やりたいこと | コマンド |
| --- | --- |
| 筐体ビルド（STL + netlist を build/ へ） | `./build.sh` |
| ファームビルド（既定ターゲット thumbv6m） | `nix develop -c cargo build --locked` |
| ロジックの host テスト（実機不要） | `nix develop -c cargo host-test` |
| SCAD レンダリングテスト | `./test/render.sh <scad>` |
| 回路ネットリストテスト | `nix develop -c ./test/netlist_test.py` |

`build/` と `*.stl` は派生物なのでコミットしない（.gitignore 済み）。

## 筐体（OpenSCAD）

### ビルド
    ./build.sh

build/ に body.stl / lid.stl / socket.stl を出力する。dev シェル外でも自動で nix develop 経由で実行される。

### 個別レンダリング
    nix develop -c openscad -D 'part="body"' -o body.stl scad/smartlock.scad

### テスト
    ./test/render.sh test/params_test.scad
    ./test/render.sh scad/smartlock.scad

### 採寸（反映済み・v2）
- サムターン: 台形 幅 28(根元)→25(先端) × 厚み 3、突き出し 11（`params.scad` の `knob_*`）。
- 座 Ø46（`rosette_d`）= 位置決め専用（回転対称ゆえトルクは受けない）。
- クリアランス: 左 30 / 下 40（`clear_left` / `clear_down`）。本体は右・上へ展開。

### 次フェーズ（トルク対策・現物合わせ）
- `mount_plate()` の下方向ブレーススタブを、実ノブ/枠の形状に合わせて確定する。
- 必要ならドア写真を `docs/superpowers/assets/` に追加。

## 回路（ネットリスト as code）

    nix develop -c ./circuit/netlist.py

`uv run --script circuit/netlist.py` でも同じ。
回路を `circuit/netlist.py` にコードで定義し、ERC ライト（結線チェック）の後に
`build/from-to.md`（手配線手順表）と `build/bom.md`（部品表）を生成する。
GPIO 番号は `netlist.py` の `GPIO` 変数に集約し、ファームの割り当て（GP15/14/16/18/17）と一致させている。
生成物は STL と同様 build/ で非コミット。テストは `nix develop -c ./test/netlist_test.py`。

## ファームウェア（Rust / Embassy）

リポジトリルートは Cargo workspace。`crates/firmware/` が embassy / CYW43 WiFi / PWM の接合部、
`crates/smtlk-core/` がハード非依存のロジック（LockState・コマンド解釈・状態機械・
サーボ角度変換）で、実機なしで host テストできる。

現状は「WiFi 接続 → DHCP → TCP ポート 6000 でコマンド受信 → サーボ施錠/解錠」まで。
serve ループは host テスト済み、実機での実 TCP 確認は次サイクル。

### 準備
    nix develop

`nix develop` が rustup を用意する（rust-toolchain.toml が stable + thumbv6m を自動導入）。ほかに手動の準備が 2 つ:

- CYW43 ファームウェアブロブを取得する。ライセンス物のため未コミット。詳細は `crates/firmware/cyw43-firmware/README.md`。
- WiFi 認証をビルド時環境変数で渡す: `WIFI_SSID=... WIFI_PASSWORD=... nix develop -c cargo build --release --locked`。
  未設定でもビルドは通るが、プレースホルダのままなので実機では WiFi に接続できない（`crates/firmware/src/config.rs`）。
  direnv を使う場合はリポジトリ直下に `.env.local`（dotenv 形式、`WIFI_SSID=値`）か
  `.envrc.local`（bash、`export WIFI_SSID=値`）を作れば `.envrc` が自動で環境変数に載せる
  （どちらも gitignore 済み。`direnv allow` を忘れずに）。

### ビルド
    nix develop -c cargo build --locked

ターゲットは thumbv6m-none-eabi（.cargo/config.toml で既定指定済み）。

依存の Embassy / cyw43 は crates.io 公開バージョンに固定済み。`Cargo.lock` をコミットしているため、`cargo build --locked` で完全に再現できる。

### ロジックの host テスト（実機不要）
    nix develop -c cargo host-test

ロック・コマンド（LOCK/UNLOCK/STATUS）の解釈と状態機械、および TCP serve ループ
（行分割・接続ライフサイクル・エラー処理・長すぎ行の棄却）を host でモック通しテスト済み。
内部的には `cargo test -p smtlk-core --target <host-triple>` を実行する外部サブコマンド（`cargo-host-test`）で実装しており、`uname -m` でホストトリプルを動的に解決する。x86_64 / aarch64 のどちらの環境でも同じコマンドで動く。

未検証で残るのは `TcpSocket` を `serve_connection` に渡すアダプタ配線のみ。
実機での実 TCP 接続確認は次サイクル。

### 遠隔操作（TCP）

WiFi 接続後、TCP ポート 6000 で 1 接続ずつコマンドを受け付ける。1 行 1 コマンド（`\n` 区切り）。
接続中はオンボード LED が点灯する。

ロック状態は外付けの二色LED（D1）で表示する（施錠=赤 GP16 / 解錠=黄緑 GP18、コモンカソード）。
オンボード LED（CYW43）は TCP 接続状態の表示で、役割を分担する。
GP17 のタクトスイッチを押すと施錠⇄解錠をトグルできる（室内側の手動操作）。ボタンは
Pico W の内部プルアップを使う（外付けプルアップ抵抗は付けない）。ボタン操作も TCP STATUS に反映される。

| コマンド | 応答 | 動作 |
| -------- | ------ | ------------ |
| UNLOCK   | UNLOCKED | 解錠 |
| LOCK     | LOCKED   | 施錠 |
| STATUS   | LOCKED / UNLOCKED | 現在の状態を返す |
| （不正）  | ERR    | 無視して次の行へ |

bench 確認例:
    nc <Pico W の IP> 6000
    UNLOCK

serve ループ自体（行分割・接続終了・エラー処理）は `smtlk_core::serve::serve_connection` に
実装され、`nix develop -c cargo host-test` でモックにより通しテスト済み。

### 書き込み・実行
- デバッグプローブあり: `cargo run --release`（runner = `probe-rs run --chip RP2040`、defmt ログが出る）
- プローブなし: BOOTSEL ボタンを押しながら USB 接続 → UF2 を生成して書き込む
      cargo install elf2uf2-rs
      elf2uf2-rs -d target/thumbv6m-none-eabi/release/smtlk-firmware

### サーボ動作確認（bench）
probe-rs か BOOTSEL+UF2 で焼くと、起動・WiFi 接続後に約3秒ごとに施錠⇄解錠を繰り返す
（オンボード LED がハートビート）。サーボ給電は動作時だけ ON（GP14 の電源ゲート）。

**実機合わせ:** キャリブ定数だけを調整する。角度→パルス変換の 4 つ（SERVO_MIN_US / SERVO_MAX_US /
LOCK_DEG / UNLOCK_DEG）は `crates/smtlk-core/src/servo_math.rs` に集約、整定待ち SETTLE_MS は
`crates/firmware/src/servo.rs` にある。SG90 は個体差が大きいので、
まず安全側（狭い MIN/MAX）で焼き、唸らない・突き当てない範囲を実測で広げること。
初回はサムターンを手で止められる状態で投入する（突き当て保護）。

## 3D プレビュー（ブラウザ + Cloudflare quick tunnel）

    nix develop
    uv run --script viewer/serve.py

`nix develop` で openscad / uv / cloudflared を用意する。`./viewer/serve.py` でも同じ。

STL 再生成 → ビューア配置 → ローカル配信 → 公開 URL（https://*.trycloudflare.com）を表示する。
ブラウザでその URL を開くと Three.js のビューアでパーツを確認できる。
URL は起動ごとに変わり、Ctrl-C でサーバとトンネルを停止する。
STL は build/ に再生成される派生物なのでコミットしない（.gitignore 済み）。

`serve.py` は PEP 723 のインラインメタデータを持ち、`uv` が Python と依存を解決して実行する
（cloudflared の pip 版は aarch64 非対応のため、バイナリは devShell から供給する）。

## 未確定（積み残し）
- 筐体: ドア固定の突っ張り先（mount_plate で隔離）。サムターン実寸（socket パラメータで隔離）。
- ファーム: 実機での実 TCP 接続確認 / 省電力運用 / 手回し後の状態再同期。

# ファームウェア詳細（セットアップ・書き込み・キャリブ・TCP）

README から退避したファームウェアの詳細手順。全体像とコマンド表は [README](../README.md) を参照。

## セットアップ

rustup があれば rust-toolchain.toml が stable + thumbv6m を自動導入する（rustup ごと揃えたい場合は
オプションで `nix develop` も使える）。ほかに手動の準備が 2 つある。

- CYW43 ファームウェアブロブを取得する。ライセンス物のため未コミット。詳細は `crates/firmware/cyw43-firmware/README.md`。
- WiFi 認証をビルド時環境変数で渡す: `WIFI_SSID=... WIFI_PASSWORD=... cargo build --release --locked`。
  未設定でもビルドは通るが、プレースホルダのままなので実機では WiFi に接続できない（`crates/firmware/src/config.rs`）。

direnv を使う場合はリポジトリ直下に `.env.local`（dotenv 形式、`WIFI_SSID=値`）か
`.envrc.local`（bash、`export WIFI_SSID=値`）を作れば `.envrc` が自動で環境変数に載せる
（どちらも gitignore 済み。`direnv allow` を忘れずに）。`.envrc` は `use flake` を使うので
direnv に加えて **nix-direnv** が必要（未導入なら環境変数の読込だけ手動で行う）。

## ビルド

    cargo build --locked

ターゲットは thumbv6m-none-eabi（.cargo/config.toml で既定指定済み）。
依存の Embassy / cyw43 は crates.io 公開バージョンに固定済み。`Cargo.lock` をコミットしているため、`cargo build --locked` で完全に再現できる。

## ロジックの host テスト（実機不要）

    cargo host-test

ロック・コマンド（LOCK/UNLOCK/STATUS）の解釈と状態機械、および TCP serve ループ
（行分割・接続ライフサイクル・エラー処理・長すぎ行の棄却）を host でモック通しテストする。
`cargo host-test` は Nix devShell が提供する外部サブコマンド（`cargo-host-test`）で、実体は
`cargo test -p smtlk-core --target <host-triple>`（`uname -m` でホストトリプルを動的に解決）。
devShell を使わない場合はこの実体コマンドを直接叩けば同じ（x86_64 / aarch64 どちらでも動く）。

## 書き込み・実行

- デバッグプローブあり: `cargo run --release`（runner = `probe-rs run --chip RP2040`、defmt ログが出る）
- プローブなし: BOOTSEL ボタンを押しながら USB 接続 → UF2 を生成して書き込む

```
cargo install elf2uf2-rs
elf2uf2-rs -d target/thumbv6m-none-eabi/release/smtlk-firmware
```

## 遠隔操作（TCP）

WiFi 接続後、TCP ポート 6000 で 1 接続ずつコマンドを受け付ける。1 行 1 コマンド（`\n` 区切り）。
接続中はオンボード LED が点灯する。ブレッドボード実機でサーボ・LED・スイッチ全部載せの
同時動作を検証済み。

ロック状態は外付けの二色 LED（D1）で表示する（施錠=赤 GP16 / 解錠=黄緑 GP18、コモンカソード）。
オンボード LED（CYW43）は TCP 接続状態の表示で、役割を分担する。
GP17 のタクトスイッチを押すと施錠⇄解錠をトグルできる（室内側の手動操作）。ボタンは
Pico W の内部プルアップを使う（外付けプルアップ抵抗は付けない）。ボタン操作も TCP STATUS に反映される。

| コマンド | 応答 | 動作 |
| -------- | ------ | ------------ |
| UNLOCK   | UNLOCKED | 解錠 |
| LOCK     | LOCKED   | 施錠 |
| STATUS   | LOCKED / UNLOCKED | 現在の状態を返す |
| （不正）  | ERR    | 無視して次の行へ |

日常の操作はリポジトリ直下の `lockctl.sh` を使う（bash の /dev/tcp のみ使用、nc 不要）。
接続先 IP は環境変数 `TARGET_IP`（`.envrc.local` で定義 → direnv がロード）。

```
./lockctl.sh            # 現在と逆に切り替え（トグル）
./lockctl.sh toggle     # 同上
./lockctl.sh lock       # 施錠（赤）
./lockctl.sh unlock     # 解錠（緑）
./lockctl.sh status     # 現在状態を問い合わせ（駆動しない）
```

serve ループ自体（行分割・接続終了・エラー処理）は `smtlk_core::serve::serve_connection` に
実装され、host テスト（`cargo host-test`）でモックにより通しテスト済み。

## サーボ動作確認とキャリブレーション

probe-rs か BOOTSEL+UF2 で焼くと、起動・WiFi 接続後に約 3 秒ごとに施錠⇄解錠を繰り返す
（オンボード LED がハートビート）。サーボ給電は動作時だけ ON（GP14 の電源ゲート）。

実機合わせはキャリブ定数だけを調整する。角度→パルス変換の 4 つ（SERVO_MIN_US / SERVO_MAX_US /
LOCK_DEG / UNLOCK_DEG）は `crates/smtlk-core/src/servo_math.rs` に集約、整定待ち SETTLE_MS は
`crates/firmware/src/servo.rs` にある。SG90 は個体差が大きいので、
まず安全側（狭い MIN/MAX）で焼き、唸らない・突き当てない範囲を実測で広げること。
初回はサムターンを手で止められる状態で投入する（突き当て保護）。

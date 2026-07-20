# ファームウェア詳細

セットアップから書き込み、キャリブレーション、TCP 運用までの詳細手順。
全体像とコマンド表は [README](../README.md) を参照。

## セットアップ

rustup があれば rust-toolchain.toml が stable + thumbv6m を自動導入する（`nix develop` でも揃う）。
ほかに手動の準備が 2 つある。

- CYW43 ファームウェアブロブを取得する。ライセンス物のため未コミット。詳細は `crates/firmware/cyw43-firmware/README.md`。
- WiFi 認証をビルド時環境変数で渡す: `WIFI_SSID=... WIFI_PASSWORD=... cargo build --release`。
  未設定でもビルドは通るが、プレースホルダのままなので実機では WiFi に接続できない（`crates/firmware/src/config.rs`）。

direnv を使う場合はリポジトリ直下に `.env.local`（dotenv 形式、`WIFI_SSID=値`）か `.envrc.local`（bash、`export WIFI_SSID=値`）を作れば、`.envrc` が自動で環境変数に載せる（どちらも gitignore 済み。`direnv allow` を忘れずに）。
`.envrc` は `use flake` を使うので、direnv に加えて nix-direnv が必要（未導入なら環境変数の読込だけ手動で行う）。

## ビルド

    cargo build

ターゲットは thumbv6m-none-eabi（.cargo/config.toml で既定指定済み）。
依存は crates.io 公開バージョンに固定し、Cargo.lock をコミットしている。

## ロジックの host テスト（実機不要）

    cargo host-test

ロックコマンドの解釈と状態機械、ロジック部をモックで通しテストする。
`cargo host-test` は devShell が提供する別名で、実体は `cargo test -p mube-core --target <ホストトリプル>`（devShell の外ではこちらを直接叩く）。

## 書き込みと実行

- デバッグプローブあり: `cargo run --release`（runner = `probe-rs run --chip RP2040`、defmt ログが出る）
- プローブなし: BOOTSEL ボタンを押しながら USB 接続 → UF2 を生成して書き込む

```
cargo install elf2uf2-rs
elf2uf2-rs -d target/thumbv6m-none-eabi/release/mube-firmware
```

## 遠隔操作（HTTP / WebUI）

WiFi 接続後、HTTP ポート 80 で yew SPA（WebUI）と JSON API を配信する。

ブラウザで `http://<pico-ip>/` を開くと、現在のロック状態と施錠/解錠ボタンが表示される。

### JSON API

| エンドポイント | メソッド | レスポンス例 |
| --- | --- | --- |
| `/api/status` | GET | `{"state":"LOCKED"}` または `{"state":"UNLOCKED"}` |
| `/api/lock` | POST | `{"state":"LOCKED"}` |
| `/api/unlock` | POST | `{"state":"UNLOCKED"}` |
| `/api/toggle` | POST | `{"state":"LOCKED"}` または `{"state":"UNLOCKED"}` |

### ハードウェア

ロック状態は外付けの二色 LED（D1）で表示する（施錠=赤 GP16 / 解錠=黄緑 GP18、コモンカソード）。
GP17 のタクトスイッチを押すと施錠⇄解錠をトグルできる（室内側の手動操作）。
ボタンは Pico W の内部プルアップを使い（外付けプルアップ抵抗は付けない）、ボタン操作も WebUI の状態表示に反映される。
状態は WebUI・API・物理ボタンで一致する（単一の状態変数）。

### lockctl.ts（CLI）

日常の操作はリポジトリ直下の `lockctl.ts` を使う。
接続先 IP は環境変数 `TARGET_IP`（`.envrc.local` で定義 → direnv がロード）。
ポートは既定 80、環境変数 `PORT` で上書き可能。

```
bun lockctl.ts            # 現在と逆に切り替え（トグル）
bun lockctl.ts toggle     # 同上
bun lockctl.ts lock       # 施錠（赤）
bun lockctl.ts unlock     # 解錠（緑）
bun lockctl.ts status     # 現在状態を問い合わせ（駆動しない）
```

### セキュリティ注意事項

平文 HTTP・無認証。LAN 内のみで使用すること（公開ネットワークに晒さない）。

### WebUI の事前ビルド

WebUI（yew/trunk 出力）は firmware に埋め込まれるため、**firmware をビルドする前に WebUI を先にビルドする必要がある**。
未実行の場合、`cargo build` が明示的なエラーで失敗する。

```
cd crates/webui && trunk build --release
cargo build
```

## サーボ動作確認とキャリブレーション

probe-rs か BOOTSEL+UF2 で焼くと、起動して WiFi 接続後、約 3 秒ごとに施錠⇄解錠を繰り返す（オンボード LED がハートビート）。
サーボ給電は動作時だけ ON にする（GP14 の電源ゲート）。

実機合わせはキャリブ定数だけを調整する。
角度→パルス変換の 4 定数（SERVO_MIN_US / SERVO_MAX_US / LOCK_DEG / UNLOCK_DEG）は `crates/mube-core/src/servo_math.rs` に集約し、整定待ち SETTLE_MS は `crates/firmware/src/servo.rs` にある。
SG90 は個体差が大きいので、まず安全側（狭い MIN/MAX）で焼き、唸らず突き当たらない範囲を実測で広げる。
初回はサムターンを手で止められる状態で投入する（突き当て保護）。

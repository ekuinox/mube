# ファームウェア詳細

セットアップから書き込み、キャリブレーション、HTTP WebUI/API 運用までの詳細手順。
全体像とコマンド表は [README](../README.md) を参照。

## セットアップ

rustup があれば rust-toolchain.toml が stable + thumbv6m/wasm32 を自動導入する。
`nix develop` は rust-overlay 経由で同じ rust-toolchain.toml から実バイナリのツールチェーンを供給する
（rustup のシムを介さないため、外部環境の `RUSTUP_TOOLCHAIN` に影響されない）。
ほかに手動の準備が 2 つある。

- CYW43 ファームウェアブロブを取得する（リポジトリルートで `just blobs`）。ライセンス物のため未コミット。詳細は `crates/mube-firmware/cyw43-firmware/README.md`。
- WiFi 認証をビルド時環境変数で渡す: `WIFI_SSID=... WIFI_PASSWORD=... cargo build --release`。
  未設定でもビルドは通るが、プレースホルダのままなので実機では WiFi に接続できない（`crates/mube-firmware/src/config.rs`）。

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

フラッシュは OTA 対応の A/B レイアウトに分割されている（単一ソースは `crates/mube-boot/memory.x`）。

```
0x10000000  BOOT2 + ブートローダー   28KB   (crates/mube-boot = embassy-boot-rp)
0x10007000  STATE パーティション      4KB   (swap/revert フラグ)
0x10008000  ACTIVE スロット         988KB   (実行中ファーム。XIP でここから実行)
0x100FF000  DFU スロット            992KB   (OTA 受信バッファ)
0x101F7000  余白（将来用）           36KB
```

### 初回プロビジョニング（DAP、一度だけ）

新しい Pico W には、ブートローダーとアプリの 2 つを DAP 経由で焼く。

```
cargo build --release        # mube-boot と mube-firmware の両方がビルドされる
probe-rs download --chip RP2040 target/thumbv6m-none-eabi/release/mube-boot
probe-rs download --chip RP2040 target/thumbv6m-none-eabi/release/mube-firmware
probe-rs reset --chip RP2040
```

2 段書き込みが要るのは**初回と、mube-boot 自体を変更した時だけ**。以後の更新は
OTA（後述）だけで済み、開発中の焼き直しも従来どおり `cargo run --release`
（probe-rs runner、defmt ログが出る）で**アプリだけ**焼き直せばよい。

これが安全なのは、アプリ ELF が boot2 を持たないため（embassy-rp の `boot2-none`
feature）。boot2（256B）とブートローダー先頭は同じ 4KB 消去セクタに同居しており、
アプリ側に boot2 を残すと probe-rs のセクタ消去がブートローダーを壊しうる。
boot2 は mube-boot が `rp2040_boot2::BOOT_LOADER_W25Q080` を明示的に持つ
（embassy-rp の feature 任せにしないのは、ワークスペースの feature 統一で
boot2-none がブートローダー側にも効いて boot2 が消えるため）。

プローブなしの場合は BOOTSEL + UF2 も使える（UF2 はアドレス付きなので、
ブートローダー書き込み済みならアプリの UF2 だけでよい）:

```
cargo install elf2uf2-rs
elf2uf2-rs -d target/thumbv6m-none-eabi/release/mube-firmware
```

## OTA アップデート

初回プロビジョニング済みの実機は、LAN 内から一発で更新できる:

```
just ota        # blobs → webui → cargo build --release → objcopy → TCP 4242 で送信
```

接続先は `TARGET_IP`（lockctl と同じ）。流れと安全装置は次のとおり。

- 送信側（`scripts/lockctl.ts ota`）はイメージの CRC32 を添えて送り、
  デバイスは **DFU スロットに書き終えて CRC 一致を確認してから** 更新を確定する。
  転送中の切断・電源断では ACTIVE スロットに触れていないため、現行ファームが無傷で動き続ける。
- 確定後に自動リセット → ブートローダーが DFU→ACTIVE をスワップして新ファームを起動する。
  スワップは約 1MB の消去・書き込みを伴うため**再起動に数十秒かかる**。
  `lockctl ota` は `/api/version` をポーリングし、バージョンが変わったら完了報告する。
- 新ファームは「サーボ初期化 + WiFi 接続 + HTTP サーバ起動」に到達すると mark_booted で自分を確定する。
  到達できないまま watchdog（8 秒）が発火すると、ブートローダーが**旧ファームへ自動ロールバック**する。
- 解錠中の OTA は既定で拒否する（再起動で状態表示が実態とずれるため）。
  やむを得ない場合は `OTA_ALLOW_UNLOCKED=1` で上書きできる。

なお watchdog は mark_booted 後も常時有効のままにしている。OTA と無関係のハングでも
8 秒で自動再起動するようになった（鍵の可用性優先の挙動変更）。

### 実機テスト（OTA 導入時のチェックリスト）

1. **正常系**: 適当なコミットを積んで `just ota` → `/api/version` が新しい git describe になる。
2. **転送中の電源断**: `just ota` の転送中に AC を抜く → 再起動後も旧版で施解錠できる。
3. **ロールバック**: 意図的に起動失敗する「壊れ玉」を送る。

```
cargo build --release -p mube-firmware --features ota-rollback-test
rust-objcopy -O binary --remove-section .boot2 target/thumbv6m-none-eabi/release/mube-firmware target/mube-firmware-broken.bin
bun scripts/lockctl.ts ota target/mube-firmware-broken.bin
```

   スワップ → 起動即 panic → watchdog リセット → revert スワップ、と 2 回のスワップを挟むため
   数分待ってから `/api/version` が**旧版のまま**であることを確認する。

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
| `/api/version` | GET | `{"version":"f90217f"}`（git describe。更新の反映確認用） |

### ハードウェア

ロック状態は外付けの二色 LED（D1）で表示する（施錠=赤 GP16 / 解錠=黄緑 GP18、コモンカソード）。
GP17 のタクトスイッチを押すと施錠⇄解錠をトグルできる（室内側の手動操作）。
ボタンは Pico W の内部プルアップを使い（外付けプルアップ抵抗は付けない）、ボタン操作も WebUI の状態表示に反映される。
状態は WebUI・API・物理ボタンで一致する（単一の状態変数）。

### lockctl.ts（CLI）

日常の操作はトップレベルの `scripts/lockctl.ts` を使う（`just lockctl <sub>` で起動）。
接続先 IP は環境変数 `TARGET_IP`（`.envrc.local` で定義 → direnv がロード）。
ポートは既定 80、環境変数 `PORT` で上書き可能。

サブコマンドは必須（引数なしは usage を表示して何もしない。誤操作で施錠状態を変えないため）。

```
bun scripts/lockctl.ts toggle     # 現在と逆に切り替え
bun scripts/lockctl.ts lock       # 施錠（赤）
bun scripts/lockctl.ts unlock     # 解錠（緑）
bun scripts/lockctl.ts status     # 現在状態を問い合わせ（駆動しない）
```

### セキュリティ注意事項

平文 HTTP・無認証。LAN 内のみで使用すること（公開ネットワークに晒さない）。
OTA ポート（TCP 4242）も同じ信頼モデルで、LAN 内の誰でもファームを書き換えられる。
インターネットへは絶対に露出しないこと（Cloudflare Tunnel の公開対象にも含めない）。

### WebUI の事前ビルド

WebUI（yew/trunk 出力）は firmware に埋め込まれるため、**firmware をビルドする前に WebUI を先にビルドする必要がある**。
未実行の場合、`cargo build` が明示的なエラーで失敗する。

```
cd crates/mube-webui && trunk build --release
cargo build
```

## サーボ動作確認とキャリブレーション

probe-rs か BOOTSEL+UF2 で焼くと、起動して WiFi 接続後、約 3 秒ごとに施錠⇄解錠を繰り返す（オンボード LED がハートビート）。
サーボ給電は動作時だけ ON にする（GP14 の電源ゲート）。

実機合わせはキャリブ定数だけを調整する。
角度→パルス変換の 4 定数（SERVO_MIN_US / SERVO_MAX_US / LOCK_DEG / UNLOCK_DEG）は `crates/mube-core/src/servo_math.rs` に集約し、整定待ち SETTLE_MS は `crates/mube-firmware/src/servo.rs` にある。
SG90 は個体差が大きいので、まず安全側（狭い MIN/MAX）で焼き、唸らず突き当たらない範囲を実測で広げる。
初回はサムターンを手で止められる状態で投入する（突き当て保護）。

# smtlk — 自作スマートロック筐体

既存ドアのサムターンに後付けする SG90 サーボ式スマートロックの筐体（OpenSCAD）。

## 開発環境（Nix）
    nix develop           # devShell に入る（openscad / uv / cloudflared）

## ビルド
    ./build.sh            # build/ に body.stl / lid.stl / socket.stl を出力（dev シェル外でも自動で nix develop 経由で実行）

## 個別レンダリング
    nix develop -c openscad -D 'part="body"' -o body.stl scad/smartlock.scad

## テスト
    ./test/render.sh test/params_test.scad
    ./test/render.sh scad/smartlock.scad

## 基板（電気設計・手配線用）
    uv run --script circuit/netlist.py   # = ./circuit/netlist.py

回路を `circuit/netlist.py` にコードで定義し、ERC ライト（結線チェック）の後に
`build/from-to.md`（手配線手順表）と `build/bom.md`（部品表）を生成する。
GPIO 番号は仮で `netlist.py` の `GPIO` 変数に隔離（ファームで確定後に差し替え）。
生成物は STL と同様 build/ で非コミット。テストは `./test/netlist_test.py`。

## 3D プレビュー（ブラウザ + Cloudflare quick tunnel）
    nix develop                          # openscad / uv / cloudflared を用意
    uv run --script viewer/serve.py      # = ./viewer/serve.py

STL再生成 → ビューア配置 → ローカル配信 → 公開URL(https://*.trycloudflare.com)を表示する。
ブラウザでその URL を開くと Three.js のビューアでパーツを確認できる。
URL は起動ごとに変わり、Ctrl-C でサーバとトンネルを停止する。
STL は build/ に再生成される派生物なのでコミットしない（.gitignore 済み）。

`serve.py` は PEP 723 のインラインメタデータを持ち、`uv` が Python と依存を解決して実行する
（cloudflared の pip 版は aarch64 非対応のため、バイナリは devShell から供給する）。

## 採寸（反映済み・v2）
- サムターン: 台形 幅 28(根元)→25(先端) × 厚み 3、突き出し 11（`params.scad` の `knob_*`）。
- 座 Ø46（`rosette_d`）= 位置決め専用（回転対称ゆえトルクは受けない）。
- クリアランス: 左 30 / 下 40（`clear_left` / `clear_down`）。本体は右・上へ展開。

## 次フェーズ（トルク対策・現物合わせ）
- `mount_plate()` の下方向ブレーススタブを、実ノブ/枠の形状に合わせて確定する。
- 必要ならドア写真を `docs/superpowers/assets/` に追加。

## Pico W ファームウェア（Rust / Embassy）

リポジトリ直下が Rust パッケージ（`Cargo.toml` / `src/`）も兼ねる。Embassy(async) + CYW43 WiFi
の雛形で、現状は「WiFi 接続 → DHCP → オンボード LED 点滅」まで。サーボ制御や遠隔操作は
`src/main.rs` の TODO を参照。

### 準備
    nix develop                                   # rustup を用意（rust-toolchain.toml が stable + thumbv6m を自動導入）
    # CYW43 ファームウェアブロブを取得（ライセンス物のため未コミット）
    #   詳細は cyw43-firmware/README.md
    # src/config.rs の WIFI_SSID / WIFI_PASSWORD を実値に書き換える

### ビルド
    cargo build --release                         # thumbv6m-none-eabi（.cargo/config.toml で既定ターゲット指定済み）

### 書き込み・実行
- デバッグプローブあり: `cargo run --release`（runner = `probe-rs run --chip RP2040`、defmt ログが出る）
- プローブなし: BOOTSEL ボタンを押しながら USB 接続 → UF2 を生成して書き込む
      cargo install elf2uf2-rs
      elf2uf2-rs -d target/thumbv6m-none-eabi/release/smtlk-firmware

### サーボ動作確認（bench）
probe-rs か BOOTSEL+UF2 で焼くと、起動・WiFi 接続後に約3秒ごとに施錠⇄解錠を繰り返す
（オンボード LED がハートビート）。サーボ給電は動作時だけ ON（GP14 の電源ゲート）。

**実機合わせ:** `src/servo.rs` 冒頭のキャリブ定数 5 つ（SERVO_MIN_US / SERVO_MAX_US /
LOCK_DEG / UNLOCK_DEG / SETTLE_MS）だけを調整する。SG90 は個体差が大きいので、
まず安全側（狭い MIN/MAX）で焼き、唸らない・突き当てない範囲を実測で広げること。
初回はサムターンを手で止められる状態で投入する（突き当て保護）。

依存の Embassy は git 追従（`Cargo.toml` のコメント参照）。再現性が要るなら rev 固定する。

## 未確定（積み残し）
- ドア固定の突っ張り先（mount_plate で隔離）。
- サムターン実寸（socket パラメータで隔離）。
- Pico W ファームウェア: SG90 サーボ PWM 制御 / 遠隔操作の口 / 省電力運用 / 手回し後の状態再同期。

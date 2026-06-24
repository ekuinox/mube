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

## 3D プレビュー（ブラウザ + Cloudflare quick tunnel）
    nix develop                          # openscad / uv / cloudflared を用意
    uv run --script viewer/serve.py      # = ./viewer/serve.py

STL再生成 → ビューア配置 → ローカル配信 → 公開URL(https://*.trycloudflare.com)を表示する。
ブラウザでその URL を開くと Three.js のビューアでパーツを確認できる。
URL は起動ごとに変わり、Ctrl-C でサーバとトンネルを停止する。
STL は build/ に再生成される派生物なのでコミットしない（.gitignore 済み）。

`serve.py` は PEP 723 のインラインメタデータを持ち、`uv` が Python と依存を解決して実行する
（cloudflared の pip 版は aarch64 非対応のため、バイナリは devShell から供給する）。

## 採寸後にやること
- `scad/params.scad` の `knob_w/knob_t/knob_h`（サムターン実寸）を更新。
- ドア固定が決まったら `scad/mount_plate.scad` の `mount_plate()` を差し替え。

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

依存の Embassy は git 追従（`Cargo.toml` のコメント参照）。再現性が要るなら rev 固定する。

## 未確定（積み残し）
- ドア固定の突っ張り先（mount_plate で隔離）。
- サムターン実寸（socket パラメータで隔離）。
- Pico W ファームウェア: SG90 サーボ PWM 制御 / 遠隔操作の口 / 省電力運用 / 手回し後の状態再同期。

# smtlk — 自作スマートロック筐体

既存ドアのサムターンに後付けする SG90 サーボ式スマートロックの筐体（OpenSCAD）。

## 開発環境（Nix）
    nix develop           # devShell に入る（openscad / python3 / cloudflared / gh）

## ビルド
    ./build.sh            # build/ に body.stl / lid.stl / socket.stl を出力（dev シェル外でも自動で nix develop 経由で実行）

## 個別レンダリング
    nix develop -c openscad -D 'part="body"' -o body.stl scad/smartlock.scad

## テスト
    ./test/render.sh test/params_test.scad
    ./test/render.sh scad/smartlock.scad

## 3D プレビュー（ブラウザ + Cloudflare quick tunnel）
    ./viewer/serve.sh     # STL再生成 → ビューア配置 → 配信 → 公開URL(https://*.trycloudflare.com)を表示

ブラウザで表示された URL を開くと Three.js のビューアでパーツを確認できる。
URL は起動ごとに変わり、Ctrl-C でサーバとトンネルを停止する。
STL は build/ に再生成される派生物なのでコミットしない（.gitignore 済み）。

## 採寸後にやること
- `scad/params.scad` の `knob_w/knob_t/knob_h`（サムターン実寸）を更新。
- ドア固定が決まったら `scad/mount_plate.scad` の `mount_plate()` を差し替え。

## 未確定（積み残し）
- ドア固定の突っ張り先（mount_plate で隔離）。
- サムターン実寸（socket パラメータで隔離）。
- Pico W ファームウェア・省電力運用・手回し後の状態再同期。

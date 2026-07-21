---
name: viewer-preview
description: >-
  smartlock 筐体(OpenSCAD)の 3D モデルをレンダリングして、ブラウザビューアを
  Cloudflare quick tunnel で公開する。「モデルをビルドして viewer で見たい」
  「STL をブラウザで確認したい」「筐体プレビューを共有して」「tunnel でモデルを見せて」
  「トレイ/body/lid の形を確認して」など、このリポジトリの 3D モデルを画面で確認・共有
  したい時は必ずこのスキルを使う。enclosure/models/ を触った後の目視確認も対象。nix devShell と
  cloudflared の落とし穴込みで手順を固めてあるので、毎回思い出さずに済む。
---

# viewer-preview

smartlock の OpenSCAD モデルを `viewer/serve.ts` でレンダリング→配信→Cloudflare quick
tunnel で公開する。`enclosure/models/` を編集した後の目視確認や、URL を誰かに共有したい時に使う。

## これ一発でやること

`viewer/serve.ts` が中で全部やる。二度ビルドは不要。

1. `enclosure/models/smartlock.scad` から `body` / `lid` / `socket` / `tray` / `assembly` / `asm_*` を
   openscad でレンダリングして `enclosure/build/` に STL を出す
2. `enclosure/build/` を `http://127.0.0.1:8765` でローカル配信する
3. `cloudflared` で quick tunnel を張り、`https://xxx.trycloudflare.com` を発行する

## 実行手順

正式なコマンドは `just viewer`（素のコマンド: `bun viewer/serve.ts`。Nix はプロジェクトの前提ではない）。ただしこの開発機の
非対話シェルには `openscad` / `bun` / `cloudflared` / `just` が PATH に無いので、Claude が起動するときは
`nix develop -c` を前置する。

サーバは Ctrl-C まで動き続けるので、バックグラウンドで起動して URL が出るまで待つ:

```
nix develop -c just viewer
```

起動後、出力に次の行が出たら成功。この URL をユーザーに渡す:

```
  Open in your browser:  https://<ランダム>.trycloudflare.com
```

URL は openscad レンダリング完了後に出るので、全パーツ揃うまで数十秒待つことがある。
`trycloudflare.com` の行を grep で待ち受けてから報告するとよい。

## 注意点（ハマりどころ）

- **二重ビルドしない**: `serve.ts` が自前でレンダリングする。事前に `just enclosure`（`bun enclosure/scripts/build.ts`）を回す
  必要はない。`enclosure/models/` を編集したら serve.ts を起動し直せば最新が反映される。
- **quick tunnel の URL は毎回変わる**: trycloudflare のクイックトンネルは使い捨て。
  起動し直すと別 URL になる。共有済みの URL は再起動で無効になると伝える。
- **停止**: Ctrl-C（バックグラウンドプロセスなら kill）でサーバと tunnel を両方止める。
- **`enclosure/build/` は派生物**: STL はコミットしない（.gitignore 済み）。
- **cloudflared のバイナリ**: pip 版 cloudflared は aarch64 非対応。この環境では
  nix devShell のバイナリを使う。
- **`NO_TUNNEL=1`**: トンネルなしでローカルのみ配信したい場合は `NO_TUNNEL=1 nix develop -c bun viewer/serve.ts` で起動する。
- **part="assembly"**: `smartlock.scad` は未知の part 名を「全体アセンブリ」として描く
  ので、serve.ts の PARTS に `assembly` があっても落ちない。

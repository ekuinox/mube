# 遠隔操作の中継スタック（Caddy + cloudflared）

インターネット越しにドアロックを操作するための中継環境。
中継役の Pi 上で home-manager モジュール（`nix/door-lock-relay.nix`）として宣言的にデプロイする。

## 構成

```
ブラウザ / lockctl
    │ https://door-lock-private.ekuinox.dev (Cloudflare Access で認証)
    ▼
Cloudflare Edge
    │ named tunnel (protocol: http2)
    ▼
cloudflared (user service: cloudflared-door-lock)
    │ http://127.0.0.1:8080
    ▼
Caddy (user service: door-lock-proxy)
    │ Cookie / Cf-* / Sec-* など太いヘッダを削ぎ落とす
    ▼
Pico W (http://172.20.10.13:80, HTTP バッファ 2KB)
```

Caddy を挟む理由: Cloudflare Access 経由のリクエストは Cookie（約1300B）+ JWT ヘッダ（約1400B）で
Pico の 2KB HTTP バッファを溢れさせるため、不要ヘッダを削いでから転送する。

## 前提

- lingering 有効: `loginctl enable-linger <user>`（未設定だとログアウトで user service が止まる）
- 秘密物は手動配置: `~/.cloudflared/cert.pem` とトンネル資格情報 `~/.cloudflared/<tunnel-id>.json`。
  モジュールは配布しない（無ければ cloudflared が起動失敗するだけ）
- Cloudflare 側（Tunnel / Access / DNS）は作成済みが前提

## 利用側（home-manager flake）

```nix
inputs.mube.url = "github:ekuinox/mube";        # マージ前は github:ekuinox/mube/<branch>
# home.nix:
imports = [ inputs.mube.homeManagerModules.default ];
services.mube-door-lock = {
  enable = true;
  hostname = "door-lock.example.com";           # Cloudflare Tunnel の公開ホスト名
  tunnelId = "00000000-0000-0000-0000-000000000000";
  picoOrigin = "http://192.168.1.50:80";        # Pico の IP が変わったらここを更新して switch
  protocol = "http2";                           # QUIC が塞がれた回線のみ。通常は省略可
};
```

マシン固有の `hostname` / `tunnelId` / `picoOrigin` は既定値なしの必須オプション。
`proxyPort`（既定 8080）と `credentialsFile`（既定 `~/.cloudflared/<tunnelId>.json`）は省略可。
`protocol` は未指定なら cloudflared の既定（auto）。

## 移行手順（手作業版からの引っ越し。実機で1回だけ）

1. 手作業版の撤去: `systemctl --user disable --now door-lock-proxy` +
   `rm ~/.config/systemd/user/door-lock-proxy.service` + `nix profile remove` の caddy +
   `rm -r ~/.config/door-lock-proxy`
2. `home-manager switch`（モジュール版 proxy + cloudflared user service が起動。
   system unit の cloudflared と一時的に併走するが、named tunnel はレプリカ併走可能なので無停止）
3. `sudo systemctl disable --now cloudflared-door-lock`（system unit 廃止。sudo はここだけ）
4. `~/.cloudflared/config.yml` は未参照になる（残しても無害。バックアップとして残置可）

## トラブルシュート

- **応答に `Via: 1.1 Caddy` が無い**: reverse_proxy を通っていない。Caddy が該当リクエストを
  site block で受けられていないか、cloudflared の転送先がずれている。
- **Caddy の Host 照合の罠**: サイトアドレスを `127.0.0.1:<port>` にすると Caddy が Host ヘッダを
  照合し、cloudflared からのリクエスト（Host: 公開ホスト名）にマッチせず空の 200 を返す。
  正解は Host 不問の `http://:<port>` + `default_bind 127.0.0.1`（モジュールはこの形で生成する）。
- **cloudflared が繋がらない（error 1033 / 接続数 0）**: QUIC(UDP 7844) が塞がれた環境では
  `protocol = "http2"` の明示が必須（未指定だと cloudflared は QUIC を試みる）。

# door-lock 中継一式の home-manager モジュール化 設計

日付: 2026-07-22 / 対象: TASK-14 の恒久化（中継役 Pi の宣言的デプロイ）

## 背景と目的

TASK-14 で構築した遠隔操作の中継スタック（Caddy ヘッダ削ぎプロキシ + cloudflared named tunnel）は、
nix profile への手動インストール・手書きの Caddyfile・手書きの systemd unit で動いている。
これを mube リポジトリが home-manager モジュールとしてエクスポートし、利用側（chezmoi 管理の
home-manager flake）は `github:ekuinox/mube` を input に足して `enable = true` するだけで
同じ中継環境を再現できるようにする。

## スコープ

- **含む**: Caddy プロキシ（Caddyfile 生成 + user service）、cloudflared（config.yml 生成 + user service。
  既存の system unit から引っ越し）
- **含まない**: 秘密物（`~/.cloudflared/cert.pem` とトンネル資格情報 `<tunnel-id>.json`）。
  これらは従来どおり手動配置。無ければ cloudflared が起動失敗するだけで、モジュールは何も漏らさない。
- **含まない**: Pico ファーム・回路・Cloudflare 側設定（Tunnel/Access はダッシュボード・CLI で作成済みが前提）

## モジュール設計

- ファイル: `nix/door-lock-relay.nix`。`flake.nix` の出力に `homeManagerModules.door-lock-relay`
  と `homeManagerModules.default`（エイリアス）を追加。devShell は変更しない。
- オプション名前空間 `services.mube-door-lock`:

| オプション | 型 | 既定値 |
| --- | --- | --- |
| `enable` | bool | `false` |
| `hostname` | str | なし（必須） |
| `tunnelId` | str | なし（必須） |
| `picoOrigin` | str | なし（必須） |
| `proxyPort` | port | `8080` |
| `protocol` | nullOr str | `null`（cloudflared の既定。QUIC 塞がれ回線では `"http2"` を指定） |
| `credentialsFile` | str | `${home}/.cloudflared/<tunnelId>.json` |

マシン固有の値（hostname / tunnelId / picoOrigin）は既定値を持たせず利用側に必ず設定させる
（当初は実環境の値を既定にする案だったが、作者個人環境への依存を避けるためレビューで必須化に変更。
2026-07-22）。汎用的に妥当な proxyPort / credentialsFile のみ既定値を持つ。

- 生成物（すべて Nix ストア産）:
  1. **Caddyfile**: サイトは `http://:<proxyPort>`（Host 不問）+ グローバル `default_bind 127.0.0.1`。
     `127.0.0.1:<port>` をサイトアドレスにすると Caddy の Host 照合で cloudflared からのリクエストに
     マッチせず空の 200 になる（2026-07-22 に踏んだ）。`header_up -` で Cookie / Cf-* / Sec-* /
     User-Agent / Accept / Accept-Language / Accept-Encoding / Referer / Priority /
     Upgrade-Insecure-Requests / Cdn-Loop / X-Forwarded-* / X-Real-Ip を削除。
     `admin off` / `auto_https off` / `persist_config off`、アクセスログは stderr へ JSON。
  2. **cloudflared config.yml**: `tunnel` / `credentials-file` / `protocol` / ingress
     （`hostname` → `http://127.0.0.1:<proxyPort>`、フォールバック `http_status:404`）。
  3. **user service `door-lock-proxy`**: `caddy run --config <storepath> --adapter caddyfile`
     （ストアパスのファイル名は `Caddyfile` 丸ごとではないため adapter 明示が必須）。
     `Restart=always`。
  4. **user service `cloudflared-door-lock`**: `cloudflared tunnel --config <storepath> run`。
     `Restart=always`。
- 前提: lingering 有効（`loginctl enable-linger <user>`。Pi 設定済み）。モジュールの説明に明記する。
- パッケージは モジュール評価時の `pkgs.caddy` / `pkgs.cloudflared` を使用。

## 利用側（chezmoi 管理の home-manager flake）

```nix
inputs.mube.url = "github:ekuinox/mube";        # マージ前は github:ekuinox/mube/<branch>
# home.nix:
imports = [ inputs.mube.homeManagerModules.default ];
services.mube-door-lock = {
  enable = true;
  hostname = "...";      # 必須3点はマシン固有値
  tunnelId = "...";
  picoOrigin = "http://...";
  protocol = "http2";    # QUIC 塞がれ回線のみ
};
```

## 移行手順（実機で1回だけ）

1. 手作業版の撤去: `systemctl --user disable --now door-lock-proxy` +
   `rm ~/.config/systemd/user/door-lock-proxy.service` + `nix profile remove` の caddy +
   `rm -r ~/.config/door-lock-proxy`
2. `home-manager switch`（モジュール版 proxy + cloudflared user service が起動。
   system unit の cloudflared と一時的に併走するが、named tunnel はレプリカ併走可能なので無停止）
3. `sudo systemctl disable --now cloudflared-door-lock`（system unit 廃止。sudo はここだけ）
4. `~/.cloudflared/config.yml` は未参照になる（残しても無害。バックアップとして残置可）

## 検証

- `nix flake show` / モジュールを import した home-manager 設定の評価が通ること
- 実機（この Pi）で `home-manager switch` 後: 未認証 302 プローブ、プロキシ経由
  `GET /api/status` = 200、太ヘッダ（Cookie 1300B + JWT 1400B）でも 200、WASM 1.2MB 配信

## ドキュメント

- `docs/remote-relay.md` に中継スタックの構成・移行手順・トラブルシュート
  （Via ヘッダの見分け方、Host 照合、linger）を短くまとめ、README のコマンド表から参照する。

# インターネット越しの鍵操作: Cloudflare Tunnel + Access 設計

## 背景と目的

現状、鍵の操作経路は3つで、いずれも家の中に閉じている。

- LAN 内の WebUI（`http://<pico-ip>/`）と JSON API（平文 HTTP・無認証）
- `lockctl.ts` CLI（同じ LAN 内 API を叩く）
- 室内側の物理タクトスイッチ（GP17）

`docs/firmware.md` にも「平文 HTTP・無認証。LAN 内のみで使用すること」と明記済み。
外出先からインターネット経由で施錠/解錠したい、というのが本設計の目的。

物理の鍵をインターネットへ出すため、**セキュリティが最優先**。無認証のまま公開する選択肢は取らない。

## 制約と前提

- 家庭内に常時起動の中継役マシンがある（このプロジェクトの開発機でもある Raspberry Pi）。
- 家庭回線は**固定 IP ではない**。インバウンドのポート開放・ポートフォワードは避けたい。
- ネットワークそのものを公開したくない（HTTP サーバーを直接インターネットに晒さない）。
- VPN 常用（Tailscale/WireGuard の端末側設定）は運用が煩わしいので避けたい。
- Cloudflare に載せられる自分のドメイン（`ekuinox.dev`）を保有している。

### 確定値

- 公開ホスト名: `door-lock.private.ekuinox.dev`
- Pico W の LAN アドレス: `172.20.10.13`（自宅ルータ配下。DHCP 予約はせず**可変運用**とし、変わったら `config.yml` を更新する）
- Access 許可メール: `lm0xlemon@gmail.com` のみ
- ログイン方式: Google
- 中継役: この開発機（Raspberry Pi）。`cloudflared` は導入済み（nix、v2026.6.0）

## 検討した方式

- **A: オーバーレイ VPN（Tailscale/WireGuard）** — 自分の端末だけが到達。攻撃面は最小だが、
  操作端末ごとに VPN 設定が要り、運用が煩わしい。→ 却下。
- **B-1: Cloudflare Tunnel + Access（採用）** — 中継役が外向きトンネルを張り、認証は
  Cloudflare のエッジ（Access）に任せる。ポート開放ゼロ・固定 IP 不要・アプリも VPN も不要。
  認証を自作しないのでセキュリティ実装のバグを抱えない。
- **B-2: 中継役に自前ログインを実装** — 柔軟だが認証を自作する分バグ = 開錠のリスクを背負う。
  無料の Access がある以上あえて選ぶ理由が薄い。→ 却下。

## 採用アーキテクチャ

```
スマホ/ブラウザ（どこからでも）
   │ HTTPS
   ▼
Cloudflare エッジ ──[Access 認証の壁: 未認証はここで遮断]
   │ 認証済みのみ通す（TLS トンネル）
   ▼
中継役の cloudflared（家の中・常時起動・外向き接続のみ)
   │ LAN 内 平文 HTTP
   ▼
Pico W（ファーム変更なし）:80  →  サーボ / LED / 状態
```

- **インバウンドのポート開放ゼロ・固定 IP 不要。** 中継役が外へ接続を張るだけ。
- **Pico W のファーム・回路は一切変更しない。** LAN 内無認証 HTTP のまま。
- 平文区間は「中継役 ↔ Pico」の LAN 内 1ホップのみ。スマホ↔Cloudflare は HTTPS、
  Cloudflare↔中継役は TLS トンネル。

## セットアップ内容（アプリのコードは書かない。設定のみ）

### 中継役（Raspberry Pi）

1. `cloudflared` は導入済み（nix、v2026.6.0）。
2. `cloudflared tunnel login`（ブラウザで `ekuinox.dev` を認可。ユーザー操作。`~/.cloudflared/cert.pem` が入る）。
3. named tunnel を作成し、認証情報（credentials JSON）を `~/.cloudflared/` に配置する。
4. トンネル設定ファイル（`config.yml`）で `door-lock.private.ekuinox.dev` → `http://172.20.10.13:80` を割り当てる。
   Pico の IP はこの1箇所で管理し、変わったら書き換えて `cloudflared` を再読込する。
5. systemd サービス化して常駐・自動再起動させる。

### Cloudflare ダッシュボード（ユーザー操作）

1. 公開ホスト名 `door-lock.private.ekuinox.dev` → トンネル → Pico W へルート（`cloudflared tunnel route dns` で CLI からも可）。
2. Access アプリケーションを1個作成。ポリシーは「許可メール = `lm0xlemon@gmail.com`」だけ。
   身内を足すときはメールを追加するだけ。
3. ログイン方式は Google。

## セキュリティ / 運用上の勘所

- **URL は公開前提で設計する。** バレても未認証は Cloudflare で遮断され、届くのはログイン画面のみ。
  URL の秘匿には依存しない（隠すことによるセキュリティを使わない）。
- **Pico の IP は `config.yml` の1箇所で管理（可変運用）**: 変わったら書き換えて `cloudflared` を
  再読込する。**外出中に IP が変わると開けられなくなる**リスクがあるため、安定させたくなったら
  自宅ルータで DHCP 予約にすれば set-and-forget にできる（今回は採らない）。
- **cloudflared はサービス化**して、中継役の再起動後も自動復帰する。
- **失効が容易**: 端末紛失時は Access のセッション無効化、または許可メールを外せば即遮断。
- Pico 側は Access が付与する認証情報を検証しない。**未認証リクエストがそもそも到達しない**ため問題なし。
- 既存の API は施錠/解錠/トグルが POST。Access がエッジで前段に立つため、
  未認証のプリフェッチ等が駆動に到達することはない。

## 検証

外部回線（スマホの4G等、家の WiFi を切る）から確認する。

1. 未ログイン状態で公開 URL を開く → Cloudflare のログイン画面で弾かれる（Pico に到達しない）。
2. 許可メールでログイン → `GET /api/status` が現在状態を返す。
3. `POST /api/lock` / `POST /api/unlock` で実機が施錠/解錠し、LED と状態が一致する。
4. 中継役を再起動 → cloudflared が自動復帰し、再び操作できる。

## スコープ外（別タスク候補）

- Pico ファームの HTTPS 化。
- Pico を直接クラウド（MQTT 等）へ繋ぐ方式。
- 家族共有の細かい権限分け（読み取り専用ユーザー等）。
- 操作ログ/監査。

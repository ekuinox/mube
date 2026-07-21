---
id: TASK-14
title: '遠隔操作: Cloudflare Tunnel + Access でインターネット越しに鍵を操作'
status: To Do
assignee: []
created_date: '2026-07-21 13:11'
updated_date: '2026-07-21 15:32'
labels:
  - firmware
  - ops
dependencies: []
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
外出先からインターネット経由で鍵を操作できるようにする。中継役の Raspberry Pi（本開発機）で Cloudflare Tunnel を張り、認証は Cloudflare Access に任せる方式。

設計詳細は docs/superpowers/specs/2026-07-21-remote-lock-cloudflare-tunnel-design.md 参照。

確定値:
- 公開ホスト名: door-lock-private.ekuinox.dev（ドメイン ekuinox.dev は Cloudflare 上）
- Pico W: 172.20.10.13（自宅ルータ配下。DHCP 予約はせず可変運用。変わったら config.yml を更新）
- Access 許可メール: lm0xlemon@gmail.com のみ / ログインは Google
- cloudflared は導入済み（nix, v2026.6.0）

要点:
- Pico W のファーム・回路は変更しない（LAN 内 平文 HTTP のまま）。
- インバウンドのポート開放ゼロ・固定 IP 不要（中継役が外向き接続を張る）。
- named tunnel の向き先は http://172.20.10.13:80。IP は config.yml の1箇所で管理し変わったら更新。

ユーザー操作が必要な所: cloudflared tunnel login（ブラウザ認証）、ダッシュボードでの Access アプリ/ポリシー作成。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 外部回線から未ログインで公開URLを開くとCloudflareのログイン画面で弾かれPicoWに到達しない
- [ ] #2 許可メールでログイン後 GET /api/status が状態を返す
- [ ] #3 POST /api/lock・/api/unlock で実機が施錠/解錠しLEDと状態が一致する
- [ ] #4 cloudflaredがsystemd常駐で中継役の再起動後に自動復帰する
- [ ] #5 PicoのIPが変わったらconfig.ymlを更新しcloudflared再読込で復帰できる（可変運用）
- [ ] #6 公開ホスト名は1段(door-lock-private.ekuinox.dev)にする。2段はUniversal SSL非対応でERR_SSL_VERSION_OR_CIPHER_MISMATCHになる
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## 進捗（2026-07-21 セッション）

■ 完了・稼働中（中継役 = この Pi 上）
- cloudflared ログイン済み（~/.cloudflared/cert.pem）
- named tunnel「door-lock」作成済み: id b45a50d5-24f6-4732-9568-7971f9772504
- DNS ルート: door-lock-private.ekuinox.dev（1段。2段はUniversal SSL非対応で ERR_SSL_VERSION_OR_CIPHER_MISMATCH）
- ~/.cloudflared/config.yml: hostname→http://172.20.10.13:80。protocol: http2 指定（QUIC/UDP7844 塞がれ対策。既定だと接続0で error 1033）
- systemd: /etc/systemd/system/cloudflared-door-lock.service（User=ekuinox）active。エッジ接続2本確立済み
- Access: door-lock-private.ekuinox.dev に自分のGmail許可で設定済み。未認証は302でログインへ（検証済み）

■ 残ブロッカー（唯一）
Access ログイン後、Pico への転送で「Unexpected EOF while reading request」。
原因: Pico の picoserve http_buffer=2048B（main.rs:280）が小さく、Access の大ヘッダ（Cf-Access-Jwt-Assertion＋CF_Authorizationクッキー＋Cf-*）が2KB超で 400/切断。
実測: 直curlでヘッダ合計~2.4KBは200、~4KB以上は400。

■ 次の一手（どちらか。memory: pico-http-buffer-2kb-vs-access 参照）
1. ファーム: http_buffer(必要ならrxも)を~8KBへ拡大→cargo build→再フラッシュ。堅牢だが再書込＝「ファーム無変更」方針は外れる。cargo host-test を通すこと。
2. Cloudflare Transform Rule で該当ホストの Cookie と Cf-Access-Jwt-Assertion を origin転送前に削除→2KB未満に。再フラッシュ不要でファーム無変更を維持。Access はエッジ検証済みで削除は安全。無料可。おすすめ（設計方針に沿う）。

■ 最終受け入れ（未実施）
外部回線(4G)から https://door-lock-private.ekuinox.dev をログイン→status/lock/unlock。
<!-- SECTION:NOTES:END -->

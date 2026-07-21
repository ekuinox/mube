---
id: TASK-14
title: '遠隔操作: Cloudflare Tunnel + Access でインターネット越しに鍵を操作'
status: To Do
assignee: []
created_date: '2026-07-21 13:11'
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

要点:
- Pico W のファーム・回路は変更しない（LAN 内 平文 HTTP のまま）。
- インバウンドのポート開放ゼロ・固定 IP 不要（中継役が外向き接続を張る）。
- named tunnel の向き先は http://<pico-ip>:80。Pico の IP は DHCP 予約で安定させる。
- Access ポリシーで許可メール（自分の Gmail）だけ通す。URL は公開前提。

ユーザー操作が必要な所: cloudflared tunnel login（ブラウザ認証）、ダッシュボードでの Access アプリ/ポリシー作成。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 外部回線から未ログインで公開URLを開くとCloudflareのログイン画面で弾かれPicoWに到達しない
- [ ] #2 許可メールでログイン後 GET /api/status が状態を返す
- [ ] #3 POST /api/lock・/api/unlock で実機が施錠/解錠しLEDと状態が一致する
- [ ] #4 cloudflaredがsystemd常駐で中継役の再起動後に自動復帰する
- [ ] #5 PicoのIPをDHCP予約で固定しトンネルの向き先がズレない
<!-- AC:END -->

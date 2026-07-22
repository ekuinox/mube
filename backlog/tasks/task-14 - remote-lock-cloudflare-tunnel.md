---
id: TASK-14
title: '遠隔操作: Cloudflare Tunnel + Access でインターネット越しに鍵を操作'
status: To Do
assignee: []
created_date: '2026-07-21 13:11'
updated_date: '2026-07-22 10:02'
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
- [x] #1 外部回線から未ログインで公開URLを開くとCloudflareのログイン画面で弾かれPicoWに到達しない
- [x] #2 許可メールでログイン後 GET /api/status が状態を返す
- [x] #3 POST /api/lock・/api/unlock で実機が施錠/解錠しLEDと状態が一致する
- [ ] #4 cloudflaredがsystemd常駐で中継役の再起動後に自動復帰する
- [ ] #5 PicoのIPが変わったらconfig.ymlを更新しcloudflared再読込で復帰できる（可変運用）
- [x] #6 公開ホスト名は1段(door-lock-private.ekuinox.dev)にする。2段はUniversal SSL非対応でERR_SSL_VERSION_OR_CIPHER_MISMATCHになる
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

## Transform Rule 検証（2026-07-22 セッション）

■ 判明した制約（Cloudflare 公式 docs で確認）
Request Header Transform Rule は cf-* / x-cf- で始まるヘッダを削除できない（例外は cf-connecting-ip のみ）。
つまり当初案の「Cookie + Cf-Access-Jwt-Assertion を削除」は後者が不可能。
https://developers.cloudflare.com/rules/transform/request-header-modification/

■ Pico 実測（LAN 直 curl、GET /api/status のみ・実機は動かしていない）
- 閾値: ヘッダ合計 ~2100B まで 200、~2150B から 400（http_buffer=2048B どおり。旧メモの「2.4KB OK」より厳しい）
- Cookie だけ削除した想定（ブラウザヘッダ+JWT 950B+cf-*）: 合計 ~2000B で 200。ただし余裕 ~100B しかなく、JWT やブラウザ差でオーバーし得る → 単独では危険
- Cookie + ブラウザ系ヘッダも削除した想定（Host/JWT/cf-*/x-forwarded-* のみ残す）: JWT 1400B でも 200（1600B で 400）。現実の Access JWT は ~900B なので余裕 ~500B → これで行く

■ 確定した方式: Transform Rule 1本（Cookie に加えブラウザ系ヘッダも削除）
- 対象: (http.host eq "door-lock-private.ekuinox.dev")
- Phase: http_request_late_transform（Rules → Overview → Request Header Transform Rule / 無料プラン可）
- Remove するヘッダ: cookie, user-agent, accept, accept-language, referer, sec-ch-ua, sec-ch-ua-mobile, sec-ch-ua-platform, sec-fetch-site, sec-fetch-mode, sec-fetch-dest, sec-fetch-user, upgrade-insecure-requests, priority
  （accept-encoding は forbidden で削除不可。cf-* も削除不可だが JWT 含め残っても上記実測で収まる。Pico 側はどのヘッダも参照していないので削除は安全。Access の CF_Authorization Cookie はエッジで検証済みなので origin へ転送不要）

■ 残作業（ユーザー操作が必要）
1. ダッシュボード or API トークン（Zone: ekuinox.dev / Transform Rules: Edit）で上記ルールを作成
2. 外部回線から Google ログイン → status/lock/unlock の最終受け入れ

## 方式転換: ローカルプロキシ (2026-07-22 セッション続き)

Transform Rule 適用後に「invalid login session」が発生（原因は一時的なものかルール起因か未確定のまま）。
Cloudflare 側の挙動が公式フェーズ順ドキュメントと突き合わせても説明できず、切り分け不能と判断して
Pi 上のローカルリバースプロキシ方式へ転換（ユーザー承認済み）。Transform Rule は削除済み（late_transform フェーズは rules 0 件を確認）。

■ 新構成（構築・検証済み）
cloudflared → 127.0.0.1:8080 (Caddy 2.11.4, ヘッダ削ぎ落とし) → Pico(172.20.10.13:80)
- Caddy: nix profile でインストール（~/.nix-profile/bin/caddy）
- 設定: ~/.config/door-lock-proxy/Caddyfile（Cookie/Cf-*/Sec-*/UA/Accept* 等を header_up で削除）
- 常駐: user systemd「door-lock-proxy.service」enabled+active（linger 有効なので再起動後も自動復帰、sudo 不要）
- Pico の IP 管理は config.yml から Caddyfile へ移動（変更→ systemctl --user restart door-lock-proxy）
- ~/.cloudflared/config.yml: service を http://127.0.0.1:8080 へ変更（バックアップ config.yml.bak-20260722）。ingress validate OK

■ 実測（LAN）
- 4KB 超の Access 相当リクエスト（Cookie 1300B + JWT 1400B + ブラウザヘッダ）→ プロキシ経由で GET /api/status・GET / とも 200
- プロキシが Pico へ送るヘッダは 121B まで縮小（Host/UA(Go 既定)/Via/Accept-Encoding のみ）

■ 残作業
1. sudo systemctl restart cloudflared-door-lock（ユーザー操作）
2. 外部回線から Google ログイン → status/lock/unlock の最終受け入れ
3. 完了後: ~/.cloudflare-api-token 削除とダッシュボードでのトークン失効

## 真っ白ページの修正 (2026-07-22 続き)

症状: cloudflared 再起動後、外から開くとエラー無しの真っ白ページ。
原因: Caddyfile のサイトアドレスを「127.0.0.1:8080」と書いていたため、Caddy が Host ヘッダでサイトを照合し、
cloudflared が送る Host: door-lock-private.ekuinox.dev にマッチせず「空の 200」(Server: Caddy、Via 無し) を返していた。
修正: サイトを「http://:8080」(Host 不問) にし、グローバルの default_bind 127.0.0.1 で bind だけ限定。
検証: Host 付き GET / が 811B の HTML、太ヘッダ付き GET /api/status が {"state":"LOCKED"} を返すことを確認。bind は 127.0.0.1 のみ。
見分け方: プロキシ経由なのに Via: 1.1 Caddy が無い応答は reverse_proxy を通っていない。

## 受け入れ確認 (2026-07-22 夜)

「切断されてしまう」の原因はスマホ側の古い Access セッション状態で、シークレットウィンドウでログインしたら全経路が開通。
プロキシのアクセスログ(cf-ray 付き=エッジ経由)で確認した実績:
- GET / → 200 811B、/webui.js → 200 32KB、/webui_bg.wasm → 200 1.2MB(プロキシ→Pico は約1.5秒/800KB/s)
- GET /api/status → 200、POST /api/lock → 200、POST /api/unlock → 200、POST /api/lock → 200(実機動作をユーザー確認)
AC #1(未ログイン302で拒否) #2(status) #3(lock/unlock) #6(1段ホスト名) を達成。
残り: AC #4(Pi 再起動後の自動復帰。cloudflared=system unit enabled、door-lock-proxy=user unit enabled+linger で構成上は復帰するはずだが再起動テスト未実施) と AC #5(Pico IP 変更→Caddyfile 更新→復帰の実地訓練)。
通常ウィンドウで引き続き失敗する場合は door-lock-private.ekuinox.dev と cloudflareaccess.com の Cookie/サイトデータ削除で直る見込み。
API トークンの後片付け: ~/.cloudflare-api-token はセッション内で削除済み。ダッシュボードでの失効はユーザー操作待ち。
<!-- SECTION:NOTES:END -->

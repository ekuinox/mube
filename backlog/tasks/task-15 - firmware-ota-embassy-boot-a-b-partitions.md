---
id: TASK-15
title: 'ファーム: embassy-boot A/B パーティションで OTA アップデート対応'
status: To Do
assignee: []
created_date: '2026-07-26 14:03'
updated_date: '2026-07-26 14:32'
labels:
  - firmware
dependencies: []
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
ファーム更新のたびに DAP（デバッグプローブ）を物理的に繋ぎに行くのをやめ、LAN 内から `just lockctl ota` 一発で更新できるようにする。

## 方式（ブレインストーミング済み・案A採用）

embassy-boot-rp による A/B パーティション OTA。

- 2MB フラッシュを「ブートローダー + 状態ページ + ACTIVE スロット + DFU スロット」に分割（memory.x 再構成）
- アプリは HTTP で新ファームを受信し DFU スロットへ逐次書き込み → mark_updated → 再起動
- ブートローダーが DFU→ACTIVE へスワップして新ファームを起動
- 新ファームは WiFi 接続 + HTTP サーバ起動まで到達したら mark_booted。呼べないまま watchdog リセットすると旧ファームへ自動ロールバック
- 転送中の電源断は ACTIVE 無傷なので安全
- `scripts/lockctl.ts` に `ota` サブコマンドを追加

## 制約・リスク

- 各スロット ~960KB にバイナリが収まるかのサイズ検証が最初の関門。収まらない場合は CYW43 ブロブ（約230KB・ほぼ更新不要）を固定アドレスの共有領域へ逃がす
- 経路は LAN 内のみ・無認証（既存 lock/unlock API と同じ信頼モデル）
- 初回だけは DAP でブートローダー + 初期イメージの書き込み手順が変わる（docs/firmware.md 更新要）

設計ドキュメントは docs/ 配下に置く（このタスクの作業中に作成）。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 LAN 内から just lockctl ota で新ファームを書き込める
- [ ] #2 転送中に電源断してもロック操作が引き続き可能（ACTIVE 無傷）
- [ ] #3 起動に失敗する新ファームを焼いた場合、旧ファームへ自動ロールバックする
- [ ] #4 cargo host-test が通る
- [ ] #5 docs/firmware.md に OTA 手順と初回書き込み手順が記載されている
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
実装済み（mube-boot / mube-core ota / firmware ota タスク / lockctl ota / just ota / docs）。残: 実機での初回プロビジョニング（ブートローダー + アプリの DAP 書き込み）と 3 種の実機テスト（正常系・電源断・ロールバック。docs/firmware.md の OTA 節参照）。実機系の AC はそこで消化する
<!-- SECTION:NOTES:END -->

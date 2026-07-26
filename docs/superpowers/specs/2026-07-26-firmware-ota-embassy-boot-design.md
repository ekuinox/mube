# ファーム OTA アップデート設計（embassy-boot A/B）

対応タスク: TASK-15

## 目的

ファーム更新のたびに DAP（デバッグプローブ）を物理的に繋ぎに行くのをやめ、
LAN 内の開発機から `just lockctl ota` 一発で更新できるようにする。
鍵という性質上、**転送中の電源断や壊れたファームの投入でロック操作が失われないこと**
（自動ロールバック）を必須要件とする。

## 要件

- LAN 内から新ファームを無線で書き込める。経路は LAN 内のみ・無認証
  （既存 `/api/lock` 等と同じ信頼モデル。外出先からの更新はスコープ外）。
- 転送中の電源断・切断では現行ファームが無傷のまま動き続ける。
- 起動に失敗する（WiFi + HTTP サーバ起動まで到達しない）新ファームを焼いた場合、
  自動で旧ファームに巻き戻る。
- 更新が本当に反映されたかをリモートから確認できる（バージョン表示）。
- 既存の施錠/解錠機能・API・WebUI は無変更で動き続ける。

## 方式の骨子

Embassy 公式ブートローダー `embassy-boot`（RP2040 向けバインディング `embassy-boot-rp`）
による A/B パーティション構成を採る。ロールバック・電源断耐性・スワップの
アルゴリズムは実績あるライブラリに任せ、自作しない。

```
更新フロー:
  開発機: cargo build → objcopy で raw バイナリ化 → lockctl ota が TCP で送信
  Pico:   受信しながら DFU パーティションへ逐次書き込み → CRC 検証 → OK 応答
          → mark_updated → ソフトリセット
  ブートローダー: DFU→ACTIVE をスワップして新ファーム起動
  新ファーム: WiFi 接続 + HTTP サーバ起動まで到達 → mark_booted（確定）
              到達できず watchdog リセット → ブートローダーが旧ファームへ自動復帰
```

## フラッシュレイアウト

2MB (0x200000) を以下に分割する（embassy の examples/boot/bootloader/rp の並びに
合わせ、STATE はブートローダー直後に置く。境界はすべて 4KB セクタ境界）。

```
0x10000000  BOOT2 + ブートローダー   28KB   (embassy-boot-rp、めったに更新しない)
0x10007000  STATE パーティション      4KB   (ブートローダー状態: swap/revert フラグ)
0x10008000  ACTIVE スロット         988KB   (実行中ファーム。XIP でここから実行)
0x100FF000  DFU スロット            992KB   (受信バッファ。ACTIVE + 1 セクタ)
0x101F7000  余白（将来用）           36KB
```

- アプリの `memory.x` は FLASH 原点を ACTIVE 先頭（0x10008000）へ変更する。
  boot2 セクションはブートローダー側だけが持つ。
- ブートローダーは新規クレート `crates/mube-boot`（ワークスペースに追加）。
- **サイズ収支は実測で確認済み**（2026-07-26、release ビルド）: フラッシュ搭載分は
  約 532KB（.text 127KB + .rodata 407KB[CYW43 ブロブ + WebUI wasm 含む] + vector/boot2/data）で、
  ACTIVE 988KB の約 54%。A/B 構成は成立する。将来溢れそうになった場合の逃げ道として、
  CYW43 ブロブ（約 230KB・ほぼ更新不要）を固定アドレスの共有領域に置き、両スロットから
  参照する構成に変更できる（その場合レイアウトを引き直す）。

## OTA 転送プロトコル

picoserve の HTTP に大きなボディを流すのではなく、**専用 TCP リスナー（port 4242）**
に最小限のフレームプロトコルを設ける。理由: 2KB の HTTP バッファで ~1MB のボディを
picoserve のハンドラ越しにストリームするのはフレームワークと戦うことになり、
素の TCP ソケット + 逐次フラッシュ書き込みのほうが単純で、この
リポジトリでは TCP リスナー実装の実績もある（2026-06-25-tcp-listener）。

```
クライアント → Pico:
  ヘッダ 16 バイト: magic "MUBEOTA1" (8B) + length u32 LE + crc32 u32 LE
  続けてペイロード（アプリの raw バイナリ）を length バイト

Pico → クライアント（1 行応答）:
  "OK <length>\n"          受信完了・CRC 一致。この直後に mark_updated → リセット
  "ERR <reason>\n"         magic 不一致 / length 超過 / CRC 不一致 / 書き込み失敗
```

- 受信は 4KB 単位で DFU パーティションへ `FirmwareUpdater::write_firmware` する。
  CRC32 は受信しながら逐次計算する。
- length の上限は ACTIVE スロットサイズ。超過はヘッダ時点で拒否する。
- 途中切断・CRC 不一致では mark_updated を呼ばない。DFU パーティションが
  中途半端でも ACTIVE には一切触れていないので安全。
- 施錠/解錠のサーボ駆動中はリセットしない: OK 応答後、サーボがアイドルに
  なるのを待ってからリセットする。

### mube-core への切り出し

ヘッダ解析・受信オフセット管理・逐次 CRC32・完了判定は純ロジックとして
`mube-core` に `ota` モジュールで置き、host テストする（このリポジトリの
testable-core 方針どおり）。firmware 側はソケット読み取りとフラッシュ書き込みを
つなぐ薄いアダプタだけを持つ。CRC32 は依存を増やさずテーブル生成の
小実装を `mube-core` 内に持つ（既知ベクタで host テスト）。

## ロールバックと watchdog

- 新ファームは「WiFi 接続完了 + HTTP サーバタスク起動 + サーボ初期化完了」を
  ヘルス条件とし、そこへ到達したら `mark_booted` を呼んで更新を確定する。
- RP2040 の watchdog を起動直後に有効化し（タイムアウト ~8 秒）、メインループで
  定期的に餌をやる。新ファームがヘルス条件前に panic・ハングすると watchdog
  リセット → ブートローダーが state を見て旧ファームへ revert する。
- watchdog は mark_booted 後も有効のままにする。以後どんなハングでも自動再起動
  するようになり、鍵としての可用性はむしろ上がる（挙動変更として README に明記）。
- WiFi が本当に圏外のケース: 旧ファームでも接続できないので revert しても
  状況は同じ。ヘルス条件に WiFi を含めるのは「新ファームだけ接続できない」
  リグレッション（cyw43 初期化壊しなど）を検出するため。

## バージョン確認

更新が反映されたかをリモートで確認するため、`/api/version` を追加する。
build.rs で `git describe --always --dirty` を環境変数に埋め、
`{"version":"f90217f"}` の形で返す。`lockctl ota` は更新後にこれをポーリングし、
バージョンが変わったこと（= スワップ成功）を確認して完了報告する。

## クライアント側（lockctl / Justfile）

- `scripts/lockctl.ts` に `ota <bin>` サブコマンドを追加する。TCP 4242 へ
  ヘッダ + バイナリを送り、応答を表示 → `/api/version` をポーリングして
  新バージョン起動を確認する。接続先は既存どおり `TARGET_IP`。
- `Justfile` に `ota` レシピを追加する:
  ビルド（blobs → webui → cargo build --release）→ `rust-objcopy -O binary` で
  raw バイナリ化 → `lockctl ota` 実行、までの一発化。
  objcopy は rust-toolchain の llvm-tools（devShell で供給）を使う。

## 初回書き込み（プロビジョニング）

初回だけは DAP で 2 つ焼く（docs/firmware.md を更新する）:

1. `crates/mube-boot` を probe-rs で書き込み（ブートローダー + boot2）
2. `crates/mube-firmware` を probe-rs で書き込み（ACTIVE 先頭へリンク済み）

以後の更新は `just ota` のみ。BOOTSEL + UF2 経路も従来同様に使える
（UF2 はアドレス付きなので、ブートローダーが焼けていればアプリ UF2 だけで良い）。

## テスト

- **host テスト（cargo host-test）**: mube-core の ota モジュール —
  ヘッダ解析（正常 / magic 不一致 / length 超過）、逐次 CRC32 の既知ベクタ、
  分割受信のオフセット管理、完了・エラー判定。既存テストのリグレッション確認。
- **実機テスト（手動・docs に手順を書く）**:
  1. 正常系: バージョンを変えて `just ota` → `/api/version` が変わる
  2. 電源断: 転送中に AC を抜く → 再起動後も旧ファームで施解錠できる
  3. ロールバック: ヘルス条件前に意図的に panic するビルド
     （dev 用 feature `ota-rollback-test`）を `just ota` → watchdog リセット後、
     旧バージョンに戻っていることを `/api/version` で確認

## 触るファイル

- `crates/mube-boot/` — 新規: ブートローダークレート（main.rs / memory.x / Cargo.toml）
- `crates/mube-firmware/memory.x` — FLASH 原点を ACTIVE へ、boot2 を外す
- `crates/mube-firmware/Cargo.toml` — embassy-boot-rp / embassy-embedded-hal 等を追加
- `crates/mube-firmware/src/main.rs` — OTA タスク spawn・watchdog・mark_booted
- `crates/mube-firmware/src/ota.rs` — 新規: TCP リスナー + フラッシュ書き込みアダプタ
- `crates/mube-firmware/src/http.rs` — `/api/version` 追加
- `crates/mube-firmware/build.rs` — git describe の埋め込み
- `crates/mube-core/src/ota.rs` — 新規: プロトコル状態機械 + CRC32（host テスト込み）
- `scripts/lockctl.ts` — `ota` サブコマンド
- `Justfile` — `ota` レシピ
- `Cargo.toml`（ワークスペース）— mube-boot 追加
- `docs/firmware.md` — OTA 手順・初回書き込み手順・watchdog 挙動
- `backlog/tasks/task-15 - firmware-ota-embassy-boot-a-b-partitions.md` — 進捗反映

## やらないこと（YAGNI）

- 署名検証・暗号化（LAN 内・無認証の既存信頼モデルに合わせる。将来
  外部公開するならその時に）
- 差分更新・圧縮転送
- WebUI からのファームアップロード（lockctl で足りる）
- ブートローダー自身の OTA（めったに変えない。変えるときは DAP）
- CYW43 ブロブの共有領域化（サイズが収まるうちはやらない。逃げ道としてだけ確保）

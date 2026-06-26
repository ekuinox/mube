# スマートロック パーツ選定（調達ドキュメント）

## 概要

- 目的: `circuit/netlist.py` の BOM を日本のネット通販で発注できる実商品へ対応づけ、購入先をまとめて 1 台分の概算を出す。
- 範囲: 完成実機に物理的に残る全 14 品目（BOM 9 点＋手配線に要る追加 5 点）。道具・消耗品は対象外。
- 購入先方針: 秋月電子通商に集約。全 14 品目が秋月で揃う。
- 調査日: 2026-06-25（価格・在庫・通販コードはこの時点のスナップショット。変動するため発注前に各店で要確認）。通販コードは各商品ページへのリンクになっている。
- 数量: スマートロック 1 台分。パック品はパック価格と 1 台按分額を併記。

## メイン表

| Ref/品目 | 商品名 | 店 | 通販コード | 商品単価(税込) | 入数 | 1台必要数 | 1台按分額 |
|----------|--------|----|-----------|---------------|------|-----------|-----------|
| U1 Pico W | Raspberry Pi Pico W | 秋月 | [M-17947](https://akizukidenshi.com/catalog/g/g117947/) | ¥1,240 | 1 | 1 | ¥1,240 |
| M1 SG90 | マイクロサーボ9g SG90 | 秋月 | [M-08761](https://akizukidenshi.com/catalog/g/g108761/) | ¥650 | 1 | 1 | ¥650 |
| Q1 FET | NchパワーMOSFET 30V260A IRLB3813PBF | 秋月 | [I-06270](https://akizukidenshi.com/catalog/g/g106270/) | ¥140 | 1 | 1 | ¥140 |
| Rg 220Ω | カーボン抵抗(炭素皮膜抵抗) 1/4W220Ω | 秋月 | [R-25221](https://akizukidenshi.com/catalog/g/g125221/) | ¥150 | 100 | 1 | ¥2 |
| Rgs 10kΩ | カーボン抵抗(炭素皮膜抵抗) 1/4W10kΩ | 秋月 | [R-25103](https://akizukidenshi.com/catalog/g/g125103/) | ¥100 | 100 | 1 | ¥1 |
| Rled 330Ω | カーボン抵抗(炭素皮膜抵抗) 1/4W330Ω | 秋月 | [R-25331](https://akizukidenshi.com/catalog/g/g125331/) | ¥180 | 100 | 1 | ¥2 |
| D1 LED | 5mm砲弾型赤色LED 640nm 1200mcd 15° OSDR5113A | 秋月 | [I-11655](https://akizukidenshi.com/catalog/g/g111655/) | ¥20 | 1 | 1 | ¥20 |
| SW1 タクト | タクトスイッチ(黒色) | 秋月 | [P-03647](https://akizukidenshi.com/catalog/g/g103647/) | ¥15 | 1 | 1 | ¥15 |
| C1 470µF | 電解コンデンサー 470µF16V105℃ ルビコンPX | 秋月 | [P-10273](https://akizukidenshi.com/catalog/g/g110273/) | ¥10 | 1 | 1 | ¥10 |
| - ユニバーサル基板 | 片面ユニバーサル基板 Dタイプ(47×36mm) ガラスコンポジット | 秋月 | [P-08241](https://akizukidenshi.com/catalog/g/g108241/) | ¥80 | 1 | 1 | ¥80 |
| - 配線材 | 耐熱電子ワイヤー 1m×10色 導体外径0.36mm(AWG28相当) | 秋月 | [P-11640](https://akizukidenshi.com/catalog/g/g111640/) | ¥350 | 10 | 1 | ¥35 |
| - ピンヘッダ | ピンヘッダー 1×40 (40P) | 秋月 | [C-00167](https://akizukidenshi.com/catalog/g/g100167/) | ¥35 | 1 | 2 | ¥70 |
| - USB電源 | スイッチングACアダプター(USB ACアダプター) Type-Aメス 5V1A | 秋月 | [M-08312](https://akizukidenshi.com/catalog/g/g108312/) | ¥770 | 1 | 1 | ¥770 |
| - micro-USBケーブル | USBケーブル USB2.0 Aオス-マイクロBオス 0.5m A-microB | 秋月 | [C-09314](https://akizukidenshi.com/catalog/g/g109314/) | ¥150 | 1 | 1 | ¥150 |

## 概算サマリ

- ① 1台分の理論按分合計: ¥3,185（按分額列の総和。理論上 1 台が消費する分だけの価値）
- ② 実際に 1 台作るために払う総額: ¥3,925（パック品も丸ごと買う前提の実支出。送料別）
  - 内訳: 秋月 ¥3,925（全点秋月、他店送りなし）
  - 送料の目安: 秋月電子は注文金額により変動。発注前に各店の送料条件を確認。
- 補足: ②は初回 1 台の実支出。抵抗等のパック余剰（各 99 本残）により 2 台目以降は①に近づく。

## 購入先まとめ

秋月電子通商で全点購入（集約率 14/14 = 100%）。他店送りなし。

| 店 | 通販コード | 品目 |
|----|-----------|------|
| 秋月電子通商 | [M-17947](https://akizukidenshi.com/catalog/g/g117947/) | Raspberry Pi Pico W |
| 秋月電子通商 | [M-08761](https://akizukidenshi.com/catalog/g/g108761/) | マイクロサーボ9g SG90 |
| 秋月電子通商 | [I-06270](https://akizukidenshi.com/catalog/g/g106270/) | NchパワーMOSFET IRLB3813PBF |
| 秋月電子通商 | [R-25221](https://akizukidenshi.com/catalog/g/g125221/) | カーボン抵抗 1/4W 220Ω（100本入） |
| 秋月電子通商 | [R-25103](https://akizukidenshi.com/catalog/g/g125103/) | カーボン抵抗 1/4W 10kΩ（100本入） |
| 秋月電子通商 | [R-25331](https://akizukidenshi.com/catalog/g/g125331/) | カーボン抵抗 1/4W 330Ω（100本入） |
| 秋月電子通商 | [I-11655](https://akizukidenshi.com/catalog/g/g111655/) | 5mm砲弾型赤色LED 単品 |
| 秋月電子通商 | [P-03647](https://akizukidenshi.com/catalog/g/g103647/) | タクトスイッチ(黒色) |
| 秋月電子通商 | [P-10273](https://akizukidenshi.com/catalog/g/g110273/) | 電解コンデンサー 470µF16V |
| 秋月電子通商 | [P-08241](https://akizukidenshi.com/catalog/g/g108241/) | 片面ユニバーサル基板 Dタイプ(47×36mm) |
| 秋月電子通商 | [P-11640](https://akizukidenshi.com/catalog/g/g111640/) | 耐熱電子ワイヤー 1m×10色 AWG28 |
| 秋月電子通商 | [C-00167](https://akizukidenshi.com/catalog/g/g100167/) | ピンヘッダー 1×40 ×2本 |
| 秋月電子通商 | [M-08312](https://akizukidenshi.com/catalog/g/g108312/) | USB ACアダプター Type-Aメス 5V1A |
| 秋月電子通商 | [C-09314](https://akizukidenshi.com/catalog/g/g109314/) | USBケーブル A-microB 0.5m |

## 備考

### MOSFET の注意（重要）

第一候補の IRLZ44N は秋月取扱なし。採用した IRLB3813PBF は Vgs(th) 最大 2.35V で Pico W の 3.3V GPIO で閾値は超えられるが、フル導通には 4.5V 以上が望ましく、3.3V 駆動時は Rds(on) が増える。サーボ電源ゲート（低頻度 ON/OFF）では実用上許容の見込みだが、購入前・実装時に 3.3V ゲート駆動の導通特性を要確認。

### 配線材

ジュンフロン線は秋月ネット通販で取扱なし。耐熱電子ワイヤー AWG28（[P-11640](https://akizukidenshi.com/catalog/g/g111640/)）で代替。手配線に十分。

### 代替候補

- Pico WH ヘッダ付き（[M-18086](https://akizukidenshi.com/catalog/g/g118086/) ¥1,375）: ピンヘッダ実装済みのため、ピンヘッダ（[C-00167](https://akizukidenshi.com/catalog/g/g100167/)）の購入が不要になる。
- 電解コンデンサ 25V 品（[P-17883](https://akizukidenshi.com/catalog/g/g117883/) ¥20）: 耐圧に余裕が欲しい場合の代替。
- 5mm 赤色 LED 10個パック（[I-01318](https://akizukidenshi.com/catalog/g/g101318/) ¥150）: 1 個あたり ¥15 でコスパが高い。複数台予定なら検討。
- ユニバーサル基板 72×47.5mm（[P-00517](https://akizukidenshi.com/catalog/g/g100517/) ¥100）: 部品点数が増えた場合の代替。
- USB ACアダプター Micro-Bオス直結 5V3A（[M-12001](https://akizukidenshi.com/catalog/g/g112001/) ¥1,100）: Pico W の Micro-USB 端子に直結でき、品目 14 の micro-USB ケーブルが不要になる。電力余裕あり。

### 注意点

- 電解コンデンサ（C1）は極性あり。実装時に＋端子の向きを確認すること。耐圧 16V は VBUS 5V に対し十分な余裕がある。
- USB ACアダプタは 5V/1A 以上の出力を持つ製品を選ぶこと。
- Pico W の USB コネクタは Micro-USB B。品目 14 のケーブルが対応していることを確認。

### netlist.py への申し送り TODO

実機で型番確定後に FET の value を 1 つへ絞り込み、コンデンサ耐圧を value に追記する（本作業では netlist.py は変更しない）。

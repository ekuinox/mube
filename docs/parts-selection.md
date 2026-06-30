# スマートロック パーツ選定（調達ドキュメント）

## 概要

- 目的: `circuit/netlist.py` の BOM を日本のネット通販で発注できる実商品へ対応づけ、購入先をまとめて 1 台分の概算を出す。
- 範囲: 完成実機に物理的に残る全 17 品目（BOM 11 点＋手配線に要る追加 6 点）。道具・消耗品は対象外。
- 購入先方針: 秋月電子通商に集約。全 17 品目が秋月で揃う。
- 調査日: 2026-06-25（価格・在庫・通販コードはこの時点のスナップショット。変動するため発注前に各店で要確認）。通販コードは各商品ページへのリンクになっている。
- 在庫・販売状況: 2026-06-25 時点で、メイン表 17 品目および備考の代替候補 4 品目すべてが秋月電子で販売中・在庫ありであることを商品ページで確認済み（廃盤なし）。一部は次回入荷待ちの表記があるが注文は可能。追加 3 品目（C2, D2, M2ネジ）は 2026-06-30 時点で在庫確認済み。
- 数量: スマートロック 1 台分。パック品はパック価格と 1 台按分額を併記。

## メイン表

| Ref/品目 | 商品名 | 店 | 通販コード | 商品単価(税込) | 入数 | 1台必要数 | 1台按分額 |
|----------|--------|----|-----------|---------------|------|-----------|-----------|
| U1 Pico W | Raspberry Pi Pico W | 秋月 | [M-17947](https://akizukidenshi.com/catalog/g/g117947/) | ¥1,240 | 1 | 1 | ¥1,240 |
| M1 SG90 | マイクロサーボ9g SG90 | 秋月 | [M-08761](https://akizukidenshi.com/catalog/g/g108761/) | ¥650 | 1 | 1 | ¥650 |
| Q1 FET | NchパワーMOSFET 30V260A IRLB3813PBF | 秋月 | [I-06270](https://akizukidenshi.com/catalog/g/g106270/) | ¥140 | 1 | 1 | ¥140 |
| Rg 220Ω | カーボン抵抗(炭素皮膜抵抗) 1/4W220Ω | 秋月 | [R-25221](https://akizukidenshi.com/catalog/g/g125221/) | ¥150 | 100 | 1 | ¥2 |
| Rgs 10kΩ | カーボン抵抗(炭素皮膜抵抗) 1/4W10kΩ | 秋月 | [R-25103](https://akizukidenshi.com/catalog/g/g125103/) | ¥100 | 100 | 1 | ¥1 |
| Rled 330Ω | カーボン抵抗(炭素皮膜抵抗) 1/4W330Ω | 秋月 | [R-25331](https://akizukidenshi.com/catalog/g/g125331/) | ¥180 | 100 | 2 | ¥4 |
| D1 2色LED | 2色LED 赤・黄緑5mm カソードコモン 乳白色 OSRGHC5B32A（10個入） | 秋月 | [I-06314](https://akizukidenshi.com/catalog/g/g106314/) | ¥150 | 10 | 1 | ¥15 |
| SW1 タクト | タクトスイッチ(黒色) | 秋月 | [P-03647](https://akizukidenshi.com/catalog/g/g103647/) | ¥15 | 1 | 1 | ¥15 |
| C1 470µF | 電解コンデンサー 470µF16V105℃ ルビコンPX | 秋月 | [P-10273](https://akizukidenshi.com/catalog/g/g110273/) | ¥10 | 1 | 1 | ¥10 |
| - ユニバーサル基板 | 片面ガラスコンポジット・ユニバーサル基板 Cタイプ(72×47mm) めっき仕上げ | 秋月 | [P-03229](https://akizukidenshi.com/catalog/g/g103229/) | ¥130 | 1 | 1 | ¥130 |
| - 配線材 | 耐熱電子ワイヤー 1m×10色 導体外径0.36mm(AWG28相当) | 秋月 | [P-11640](https://akizukidenshi.com/catalog/g/g111640/) | ¥350 | 10 | 1 | ¥35 |
| - ピンヘッダ | ピンヘッダー 1×40 (40P) | 秋月 | [C-00167](https://akizukidenshi.com/catalog/g/g100167/) | ¥35 | 1 | 2 | ¥70 |
| - USB電源 | スイッチングACアダプター(USB ACアダプター) Type-Aメス 5V1A | 秋月 | [M-08312](https://akizukidenshi.com/catalog/g/g108312/) | ¥770 | 1 | 1 | ¥770 |
| - micro-USBケーブル | USBケーブル USB2.0 Aオス-マイクロBオス 0.5m A-microB | 秋月 | [C-09314](https://akizukidenshi.com/catalog/g/g109314/) | ¥150 | 1 | 1 | ¥150 |
| C2 100nF | 積層セラミックコンデンサー 0.1µF100V X7R 5mmピッチ | 秋月 | [P-15927](https://akizukidenshi.com/catalog/g/g115927/) | ¥120 | 10 | 1 | ¥12 |
| D2 1N5819 | ショットキーバリアダイオード 40V1A 1N5819 | 秋月 | [I-17244](https://akizukidenshi.com/catalog/g/g117244/) | ¥100 | 10 | 1 | ¥10 |
| - M2ネジ (サーボ固定) | なべ小ねじ(+) M2×5 黄銅 | 秋月 | [P-15887](https://akizukidenshi.com/catalog/g/g115887/) | ¥100 | 10 | 2 | ¥20 |

## 概算サマリ

- ① 1台分の理論按分合計: ¥3,274（按分額列の総和。理論上 1 台が消費する分だけの価値）
- ② 実際に 1 台作るために払う総額: ¥4,425（パック品も丸ごと買う前提の実支出。送料別）
  - 内訳: 秋月 ¥4,425（全点秋月、他店送りなし）
  - 送料の目安: 秋月電子は注文金額により変動。発注前に各店の送料条件を確認。
- 補足: ②は初回 1 台の実支出。抵抗等のパック余剰（各 99 本残）により 2 台目以降は①に近づく。

## 購入先まとめ

秋月電子通商で全点購入（集約率 17/17 = 100%）。他店送りなし。

| 店 | 通販コード | 品目 |
|----|-----------|------|
| 秋月電子通商 | [M-17947](https://akizukidenshi.com/catalog/g/g117947/) | Raspberry Pi Pico W |
| 秋月電子通商 | [M-08761](https://akizukidenshi.com/catalog/g/g108761/) | マイクロサーボ9g SG90 |
| 秋月電子通商 | [I-06270](https://akizukidenshi.com/catalog/g/g106270/) | NchパワーMOSFET IRLB3813PBF |
| 秋月電子通商 | [R-25221](https://akizukidenshi.com/catalog/g/g125221/) | カーボン抵抗 1/4W 220Ω（100本入） |
| 秋月電子通商 | [R-25103](https://akizukidenshi.com/catalog/g/g125103/) | カーボン抵抗 1/4W 10kΩ（100本入） |
| 秋月電子通商 | [R-25331](https://akizukidenshi.com/catalog/g/g125331/) | カーボン抵抗 1/4W 330Ω（100本入, 2本使用） |
| 秋月電子通商 | [I-06314](https://akizukidenshi.com/catalog/g/g106314/) | 2色LED 赤・黄緑 5mm カソードコモン 乳白色 OSRGHC5B32A（10個入） |
| 秋月電子通商 | [P-03647](https://akizukidenshi.com/catalog/g/g103647/) | タクトスイッチ(黒色) |
| 秋月電子通商 | [P-10273](https://akizukidenshi.com/catalog/g/g110273/) | 電解コンデンサー 470µF16V |
| 秋月電子通商 | [P-03229](https://akizukidenshi.com/catalog/g/g103229/) | 片面ユニバーサル基板 Cタイプ(72×47mm) めっき仕上げ |
| 秋月電子通商 | [P-11640](https://akizukidenshi.com/catalog/g/g111640/) | 耐熱電子ワイヤー 1m×10色 AWG28 |
| 秋月電子通商 | [C-00167](https://akizukidenshi.com/catalog/g/g100167/) | ピンヘッダー 1×40 ×2本 |
| 秋月電子通商 | [M-08312](https://akizukidenshi.com/catalog/g/g108312/) | USB ACアダプター Type-Aメス 5V1A |
| 秋月電子通商 | [C-09314](https://akizukidenshi.com/catalog/g/g109314/) | USBケーブル A-microB 0.5m |
| 秋月電子通商 | [P-15927](https://akizukidenshi.com/catalog/g/g115927/) | 積層セラミックコンデンサー 0.1µF100V X7R 5mmピッチ（10個入, 1個使用） |
| 秋月電子通商 | [I-17244](https://akizukidenshi.com/catalog/g/g117244/) | ショットキーバリアダイオード 40V1A 1N5819（10本入, 1本使用） |
| 秋月電子通商 | [P-15887](https://akizukidenshi.com/catalog/g/g115887/) | なべ小ねじ(+) M2×5 黄銅（10個入, 2個使用） |

## 備考

### MOSFET の注意（重要）

第一候補の IRLZ44N は秋月取扱なし。採用した IRLB3813PBF は Vgs(th) 最大 2.35V で Pico W の 3.3V GPIO で閾値は超えられるが、フル導通には 4.5V 以上が望ましく、3.3V 駆動時は Rds(on) が増える。サーボ電源ゲート（低頻度 ON/OFF）では実用上許容の見込みだが、購入前・実装時に 3.3V ゲート駆動の導通特性を要確認。

### 配線材

ジュンフロン線は秋月ネット通販で取扱なし。耐熱電子ワイヤー AWG28（[P-11640](https://akizukidenshi.com/catalog/g/g111640/)）で代替。手配線に十分。

### 代替候補

- Pico WH ヘッダ付き（[M-18086](https://akizukidenshi.com/catalog/g/g118086/) ¥1,375）: ピンヘッダ実装済みのため、ピンヘッダ（[C-00167](https://akizukidenshi.com/catalog/g/g100167/)）の購入が不要になる。
- 電解コンデンサ 25V 品（[P-17883](https://akizukidenshi.com/catalog/g/g117883/) ¥20）: 耐圧に余裕が欲しい場合の代替。
- ユニバーサル基板 72×47.5mm（[P-00517](https://akizukidenshi.com/catalog/g/g100517/) ¥100）: 部品点数が増えた場合の代替。
- USB ACアダプター Micro-Bオス直結 5V3A（[M-12001](https://akizukidenshi.com/catalog/g/g112001/) ¥1,100）: Pico W の Micro-USB 端子に直結でき、品目 14 の micro-USB ケーブルが不要になる。電力余裕あり。

### 注意点

- 二色LED（D1, OSRGHC5B32A）はコモンカソード。3 本足のうち共通カソード（K）を GND、赤アノード（R）を GP16、黄緑アノード（G）を GP18 へ。足の並びはデータシートで確認すること。赤・黄緑とも Vf=2.1V のため抵抗は両側 330Ω で明るさが揃う。施錠=赤・解錠=黄緑で点灯し、同時点灯はしない。
- 電解コンデンサ（C1）は極性あり。実装時に＋端子の向きを確認すること。耐圧 16V は VBUS 5V に対し十分な余裕がある。
- USB ACアダプタは 5V/1A 以上の出力を持つ製品を選ぶこと。
- Pico W の USB コネクタは Micro-USB B。品目 14 のケーブルが対応していることを確認。
- セラミックコンデンサ（C2）は無極性。C1（電解 470µF）に並列で VBUS-GND 間に配置する。C1 に隣接させること（高周波バイパス効果のため）。
- ショットキーダイオード（D2, 1N5819）はカソード帯（白帯）を +5V 側（M1.V+）に、アノードを SERVO_RTN 側（M1.GND / Q1.D）に接続する。逆に付けるとサーボ電源が短絡するので極性に注意。
- M2 ネジ（なべ小ねじ M2×5）はサーボ耳のネジ穴 2 箇所に使用する。3D プリント筐体の 1.8mm パイロットホールにセルフタップで固定する。締めすぎるとボスが割れるので注意。

### netlist.py への申し送り TODO

実機で型番確定後に FET の value を 1 つへ絞り込み、コンデンサ耐圧を value に追記する。

# tscircuit 全体シミュレーション（Pico/サーボ モック）設計

日付: 2026-07-04
ステータス: 承認待ち

## 目的

smtlk 回路全体を tscircuit の SPICE シミュレーションにかけられるようにする。
Pico W と SG90 サーボは SPICE モデルを持たないため、電気的に等価なモックへ置き換える。
「サーボON（解錠中）」の静的な動作点を 1 状態だけ再現し、各部の電圧・電流を読む。

前提として確認済みの事実（node_modules 実装を確認）:
- tscircuit の解析モードは過渡解析（`spice_transient_analysis`）のみ。DC 動作点解析（`.op`）は無い。
  → 静的動作点は「DC 一定入力の過渡解析を短時間流し、落ち着いた値を読む」で得る。波形は平坦。
- SPICE 変換対象: 抵抗/コンデンサ/インダクタ/ダイオード/LED/MOSFET/BJT/電圧源/電流源/スイッチ。
  MOSFET・ダイオード・LED には汎用デフォルトモデルが自動付与される（実物のモデルではない）。
- 電流は `ammeter`（直列挿入）、電圧は `voltageprobe` で読む。

## 配置

- 独立ファイル `tscircuit/sim-full.tsx` に全部を書く。`index.tsx` と `circuit/netlist.py` は変更しない。
- ネット名は index.tsx と揃える（V5=+5V, GND, SERVO_RTN, SERVO_SIG, GATE_DRV, GATE,
  LED_DRV_R, LED_A_R, LED_DRV_G, LED_A_G, BTN）。見比べやすさのため。

## モック

### モック① Pico W（電源 + GPIO 出力の集合）

- VBUS: `V5`（+5V）と `GND` の間に 5V 電圧源。USB 給電の代役。
- 3.3V ロジックレール源を 1 つ用意し、そこから各 GPIO を駆動する。
- GP14（ゲート駆動）= 3.3V（HIGH）。MOSFET を ON にしてサーボへ給電する。
  これが「サーボON状態」の定義。GATE_DRV ノード（元 U1.GP14）を 3.3V に駆動。
- GP16（赤 LED）= 3.3V（点灯）、GP18（緑 LED）= 0V（消灯）。点灯側は後で入れ替え可能。
- GP15（サーボ SIG）= 3.3V をサーボモックの SIG 入力へ。高抵抗終端で電流は無視できる。
- GP17（ボタン）= Pico 内部プルアップを「BTN → 3.3V レールの抵抗（約 50k）」で表現。
  SW1 は開（未押下）とし、BTN は 3.3V 付近に落ち着く。

### モック② SG90 サーボ（3 ピン: V+ / 戻り / SIG）

- V+（=`V5`）→ 戻り（`SERVO_RTN`）を抵抗で表す。SG90 の動作電流〜200mA 相当で約 25Ω。
  値は調整可能。静的スナップショットのためインダクタンスは不要（電流変化が無く効かない）。
- SIG は高インピーダンス入力。10k 程度で `GND`（または戻り）へ。電流は無視できる。

## 測定

- 電圧プローブ: `V5` レール、`GATE`（Q1 ゲート電圧＝ON しているか）、
  `SERVO_RTN`（＝Q1 ドレイン電圧＝MOSFET の電圧降下）、`LED_A_R`（赤 LED アノード）。
- 電流計（ammeter, 直列挿入）: サーボ電流（＝Q1 ドレイン電流）、赤 LED 電流（Rled 直列）。

## 期待される目安の値（topology が正しければこの近辺に落ち着く）

- `V5` レール ≈ 5V。
- `GATE` ≈ 3.2V（Rg/Rgs の分圧 3.3 × 10k/(220+10k)）→ MOSFET ON。
- `SERVO_RTN`（Q1 の Vds）= 小さい値。サーボ電流 ≈ 200mA 弱。赤 LED 電流 ≈ 数 mA。

## 制約（正直に明記する）

- MOSFET・ダイオード・LED は tscircuit の汎用デフォルト SPICE モデルであり、実物
  （IRLB3813 / 1N5819 / OSRGHC5B32A）ではない。したがって数値は「topology が妥当か・
  おおよそ何 mA 流れるか」を掴むためのざっくり値。特に MOSFET の Vds と正確な電流は目安。
  実精度が必要なら `<spicemodel>` で実モデルを貼れるが今回は対象外。
- 静的動作点のため、還流ダイオード D2 の保護動作（逆起電力を逃がす）は波形に出ない。
  静的 ON では D2 は逆バイアスで電流ほぼ 0 が正しい姿。D2 の動作を見るには MOSFET を
  OFF する瞬間の過渡シムが別途必要（今回の対象外）。

## 成功条件

- `nix develop -c bunx tsci build sim-full.tsx` が通り、circuit.json に simulation_experiment が
  生成される。
- 各プローブ／電流計が上記の妥当なオーダーの値に落ち着く（明らかな異常値＝配線ミスが無い）。
- `nix develop -c bunx tsci dev sim-full.tsx` を 172.20.0.0/16 の LAN から開き、Simulation タブで
  確認できる。

## テスト方針

- ビルド成功、かつ circuit.json に simulation 要素（simulation_experiment / 
  simulation_transient_voltage_graph 等）が含まれることを機械的に確認する。
- 主要プローブの落ち着き値が妥当なレンジ内かを目視する。初心者でも判断できるよう、
  期待値のメモを `sim-full.tsx` 冒頭コメントに書く。

## やらないこと

- `index.tsx` / `circuit/netlist.py` の変更。
- 実部品の SPICE モデル（`<spicemodel>`）の貼り付け。
- 解錠シーケンスの時間変化再現、D2 保護動作の過渡解析。
- 基板レイアウト・CI 組み込み。

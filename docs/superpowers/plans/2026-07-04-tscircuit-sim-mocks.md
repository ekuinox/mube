# 全体シミュレーション（Pico/サーボ モック）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** smtlk 回路全体を、Pico W とサーボを電気モックに置換して SPICE シミュレーションできる `tscircuit/sim-full.tsx` を作り、「サーボON」の静的動作点が妥当な値に落ち着くことを確認する。

**Architecture:** 独立ファイル `sim-full.tsx` に、実部品（Q1/D1/D2 は simulatable な mosfet/led/diode で記述）＋ Pico モック（VBUS 5V 源・3.3V ロジックレール源）＋サーボモック（抵抗）を書く。DC 一定入力の過渡解析を短時間流し、落ち着いた値＝動作点を読む。`index.tsx` と `circuit/netlist.py` は変更しない。

**Tech Stack:** tscircuit, @tscircuit/cli (tsci), bun, nix devShell

## Global Constraints

- 独立ファイル `tscircuit/sim-full.tsx` に書く。`index.tsx` / `circuit/netlist.py` は変更しない。
- ネット名は index.tsx と揃える: V5(=+5V), GND, SERVO_RTN, SERVO_SIG, GATE_DRV, GATE, LED_DRV_R, LED_A_R, LED_DRV_G, LED_A_G, BTN。
- 解析は過渡解析のみ（`spice_transient_analysis`）。DC 動作点解析は無いので、DC 一定入力を短時間流して落ち着き値を読む。
- MOSFET/ダイオード/LED は tscircuit の汎用デフォルト SPICE モデル（実物ではない）。数値はざっくり値。検証レンジは緩めに取る。
- `<analogsimulation>` に `spiceEngine="ngspice"` を必ず指定する。既定エンジン（"spicey"）は MOSFET を正しく解けず Q1 が導通せず VP_RTN が 5V に張り付く（実測確認済み）。ngspice なら Vgs=3.2V/Vth=1V で導通し VP_RTN≈0.9V・サーボ電流≈160mA になる。
- 静的動作点のため D2 の還流(保護)動作は出ない（静的 ON では D2 逆バイアスで電流≈0 が正しい）。
- コマンドは nix devShell 経由。作業は `tscircuit/` ディレクトリ内で `nix develop .. -c <cmd>`。ネットワークが要るビルドはサンドボックス外実行の許可を取る。
- tscircuit の API は更新が速い。ビルドが prop/セレクタ/コネクション記法でエラーになったら、エラーメッセージと `node_modules` の型定義（`@tscircuit/props/dist/index.d.ts`）を根拠に**記法だけ**修正してよい。ただし部品構成・モックの考え方・ネット名・測定点は本プラン通りを維持する。

確認済みの API 事実（`@tscircuit/props/dist/index.d.ts` / `circuit-json-to-spice`）:
- `<voltagesource voltage="5V" />` は waveShape 省略で DC 源。ピンは `.pos` / `.neg`。
- `<mosfet channelType="n" mosfetMode="enhancement" />`。ピンは `.gate` / `.drain` / `.source`。
- `<led />` / `<diode />` のピンは `.anode` / `.cathode`。
- `<ammeter connections={{ pin1: "...", pin2: "..." }} />`（connections は必須プロップ）。
- `<voltageprobe connectsTo="..." />` は**部品ピン**に繋ぐ（`net.XXX` を指すとビルドエラー）。
- 出力は `dist/sim-full/circuit.json`。過渡電圧グラフは `simulation_transient_voltage_graph`（`voltage_levels` 配列の末尾が落ち着き値）。

---

### Task 1: 電源経路コア（VBUS/3.3V モック＋Q1＋サーボ抵抗＋電流計＋電圧プローブ）

「サーボON」の中心（Pico 電源モック・MOSFET の SPICE 化・ammeter 記法・probe-on-pin・シミュレーションパイプライン）を最小構成で通す。LED/ボタン/SIG は Task 2。

**Files:**
- Create: `tscircuit/sim-full.tsx`

**Interfaces:**
- Consumes: `nix develop .. -c bunx tsci build sim-full.tsx`（Task 2 の tscircuit プロジェクトは構築済み）
- Produces: `sim-full.tsx`（Task 2 が同ファイルを拡張する）。ネット名 V5/GND/SERVO_RTN/GATE_DRV/GATE、部品名 VBUS/V3V3/Rservo/Q1/Rg/Rgs/C1/C2/D2/A_servo、プローブ名 VP_V5/VP_GATE/VP_RTN。

- [ ] **Step 1: ビルドが失敗することを確認（ファイル未作成）**

Run: `cd tscircuit && nix develop .. -c bunx tsci build sim-full.tsx`
Expected: FAIL（`sim-full.tsx` が見つからない旨のエラー）

- [ ] **Step 2: sim-full.tsx（電源経路コア）を作成**

`tscircuit/sim-full.tsx`:

```tsx
// smtlk 回路の全体シミュレーション（サーボON=解錠中 の静的動作点）。
// Pico W と SG90 サーボを電気モックに置換。DC 一定入力の過渡解析を短時間流し、
// 落ち着いた値を読む＝スナップショット（波形は平坦）。
// 実部品 Q1/D2 は SPICE モデルが要るため chip ではなく mosfet/diode で書く。
//
// 期待される落ち着き値の目安（汎用デフォルト SPICE モデルのためざっくり値）:
//   VP_V5   ≈ 5V（V5 レール）
//   VP_GATE ≈ 3.2V（3.3×10k/(220+10k)）→ Q1 ON
//   VP_RTN  = 小さめ（Q1 の Vds）
//   A_servo ≈ 200mA 弱（Rservo=25Ω を通る）
// 注: 静的動作点なので D2 の還流(保護)動作は出ない（静的 ON では D2 逆バイアスで電流≈0）。
export default () => (
  <board width="60mm" height="45mm" routingDisabled>
    {/* 既定エンジンは MOSFET を解けないため ngspice を明示（Q1 を導通させるのに必須） */}
    <analogsimulation duration="50ms" timePerStep="50us" spiceEngine="ngspice" />

    {/* ── Pico W モック: 電源 ── */}
    <voltagesource name="VBUS" voltage="5V" />
    <voltagesource name="V3V3" voltage="3.3V" />

    {/* ── サーボ モック: 動作電流〜200mA 相当（5V/25Ω）。静的なのでL不要 ── */}
    <resistor name="Rservo" resistance="25" footprint="0805" />

    {/* ── 実回路の部品（index.tsx と同じ値） ── */}
    <mosfet name="Q1" channelType="n" mosfetMode="enhancement" />
    <resistor name="Rg" resistance="220" footprint="0603" />
    <resistor name="Rgs" resistance="10k" footprint="0603" />
    <capacitor name="C1" capacitance="470uF" polarized footprint="1206" />
    <capacitor name="C2" capacitance="100nF" footprint="0603" />
    <diode name="D2" footprint="sod123" />

    {/* ── 電流計（直列挿入） ── */}
    <ammeter name="A_servo" connections={{ pin1: ".Rservo .pin2", pin2: "net.SERVO_RTN" }} />

    {/* ── 電圧プローブ（ピンに接続） ── */}
    <voltageprobe name="VP_V5" connectsTo=".C1 .pin1" />
    <voltageprobe name="VP_GATE" connectsTo=".Q1 .gate" />
    <voltageprobe name="VP_RTN" connectsTo=".Q1 .drain" />

    {/* ── V5 レール ── */}
    <trace from=".VBUS .pos" to="net.V5" />
    <trace from=".C1 .pin1" to="net.V5" />
    <trace from=".Rservo .pin1" to="net.V5" />
    <trace from=".C2 .pin1" to="net.V5" />
    <trace from=".D2 .cathode" to="net.V5" />

    {/* ── GND ── */}
    <trace from=".VBUS .neg" to="net.GND" />
    <trace from=".V3V3 .neg" to="net.GND" />
    <trace from=".C1 .pin2" to="net.GND" />
    <trace from=".Q1 .source" to="net.GND" />
    <trace from=".Rgs .pin2" to="net.GND" />
    <trace from=".C2 .pin2" to="net.GND" />

    {/* ── SERVO_RTN: Q1.drain, D2.anode（電流計経由で Rservo からも） ── */}
    <trace from=".Q1 .drain" to="net.SERVO_RTN" />
    <trace from=".D2 .anode" to="net.SERVO_RTN" />

    {/* ── GP14 HIGH（ゲート駆動）: V3V3 → Rg → GATE → Q1.gate, Rgs → GND ── */}
    <trace from=".V3V3 .pos" to="net.GATE_DRV" />
    <trace from=".Rg .pin1" to="net.GATE_DRV" />
    <trace from=".Rg .pin2" to="net.GATE" />
    <trace from=".Q1 .gate" to="net.GATE" />
    <trace from=".Rgs .pin1" to="net.GATE" />
  </board>
);
```

- [ ] **Step 3: ビルドを通す**

Run: `cd tscircuit && nix develop .. -c bunx tsci build sim-full.tsx`
Expected: PASS（`Circuits 1 passed` / exit 0）。`dist/sim-full/circuit.json` 生成。
ビルドが prop/セレクタ/connections 記法でエラーになったら、Global Constraints の方針どおり
エラー文と `@tscircuit/props/dist/index.d.ts` を根拠に**記法だけ**直す。部品/モック/ネット/測定点は変えない。

- [ ] **Step 4: シミュレーション要素と落ち着き値を機械的に確認**

Run:
```bash
cd tscircuit && nix develop .. -c python3 -c '
import json
d = json.load(open("dist/sim-full/circuit.json"))
has_exp = any(e.get("type") == "simulation_experiment" for e in d)
graphs = {e["name"]: e["voltage_levels"][-1]
          for e in d if e.get("type") == "simulation_transient_voltage_graph"}
print("simulation_experiment:", has_exp)
print("settled:", {k: round(v, 3) for k, v in graphs.items()})
assert has_exp, "no simulation_experiment"
for n in ("VP_V5", "VP_GATE", "VP_RTN"):
    assert n in graphs, f"missing probe {n}"
assert 4.5 <= graphs["VP_V5"] <= 5.5, graphs["VP_V5"]
assert 3.0 <= graphs["VP_GATE"] <= 3.35, graphs["VP_GATE"]
# Q1 が導通していること（未導通なら VP_RTN が 5V に張り付く）
assert graphs["VP_RTN"] <= 2.0, graphs["VP_RTN"]
print("OK")
'
```
Expected: `simulation_experiment: True`、`VP_V5`≈5、`VP_GATE`≈3.2、末尾に `OK`。
（グラフ要素の型名やキー名が違ってエラーになったら、`dist/sim-full/circuit.json` を実際に開いて
電圧グラフの型名・値配列キーを確認し、この検証スクリプトのキー名だけ合わせる。測定対象は変えない。）

- [ ] **Step 5: Commit**

```bash
git add tscircuit/sim-full.tsx
git commit -m "feat(tscircuit): 全体シム 電源経路コア（Pico/サーボ モック＋Q1）"
```

（コミットメッセージ末尾に付ける:
`Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`）

---

### Task 2: 回路全体を完成（LED・ボタン・SIG＋赤LED電流計＋プローブ）

Task 1 の電源経路に、残りの GPIO まわり（赤/緑 LED、ボタン、サーボ SIG）と測定点を足して「回路全体」にする。

**Files:**
- Modify: `tscircuit/sim-full.tsx`（Task 1 で作成したファイルを全面的に置き換える）

**Interfaces:**
- Consumes: Task 1 の `sim-full.tsx`（VBUS/V3V3/Q1/Rg/Rgs/C1/C2/D2/Rservo/A_servo/VP_V5/VP_GATE/VP_RTN、ネット V5/GND/SERVO_RTN/GATE_DRV/GATE）
- Produces: 完成した `sim-full.tsx`（追加: Rsig/Dr/Dg/Rled/Rled2/Rpu/SW1/A_led_r/VP_LED_R、ネット LED_A_R/LED_A_G/SERVO_SIG/BTN）

- [ ] **Step 1: sim-full.tsx を完成版に置き換える**

`tscircuit/sim-full.tsx`（全体を以下で置き換え）:

```tsx
// smtlk 回路の全体シミュレーション（サーボON=解錠中 の静的動作点）。
// Pico W と SG90 サーボを電気モックに置換。DC 一定入力の過渡解析を短時間流し、
// 落ち着いた値を読む＝スナップショット（波形は平坦）。
// 実部品 Q1/D1/D2 は SPICE モデルが要るため chip ではなく mosfet/led/diode で書く。
// D1（2色LED, カソードコモン）は赤 Dr・緑 Dg の 2 個の led に分けて表現。
//
// サーボON状態の想定: GP14=HIGH(MOSFET ON), GP16=HIGH(赤点灯), GP18=LOW(緑消灯),
//   GP15=HIGH(サーボSIG), GP17=ボタン未押下。
// 期待される落ち着き値の目安（汎用デフォルト SPICE モデルのためざっくり値）:
//   VP_V5    ≈ 5V（V5 レール）
//   VP_GATE  ≈ 3.2V（3.3×10k/(220+10k)）→ Q1 ON
//   VP_RTN   ≈ 0.9V（Q1 の Vds）。※既定エンジンでは Q1 が非導通で 5V に張り付くため
//              analogsimulation で ngspice を明示している
//   VP_LED_R = 赤LEDアノード電圧
//   A_servo  ≈ 160mA（(5-0.9)/25）／ A_led_r ≈ 数 mA
// 注: 静的動作点なので D2 の還流(保護)動作は出ない（静的 ON では D2 逆バイアスで電流≈0）。
export default () => (
  <board width="60mm" height="45mm" routingDisabled>
    {/* 既定エンジンは MOSFET を解けないため ngspice を明示（Q1 を導通させるのに必須） */}
    <analogsimulation duration="50ms" timePerStep="50us" spiceEngine="ngspice" />

    {/* ── Pico W モック: 電源と GPIO ロジックレール ── */}
    <voltagesource name="VBUS" voltage="5V" />
    <voltagesource name="V3V3" voltage="3.3V" />

    {/* ── サーボ モック ── */}
    <resistor name="Rservo" resistance="25" footprint="0805" />
    {/* SIG は高インピーダンス入力。10k で GND 終端 */}
    <resistor name="Rsig" resistance="10k" footprint="0402" />

    {/* ── 実回路の部品（index.tsx と同じ値） ── */}
    <mosfet name="Q1" channelType="n" mosfetMode="enhancement" />
    <resistor name="Rg" resistance="220" footprint="0603" />
    <resistor name="Rgs" resistance="10k" footprint="0603" />
    <resistor name="Rled" resistance="330" footprint="0603" />
    <resistor name="Rled2" resistance="330" footprint="0603" />
    {/* D1（2色LED,カソードコモン）→ 赤 Dr / 緑 Dg */}
    <led name="Dr" />
    <led name="Dg" />
    <capacitor name="C1" capacitance="470uF" polarized footprint="1206" />
    <capacitor name="C2" capacitance="100nF" footprint="0603" />
    <diode name="D2" footprint="sod123" />
    {/* ボタン: 内部プルアップ Rpu(→3.3V) と SW1(未押下=開) */}
    <resistor name="Rpu" resistance="50k" footprint="0402" />
    <pushbutton name="SW1" footprint="pushbutton" />

    {/* ── 電流計（直列挿入） ── */}
    <ammeter name="A_servo" connections={{ pin1: ".Rservo .pin2", pin2: "net.SERVO_RTN" }} />
    <ammeter name="A_led_r" connections={{ pin1: ".Rled .pin2", pin2: ".Dr .anode" }} />

    {/* ── 電圧プローブ（ピンに接続） ── */}
    <voltageprobe name="VP_V5" connectsTo=".C1 .pin1" />
    <voltageprobe name="VP_GATE" connectsTo=".Q1 .gate" />
    <voltageprobe name="VP_RTN" connectsTo=".Q1 .drain" />
    <voltageprobe name="VP_LED_R" connectsTo=".Dr .anode" />

    {/* ── V5 レール ── */}
    <trace from=".VBUS .pos" to="net.V5" />
    <trace from=".C1 .pin1" to="net.V5" />
    <trace from=".Rservo .pin1" to="net.V5" />
    <trace from=".C2 .pin1" to="net.V5" />
    <trace from=".D2 .cathode" to="net.V5" />

    {/* ── GND ── */}
    <trace from=".VBUS .neg" to="net.GND" />
    <trace from=".V3V3 .neg" to="net.GND" />
    <trace from=".C1 .pin2" to="net.GND" />
    <trace from=".Q1 .source" to="net.GND" />
    <trace from=".Rgs .pin2" to="net.GND" />
    <trace from=".Dr .cathode" to="net.GND" />
    <trace from=".Dg .cathode" to="net.GND" />
    <trace from=".SW1 .pin2" to="net.GND" />
    <trace from=".C2 .pin2" to="net.GND" />
    <trace from=".Rsig .pin2" to="net.GND" />

    {/* ── SERVO_RTN: Q1.drain, D2.anode ── */}
    <trace from=".Q1 .drain" to="net.SERVO_RTN" />
    <trace from=".D2 .anode" to="net.SERVO_RTN" />

    {/* ── GP14 HIGH（ゲート駆動） ── */}
    <trace from=".V3V3 .pos" to="net.GATE_DRV" />
    <trace from=".Rg .pin1" to="net.GATE_DRV" />
    <trace from=".Rg .pin2" to="net.GATE" />
    <trace from=".Q1 .gate" to="net.GATE" />
    <trace from=".Rgs .pin1" to="net.GATE" />

    {/* ── GP16 HIGH（赤LED点灯）: V3V3 → Rled → A_led_r → Dr ── */}
    <trace from=".V3V3 .pos" to=".Rled .pin1" />
    {/* Rled.pin2 → A_led_r → Dr.anode は ammeter の connections で結線済み */}

    {/* ── GP18 LOW（緑LED消灯）: Rled2 の入口を GND に落とす ── */}
    <trace from=".Rled2 .pin1" to="net.GND" />
    <trace from=".Rled2 .pin2" to=".Dg .anode" />

    {/* ── GP15 HIGH（サーボSIG, 高抵抗終端） ── */}
    <trace from=".V3V3 .pos" to=".Rsig .pin1" />

    {/* ── GP17 ボタン: プルアップ Rpu(→V3V3) と SW1(→GND, 開) ── */}
    <trace from=".V3V3 .pos" to=".Rpu .pin1" />
    <trace from=".Rpu .pin2" to="net.BTN" />
    <trace from=".SW1 .pin1" to="net.BTN" />
  </board>
);
```

- [ ] **Step 2: ビルドを通す**

Run: `cd tscircuit && nix develop .. -c bunx tsci build sim-full.tsx`
Expected: PASS（`Circuits 1 passed` / exit 0）。
記法エラー時の対処は Task 1 Step 3 と同じ（記法のみ修正、構成は維持）。

- [ ] **Step 3: 全測定点の存在と落ち着き値を機械的に確認**

Run:
```bash
cd tscircuit && nix develop .. -c python3 -c '
import json
d = json.load(open("dist/sim-full/circuit.json"))
assert any(e.get("type") == "simulation_experiment" for e in d), "no simulation_experiment"
vgraphs = {e["name"]: e["voltage_levels"][-1]
           for e in d if e.get("type") == "simulation_transient_voltage_graph"}
print("voltage settled:", {k: round(v, 3) for k, v in vgraphs.items()})
for n in ("VP_V5", "VP_GATE", "VP_RTN", "VP_LED_R"):
    assert n in vgraphs, f"missing probe {n}"
assert 4.5 <= vgraphs["VP_V5"] <= 5.5, vgraphs["VP_V5"]
assert 3.0 <= vgraphs["VP_GATE"] <= 3.35, vgraphs["VP_GATE"]
# Q1 が導通していること（未導通なら VP_RTN が 5V に張り付く）
assert vgraphs["VP_RTN"] <= 2.0, vgraphs["VP_RTN"]
# 電流グラフ（型名は circuit.json で確認）: 2本の ammeter が要素として存在すること
cur = [e for e in d if "current" in e.get("type", "") and "graph" in e.get("type", "")]
print("current graph elements:", len(cur))
assert len(cur) >= 2, f"expected >=2 current graphs, got {len(cur)}"
print("OK")
'
```
Expected: 4 本の電圧プローブが揃い、`VP_V5`≈5・`VP_GATE`≈3.2、電流グラフ要素が 2 本以上、末尾に `OK`。
（電流グラフの型名が想定と違ってこの assert が落ちたら、`dist/sim-full/circuit.json` を開いて
ammeter 由来の要素型名を確認し、`"current" in type and "graph" in type` の判定を実際の型名に合わせる。
測定対象＝ammeter 2 本は変えない。）

- [ ] **Step 4: dev サーバーで表示確認（任意・目視）**

Run（バックグラウンド起動）: `cd tscircuit && nix develop .. -c bunx tsci dev sim-full.tsx --port 3022`
Expected: `http://172.20.1.3:3022` を LAN のブラウザで開き、Simulation タブで平坦な波形（落ち着いた動作点）が見える。確認後サーバーは停止してよい。

- [ ] **Step 5: Commit**

```bash
git add tscircuit/sim-full.tsx
git commit -m "feat(tscircuit): 全体シムを完成（LED/ボタン/SIG＋測定点）"
```

（コミットメッセージ末尾に付ける:
`Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`）

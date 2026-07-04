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
//   VP_LED_R ≈ 2.1V（赤LEDアノード = LED の順方向電圧 Vf）
//   A_servo  ≈ 160mA（(5-0.9)/25）／ A_led_r ≈ 数 mA
// 注: 静的動作点なので D2 の還流(保護)動作は出ない（静的 ON では D2 逆バイアスで電流≈0）。
// 注: simulatable 部品（Q1/Dr/Dg）は footprint を付けないと SPICE が Singular matrix で失敗するため footprint を明示している。
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
    <mosfet name="Q1" channelType="n" mosfetMode="enhancement" footprint="sot23" />
    <resistor name="Rg" resistance="220" footprint="0603" />
    <resistor name="Rgs" resistance="10k" footprint="0603" />
    <resistor name="Rled" resistance="330" footprint="0603" />
    <resistor name="Rled2" resistance="330" footprint="0603" />
    {/* D1（2色LED,カソードコモン）→ 赤 Dr / 緑 Dg */}
    <led name="Dr" footprint="0603" />
    <led name="Dg" footprint="0603" />
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
    <trace from=".VBUS .pin1" to="net.V5" />
    <trace from=".C1 .pin1" to="net.V5" />
    <trace from=".Rservo .pin1" to="net.V5" />
    <trace from=".C2 .pin1" to="net.V5" />
    <trace from=".D2 .cathode" to="net.V5" />

    {/* ── GND ── */}
    <trace from=".VBUS .pin2" to="net.GND" />
    <trace from=".V3V3 .pin2" to="net.GND" />
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
    <trace from=".V3V3 .pin1" to="net.GATE_DRV" />
    <trace from=".Rg .pin1" to="net.GATE_DRV" />
    <trace from=".Rg .pin2" to="net.GATE" />
    <trace from=".Q1 .gate" to="net.GATE" />
    <trace from=".Rgs .pin1" to="net.GATE" />

    {/* ── GP16 HIGH（赤LED点灯）: V3V3 → Rled → A_led_r → Dr ── */}
    <trace from=".V3V3 .pin1" to=".Rled .pin1" />
    {/* Rled.pin2 → A_led_r → Dr.anode は ammeter の connections で結線済み */}

    {/* ── GP18 LOW（緑LED消灯）: Rled2 の入口を GND に落とす ── */}
    <trace from=".Rled2 .pin1" to="net.GND" />
    <trace from=".Rled2 .pin2" to=".Dg .anode" />

    {/* ── GP15 HIGH（サーボSIG, 高抵抗終端） ── */}
    <trace from=".V3V3 .pin1" to=".Rsig .pin1" />

    {/* ── GP17 ボタン: プルアップ Rpu(→V3V3) と SW1(→GND, 開) ── */}
    <trace from=".V3V3 .pin1" to=".Rpu .pin1" />
    <trace from=".Rpu .pin2" to="net.BTN" />
    <trace from=".SW1 .pin1" to="net.BTN" />
  </board>
);

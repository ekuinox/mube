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
    <mosfet name="Q1" channelType="n" mosfetMode="enhancement" footprint="sot23" />
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
    <trace from=".C2 .pin2" to="net.GND" />

    {/* ── SERVO_RTN: Q1.drain, D2.anode（電流計経由で Rservo からも） ── */}
    <trace from=".Q1 .drain" to="net.SERVO_RTN" />
    <trace from=".D2 .anode" to="net.SERVO_RTN" />

    {/* ── GP14 HIGH（ゲート駆動）: V3V3 → Rg → GATE → Q1.gate, Rgs → GND ── */}
    <trace from=".V3V3 .pin1" to="net.GATE_DRV" />
    <trace from=".Rg .pin1" to="net.GATE_DRV" />
    <trace from=".Rg .pin2" to="net.GATE" />
    <trace from=".Q1 .gate" to="net.GATE" />
    <trace from=".Rgs .pin1" to="net.GATE" />
  </board>
);

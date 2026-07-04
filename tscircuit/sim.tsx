// シミュレーションお試し: Q1 ゲート駆動部の RC 応答デモ。
// GP14 の 3.3V 矩形波が Rg 220Ω を通って Q1 のゲートを充電する様子を、
// ゲート容量を Cg 10nF（IRLB3813 の Ciss 相当のオーダー）で代用して過渡解析する。
// Rg / Rgs の値は circuit/netlist.py と同じ。
//
// sim-full.tsx（回路全体の静的動作点。波形は平坦）と対で、こちらは動く波形が見える
// 単体デモ。MOSFET を含まない純 RC なので既定 SPICE エンジンで正しく解ける
// （sim-full.tsx が ngspice を必要としたのは MOSFET のため）。
export default () => (
  <board width="30mm" height="20mm" routingDisabled>
    <analogsimulation duration="100us" timePerStep="100ns" />

    {/* VG: GP14 の代わりの 3.3V 矩形波（50kHz） */}
    <voltagesource
      name="VG"
      waveShape="square"
      voltage="3.3V"
      frequency="50kHz"
    />
    <resistor name="Rg" resistance="220" footprint="0603" />
    <resistor name="Rgs" resistance="10k" footprint="0603" />
    {/* Cg: Q1 のゲート容量の代用 */}
    <capacitor name="Cg" capacitance="10nF" footprint="0603" />

    <trace from=".VG .pos" to=".Rg .pin1" />
    <trace from=".Rg .pin2" to="net.GATE" />
    <trace from=".Rgs .pin1" to="net.GATE" />
    <trace from=".Cg .pin1" to="net.GATE" />
    <trace from=".VG .neg" to="net.GND" />
    <trace from=".Rgs .pin2" to="net.GND" />
    <trace from=".Cg .pin2" to="net.GND" />

    {/* GATE ノード（= Cg.pin1）の電圧をグラフ表示 */}
    <voltageprobe name="VP_GATE" connectsTo=".Cg .pin1" />
  </board>
);

// smtlk 回路の tscircuit 版。circuit/netlist.py と同じ部品・ネット・GPIO 割当。
// ネット V5 は netlist.py の +5V に対応（tscircuit のネット名に "+" が使えないため）。
export default () => (
  <board width="60mm" height="45mm" routingDisabled>
    {/* U1: Raspberry Pi Pico W — 使用ピンのみのヘッダ代用 */}
    <chip
      name="U1"
      footprint="pinrow7"
      pinLabels={{
        pin1: "VBUS",
        pin2: "GND",
        pin3: "GP15", // servo
        pin4: "GP14", // gate
        pin5: "GP16", // led_r
        pin6: "GP18", // led_g
        pin7: "GP17", // btn
      }}
    />
    {/* M1: SG90 サーボ（3 線コネクタとして表現） */}
    {/* pin2 VPLUS は netlist.py の M1.V+ に対応（tscircuit のピン名に "+" が使えないため） */}
    <chip
      name="M1"
      footprint="pinrow3"
      pinLabels={{ pin1: "SIG", pin2: "VPLUS", pin3: "GND" }}
    />
    {/* Q1: N-ch MOSFET IRLB3813PBF（ローサイドで SERVO_RTN をゲート） */}
    <chip
      name="Q1"
      footprint="pinrow3"
      pinLabels={{ pin1: "G", pin2: "D", pin3: "S" }}
    />
    <resistor name="Rg" resistance="220" footprint="0603" />
    <resistor name="Rgs" resistance="10k" footprint="0603" />
    <resistor name="Rled" resistance="330" footprint="0603" />
    <resistor name="Rled2" resistance="330" footprint="0603" />
    {/* D1: 2 色 LED OSRGHC5B32A（R/YG カソードコモン） */}
    <chip
      name="D1"
      footprint="pinrow3"
      pinLabels={{ pin1: "R", pin2: "G", pin3: "K" }}
    />
    <pushbutton name="SW1" footprint="pushbutton" />
    <capacitor name="C1" capacitance="470uF" polarized footprint="1206" />
    <capacitor name="C2" capacitance="100nF" footprint="0603" />
    {/* D2: ショットキー 1N5819（+5V → SERVO_RTN の還流） */}
    <diode name="D2" footprint="sod123" />

    {/* +5V (= netlist.py の +5V) */}
    <trace from=".U1 .VBUS" to="net.V5" />
    <trace from=".C1 .pin1" to="net.V5" />
    <trace from=".M1 .VPLUS" to="net.V5" />
    <trace from=".C2 .pin1" to="net.V5" />
    <trace from=".D2 .cathode" to="net.V5" />
    {/* GND */}
    <trace from=".U1 .GND" to="net.GND" />
    <trace from=".C1 .pin2" to="net.GND" />
    <trace from=".Q1 .S" to="net.GND" />
    <trace from=".Rgs .pin2" to="net.GND" />
    <trace from=".D1 .K" to="net.GND" />
    <trace from=".SW1 .pin2" to="net.GND" />
    <trace from=".C2 .pin2" to="net.GND" />
    {/* SERVO_RTN */}
    <trace from=".M1 .GND" to="net.SERVO_RTN" />
    <trace from=".Q1 .D" to="net.SERVO_RTN" />
    <trace from=".D2 .anode" to="net.SERVO_RTN" />
    {/* SERVO_SIG */}
    <trace from=".U1 .GP15" to="net.SERVO_SIG" />
    <trace from=".M1 .SIG" to="net.SERVO_SIG" />
    {/* GATE_DRV / GATE */}
    <trace from=".U1 .GP14" to="net.GATE_DRV" />
    <trace from=".Rg .pin1" to="net.GATE_DRV" />
    <trace from=".Rg .pin2" to="net.GATE" />
    <trace from=".Q1 .G" to="net.GATE" />
    <trace from=".Rgs .pin1" to="net.GATE" />
    {/* LED */}
    <trace from=".U1 .GP16" to="net.LED_DRV_R" />
    <trace from=".Rled .pin1" to="net.LED_DRV_R" />
    <trace from=".Rled .pin2" to="net.LED_A_R" />
    <trace from=".D1 .R" to="net.LED_A_R" />
    <trace from=".U1 .GP18" to="net.LED_DRV_G" />
    <trace from=".Rled2 .pin1" to="net.LED_DRV_G" />
    <trace from=".Rled2 .pin2" to="net.LED_A_G" />
    <trace from=".D1 .G" to="net.LED_A_G" />
    {/* BTN */}
    <trace from=".U1 .GP17" to="net.BTN" />
    <trace from=".SW1 .pin1" to="net.BTN" />
  </board>
);

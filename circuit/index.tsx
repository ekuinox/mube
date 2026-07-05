// smtlk 回路の tscircuit 版（本番配線・唯一の正）。部品・ネット・GPIO 割当を定義する。
// ネット V5 は電源 +5V に対応（tscircuit のネット名に "+" が使えないため V5 表記）。
export default () => (
  <board width="60mm" height="45mm" routingDisabled>
    {/* schX/schY で schematic レイアウトを明示し、自動配置の密集・ネットラベル重なりを回避する。
        結線（trace）は不変。左半分＝電源/サーボ/ゲート、右半分＝LED/ボタン、U1 を中央ハブに配置。 */}
    {/* U1: Raspberry Pi Pico W — 使用ピンのみのヘッダ代用 */}
    <chip
      name="U1"
      footprint="pinrow7"
      schX={0}
      schY={0}
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
    {/* pin2 VPLUS は電源 +（サーボの V+）。tscircuit のピン名に "+" が使えないため VPLUS 表記 */}
    <chip
      name="M1"
      footprint="pinrow3"
      schX={-6}
      schY={3}
      pinLabels={{ pin1: "SIG", pin2: "VPLUS", pin3: "GND" }}
    />
    {/* Q1: N-ch MOSFET IRLB3813PBF（ローサイドで SERVO_RTN をゲート） */}
    <chip
      name="Q1"
      footprint="pinrow3"
      schX={-8}
      schY={-5}
      pinLabels={{ pin1: "G", pin2: "D", pin3: "S" }}
    />
    <resistor name="Rg" resistance="220" footprint="0603" schX={-4} schY={-5} />
    <resistor name="Rgs" resistance="10k" footprint="0603" schX={-6} schY={-6} schRotation={90} />
    <resistor name="Rled" resistance="330" footprint="0603" schX={4} schY={2} />
    <resistor name="Rled2" resistance="330" footprint="0603" schX={4} schY={-2} />
    {/* D1: 2 色 LED OSRGHC5B32A（R/YG カソードコモン） */}
    <chip
      name="D1"
      footprint="pinrow3"
      schX={8}
      schY={0}
      pinLabels={{ pin1: "R", pin2: "G", pin3: "K" }}
    />
    <pushbutton name="SW1" footprint="pushbutton" schX={5} schY={-6} />
    {/* C1: pin1=+（V5 側）, pin2=-（GND 側）。極性あり電解コンデンサ（バルク） */}
    <capacitor name="C1" capacitance="470uF" polarized footprint="1206" schX={-4} schY={5} schRotation={90} />
    <capacitor name="C2" capacitance="100nF" footprint="0603" schX={-7} schY={5} schRotation={90} />
    {/* D2: ショットキー 1N5819（SERVO_RTN → +5V の還流。サーボ電源カット時の逆起電力を逃がす） */}
    <diode name="D2" footprint="sod123" schX={-1} schY={5} schRotation={90} />

    {/* +5V レール（ネット名は V5） */}
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

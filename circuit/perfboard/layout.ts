// circuit/perfboard/layout.ts
// 利用者が編集する唯一のファイル。at=[x,y] は各部品の 1 番ピン(先頭ピン)の穴（左上原点）。
// U1(Pico) は pico.ts が固定配置するのでここには書かない。
// 実基板は O25（x=0..14=A..O / y=0..24=1..25）で四隅は使用不可。Pico GP0=E4、x=4,11 の列(y=3..22)を占有。
//
// GPIO 再配置後のゾーン分け:
//  - LED/ボタン = 左（GP2=E7 / GP3=E8 / GP5=E10）。抵抗 Rled/Rled2 は LED のすぐ左。
//  - サーボ = 右（SERVO_SIG=GP16=L23 / GATE_DRV=GP17=L22、コネクタ M1 は右端 O 列）。駆動部 Q1/Rg/Rgs/D2 は右へ。
//  - インターフェース3点 D1/SW1/M1 は筐体都合で固定。
import type { XY } from "./board"

export type Place = { at: XY; rot: 0 | 90 | 180 | 270 }

export const PLACEMENT: Record<string, Place> = {
  // 電源デカップリング（右上・VBUS(11,3) の近く）
  C1: { at: [12, 3], rot: 0 },   // 470uF pin1(+)=M4 / pin2=N4
  C2: { at: [12, 5], rot: 0 },   // 100nF M6/N6

  // LED 抵抗（Pico の外＝左マージン x=2,3 に縦置き。GP2/GP5 と LED をつなぐ）
  Rled:  { at: [3, 5], rot: 90 },  // LED_DRV_R=D6(→GP2) ↔ LED_A_R=D9(→D1.R)
  Rled2: { at: [2, 5], rot: 90 },  // LED_DRV_G=C6(→GP5) ↔ LED_A_G=C9(→D1.G)

  // サーボ駆動（右ゾーン）。抵抗は右マージン x=12 に縦置き（行15〜22）で M1/Q1/D2 の密集を回避。
  Rg:  { at: [12, 14], rot: 90 }, // GATE_DRV=M15(→GP17) ↔ GATE=M18
  Rgs: { at: [14, 14], rot: 90 }, // GATE=O15 ↔ GND=O18（列O 縦置き）
  Q1:  { at: [11, 23], rot: 0 },  // G=L24 / D=M24 / S=N24（M1 の隣）
  D2:  { at: [13, 20], rot: 90 }, // フライバック cathode=N21 / anode=N23（M1 の隣）
  // サーボコネクタ M1（固定・右端 O 列）: GND=O22 / VPLUS(VBUS)=O23 / SIG=O24
  M1:  { at: [14, 23], rot: 270 },

  // インターフェース（固定）
  D1:  { at: [7, 6], rot: 0 },   // 二色LED G=H7 / K=I7 / R=J7
  SW1: { at: [7, 9], rot: 0 },   // タクト pin1=H10 / pin2=J13（対角）
}

// GND 落とし先の明示指定（部品ピン → Pico の GND 物理ピン番号）。
// 指定が無い GND 端点は従来どおり MST。Pico の GND ピンは内部で全て導通している。
export const GND_ASSIGN: Record<string, number> = {
  "D1.K": 3,      // LED コモンカソード → GP1,GP2 間の GND(pin3=E6)
  "SW1.pin2": 8,  // タクト GND → GP5,GP6 間の GND(pin8=E11)
  "C1.pin2": 38,  // コンデンサ GND → VSYS(pin39) の下の GND(pin38=L6)
  "C2.pin2": 38,  // 同上
}

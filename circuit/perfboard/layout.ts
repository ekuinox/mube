// circuit/perfboard/layout.ts
// 利用者が編集する唯一のファイル。at=[x,y] は各部品の 1 番ピン(先頭ピン)の穴（左上原点）。
// U1(Pico) は pico.ts が固定配置するのでここには書かない。
// 実基板は O25（x=0..14=A..O / y=0..24=1..25）で四隅は使用不可。Pico GP0=D3、x=3,10 の列(y=2..21)を占有。
//
// GPIO 再配置後のゾーン分け:
//  - LED/ボタン = 左（LED 赤=GP2=D6 / LED 黄緑=GP3=D7 / ボタン=GP5=D9）。抵抗 Rled/Rled2 は Pico の外＝左マージン。
//  - サーボ = 右（SERVO_SIG=GP16=K22 / GATE_DRV=GP17=K21、コネクタ M1 は右端 O 列）。駆動部 Q1/Rg/Rgs/D2 は右へ。
//  - インターフェース3点 D1/SW1/M1 は筐体都合で固定（D1=G6/H6/I6, SW1=G9/I12, M1=O21/O22/O23）。
import type { XY } from "./board"

export type Place = { at: XY; rot: 0 | 90 | 180 | 270 }

export const PLACEMENT: Record<string, Place> = {
  // 電源デカップリング（右上・VBUS(10,2) の近く）
  C1: { at: [11, 2], rot: 0 },   // 470uF pin1(+)=L3 / pin2=M3
  C2: { at: [11, 4], rot: 0 },   // 100nF L5/M5

  // LED 抵抗（Pico の外＝左マージン x=1,2 に縦置き。GP2/GP5 と LED をつなぐ）
  Rled:  { at: [2, 4], rot: 90 },  // LED_DRV_R=C5(→GP2) ↔ LED_A_R=C8(→D1.R)
  Rled2: { at: [1, 4], rot: 90 },  // LED_DRV_G=B5(→GP3) ↔ LED_A_G=B8(→D1.G)

  // サーボ駆動（右ゾーン）。抵抗は右マージン縦置きで M1/Q1/D2 の密集を回避。
  Rg:  { at: [11, 13], rot: 90 }, // GATE_DRV=L14(→GP17) ↔ GATE=L17
  Rgs: { at: [13, 13], rot: 90 }, // GATE=N14 ↔ GND=N17（列N 縦置き）
  Q1:  { at: [10, 22], rot: 0 },  // G=K23 / D=L23 / S=M23（M1 の隣）
  D2:  { at: [12, 19], rot: 90 }, // フライバック cathode=M20 / anode=M22（M1 の隣）
  // サーボコネクタ M1（固定・右端 O 列）: GND=O21 / VPLUS(VBUS)=O22 / SIG=O23
  M1:  { at: [14, 22], rot: 270 },

  // インターフェース（固定）
  D1:  { at: [6, 5], rot: 0 },   // 二色LED G=G6 / K=H6 / R=I6
  SW1: { at: [6, 8], rot: 0 },   // タクト pin1=G9 / pin2=I12（対角）
}

// GND 落とし先の明示指定（部品ピン → Pico の GND 物理ピン番号）。
// 指定が無い GND 端点は従来どおり MST。Pico の GND ピンは内部で全て導通している。
export const GND_ASSIGN: Record<string, number> = {
  "D1.K": 3,      // LED コモンカソード → GP1,GP2 間の GND(pin3=D5)
  "SW1.pin2": 8,  // タクト GND → GP5,GP6 間の GND(pin8=D10)
  "C1.pin2": 38,  // コンデンサ GND → VSYS(pin39) の下の GND(pin38=K5)
  "C2.pin2": 38,  // 同上
}

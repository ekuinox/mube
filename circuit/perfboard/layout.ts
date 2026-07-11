// circuit/perfboard/layout.ts
// 利用者が編集する唯一のファイル。at=[x,y] は各部品の 1 番ピン(先頭ピン)の穴（左上原点）。
// U1(Pico) は pico.ts が固定配置するのでここには書かない。
// 実基板は O25（x=0..14=A..O / y=0..24=1..25）で四隅は使用不可。
// Pico GP0=E4 に移動したのに合わせ、全指定を +1,+1 した（Pico は x=4,11 の列 y=3..22 を占有）。
import type { XY } from "./board"

export type Place = { at: XY; rot: 0 | 90 | 180 | 270 }

export const PLACEMENT: Record<string, Place> = {
  // 電源デカップリング（右マージン上・VBUS(11,3) の近く）
  C1: { at: [12, 3], rot: 0 },   // 470uF  pin1(+),pin2
  C2: { at: [12, 5], rot: 0 },   // 100nF

  // サーボ駆動
  Rg:  { at: [1, 17], rot: 90 },  // GATE_DRV↔GATE   (1,17)-(1,20)
  Rgs: { at: [3, 17], rot: 90 },  // GATE↔GND        (3,17)-(3,20)
  Q1:  { at: [5, 23], rot: 0 },   // G,D,S
  D2:  { at: [2, 24], rot: 0 },   // フライバック cathode,anode
  // サーボコネクタ M1: 右端 O 列。x は +1 できない(P 列は無い)ので O 固定・縦のみ +1。
  // GND=O22 / VPLUS(VBUS)=O23 / SIG=O24
  M1:  { at: [14, 23], rot: 270 },

  // LED/ボタン（利用者指定を +1,+1）
  Rled:  { at: [8, 23], rot: 0 },  // (8,23)-(11,23)
  Rled2: { at: [8, 24], rot: 0 },  // (8,24)-(11,24)
  D1:    { at: [7, 6], rot: 0 },   // G=H7 / K=I7 / R=J7
  SW1:   { at: [7, 9], rot: 0 },   // pin1=H10 / pin2=J13（対角）
}

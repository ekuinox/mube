// circuit/perfboard/layout.ts
// 利用者が編集する唯一のファイル。at=[x,y] は各部品の 1 番ピンの穴（左上原点）。
// U1(Pico) は pico.ts が固定配置するのでここには書かない。
import type { XY } from "./board"

export type Place = { at: XY; rot: 0 | 90 | 180 | 270 }

export const PLACEMENT: Record<string, Place> = {
  // 電源まわり（Pico 左の x=1,2 と下段）
  C1: { at: [1, 24], rot: 0 },   // 470uF  pin1(+),pin2
  C2: { at: [1, 26], rot: 0 },   // 100nF
  D2: { at: [4, 27], rot: 0 },   // フライバック cathode,anode
  // サーボ駆動（下段 x=4..8）
  M1: { at: [4, 23], rot: 0 },   // SIG,VPLUS,GND
  Q1: { at: [4, 25], rot: 0 },   // G,D,S
  Rg: { at: [8, 23], rot: 0 },   // GATE_DRV↔GATE
  Rgs: { at: [8, 25], rot: 0 },  // GATE↔GND
  // LED/ボタン（Pico 右 x=11..17）
  Rled: { at: [12, 20], rot: 0 },
  Rled2: { at: [12, 18], rot: 0 },
  D1: { at: [15, 22], rot: 0 },  // R,G,K
  SW1: { at: [13, 25], rot: 0 }, // pin1,pin2
}

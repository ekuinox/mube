// circuit/perfboard/layout.ts
// 基板上のどの穴に何を置くかだけを持つ。繋がっているかどうかはここでは主張しない。
// 検証は verify.ts の仕事。設計書は docs/superpowers/specs/2026-08-23-perfboard-wiring-design.md。
//
// 方位は室内側からドアを正面に見た向き。行 P が +Y（上）端、行 A が −Y（下）端、
// 列 1 が +X（右）端。ピン列は 1〜20 番が行 L、21〜40 番が行 E。
//
// 穴の割り当てはこのファイルが最終的な正。設計書（決定 2 の表）は mm 単位のおおまかな
// 配置意図であり、部品同士が近すぎて表の区画がそのまま同じ穴に重なることがある
// （例: M1 と D2）。表とここがずれる場合はここを信用すること。
//
// `insulated: true` を付けたワイヤは被覆線で引くこと。C1/C2/M1 まわりは部品が密集していて
// 裏面の裸のすずめっき線同士が別ネットの上を通ったり交差したりする箇所があり、verify.ts の
// 近接・交差検査がそれを検出する。配置は測寸前で動かせないので、そこだけは短絡しない被覆線に
// 逃がす。詳細は各ワイヤのコメントを参照。

import type { Layout } from "./verify"

export const LAYOUT: Layout = {
  legs: {
    // +Y（上）側: 表示と入力
    "D1.R": "O12",
    "D1.K": "O13",
    "D1.G": "O14",
    "Rled.pin1": "M12",
    "Rled.pin2": "N12",
    "Rled2.pin1": "M14",
    "Rled2.pin2": "N14",
    "SW1.pin1": "N7",
    "SW1.pin2": "N8",

    // −Y（下）側: 動力と電源
    // RC サーボの慣例で電源は 3 本の真ん中に置く。両端（SIG と GND）のどちらかに
    // 挿し違えても、逆挿しでは真ん中の V+ が信号線にも GND にもならないので
    // GP22 に 5V が乗ることがない。SG90 のケーブルは茶 = GND, 赤 = V+, 橙 = SIG の
    // 物理順で、V+ を端に置くと逆挿しで GP22 に 5V が直結し得た。
    "M1.SIG": "A11",
    "M1.VPLUS": "A12",
    "M1.GND": "A13",
    "D2.cathode": "B13",
    "D2.anode": "B14",
    "Q1.S": "C13",
    "Q1.D": "C14",
    "Q1.G": "C15",
    "Rg.pin1": "D16",
    "Rg.pin2": "C16",
    "Rgs.pin1": "C17",
    "Rgs.pin2": "D17",
    "C1.pin1": "B4",
    "C1.pin2": "B6",
    "C2.pin1": "C4",
    "C2.pin2": "C6",
  },
  wires: [
    // LED（+Y 側）。K は 13 番ピン（GND）の列へ真下に落ちる。
    { from: "L12", to: "M12", net: "LED_DRV_R", side: "solder" },
    { from: "N12", to: "O12", net: "LED_A_R", side: "solder" },
    { from: "L14", to: "M14", net: "LED_DRV_G", side: "solder" },
    { from: "N14", to: "O14", net: "LED_A_G", side: "solder" },
    { from: "O13", to: "L13", net: "GND", side: "solder" },

    // スイッチ（+Y 側）。2 本とも真下の 7 番と 8 番へ。
    { from: "N7", to: "L7", net: "BTN", side: "solder" },
    { from: "N8", to: "L8", net: "GND", side: "solder" },

    // サーボ信号とゲート駆動（−Y 側）
    { from: "A11", to: "E12", net: "SERVO_SIG", side: "solder" },
    { from: "E15", to: "D16", net: "GATE_DRV", side: "solder" },
    { from: "C16", to: "C15", net: "GATE", side: "solder" },
    { from: "C17", to: "C16", net: "GATE", side: "solder" },
    { from: "D17", to: "E18", net: "GND", side: "solder" },

    // サーボのリターン。Q1.D とサーボ GND と D2 のアノードで閉じる短いループ。
    { from: "C14", to: "B14", net: "SERVO_RTN", side: "solder" },
    { from: "B14", to: "A13", net: "SERVO_RTN", side: "solder" },

    // 5V。VBUS からバルクコンを経てサーボへ。
    { from: "E1", to: "B4", net: "V5", side: "solder" },
    { from: "B4", to: "C4", net: "V5", side: "solder" },
    // C1/C2/M1/Q1 が密集する区画を斜めに横切る長い区間。GND の複数本や SERVO_SIG と
    // 交差・近接するため被覆線で引く（0.56mm しか離れない箇所がある）。
    { from: "C4", to: "B13", net: "V5", side: "solder", insulated: true },
    { from: "B13", to: "A12", net: "V5", side: "solder" },

    // GND。Q1.S はバルクコンの負極へ直接返し、サーボのリターンを Pico の内部プレーン
    // だけに頼らせない。38 番ピンとバルクコンを繋ぐことで USB からの帰り道も閉じる。
    { from: "E3", to: "B6", net: "GND", side: "solder" },
    { from: "B6", to: "C6", net: "GND", side: "solder" },
    // 列 6 から列 13 まで長く斜めに這い、SERVO_SIG（A11→E12）と交差する。被覆線で引く。
    { from: "B6", to: "C13", net: "GND", side: "solder", insulated: true },
    { from: "C13", to: "E13", net: "GND", side: "solder" },
  ],
}

// circuit/perfboard/board.ts
// ユニバーサル基板 P-03229（72×47mm, 片面めっき）の穴グリッド。
// ランドは独立なので、このモデルは導通を一切持たない。繋がるのはワイヤだけ。
//
// 方位は室内側からドアを正面に見た向き。
// 列は +X（右）端を 1 として −X（左）へ、行は −Y（下）端を 1（A）として +Y（上）へ数える。

export const COLS = 25
export const ROWS = 15 // 実測（2026-08-24）。行は A〜O で、P 行は存在しない
export const PITCH = 2.54

export type Hole = { col: number; row: number }

const CENTER_COL = (COLS + 1) / 2
const CENTER_ROW = (ROWS + 1) / 2

// ソケットの 2 列は 7 ピッチ離れる。行数が奇数なので中心対称には置けず、
// Pico はグリッド中心から半ピッチ（1.27mm）+Y（上）へ寄って載る。
// 設計時は 16 行（偶数）と仮定して ±8.89 に置くつもりだったが、実測で 15 行と判明した。
/** 21〜40 番のピン列（−Y（下）側）。y = −7.62mm。 */
export const PIN_ROW_LOW = 5
/** 1〜20 番のピン列（+Y（上）側）。y = +10.16mm。 */
export const PIN_ROW_HIGH = 12

export function holeId(h: Hole): string {
  return `${String.fromCharCode(64 + h.row)}${h.col}`
}

export function parseHole(id: string): Hole {
  const m = /^([A-Z])(\d+)$/.exec(id)
  if (!m) throw new Error(`bad hole id: ${id}`)
  return { row: m[1].charCodeAt(0) - 64, col: Number(m[2]) }
}

/** 基板ローカル座標（原点は基板中心、単位 mm）。 */
export function holeXY(h: Hole): { x: number; y: number } {
  return { x: (CENTER_COL - h.col) * PITCH, y: (h.row - CENTER_ROW) * PITCH }
}

/** Pico ヘッダのピン番号 → 穴。pin1 を 1 列目に置き、+X（右）端へ寄せる。 */
export function pinHole(pin: number): Hole {
  if (!Number.isInteger(pin) || pin < 1 || pin > 40) throw new Error(`bad pin: ${pin}`)
  return pin <= 20
    ? { col: pin, row: PIN_ROW_HIGH }
    : { col: 41 - pin, row: PIN_ROW_LOW }
}

/**
 * Pico の GND ピン。基板内部で同一ノードなので、検証では 1 つに束ねる。
 * 33 番は AGND で、アナロググランドとして分けてあるため含めない。
 */
export const PICO_GND_PINS = [3, 8, 13, 18, 23, 28, 38]

/** parts.ts の U1 pinLabels → ヘッダピン番号。 */
export const PICO_PIN_OF_LABEL: Record<string, number> = {
  VBUS: 40,
  GND: 38,
  GP5: 7,
  GP9: 12,
  GP10: 14,
  GP20: 26,
  GP22: 29,
}

// circuit/perfboard/board.ts
// ユニバーサル基板の格子モデル。左上原点 (0,0)、x=横(右+)、y=縦(下+)。
export type XY = [number, number]

export const BOARD = { width: 18, height: 28 }   // x: 0..17, y: 0..27（実基板の穴数で確定）
export const PICO_ANCHOR: XY = [3, 2]            // Pico GP0(物理ピン1)。利用者実測
export const PICO_ROW_SPAN_HOLES = 7             // Pico 2ピン列の x 間隔（実測一致）

export function inBounds([x, y]: XY): boolean {
  return x >= 0 && x < BOARD.width && y >= 0 && y < BOARD.height
}

export function key([x, y]: XY): string {
  return `${x},${y}`
}

// 部品ローカルオフセットを時計回りに回す（y 下向き画面座標）
export function rotate([dx, dy]: XY, rot: 0 | 90 | 180 | 270): XY {
  switch (rot) {
    case 0: return [dx, dy]
    case 90: return [(-dy) || 0, dx]
    case 180: return [(-dx) || 0, (-dy) || 0]
    case 270: return [dy, (-dx) || 0]
  }
}

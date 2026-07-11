// circuit/perfboard/board.ts
// ユニバーサル基板の格子モデル。左上原点 (0,0)、x=横(右+)、y=縦(下+)。
export type XY = [number, number]

export const BOARD = { width: 15, height: 25 }   // x: 0..14(A..O), y: 0..24(1..25)。実基板 O25
export const PICO_ANCHOR: XY = [3, 2]            // Pico GP0(物理ピン1)=D3。利用者実測
export const PICO_ROW_SPAN_HOLES = 7             // Pico 2ピン列の x 間隔（実測一致）

// 四隅の穴は使用不可（別基板への固定に使うため実際には穴が塞がっている）
export const UNUSABLE_HOLES: XY[] = [
  [0, 0], [BOARD.width - 1, 0], [0, BOARD.height - 1], [BOARD.width - 1, BOARD.height - 1],
]
export function isUnusable([x, y]: XY): boolean {
  return UNUSABLE_HOLES.some(([ux, uy]) => ux === x && uy === y)
}

export function inBounds([x, y]: XY): boolean {
  return x >= 0 && x < BOARD.width && y >= 0 && y < BOARD.height
}

export function key([x, y]: XY): string {
  return `${x},${y}`
}

// 部品ローカルオフセットを時計回りに回す（y 下向き画面座標）
// z(): -0 を 0 に正規化（toEqual([0,x]) などのテスト等値比較で -0 !== 0 になるのを防ぐ）
const z = (n: number) => (n === 0 ? 0 : n)
export function rotate([dx, dy]: XY, rot: 0 | 90 | 180 | 270): XY {
  switch (rot) {
    case 0: return [dx, dy]
    case 90: return [z(-dy), dx]
    case 180: return [z(-dx), z(-dy)]
    case 270: return [dy, z(-dx)]
  }
}

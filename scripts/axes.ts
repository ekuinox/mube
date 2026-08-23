// scripts/axes.ts
// 方位の正。ドアを室内側から正面に見たときの向きで書く。
// 根拠は enclosure/models/params.scad の 2 行:
//   clear_left = 50;  // -X to door edge/frame  → −X はドア枠側 ＝ 左
//   clear_down = 65;  // -Y to door handle      → −Y はハンドル側 ＝ 下
// レバーハンドルはサムターンの下にあるので −Y が下になる。

export const VIEWPOINT = "室内側から"

export const AXIS_LABELS: Record<string, string> = {
  "+X": "右",
  "-X": "左",
  "+Y": "上",
  "-Y": "下",
  "+Z": "手前",
  "-Z": "奥",
  "±X": "左右",
  "±Y": "上下",
  "±Z": "前後",
}

/** 全角マイナス（U+2212）を ASCII ハイフンへ寄せる。文書側の表記ゆれを吸収する。 */
export function normaliseAxis(axis: string): string {
  return axis.replace(/−/g, "-")
}

export function axisLabel(axis: string): string {
  const label = AXIS_LABELS[normaliseAxis(axis)]
  if (!label) throw new Error(`unknown axis: ${axis}`)
  return label
}

/** 文書と図で使う併記の形。例: axisWithLabel("+X") === "+X（右）" */
export function axisWithLabel(axis: string): string {
  return `${axis}（${axisLabel(axis)}）`
}

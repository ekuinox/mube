// circuit/breadboard/config.ts
import type { Rail, StripRow } from "./model"

// ネット名 → レール。これらは配置コストから除外され、各ピン→レールの短スタブで配線される。
export const RAIL_NETS: Record<string, Rail> = { V5: "TP", GND: "TN" }

// 配置コスト重み。可読性(span,cross)を厚め、幅を薄く。実測で調整可。
export const WEIGHTS = { span: 3, cross: 5, edge: 2, width: 1 }

// 信号ジャンパの水平レーン（上段のみ。列タイ U<col> を共有するため下段は使えない）。
export const SIGNAL_LANES: StripRow[] = ["c", "d", "e"]
// 電源/GNDレールスタブが使う上段の行。
export const RAIL_STUB_ROW: StripRow = "b"

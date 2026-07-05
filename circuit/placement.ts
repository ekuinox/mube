// circuit/placement.ts
// 物理版(board.tsx)の手保守データ：基板グリッド座標(mm, 原点=中心)・向き・実物フットプリント。
// 対象: 秋月Cタイプ 72x47mm・2.54mmピッチ。ピッチ表記は footprinter 文法に合わせ Task5 で確定。
export const PLACEMENT: Record<
  string,
  { pcbX: number; pcbY: number; pcbRotation?: number; footprint: string }
> = {
  // 中央ハブ：使用7ピンのヘッダとして表現（実機は2x20モジュール。ガイド上は使用ピン列）。
  U1: { pcbX: 0, pcbY: 0, footprint: "pinrow7" },
  // 左側：電源・サーボ・ゲート
  M1: { pcbX: -25, pcbY: 12, footprint: "pinrow3" },        // サーボ3線ヘッダ
  Q1: { pcbX: -25, pcbY: -8, footprint: "to220_3" },        // TO-220 3ピン。footprinter は _ 区切り（ハイフンは "to" として解釈されエラー）
  Rg: { pcbX: -12, pcbY: -8, footprint: "axial_p7.62mm" },  // 1/4W カーボン抵抗
  Rgs: { pcbX: -12, pcbY: -14, pcbRotation: 90, footprint: "axial_p7.62mm" },
  C1: { pcbX: -8, pcbY: 14, footprint: "radial_p2.5_d6.3" }, // 470uF16V 電解
  C2: { pcbX: -19, pcbY: 4, footprint: "radial_p5.08" },    // 100nF 5mmピッチ（M1/C1との courtyard 重なり回避のため移動）
  D2: { pcbX: -2, pcbY: 14, pcbRotation: 90, footprint: "axial_p7.62mm" }, // 1N5819 DO-41
  // 右側：LED・ボタン
  Rled: { pcbX: 14, pcbY: 6, footprint: "axial_p7.62mm" },
  Rled2: { pcbX: 14, pcbY: -6, footprint: "axial_p7.62mm" },
  D1: { pcbX: 26, pcbY: 0, footprint: "pinrow3" },           // 5mm 2色LED 3リード
  SW1: { pcbX: 18, pcbY: -14, footprint: "pushbutton" },
}

// circuit/schematic-layout.ts
// 回路図(index.tsx)専用の配置とSMD仮フットプリント。物理配置とは無関係。
export const SCH_LAYOUT: Record<
  string,
  { schX: number; schY: number; schRotation?: number; footprint: string }
> = {
  U1: { schX: 0, schY: 0, footprint: "pinrow7" },
  M1: { schX: -6, schY: 3, footprint: "pinrow3" },
  Q1: { schX: -8, schY: -5, footprint: "pinrow3" },
  Rg: { schX: -4, schY: -5, footprint: "0603" },
  Rgs: { schX: -6, schY: -6, schRotation: 90, footprint: "0603" },
  Rled: { schX: 4, schY: 2, footprint: "0603" },
  Rled2: { schX: 4, schY: -2, footprint: "0603" },
  D1: { schX: 8, schY: 0, footprint: "pinrow3" },
  SW1: { schX: 5, schY: -6, footprint: "pushbutton" },
  C1: { schX: -4, schY: 5, schRotation: 90, footprint: "1206" },
  C2: { schX: -7, schY: 5, schRotation: 90, footprint: "0603" },
  D2: { schX: -1, schY: 5, schRotation: 90, footprint: "sod123" },
}

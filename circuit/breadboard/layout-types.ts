// circuit/breadboard/layout-types.ts
import type { Hole, Jumper } from "./model"

export interface Placement {
  order: string[]                          // 左→右の部品順
  cols: number                             // 使用した総列数
  partColumns: Record<string, number[]>    // ref → 占有列
  pinHoles: Record<string, Hole>           // "Ref.pin" → Hole(row a)
}

export interface RouteResult {
  jumpers: Jumper[]
  stats: { crossings: number; tracksUsed: number }
}

export interface ComponentMeta {
  label: string
  value?: string
  pins: string[]           // "Ref.pin" list（描画で束ねる）
  polarityPin?: string     // "+" を描くピン（"Ref.pin"）
  stripePin?: string       // カソード帯を描くピン（"Ref.pin"）
}

export interface BreadboardLayout {
  pinHoles: Record<string, Hole>
  jumpers: Jumper[]
  components: Record<string, ComponentMeta>
  notes: string[]
  stats: { crossings: number; tracksUsed: number; cols: number }
}

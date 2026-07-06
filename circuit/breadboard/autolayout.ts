// circuit/breadboard/autolayout.ts
import type { BreadboardLayout, ComponentMeta } from "./layout-types"
import { subcircuitNets } from "./subcircuit"
import { placeParts, usedPinsByPart } from "./place"
import { routeNets } from "./route"
import { verifyLayout } from "./verify"
import { FOOTPRINTS } from "./footprints"

export function autoLayout(refs: string[], seed = 1): BreadboardLayout {
  const nets = subcircuitNets(new Set(refs))
  const pl = placeParts(refs, nets, seed)
  const { jumpers, stats } = routeNets(pl, nets)

  // 実行時ゲート: 電気検証（端点2未満のネットは nets に含まれないので全ネット検査可）
  const errors = verifyLayout(nets, pl.pinHoles, jumpers)
  if (errors.length) throw new Error("autoLayout verification failed:\n" + errors.join("\n"))

  // components メタ（描画用）: 使用ピンのみ、footprint の描画ヒントを反映
  const used = usedPinsByPart(refs, nets)
  const components: Record<string, ComponentMeta> = {}
  for (const ref of refs) {
    const fp = FOOTPRINTS[ref]
    const pins = used[ref].map((p) => `${ref}.${p}`)
    if (pins.length === 0) continue
    components[ref] = {
      label: fp?.label ?? ref,
      value: fp?.value,
      pins,
      polarityPin: fp?.polarityPin ? `${ref}.${fp.polarityPin}` : undefined,
      stripePin: fp?.stripePin ? `${ref}.${fp.stripePin}` : undefined,
    }
  }

  const notes = [
    "電源/GNDはレール。信号は c/d/e レーン。",
    "極性・カソード帯・部品向きは実物で確認。",
    `交差 ${stats.crossings} / lane ${stats.tracksUsed} 使用。`,
  ]

  return { pinHoles: pl.pinHoles, jumpers, components, notes, stats: { ...stats, cols: pl.cols } }
}

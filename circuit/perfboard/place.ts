// circuit/perfboard/place.ts
// PLACEMENT(手置き)＋Pico(固定)を解決し "Ref.pin"→XY を得る。盤外・穴重複・未解決を検証。
import { inBounds, key, rotate, type XY } from "./board"
import { picoPinXY, picoSignalXY, PICO_PIN_NUMBER } from "./pico"
import { FOOTPRINTS } from "./footprints"
import { PLACEMENT, type Place } from "./layout"
import { NETS } from "../parts"

export interface Placement {
  pinXY: Record<string, XY>
  occupied: Set<string>
  errors: string[]
}

// tscircuit セレクタ ".U1 .VBUS" → "U1.VBUS"
export function normEndpoint(ep: string): string {
  return ep.replace(/\./g, " ").trim().split(/\s+/).join(".")
}

export function resolvePlacement(placement: Record<string, Place> = PLACEMENT): Placement {
  const pinXY: Record<string, XY> = {}
  const occupied = new Set<string>()
  const errors: string[] = []

  // 1) Pico: 全40ピンを占有として登録、使用7信号を pinXY へ
  for (let p = 1; p <= 40; p++) occupied.add(key(picoPinXY(p)))
  for (const sig of Object.keys(PICO_PIN_NUMBER)) pinXY[`U1.${sig}`] = picoSignalXY(sig)

  // 2) 手置き部品
  for (const [ref, pl] of Object.entries(placement)) {
    const fp = FOOTPRINTS[ref]
    if (!fp) { errors.push(`フットプリント未定義: ${ref}`); continue }
    for (const pin of fp.pins) {
      const [rx, ry] = rotate(pin.off, pl.rot)
      const xy: XY = [pl.at[0] + rx, pl.at[1] + ry]
      const k = key(xy)
      if (!inBounds(xy)) errors.push(`盤外: ${ref}.${pin.name} @ [${xy}]`)
      if (occupied.has(k)) errors.push(`重複: ${ref}.${pin.name} が使用済み穴 [${xy}] と衝突`)
      occupied.add(k)
      pinXY[`${ref}.${pin.name}`] = xy
    }
  }

  // 3) 全ネット endpoint が解決するか
  for (const net of NETS) {
    for (const ep of net.endpoints) {
      const n = normEndpoint(ep)
      if (!pinXY[n]) errors.push(`未解決ネット端点: ${net.name} の ${n}`)
    }
  }

  return { pinXY, occupied, errors }
}

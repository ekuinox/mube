// circuit/render-parts.tsx
// PARTS/NETS を JSX へ変換する共有ヘルパ。配置系プロップは placementFor(ref) で注入する。
import type { PartSpec } from "./parts"
import { NETS } from "./parts"

export function renderParts(parts: PartSpec[], placementFor: (ref: string) => Record<string, any>) {
  return parts.map((p) => {
    const extra = placementFor(p.ref)
    // key は spread せず直接渡す（React 19 は spread 経由の key を警告する）
    const common = { name: p.ref, ...extra }
    switch (p.kind) {
      case "chip":
        return <chip key={p.ref} {...common} pinLabels={p.pinLabels} />
      case "resistor":
        return <resistor key={p.ref} {...common} resistance={p.props!.resistance} />
      case "capacitor":
        return <capacitor key={p.ref} {...common} capacitance={p.props!.capacitance} polarized={!!p.props?.polarized} />
      case "diode":
        return <diode key={p.ref} {...common} />
      case "pushbutton":
        return <pushbutton key={p.ref} {...common} />
    }
  })
}

export function renderTraces() {
  return NETS.flatMap((net) =>
    net.endpoints.map((ep, i) => <trace key={`${net.name}-${i}`} from={ep} to={`net.${net.name}`} />),
  )
}

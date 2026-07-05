// circuit/render-parts.tsx
// PARTS/NETS を JSX へ変換する共有ヘルパ。配置系プロップは placementFor(ref) で注入する。
import type { PartSpec } from "./parts"
import { NETS } from "./parts"

export function renderParts(parts: PartSpec[], placementFor: (ref: string) => Record<string, any>) {
  return parts.map((p) => {
    const extra = placementFor(p.ref)
    const common = { key: p.ref, name: p.ref, ...extra }
    switch (p.kind) {
      case "chip":
        return <chip {...common} pinLabels={p.pinLabels} />
      case "resistor":
        return <resistor {...common} resistance={p.props!.resistance} />
      case "capacitor":
        return <capacitor {...common} capacitance={p.props!.capacitance} polarized={!!p.props?.polarized} />
      case "diode":
        return <diode {...common} />
      case "pushbutton":
        return <pushbutton {...common} />
    }
  })
}

export function renderTraces() {
  return NETS.flatMap((net) =>
    net.endpoints.map((ep, i) => <trace key={`${net.name}-${i}`} from={ep} to={`net.${net.name}`} />),
  )
}

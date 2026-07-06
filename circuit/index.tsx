// circuit/index.tsx
// smtlk 回路の正（回路図＝schematic）。部品・結線は parts.ts、回路図レイアウトは schematic-layout.ts。
import { PARTS } from "./parts"
import { SCH_LAYOUT } from "./schematic-layout"
import { renderParts, renderTraces } from "./render-parts"

export default () => (
  <board width="60mm" height="45mm" routingDisabled>
    {renderParts(PARTS, (ref) => {
      const l = SCH_LAYOUT[ref]
      return { footprint: l.footprint, schX: l.schX, schY: l.schY, ...(l.schRotation ? { schRotation: l.schRotation } : {}) }
    })}
    {renderTraces()}
  </board>
)

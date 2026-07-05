// circuit/board.tsx
// 物理版 board（実装ガイド用）。結線は parts.ts と共有し、フットプリント/配置は placement.ts。
import { RootCircuit } from "tscircuit"
import { PARTS } from "./parts"
import { PLACEMENT } from "./placement"
import { renderParts, renderTraces } from "./render-parts"

export default function PhysicalBoard() {
  return (
    <board width="72mm" height="47mm" routingDisabled>
      {renderParts(PARTS, (ref) => {
        const p = PLACEMENT[ref]
        return { footprint: p.footprint, pcbX: p.pcbX, pcbY: p.pcbY, ...(p.pcbRotation ? { pcbRotation: p.pcbRotation } : {}) }
      })}
      {renderTraces()}
    </board>
  )
}

export async function buildBoardCircuitJson(): Promise<any[]> {
  const circuit = new RootCircuit()
  circuit.add(<PhysicalBoard />)
  await circuit.renderUntilSettled()
  return circuit.getCircuitJson() as any[]
}

// 回路の導通・ショート ERC。circuit JSON を入力に取り、エラー文字列の配列を返す純関数。
// 空配列＝合格。RootCircuit 描画やファイル I/O は含まない（host で単体テスト可能）。
// 判定は各 source_port / source_net が持つ subcircuit_connectivity_map_key
// （電気的に繋がったポート・ネットが共有する接続グループのキー）で行う。
export const REQUIRED_NETS = ["V5", "GND", "SERVO_RTN"] as const

type Element = { type: string; [k: string]: any }

export function runErc(circuitJson: Element[]): string[] {
  const errors: string[] = []

  const compName: Record<string, string> = {}
  for (const e of circuitJson) {
    if (e.type === "source_component") compName[e.source_component_id] = e.name
  }
  const ports = circuitJson.filter((e) => e.type === "source_port")
  const nets = circuitJson.filter((e) => e.type === "source_net")

  // 接続キーごとにポートとネットをまとめる
  type Group = { ports: string[]; nets: string[] }
  const groups = new Map<string, Group>()
  const group = (key: string): Group => {
    let g = groups.get(key)
    if (!g) groups.set(key, (g = { ports: [], nets: [] }))
    return g
  }
  for (const p of ports) {
    const label = `${compName[p.source_component_id] ?? p.source_component_id}.${p.name}`
    group(p.subcircuit_connectivity_map_key ?? p.source_port_id).ports.push(label)
  }
  for (const n of nets) {
    group(n.subcircuit_connectivity_map_key ?? n.source_net_id).nets.push(n.name)
  }

  // ショート: 1 グループに異なる名前付きネットが 2 つ以上
  for (const g of groups.values()) {
    const uniq = [...new Set(g.nets)]
    if (uniq.length >= 2) {
      errors.push(`short: nets ${uniq.sort().join(", ")} are connected together`)
    }
  }

  // 浮きピン: 単独（1 ポートかつネット無し）のグループ
  for (const g of groups.values()) {
    if (g.nets.length === 0 && g.ports.length === 1) {
      errors.push(`${g.ports[0]} is not connected to any net`)
    }
  }

  // 孤立ネット: 名前付きネットのグループにポートが 2 未満
  for (const n of nets) {
    const g = group(n.subcircuit_connectivity_map_key ?? n.source_net_id)
    if (g.ports.length < 2) {
      errors.push(`net ${n.name} has fewer than 2 endpoints`)
    }
  }

  // 必須ネット
  const names = new Set(nets.map((n) => n.name))
  for (const r of REQUIRED_NETS) {
    if (!names.has(r)) errors.push(`required net ${r} is missing`)
  }

  return errors
}

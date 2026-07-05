// 回路の導通・ショート ERC。circuit JSON を入力に取り、エラー文字列の配列を返す純関数。
// 空配列＝合格。RootCircuit 描画やファイル I/O は含まない（host で単体テスト可能）。
// 判定は各 source_port / source_net が持つ subcircuit_connectivity_map_key
// （電気的に繋がったポート・ネットが共有する接続グループのキー）で行う。
// キーを持たない source_port は「どこにも繋がっていない」ピン（未接続）。
export const REQUIRED_NETS = ["V5", "GND", "SERVO_RTN"] as const

type Element = { type: string; [k: string]: any }

export interface ErcOptions {
  // 意図的に未接続でよいピン（"Comp.pin" 形式）。フットプリント上の未使用パッド等。
  allowUnconnected?: string[]
}

export function runErc(circuitJson: Element[], options: ErcOptions = {}): string[] {
  const errors: string[] = []
  const allowUnconnected = new Set(options.allowUnconnected ?? [])

  const compName: Record<string, string> = {}
  for (const e of circuitJson) {
    if (e.type === "source_component") compName[e.source_component_id] = e.name
  }
  const ports = circuitJson.filter((e) => e.type === "source_port")
  const nets = circuitJson.filter((e) => e.type === "source_net")
  const label = (p: Element) => `${compName[p.source_component_id] ?? p.source_component_id}.${p.name}`

  // 浮きピン: 接続キーを持たない（＝どこにも繋がっていない）ポート。
  // ただし allowUnconnected に挙げたピンは意図的な未接続として除外。
  // 注: trace セレクタの書き間違い等で結線が解決されない場合も対象ピンがキー無しになるため、
  //     未解決結線の検出はこの浮きピン判定に集約している（tscircuit の *_error/*_warning は個別に見ない）。
  for (const p of ports) {
    if (p.subcircuit_connectivity_map_key == null && !allowUnconnected.has(label(p))) {
      errors.push(`${label(p)} is not connected to any net`)
    }
  }

  // 接続キーごとにポートとネットをまとめる（キーを持つ要素のみ）
  type Group = { ports: string[]; nets: string[] }
  const groups = new Map<string, Group>()
  const group = (key: string): Group => {
    let g = groups.get(key)
    if (!g) groups.set(key, (g = { ports: [], nets: [] }))
    return g
  }
  for (const p of ports) {
    if (p.subcircuit_connectivity_map_key != null) {
      group(p.subcircuit_connectivity_map_key).ports.push(label(p))
    }
  }
  for (const n of nets) {
    if (n.subcircuit_connectivity_map_key != null) {
      group(n.subcircuit_connectivity_map_key).nets.push(n.name)
    }
  }

  // ショート: 1 グループに異なる名前付きネットが 2 つ以上
  for (const g of groups.values()) {
    const uniq = [...new Set(g.nets)]
    if (uniq.length >= 2) {
      errors.push(`short: nets ${uniq.sort().join(", ")} are connected together`)
    }
  }

  // 孤立ネット: 名前付きネットのグループにポートが 2 未満（キー無しネットは 0 端点扱い）。
  // 端点数はネットの属する接続グループ単位で数える。本番配線は 1 グループ 1 ネットなので
  // ネット単位の端点数と一致する（複数ネットが 1 グループに同居する状態はショート側で検出）。
  for (const n of nets) {
    const key = n.subcircuit_connectivity_map_key
    const count = key == null ? 0 : group(key).ports.length
    if (count < 2) {
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

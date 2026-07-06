// circuit/breadboard/model.ts
// Standard solderless breadboard connectivity model.

export const COLS = 30

export type StripRow = "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j"
export type Rail = "TP" | "TN" | "BP" | "BN"

// Upper block: rows a-e, Lower block: rows f-j
// Center gap between e and f — upper and lower of the same column are NOT connected.
const UPPER_ROWS: StripRow[] = ["a", "b", "c", "d", "e"]
const LOWER_ROWS: StripRow[] = ["f", "g", "h", "i", "j"]

export type Hole =
  | { kind: "strip"; col: number; row: StripRow }
  | { kind: "rail"; rail: Rail; col: number }

/**
 * Returns the electrical node id for a hole.
 * - Strip upper (a-e): "U<col>"
 * - Strip lower (f-j): "L<col>"
 * - Rail: the rail name (TP, TN, BP, BN)
 */
export function nodeOf(hole: Hole): string {
  if (hole.kind === "rail") return hole.rail
  if (UPPER_ROWS.includes(hole.row)) return `U${hole.col}`
  return `L${hole.col}`
}

export type Jumper = { from: Hole; to: Hole; net?: string; color?: string }

// --- Union-Find ---
class UnionFind {
  private parent: Map<string, string> = new Map()

  private root(x: string): string {
    if (!this.parent.has(x)) this.parent.set(x, x)
    const p = this.parent.get(x)!
    if (p === x) return x
    const r = this.root(p)
    this.parent.set(x, r)
    return r
  }

  union(a: string, b: string): void {
    const ra = this.root(a)
    const rb = this.root(b)
    if (ra !== rb) this.parent.set(ra, rb)
  }

  groupOf(node: string): string {
    return this.root(node)
  }
}

/**
 * Builds the connectivity fabric from a list of jumpers.
 * Returns an object with groupOf(node) that maps a node id to its
 * union-find group representative.
 *
 * Column-tie nodes (U<col> and L<col>) are pre-registered but not
 * cross-tied — they form separate groups unless a jumper bridges them.
 * Rail nodes (TP, TN, BP, BN) each start as their own group.
 * Components are LOADS: their pins do NOT union nodes.
 * Only jumpers create connectivity.
 */
export function buildConnectivity(jumpers: Jumper[]): { groupOf(node: string): string } {
  const uf = new UnionFind()

  // Pre-register all column nodes and rail nodes so they exist even if no jumper touches them.
  for (let col = 1; col <= COLS; col++) {
    uf.groupOf(`U${col}`)
    uf.groupOf(`L${col}`)
  }
  for (const rail of ["TP", "TN", "BP", "BN"] as Rail[]) {
    uf.groupOf(rail)
  }

  // Union jumper endpoints
  for (const j of jumpers) {
    uf.union(nodeOf(j.from), nodeOf(j.to))
  }

  return { groupOf: (node: string) => uf.groupOf(node) }
}

# circuit を tscircuit ERC へ移行 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 回路の正を `circuit/netlist.py`（Python）から `circuit/index.tsx`（tscircuit）へ移し、導通・ショートを pass/fail 判定する静的 ERC を `./test/erc.sh` で回せるようにする。

**Architecture:** `circuit/index.tsx` の本番配線を `@tscircuit/core` の `RootCircuit` で circuit JSON に描画し、各 `source_port` / `source_net` が持つ `subcircuit_connectivity_map_key`（接続グループのキー）でグループ化して ERC を判定する。判定ロジックは純関数 `runErc(circuitJson)` に隔離して host で単体テストし、描画・CLI は別ファイルに置く。生成物（from-to / bom）は廃止。

**Tech Stack:** TypeScript / tscircuit（`@tscircuit/core` 経由の RootCircuit） / bun（テストランナー・実行系） / Nix dev シェル（bun を供給）

## Global Constraints

- ネット名は `index.tsx` 現行ラベルに従う。`+5V` は tscircuit で `+` が使えないため `V5`。
- 必須ネットは `V5` / `GND` / `SERVO_RTN`（旧 netlist.py の REQUIRED と一致）。
- `_warning` 型の circuit JSON 要素（`source_unnamed_trace_warning`, `source_pin_missing_trace_warning`, `source_no_power_pin_defined_warning` 等）は ERC の失敗条件にしない。良性ノイズであり、特に pushbutton の余りパッド `SW1.pin3` / `SW1.pin4` が `source_pin_missing_trace_warning` を出すため。
- 浮きピンは「接続キー（`subcircuit_connectivity_map_key`）を持たない `source_port`＝未接続」として検出する。意図的に未接続でよいピンは `runErc` の `allowUnconnected` で除外し、本番の `SW1.pin3`/`pin4` は盤を知る `netlist.tsx` から渡す。（実装中に確定した挙動。当初 Task 2/3 に記した「1 ポートかつネット無しのグループ」判定・「pin3/pin4 は 2 ポートで繋がる」前提は実測で誤りと判明したため、本項が優先。実際のコミット済みコードは commit 7c21a0c を参照。）
- `.sh` ラッパーは既存 `build.sh` / `test/render.sh` と同じく自分で Nix dev シェルへ再突入する。
- `uv` は `viewer/serve.py` が使うため flake からは外さない。
- `circuit/node_modules/` は非コミット（`bun.lock` のみコミット）。
- コミットメッセージ末尾に `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` を付ける。

---

### Task 1: ディレクトリを circuit/ に集約し、旧資産を削除する

`tscircuit/` の中身を `circuit/` へ移し、Python netlist・SPICE デモ・空になった `tscircuit/` を消す。`circuit/index.tsx` の内容（結線）は変更しない。

**Files:**
- Delete: `circuit/netlist.py`, `test/netlist_test.py`, `tscircuit/sim.tsx`, `tscircuit/sim-full.tsx`
- Move: `tscircuit/index.tsx` → `circuit/index.tsx`, `tscircuit/bun.lock` → `circuit/bun.lock`
- Modify(Move+edit): `tscircuit/package.json` → `circuit/package.json`
- Modify: `.gitignore:18`

**Interfaces:**
- Produces: `circuit/index.tsx` が `export default` で本番配線コンポーネントを提供（既存のまま。`import Board from "./index"` で読める）。`circuit/package.json` に `check` / `test` スクリプト。

- [ ] **Step 1: ファイルを移動・削除する**

```bash
cd /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl
git rm circuit/netlist.py test/netlist_test.py tscircuit/sim.tsx tscircuit/sim-full.tsx
git mv tscircuit/index.tsx circuit/index.tsx
git mv tscircuit/bun.lock circuit/bun.lock
git mv tscircuit/package.json circuit/package.json
rm -rf tscircuit   # 残った node_modules（非追跡）ごと空ディレクトリを除去
```

- [ ] **Step 2: `.gitignore` の node_modules パスを更新する**

`.gitignore:18` を編集:

```
# 変更前
tscircuit/node_modules/
# 変更後
circuit/node_modules/
```

- [ ] **Step 3: `circuit/package.json` を書き換える**

`circuit/package.json` の全文を以下にする（name を変更し、`check` / `test` スクリプトを追加。`dev` / `build` は回路図ビューア用に残す）:

```json
{
  "name": "smtlk-circuit",
  "private": true,
  "scripts": {
    "check": "bun netlist.tsx",
    "test": "bun test",
    "dev": "tsci dev",
    "build": "tsci build"
  },
  "devDependencies": {
    "@tscircuit/cli": "latest",
    "tscircuit": "latest"
  }
}
```

- [ ] **Step 4: 依存をインストールして本番配線が読めることを確認する**

Run:
```bash
cd /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl/circuit
nix develop /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl -c bash -c 'bun install --frozen-lockfile && bun -e "import(\"./index\").then(m => console.log(typeof m.default))"'
```
Expected: `bun install` が成功し、最終行に `function` が出る（`circuit/index.tsx` が移動先で import 可能）。

- [ ] **Step 5: 旧資産が消えていることを確認する**

Run:
```bash
cd /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl
ls circuit/netlist.py test/netlist_test.py tscircuit 2>&1
```
Expected: 3 つとも `No such file or directory`。

- [ ] **Step 6: コミット**

```bash
cd /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl
git add -A
git commit -m "refactor(circuit): tscircuit を circuit/ に集約し netlist.py と SPICE デモを削除

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: ERC 純関数 `runErc` を TDD で実装する

circuit JSON を入力に取り、導通・ショートのエラー文字列配列を返す純関数を作る。描画も I/O も持たないので host で高速に単体テストできる。

**Files:**
- Create: `circuit/erc.ts`
- Test: `circuit/erc.test.ts`

**Interfaces:**
- Produces:
  - `export const REQUIRED_NETS: readonly string[]`（`["V5","GND","SERVO_RTN"]`）
  - `export function runErc(circuitJson: any[]): string[]` — 空配列＝合格。circuit JSON の `source_component` / `source_port` / `source_net` 要素を読み、`subcircuit_connectivity_map_key` でグループ化して判定する。

- [ ] **Step 1: 失敗するテストを書く**

`circuit/erc.test.ts` を作成:

```ts
import { expect, test } from "bun:test"
import { runErc } from "./erc"

// テスト用に circuit JSON 断片を組む小さなヘルパ
const comp = (id: string, name: string) => ({
  type: "source_component", source_component_id: id, name,
})
const port = (id: string, comp: string, name: string, key: string) => ({
  type: "source_port", source_port_id: id, source_component_id: comp, name,
  subcircuit_connectivity_map_key: key,
})
const net = (id: string, name: string, key: string) => ({
  type: "source_net", source_net_id: id, name, subcircuit_connectivity_map_key: key,
})

// 必須ネット 3 本・各 2 端点・ショート無しの最小健全回路
const good = () => [
  comp("c0", "U1"), comp("c1", "M1"), comp("c2", "Q1"),
  net("n0", "V5", "k0"), port("p0", "c0", "VBUS", "k0"), port("p1", "c1", "VPLUS", "k0"),
  net("n1", "GND", "k1"), port("p2", "c0", "GND", "k1"), port("p3", "c2", "S", "k1"),
  net("n2", "SERVO_RTN", "k2"), port("p4", "c1", "GND", "k2"), port("p5", "c2", "D", "k2"),
]

test("健全な回路はエラー 0", () => {
  expect(runErc(good())).toEqual([])
})

test("浮きピン（単独ポート）を検出", () => {
  const cj = [...good(), port("p6", "c2", "G", "k_float")]
  expect(runErc(cj).some((e) => e.includes("Q1.G is not connected"))).toBe(true)
})

test("孤立ネット（端点 1 つ）を検出", () => {
  const cj = [...good(), net("n3", "BTN", "k3"), port("p6", "c0", "GP17", "k3")]
  expect(runErc(cj).some((e) => e.includes("net BTN has fewer than 2 endpoints"))).toBe(true)
})

test("ショート（1 グループに 2 ネット）を検出", () => {
  // GND を V5 と同じ接続キー k0 に同居させる
  const cj = good().map((e) =>
    e.type === "source_net" && e.name === "GND"
      ? { ...e, subcircuit_connectivity_map_key: "k0" }
      : e,
  )
  const errs = runErc(cj)
  expect(errs.some((e) => e.includes("short") && e.includes("V5") && e.includes("GND"))).toBe(true)
})

test("必須ネット欠落を検出", () => {
  const cj = good().filter((e) => !(e.type === "source_net" && e.name === "SERVO_RTN"))
  expect(runErc(cj).some((e) => e.includes("required net SERVO_RTN is missing"))).toBe(true)
})
```

- [ ] **Step 2: テストが失敗することを確認する**

Run:
```bash
cd /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl/circuit
nix develop /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl -c bun test erc.test.ts
```
Expected: FAIL（`Cannot find module './erc'` または `runErc is not a function`）。

- [ ] **Step 3: `runErc` を実装する**

`circuit/erc.ts` を作成:

```ts
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
```

- [ ] **Step 4: テストが通ることを確認する**

Run:
```bash
cd /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl/circuit
nix develop /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl -c bun test erc.test.ts
```
Expected: PASS（5 pass, 0 fail）。

- [ ] **Step 5: コミット**

```bash
cd /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl
git add circuit/erc.ts circuit/erc.test.ts
git commit -m "feat(circuit): 導通・ショート ERC 純関数 runErc を追加

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: 本番配線を描画する CLI と統合テスト・実行ラッパーを追加する

`index.tsx` を circuit JSON に描画して `runErc` に通す CLI（`netlist.tsx`）と、本番回路が ERC を通ることを確かめる統合テスト、`./test/erc.sh` を作る。

**Files:**
- Create: `circuit/netlist.tsx`, `circuit/netlist.test.tsx`, `test/erc.sh`

**Interfaces:**
- Consumes: `circuit/index.tsx` の `export default` Board、`circuit/erc.ts` の `runErc`。
- Produces:
  - `circuit/netlist.tsx` — `export async function buildCircuitJson(): Promise<any[]>`（Board を描画して circuit JSON を返す）＋ `import.meta.main` 時に ERC を回して違反で exit 1 する CLI。
  - `test/erc.sh` — Nix 再突入 → `bun install` → `bun test` を回す実行ラッパー。

- [ ] **Step 1: 失敗する統合テストを書く**

`circuit/netlist.test.tsx` を作成:

```tsx
import { expect, test } from "bun:test"
import { buildCircuitJson } from "./netlist"
import { runErc } from "./erc"

test("本番回路 (index.tsx) が ERC を通る", async () => {
  const cj = await buildCircuitJson()
  expect(runErc(cj)).toEqual([])
}, 30_000)
```

- [ ] **Step 2: テストが失敗することを確認する**

Run:
```bash
cd /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl/circuit
nix develop /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl -c bun test netlist.test.tsx
```
Expected: FAIL（`Cannot find module './netlist'`）。

- [ ] **Step 3: `netlist.tsx` を実装する**

`circuit/netlist.tsx` を作成:

```tsx
import { RootCircuit } from "tscircuit"
import Board from "./index"
import { runErc } from "./erc"

// index.tsx の本番配線を circuit JSON へ描画する。
export async function buildCircuitJson(): Promise<any[]> {
  const circuit = new RootCircuit()
  circuit.add(<Board />)
  await circuit.renderUntilSettled()
  return circuit.getCircuitJson() as any[]
}

// 直接実行時は ERC を回し、違反があれば exit 1。
if (import.meta.main) {
  const errors = runErc(await buildCircuitJson())
  if (errors.length) {
    for (const e of errors) console.error(`ERC: ${e}`)
    process.exit(1)
  }
  console.log("ERC passed: 導通 OK / ショート無し")
}
```

- [ ] **Step 4: 統合テストが通ることを確認する**

Run:
```bash
cd /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl/circuit
nix develop /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl -c bun test netlist.test.tsx
```
Expected: PASS（1 pass）。描画時に stderr へ `MultiOffsetIrlsSolver ran out of iterations` 等のレイアウト警告が出るが無害。

- [ ] **Step 5: `test/erc.sh` を作成する**

`test/erc.sh` を作成:

```bash
#!/usr/bin/env bash
# 回路の導通・ショート ERC を bun test で回す。bun が無ければ Nix dev シェルへ再突入。
set -uo pipefail
if ! command -v bun >/dev/null 2>&1; then
  command -v nix >/dev/null 2>&1 || export PATH="/nix/var/nix/profiles/default/bin:$PATH"
  exec nix develop "$(cd "$(dirname "$0")/.." && pwd)" -c "$0" "$@"
fi
cd "$(dirname "$0")/../circuit"
bun install --frozen-lockfile
bun test
```

実行権限を付与:
```bash
chmod +x /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl/test/erc.sh
```

- [ ] **Step 6: ラッパー経由で全テストが通ることを確認する**

Run:
```bash
cd /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl
./test/erc.sh
```
Expected: `bun install` 後に `bun test` が全ケース PASS（erc.test.ts の 5 件 ＋ netlist.test.tsx の 1 件 = 6 pass, 0 fail）。

- [ ] **Step 7: CLI 直接実行の pass 出力を確認する**

Run:
```bash
cd /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl/circuit
nix develop /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl -c bun run check; echo "exit=$?"
```
Expected: `ERC passed: 導通 OK / ショート無し` と `exit=0`。

- [ ] **Step 8: コミット**

```bash
cd /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl
git add circuit/netlist.tsx circuit/netlist.test.tsx test/erc.sh
git commit -m "feat(circuit): 本番配線を描画する ERC CLI と erc.sh を追加

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: build.sh とドキュメントの参照を更新する

netlist.py への参照を除去し、ERC のコマンドに差し替える。

**Files:**
- Modify: `build.sh`, `README.md`, `CLAUDE.md`

**Interfaces:**
- Consumes: `./test/erc.sh`（Task 3）。

- [ ] **Step 1: `build.sh` から netlist 生成ステップを削除する**

`build.sh` 末尾の以下 3 行（`done` の後のブロック）を:

```bash
echo "== generating netlist (from-to / bom) =="
uv run --script circuit/netlist.py || { echo "FAIL: netlist"; exit 1; }
echo "All parts + netlist built to build/"
```

次の 1 行に置き換える:

```bash
echo "All parts built to build/"
```

- [ ] **Step 2: `README.md` を更新する**

以下の各行を置換する:

- `README.md:4` — `回路（Python netlist）` を `回路（tscircuit / TS）` に。
- `README.md:14` の表の回路行を:
  ```
  | 回路 | `circuit/` | tscircuit で回路を記述し導通・ショート ERC で検証 | ファームと同じ GPIO 割り当て |
  ```
- `README.md:29` — 列挙から `/ \`./test/netlist_test.py\`` を削除（`erc.sh` は自分で nix に再突入するため `nix develop -c` 対象ではない）。変更後:
  ```
  素の `cargo` / `uv` / `openscad` は `nix develop -c <cmd>` 経由で実行する。
  ```
- `README.md:33` — `| 筐体ビルド（STL + netlist を build/ へ） | \`./build.sh\` |` を `| 筐体ビルド（STL を build/ へ） | \`./build.sh\` |` に。
- `README.md:37` — `| 回路ネットリストテスト | \`nix develop -c ./test/netlist_test.py\` |` を `| 回路 ERC（導通・ショート） | \`./test/erc.sh\` |` に。
- `README.md:64-72`（`## 回路（ネットリスト as code）` 節の全体）を以下に置換:

```
## 回路（tscircuit / TS）

    ./test/erc.sh

本番の配線を `circuit/index.tsx` に tscircuit（回路 as code）で記述し、`circuit/erc.ts` の
導通・ショート ERC で検証する。ERC は circuit JSON の接続グループを解析し、浮きピン・
ショート（電源レール等の意図しない橋絡み）・必須ネット（V5 / GND / SERVO_RTN）欠落・
孤立ネットを検出する。GPIO 番号は `index.tsx` の pinLabels に集約し、ファームの割り当て
（GP15/14/16/18/17）と一致させている。ERC は静的チェックで生成物は無い（旧 from-to.md /
bom.md は廃止）。テストは `./test/erc.sh`（bun test）。
```

- [ ] **Step 3: `CLAUDE.md` を更新する**

- リポジトリ地図の 2 行を 1 行にまとめる。以下 2 行:
  ```
  - `circuit/` — 回路ネットリスト（Python: ERC ライト + from-to/bom 生成）
  ```
  および
  ```
  - `tscircuit/` — 回路 as code の tscircuit お試し（bun 管理。`circuit/` の netlist.py と同構成）
  ```
  を、次の 1 行に置換:
  ```
  - `circuit/` — 回路（tscircuit / TS: 導通・ショート ERC。bun 管理）
  ```
- コマンド落とし穴の記述: `- 素の \`cargo\` / \`uv\` / \`openscad\` / \`./test/netlist_test.py\` は **\`nix develop -c <cmd>\`** 経由で実行する。` から ` / \`./test/netlist_test.py\`` を削除:
  ```
  - 素の `cargo` / `uv` / `openscad` は **`nix develop -c <cmd>`** 経由で実行する。
  ```
- コマンド表の `| 回路ネットリストテスト | \`nix develop -c ./test/netlist_test.py\` |` を:
  ```
  | 回路 ERC（導通・ショート） | `./test/erc.sh` |
  ```

- [ ] **Step 4: netlist.py への参照が残っていないことを確認する**

Run:
```bash
cd /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl
grep -rn "netlist.py\|netlist_test\|from-to\|bom.md" README.md CLAUDE.md build.sh
```
Expected: 出力なし（docs/ 配下の歴史的な spec/plan は対象外なので変更しない）。

- [ ] **Step 5: build.sh が STL のみで通ることを確認する**

Run:
```bash
cd /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl
./build.sh 2>&1 | tail -3
```
Expected: 全パート `NoError` で最終行が `All parts built to build/`。`netlist` に触れる行が無い。

- [ ] **Step 6: コミット**

```bash
cd /home/ekuinox/.paseo/worktrees/06yr52ln/short-owl
git add build.sh README.md CLAUDE.md
git commit -m "docs: 回路の参照を netlist.py から tscircuit ERC へ更新

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 最終確認

- [ ] `./test/erc.sh` が 6 件 PASS（erc.test.ts 5 + netlist.test.tsx 1）。
- [ ] `nix develop -c bun run check`（circuit/ 内）が `ERC passed` で exit 0。
- [ ] `circuit/netlist.py` / `test/netlist_test.py` / `tscircuit/` / `sim*.tsx` が存在しない。
- [ ] `README.md` / `CLAUDE.md` / `build.sh` に netlist.py 参照が残っていない。
- [ ] `./build.sh` が STL のみを生成して成功する。

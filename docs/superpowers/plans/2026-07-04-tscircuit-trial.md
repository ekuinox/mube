# tscircuit お試し環境 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** smtlk の回路（circuit/netlist.py と同一構成）を tscircuit で記述し、nix devShell + bun で `tsci build` が通る状態にする。

**Architecture:** flake の default devShell に bun を追加し、新ディレクトリ `tscircuit/` に package.json 管理の tscircuit プロジェクトを置く。回路は `index.tsx` 1 ファイル。既存の `circuit/netlist.py` は触らない。

**Tech Stack:** Nix flake devShell, bun, tscircuit, @tscircuit/cli (tsci)

## Global Constraints

- Node.js は追加しない。ランタイムは `pkgs.bun` のみ（spec「bun 単独のミニマル構成」）。
- `bun.lock` はコミットする。`tscircuit/node_modules/` と生成物（`tscircuit/dist/` 等）はコミットしない。
- ネット名は netlist.py と揃える: +5V / GND / SERVO_RTN / SERVO_SIG / GATE_DRV / GATE / LED_DRV_R / LED_A_R / LED_DRV_G / LED_A_G / BTN。
  ただし tscircuit のネット名は英数字とアンダースコアのみ許容のため、`+5V` はコード上 `V5` とし、コメントで netlist.py の `+5V` に対応することを明記する。
- GPIO 割当: servo=GP15, gate=GP14, led_r=GP16, led_g=GP18, btn=GP17。
- `circuit/netlist.py` の削除・変更、基板レイアウトの作り込み、CI/build.sh への組み込みはしない。
- コマンドは nix devShell 経由（`nix develop -c <cmd>`）。ネットワークを使う `bun install` はサンドボックス外実行が必要なら許可を取る。

---

### Task 1: devShell に bun を追加

**Files:**
- Modify: `flake.nix`（packages リスト）

**Interfaces:**
- Produces: `nix develop -c bun` が使えること（Task 2 以降が依存）

- [ ] **Step 1: flake.nix に bun を追加**

`pkgs.rustup` の行の直後に追加:

```nix
            pkgs.bun          # tscircuit/ の TS 回路記述を実行（tsci は bun 管理の npm パッケージ）
```

- [ ] **Step 2: 動作確認**

Run: `nix develop -c bun --version`
Expected: バージョン番号（例 `1.x.y`）が表示される

- [ ] **Step 3: Commit**

```bash
git add flake.nix
git commit -m "feat(nix): devShell に bun を追加（tscircuit お試し用）"
```

### Task 2: tscircuit/ プロジェクトの雛形

**Files:**
- Create: `tscircuit/package.json`
- Create: `tscircuit/bun.lock`（bun install が生成）
- Modify: `.gitignore`

**Interfaces:**
- Consumes: Task 1 の bun
- Produces: `tscircuit/` 内で `bunx tsci` が動くこと（Task 3 が依存）

- [ ] **Step 1: package.json を作成**

`tscircuit/package.json`:

```json
{
  "name": "smtlk-tscircuit",
  "private": true,
  "scripts": {
    "build": "tsci build",
    "dev": "tsci dev"
  },
  "devDependencies": {
    "@tscircuit/cli": "latest",
    "tscircuit": "latest"
  }
}
```

- [ ] **Step 2: .gitignore に追記**

リポジトリルートの `.gitignore` 末尾に追加:

```gitignore
tscircuit/node_modules/
tscircuit/dist/
tscircuit/.tscircuit/
```

- [ ] **Step 3: インストール**

Run: `cd tscircuit && nix develop .. -c bun install`
Expected: 依存が解決され `bun.lock` と `node_modules/` が生成される

- [ ] **Step 4: tsci が起動することを確認**

Run: `cd tscircuit && nix develop .. -c bunx tsci --version`
Expected: tsci のバージョンが表示される

- [ ] **Step 5: Commit**

```bash
git add tscircuit/package.json tscircuit/bun.lock .gitignore
git commit -m "feat(tscircuit): bun 管理の tscircuit プロジェクト雛形を追加"
```

### Task 3: smtlk 回路を index.tsx に記述して build を通す

**Files:**
- Create: `tscircuit/index.tsx`

**Interfaces:**
- Consumes: Task 2 の `bunx tsci build`
- Produces: `tsci build` 成功と circuit.json 生成（本タスクで完了）

- [ ] **Step 1: build が失敗することを確認（回路ファイル未作成）**

Run: `cd tscircuit && nix develop .. -c bunx tsci build`
Expected: FAIL（エントリポイントが見つからない旨のエラー）

- [ ] **Step 2: index.tsx を作成**

netlist.py と同一構成。部品は既製フットプリントが無いもの（Pico W、SG90、2 色 LED）を chip / pinheader で代用する。

```tsx
// smtlk 回路の tscircuit 版。circuit/netlist.py と同じ部品・ネット・GPIO 割当。
// ネット V5 は netlist.py の +5V に対応（tscircuit のネット名に "+" が使えないため）。
export default () => (
  <board width="60mm" height="45mm" routingDisabled>
    {/* U1: Raspberry Pi Pico W — 使用ピンのみのヘッダ代用 */}
    <chip
      name="U1"
      footprint="pinrow7"
      pinLabels={{
        pin1: "VBUS",
        pin2: "GND",
        pin3: "GP15", // servo
        pin4: "GP14", // gate
        pin5: "GP16", // led_r
        pin6: "GP18", // led_g
        pin7: "GP17", // btn
      }}
    />
    {/* M1: SG90 サーボ（3 線コネクタとして表現） */}
    <chip
      name="M1"
      footprint="pinrow3"
      pinLabels={{ pin1: "SIG", pin2: "VPLUS", pin3: "GND" }}
    />
    {/* Q1: N-ch MOSFET IRLB3813PBF（ローサイドで SERVO_RTN をゲート） */}
    <chip
      name="Q1"
      footprint="pinrow3"
      pinLabels={{ pin1: "G", pin2: "D", pin3: "S" }}
    />
    <resistor name="Rg" resistance="220" footprint="0603" />
    <resistor name="Rgs" resistance="10k" footprint="0603" />
    <resistor name="Rled" resistance="330" footprint="0603" />
    <resistor name="Rled2" resistance="330" footprint="0603" />
    {/* D1: 2 色 LED OSRGHC5B32A（R/YG カソードコモン） */}
    <chip
      name="D1"
      footprint="pinrow3"
      pinLabels={{ pin1: "R", pin2: "G", pin3: "K" }}
    />
    <pushbutton name="SW1" footprint="pushbutton" />
    <capacitor name="C1" capacitance="470uF" polarized footprint="1206" />
    <capacitor name="C2" capacitance="100nF" footprint="0603" />
    {/* D2: ショットキー 1N5819（+5V → SERVO_RTN の還流） */}
    <diode name="D2" footprint="sod123" />

    {/* +5V (= netlist.py の +5V) */}
    <trace from=".U1 .VBUS" to="net.V5" />
    <trace from=".C1 .pin1" to="net.V5" />
    <trace from=".M1 .VPLUS" to="net.V5" />
    <trace from=".C2 .pin1" to="net.V5" />
    <trace from=".D2 .cathode" to="net.V5" />
    {/* GND */}
    <trace from=".U1 .GND" to="net.GND" />
    <trace from=".C1 .pin2" to="net.GND" />
    <trace from=".Q1 .S" to="net.GND" />
    <trace from=".Rgs .pin2" to="net.GND" />
    <trace from=".D1 .K" to="net.GND" />
    <trace from=".SW1 .pin2" to="net.GND" />
    <trace from=".C2 .pin2" to="net.GND" />
    {/* SERVO_RTN */}
    <trace from=".M1 .GND" to="net.SERVO_RTN" />
    <trace from=".Q1 .D" to="net.SERVO_RTN" />
    <trace from=".D2 .anode" to="net.SERVO_RTN" />
    {/* SERVO_SIG */}
    <trace from=".U1 .GP15" to="net.SERVO_SIG" />
    <trace from=".M1 .SIG" to="net.SERVO_SIG" />
    {/* GATE_DRV / GATE */}
    <trace from=".U1 .GP14" to="net.GATE_DRV" />
    <trace from=".Rg .pin1" to="net.GATE_DRV" />
    <trace from=".Rg .pin2" to="net.GATE" />
    <trace from=".Q1 .G" to="net.GATE" />
    <trace from=".Rgs .pin1" to="net.GATE" />
    {/* LED */}
    <trace from=".U1 .GP16" to="net.LED_DRV_R" />
    <trace from=".Rled .pin1" to="net.LED_DRV_R" />
    <trace from=".Rled .pin2" to="net.LED_A_R" />
    <trace from=".D1 .R" to="net.LED_A_R" />
    <trace from=".U1 .GP18" to="net.LED_DRV_G" />
    <trace from=".Rled2 .pin1" to="net.LED_DRV_G" />
    <trace from=".Rled2 .pin2" to="net.LED_A_G" />
    <trace from=".D1 .G" to="net.LED_A_G" />
    {/* BTN */}
    <trace from=".U1 .GP17" to="net.BTN" />
    <trace from=".SW1 .pin1" to="net.BTN" />
  </board>
);
```

注意: tscircuit の API は更新が速い。ビルドエラーが出たら、エラーメッセージと
node_modules 内の型定義（`tscircuit` パッケージの d.ts）を根拠に props / セレクタ記法を
修正してよい。ただし部品構成・ネット・GPIO 割当は spec 通りを維持する。

- [ ] **Step 3: build が通ることを確認**

Run: `cd tscircuit && nix develop .. -c bunx tsci build`
Expected: PASS。`dist/`（または tsci の既定出力先）に circuit.json が生成される

- [ ] **Step 4: circuit.json の中身を軽く検証**

Run: `grep -o '"name":"SERVO_SIG"' tscircuit/dist/circuit.json | head -1`（出力パスは Step 3 の実際の生成先に合わせる）
Expected: `"name":"SERVO_SIG"` がヒットし、ネットが反映されていること

- [ ] **Step 5: Commit**

```bash
git add tscircuit/index.tsx
git commit -m "feat(tscircuit): smtlk 回路を tscircuit で記述（netlist.py と同構成）"
```

# 十字ホーンポケット実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** socket.scad の滑らかな円筒シャフトボアを SG90 付属十字ホーンのポケット形状に置換し、スプライン軸とのトルク伝達を確立する (#22)

**Architecture:** params.scad に十字ホーンの寸法パラメータ（仮値・要実測）を追加し、socket.scad の cylinder ボアを十字ポケット + ネジアクセス穴に書き換える。Z 寸法・他ファイルへの影響なし。

**Tech Stack:** OpenSCAD

## Global Constraints

- ビルド・レンダリングは nix dev シェル経由。`.sh` スクリプトは自分で再突入するのでそのまま実行可
- `build/` と `*.stl` はコミットしない（.gitignore 済み）
- SCAD レンダリングテスト: `./test/render.sh <scad>`
- 筐体ビルド（全 STL）: `./build.sh`
- 既存のパラメータコメントスタイルに合わせる（`// 値の説明` 形式）

---

### Task 1: params.scad に十字ホーンパラメータを追加し、レンダリング通過を確認

**Files:**
- Modify: `scad/params.scad:20-21` (SG90 セクション直後に挿入)

**Interfaces:**
- Consumes: `servo_tab_l` (既存、params.scad:14)
- Produces: `horn_arm_l`, `horn_arm_w`, `horn_hub_d`, `horn_thick`, `horn_screw_d`, `horn_clearance` (socket.scad が Task 2 で使用)

- [ ] **Step 1: params.scad の SG90 セクション直後にホーンパラメータを追加**

`scad/params.scad` の 20 行目 (`servo_boss_h` の行) の直後、`// --- Raspberry Pi Pico W ---` の前に挿入:

```openscad
// --- SG90 cross horn (付属十字ホーン, 仮寸法・要実測) ---
horn_arm_l      = servo_tab_l / 2;  // 16.1: 長辺腕の中心→先端 (≈タブ出っ張り)
horn_arm_w      = 2;        // 腕幅 (概算)
horn_hub_d      = 7;        // 中央ハブ外径 (概算)
horn_thick      = 2;        // ホーン厚 (概算)
horn_screw_d    = 2.2;      // 中心ネジ穴径 (概算)
horn_clearance  = 0.3;      // ホーンポケット専用クリアランス (fit_clearance とは独立)
```

- [ ] **Step 2: 既存 SCAD のレンダリングが壊れていないことを確認**

パラメータ追加だけなので既存モジュールへの影響はないはずだが、assert やシンタックスエラーがないことを確認する。

Run: `./test/render.sh scad/smartlock.scad`

Expected: `OK:` で終わる出力（WARNING/ERROR なし）

- [ ] **Step 3: コミット**

```bash
git add scad/params.scad
git commit -m "feat(scad): 十字ホーン寸法パラメータを params.scad に追加 (#22)"
```

---

### Task 2: socket.scad のシャフトボアを十字ポケットに置換し、レンダリング通過を確認

**Files:**
- Modify: `scad/socket.scad:19-21` (shaft bore を horn pocket に置換)

**Interfaces:**
- Consumes: `horn_arm_l`, `horn_arm_w`, `horn_hub_d`, `horn_thick`, `horn_screw_d`, `horn_clearance` (Task 1 で追加), `fit_clearance` (既存)

- [ ] **Step 1: socket.scad のシャフトボアを十字ポケットに置換**

`scad/socket.scad` の以下の部分:

```openscad
    // servo shaft bore (bottom)
    translate([0, 0, -0.1])
      cylinder(d = servo_shaft_d + c, h = 6 + 0.1);
```

を次のように置換:

```openscad
    // cross-horn pocket (bottom face = shaft side when assembled)
    hc = horn_clearance;
    translate([0, 0, -0.1]) {
      linear_extrude(height = horn_thick + hc + 0.1)
        union() {
          for (a = [0, 90])
            rotate([0, 0, a])
              square([2*(horn_arm_l + hc), horn_arm_w + 2*hc], center = true);
          circle(d = horn_hub_d + 2*hc);
        }
      cylinder(d = horn_screw_d + hc, h = 6 + 0.1);
    }
```

- [ ] **Step 2: ソケット単体のレンダリングを確認**

Run: `./test/render.sh scad/smartlock.scad`

Expected: `OK:` で終わる出力（WARNING/ERROR なし）

- [ ] **Step 3: 全体ビルドを確認**

Run: `./build.sh`

Expected: `build/` に STL が生成され、エラーなし

- [ ] **Step 4: コミット**

```bash
git add scad/socket.scad
git commit -m "fix(scad): シャフトボアを十字ホーンポケットに置換 (closes #22)"
```

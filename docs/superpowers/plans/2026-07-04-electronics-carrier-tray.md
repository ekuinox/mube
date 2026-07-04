# 電子部品トレイ Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pico と基板を平置きで組める独立した電子部品トレイ（`scad/tray.scad`）を追加し、本体床直付けの Pico マウントを廃止して最後にトレイごとネジ止めする形にする。

**Architecture:** トレイ床の上に既存の Pico 短ボス（`pico_w_mounts` 流用）と、データシート確定の 66×41 ピッチに立てた背高ポスト4本を持つ。ポスト頂面はピンヘッダで浮く基板下面と同じ高さ（12.5mm）で基板を下支えする。基板四隅の φ3.2 穴へ M2 セルフタップ、トレイ四隅は本体床のボスへ M2 で連結。共通の Pico 配置値（`pico_gap`/`pico_y` 等）は現状 body/lid/layout_check に3重複しているので params.scad へ集約する。

**Tech Stack:** OpenSCAD（Nix dev シェル内）。テストは `assert()`（ジオメトリが空でも走る）と `./test/render.sh`（`WARNING:`/`ERROR:` で FAIL）。

## Global Constraints

- コマンドは Nix dev シェル内でのみ動く。`.sh` 系はそのまま実行可、素の `openscad` は `nix develop -c openscad …` 経由。
- 印刷補正: A1 mini(0.4ノズル/0.2mm層)。M2 セルフタップ下穴は実績値 `servo_screw_pilot = 2.2`。
- `build/` と `*.stl` は派生物。コミットしない。
- ユニバーサル基板は秋月 P-03229 Cタイプ 72×47×1.6mm、四隅マウント穴 φ3.2、ピッチ 長辺66×短辺41mm（データシート確定値）。
- DRY / YAGNI / TDD / こまめにコミット。

---

### Task 1: params へ Pico 配置と tray 定数を集約 + fit アサート

現状 `pico_gap`/`pico_y`/`pedestal_outer` は body.scad・lid.scad・layout_check.scad に、`pin_header_h`/`uboard_t` は layout_check.scad に重複定義されている。これを params.scad の単一ソースへ集約し、tray 用定数と収まりアサートを追加する。

**Files:**
- Modify: `scad/params.scad`（uboard セクション直後に定数ブロック、末尾のチェック節にアサート追加）
- Modify: `scad/body.scad:14-19`（module 内のローカル `pico_x/pico_z/pedestal_outer/pico_gap/pico_y` を除去、`pico_z` 依存を解消）
- Modify: `scad/lid.scad:6-9`（module 内のローカル `pedestal_outer/pico_gap/pico_y` を除去）
- Modify: `scad/layout_check.scad:21-28`（トップレベル重複 `pedestal_outer/pico_gap/pico_x/pico_y/pin_header_h/uboard_t` を除去）
- Test: `./test/render.sh scad/smartlock.scad` と `./test/render.sh scad/layout_check.scad`

**Interfaces:**
- Produces（params.scad のグローバル、後続タスクが参照）:
  - `pin_header_h = 8.5`, `uboard_t = 1.6`
  - `uboard_mount_span_l = 66`, `uboard_mount_span_w = 41`, `uboard_mount_d = 3.2`
  - `tray_t = 2.4`, `tray_post_d = 6.0`, `tray_post_h = 12.5`, `tray_fl = 72`, `tray_fw = 47`
  - `tray_screw_span_l = 60`, `tray_screw_span_w = 26`, `tray_screw_pilot = 2.2`, `tray_screw_clear = 2.4`
  - `pedestal_outer`, `pico_gap`, `pico_x = 0`, `pico_y`（本体 +Y 空間の Pico/トレイ中心）

- [ ] **Step 1: アサートだけ先に追加（RED）**

`scad/params.scad` の末尾（既存の `assert(...)` 群の後、最終行）に追記:

```openscad
// --- Electronics tray checks ---
assert(tray_post_h > pico_boss_h + pico_h, "背高ポストは Pico 上面より高く基板を持ち上げる");
assert(uboard_mount_span_w/2 > pico_w/2, "uボード短辺マウント穴が Pico 幅の外");
assert(uboard_mount_span_l/2 > pico_l/2, "uボード長辺マウント穴が Pico 長さの外");
assert(uboard_mount_span_w <= uboard_w && uboard_mount_span_l <= uboard_l, "マウントピッチが基板外形内");
assert(tray_fw/2 <= inner_l/2, "トレイ footprint が内寸 X 内");
assert(pico_y + tray_fl/2 <= ext_up, "トレイ +Y 端が内寸を超える");
assert(pico_y - tray_fl/2 >= pedestal_outer, "トレイ -Y 端がペデスタルに干渉");
```

- [ ] **Step 2: レンダリングで失敗を確認（RED）**

Run: `./test/render.sh scad/smartlock.scad`
Expected: FAIL。`WARNING: Ignoring unknown variable` と `ERROR: Assertion ... failed`（`tray_post_h` 等が未定義のため）。

- [ ] **Step 3: params に定数ブロックを追加（GREEN 化）**

`scad/params.scad` の `uboard_w = 47;` の行（uboard セクション）直後に挿入:

```openscad
uboard_t = 1.6;   // board thickness (P-03229 Cタイプ)

// Pin header stack height: Pico top face -> universal board underside.
pin_header_h = 8.5;

// Universal board corner mounting holes (秋月 P-03229 datasheet).
uboard_mount_span_l = 66;   // corner-hole center pitch, long side (along Y)
uboard_mount_span_w = 41;   // corner-hole center pitch, short side (along X)
uboard_mount_d      = 3.2;  // corner hole dia (M2/M3 clearance)

// --- Electronics carrier tray ---
tray_t            = 2.4;    // tray floor thickness
tray_post_d       = 6.0;    // universal-board support post outer dia
tray_post_h       = pico_boss_h + pico_h + pin_header_h;   // 12.5: post top = board underside
tray_fl           = uboard_mount_span_l + tray_post_d;     // 72: footprint along Y
tray_fw           = uboard_mount_span_w + tray_post_d;     // 47: footprint along X
tray_screw_span_l = 60;     // tray<->body screw pitch, Y (clear band, avoids posts/Pico)
tray_screw_span_w = 26;     // tray<->body screw pitch, X
tray_screw_pilot  = servo_screw_pilot;   // 2.2: M2 self-tap (posts & body bosses)
tray_screw_clear  = 2.4;    // M2 shank clearance through the tray floor

// --- Pico / tray placement in the +Y free space (single source; body/lid use these) ---
pedestal_outer = rosette_d/2 + pedestal_wall_t + fit_clearance;
pico_gap = max(6, pedestal_outer - servo_body_w/2 + 2,
              pedestal_outer + uboard_l/2 - pico_l/2 - servo_body_w/2 + 2);
pico_x = 0;
pico_y = servo_body_w/2 + pico_gap + pico_l/2;
```

- [ ] **Step 4: 重複ローカル定義を除去**

`scad/body.scad` の `module body() {` 冒頭。`pico_x`/`pedestal_outer`/`pico_gap`/`pico_y` の4つの代入だけを削除する（params から来るため）。**`pico_z = wall * 0.5;` は残す**（`usb_z` がまだ参照しており、Task 3 で `usb_z` を直すのと同時に撤去する）。削除前:

```openscad
  // Pico stacked above the servo in free +Y space; long axis along Y
  pico_x = 0;
  pico_z = wall * 0.5;
  pedestal_outer = rosette_d/2 + pedestal_wall_t + fit_clearance;
  pico_gap = max(6, pedestal_outer - servo_body_w/2 + 2,
                pedestal_outer + uboard_l/2 - pico_l/2 - servo_body_w/2 + 2);
  pico_y = servo_body_w/2 + pico_gap + pico_l/2;
```

削除後（`pico_z` のみ残る）:

```openscad
  // Pico stacked above the servo in free +Y space; long axis along Y
  pico_z = wall * 0.5;
```

`scad/lid.scad` の `module lid() {` 冒頭、次の3行を削除:

```openscad
  pedestal_outer = rosette_d/2 + pedestal_wall_t + fit_clearance;
  pico_gap = max(6, pedestal_outer - servo_body_w/2 + 2,
                pedestal_outer + uboard_l/2 - pico_l/2 - servo_body_w/2 + 2);
  pico_y = servo_body_w/2 + pico_gap + pico_l/2;
```

`scad/layout_check.scad` の次の行群を削除（`pico_z`/`pico_floor_z`/`usb_z`/`uboard_z` はここに残す。削除するのは params へ移した定義のみ）:

```openscad
pedestal_outer = rosette_d/2 + pedestal_wall_t + fit_clearance;
pico_gap = max(6, pedestal_outer - servo_body_w/2 + 2,
              pedestal_outer + uboard_l/2 - pico_l/2 - servo_body_w/2 + 2);
pico_x = 0;
pico_y = servo_body_w/2 + pico_gap + pico_l/2;
```
および
```openscad
pin_header_h = 8.5;
uboard_t = 1.6;
```

- [ ] **Step 5: レンダリングで成功を確認（GREEN）**

Run: `./test/render.sh scad/smartlock.scad`
Expected: PASS（`OK: ...`）。tray アサートが通り、未定義変数の警告が消える。

Run: `./test/render.sh scad/layout_check.scad`
Expected: PASS（重複トップレベル代入が無くなり警告なし）。

- [ ] **Step 6: コミット**

```bash
git add scad/params.scad scad/body.scad scad/lid.scad scad/layout_check.scad
git commit -m "refactor(scad): Pico 配置を params へ集約＋トレイ定数と収まりアサートを追加"
```

---

### Task 2: `scad/tray.scad` — トレイ本体モジュール

**Files:**
- Create: `scad/tray.scad`
- Test: `./test/render.sh scad/tray.scad`

**Interfaces:**
- Consumes: params の `tray_t/tray_fl/tray_fw/tray_post_d/tray_post_h/uboard_mount_span_l/uboard_mount_span_w/tray_screw_span_l/tray_screw_span_w/tray_screw_pilot/tray_screw_clear`、`hardware.scad` の `pico_w_mounts()`。
- Produces: `module tray()`（原点中心、長手 Y。Task 3/4 が呼ぶ）。

- [ ] **Step 1: 失敗を確認（RED）**

Run: `./test/render.sh scad/tray.scad`
Expected: FAIL（`Can't open input file` / ファイルが存在しない）。

- [ ] **Step 2: tray.scad を作成（GREEN）**

`scad/tray.scad` を新規作成:

```openscad
include <params.scad>
use <hardware.scad>

// Electronics carrier tray: Pico on short bosses, universal board on tall
// corner posts above it. The whole tray screws down into the body floor.
// Footprint centered at origin, long axis (Pico length / uboard long side)
// along Y — matching how the body orients the Pico.
module tray() {
  union() {
    // floor plate
    translate([0, 0, tray_t/2])
      cube([tray_fw, tray_fl, tray_t], center = true);

    // Pico short bosses (reuse hardware module), long axis along Y
    translate([0, 0, tray_t])
      rotate([0, 0, 90]) pico_w_mounts();

    // universal-board support posts at the datasheet corner pitch;
    // M2 self-taps into the top of each post through the board's φ3.2 hole
    for (sx = [-1, 1], sy = [-1, 1])
      translate([sx * uboard_mount_span_w/2, sy * uboard_mount_span_l/2, tray_t])
        difference() {
          cylinder(d = tray_post_d, h = tray_post_h);
          translate([0, 0, tray_post_h - 6])
            cylinder(d = tray_screw_pilot, h = 6 + 0.1);
        }

    // tray -> body screw bosses (M2 shank clears the floor, self-taps body boss)
    for (sx = [-1, 1], sy = [-1, 1])
      translate([sx * tray_screw_span_w/2, sy * tray_screw_span_l/2, 0])
        difference() {
          cylinder(d = tray_post_d, h = tray_t);
          translate([0, 0, -0.1])
            cylinder(d = tray_screw_clear, h = tray_t + 0.2);
        }
  }
}

// standalone render target (ignored by `use <tray.scad>`)
tray();
```

- [ ] **Step 3: 成功を確認（GREEN）**

Run: `./test/render.sh scad/tray.scad`
Expected: PASS。`Top level object is a 3D object (manifold)` と `Status: NoError`、`OK: /tmp/tray.stl`。

- [ ] **Step 4: コミット**

```bash
git add scad/tray.scad
git commit -m "feat(scad): 電子部品トレイ tray.scad を追加"
```

---

### Task 3: 本体側統合（`hardware.scad` の `tray_mounts()` + `body.scad`）

本体から Pico ボスを撤去し、トレイ連結ボスへ差し替え。USB 穴高さをトレイ床ぶん補正。

**Files:**
- Modify: `scad/hardware.scad`（`tray_mounts()` を追加）
- Modify: `scad/body.scad`（Pico standoff 撤去→`tray_mounts()`、`usb_z` 補正、`pico_z` 撤去、Y-fit は params のアサートで担保済み）
- Test: `nix develop -c openscad -D 'part="body"' -o /tmp/body.stl scad/smartlock.scad`

**Interfaces:**
- Consumes: params の `tray_screw_span_l/tray_screw_span_w/tray_post_d/tray_screw_pilot/pico_boss_h`、`pico_x/pico_y`。
- Produces: `module tray_mounts()`（本体床の4連結ボス、原点中心）。

- [ ] **Step 1: body から未定義モジュールを呼んで失敗させる（RED）**

`scad/body.scad` の Pico standoff ブロック（`// Pico standoffs, long axis along Y` と続く `translate([pico_x, pico_y, pico_z]) rotate([0, 0, 90]) pico_w_mounts();`）を次に置換:

```openscad
      // tray connector bosses on the floor (tray carries Pico + board)
      translate([pico_x, pico_y, wall])
        tray_mounts();
```

Run: `nix develop -c openscad -D 'part="body"' -o /tmp/body.stl scad/smartlock.scad`
Expected: FAIL / 警告。`WARNING: Ignoring unknown module 'tray_mounts'`。

- [ ] **Step 2: hardware.scad に tray_mounts() を追加（GREEN）**

`scad/hardware.scad` の末尾に追加:

```openscad
// Four M2 self-tap bosses on the body floor that the tray screws into.
// Positions match the tray's tray_screw_span_* pattern; centered at origin.
module tray_mounts() {
  for (sx = [-1, 1], sy = [-1, 1])
    translate([sx * tray_screw_span_w/2, sy * tray_screw_span_l/2, 0])
      difference() {
        cylinder(d = tray_post_d, h = pico_boss_h);
        translate([0, 0, -0.1])
          cylinder(d = tray_screw_pilot, h = pico_boss_h + 0.2);
      }
}
```

- [ ] **Step 3: USB 穴高さを補正 + 不要な pico_z を撤去**

`scad/body.scad` の `usb_z` 行を置換:

```openscad
  usb_z = wall + tray_t + pico_boss_h + pico_h + usb_connector_h/2;
```

同ファイルの `pico_z = wall * 0.5;` 行を削除（もう参照されない）。

- [ ] **Step 4: 成功を確認（GREEN）**

Run: `nix develop -c openscad -D 'part="body"' -o /tmp/body.stl scad/smartlock.scad 2>&1 | grep -Ei 'WARNING:|ERROR:' || echo CLEAN`
Expected: `CLEAN`（警告・エラー無し）。

Run: `./test/render.sh scad/smartlock.scad`
Expected: PASS。

- [ ] **Step 5: コミット**

```bash
git add scad/hardware.scad scad/body.scad
git commit -m "feat(scad): 本体の Pico ボスをトレイ連結ボスへ置換＋USB高さ補正"
```

---

### Task 4: ビルド接続（`smartlock.scad` 分岐 + クーポン + `build.sh`）

**Files:**
- Modify: `scad/smartlock.scad`（`use <tray.scad>`、`part=="tray"`/`part=="tray_coupon"`/`asm_tray` 分岐、フル assembly にトレイ追加）
- Modify: `build.sh`（部品リストに `tray asm_tray`）
- Test: `./build.sh` と `nix develop -c openscad -D 'part="tray_coupon"' -o /tmp/tc.stl scad/smartlock.scad`

**Interfaces:**
- Consumes: `tray()`（Task 2）、params の `pico_x/pico_y/wall/tray_fl/tray_fw/tray_post_h/tray_t`、`exp`（smartlock 内）。

- [ ] **Step 1: build.sh に tray を追加して失敗を確認（RED）**

`build.sh:10` の部品ループを置換:

```bash
for p in body lid socket tray asm_body asm_lid asm_socket asm_tray; do
```

Run: `./build.sh`
Expected: FAIL。`tray` のレンダリングで `part=="tray"` 分岐が未実装のため空 or 既定 assembly が出るが、`asm_tray` は未定義分岐で既定 assembly にフォールバックし tray 未描画。まず tray STL が期待通りにならないことを確認（この段階では `smartlock.scad` 未改修なので `tray` は既定の assembly が出力される＝トレイ単体にならない）。

- [ ] **Step 2: smartlock.scad に分岐を追加（GREEN）**

`scad/smartlock.scad:4`（`use <socket.scad>` の次行）に追加:

```openscad
use <tray.scad>
```

`part == "socket"` 分岐の後（socket_coupon の前）に追加:

```openscad
else if (part == "tray") tray();
// トレイ +X/+Y 隅の薄型クーポン（ポスト高・ネジ効き・穴位置確認用）
else if (part == "tray_coupon")
  intersection() {
    tray();
    translate([0, 0, -1])
      cube([tray_fw/2 + 3, tray_fl/2 + 3, tray_post_h + tray_t + 3]);
  }
```

`asm_socket` 分岐の後に追加:

```openscad
else if (part == "asm_tray")
  color("Plum")
    translate([pico_x, pico_y, wall + exp * 10]) tray();
```

フル assembly（最後の `else { ... }` ブロック内、socket 配置の後）に追加:

```openscad
  color("Plum")
    translate([pico_x, pico_y, wall + exp * 10]) tray();
```

- [ ] **Step 3: クーポンとビルドの成功を確認（GREEN）**

Run: `nix develop -c openscad -D 'part="tray"' -o /tmp/tray.stl scad/smartlock.scad 2>&1 | grep -Ei 'WARNING:|ERROR:' || echo CLEAN`
Expected: `CLEAN`。

Run: `nix develop -c openscad -D 'part="tray_coupon"' -o /tmp/tc.stl scad/smartlock.scad 2>&1 | grep -Ei 'WARNING:|ERROR:' || echo CLEAN`
Expected: `CLEAN`。

Run: `./build.sh`
Expected: `All parts + netlist built to build/`（`tray` と `asm_tray` を含む全部品と netlist がビルドされる）。

- [ ] **Step 4: コミット**

```bash
git add scad/smartlock.scad build.sh
git commit -m "feat(scad): smartlock に tray/tray_coupon/asm_tray 分岐と build 対象を追加"
```

---

## Self-Review

**Spec coverage:**
- 独立トレイ＋Pico 短ボス流用 → Task 2。
- 背高ポスト（66×41, h=12.5, φ3.2 穴へ M2）→ Task 2 + params(Task 1)。
- 本体 Pico ボス撤去・連結ボス追加・USB 高さ補正 → Task 3。
- ビルド/ディスパッチ/クーポン → Task 4。
- params 集約・fit アサート → Task 1。
- 高さは `tray_post_h` 一本管理（`-D tray_post_h=…` で刷り直し）→ params(Task 1) でパラメータ化済み。別ファイル量産なし（YAGNI）。

**Placeholder scan:** TBD/TODO 無し。各コードステップは実コードを記載。

**Type/naming consistency:** `tray()`, `tray_mounts()`, `pico_w_mounts()`, `tray_post_h/tray_fl/tray_fw/tray_screw_span_l/tray_screw_span_w/tray_screw_pilot/tray_screw_clear/uboard_mount_span_l/uboard_mount_span_w/uboard_mount_d/pico_x/pico_y/pedestal_outer/pico_gap` は全タスクで一貫。fit 値（pico_y=63.4, tray +Y=99.4≤100, -Y=27.4≥25.4, X=23.5≤27）は実 params のプローブレンダリングで検証済み。

**留意点（実装者向け）:**
- トレイ +Y 端は内寸壁まで 0.6mm。壁で位置決めになる想定。`tray_t` を増やすと USB 高さ式に自動反映される。
- トレイ→本体ネジは頭がトレイ床上面に載る。ネジ長は 床 2.4 + 本体ボス 3 に届く M2（M2×8 目安）。SCAD では扱わない。
- クーポンは build.sh の標準出力には含めない（既存 `mount_coupon`/`socket_coupon` と同様、必要時に `-D part="tray_coupon"` で個別レンダリング）。ただし build.sh には `tray`/`asm_tray` を追加する。

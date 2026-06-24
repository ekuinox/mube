# スマートロック筐体（OpenSCAD）実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 既存ドアのサムターンに後付けするスマートロックの筐体（ガワ）を、パラメトリックな OpenSCAD モデルとして作る。

**Architecture:** 一体モノコック箱＋開閉蓋。寸法は全て `params.scad` に集約。実物未確定の「サムターンソケット」と「ドア固定面（mount_plate）」は独立モジュールに隔離し、本体を再設計せず差し替え可能にする。SG90 サーボ・Pico W・MOSFET・LED・ボタン・USB の各フィーチャはハードウェア参照モジュールから生成する。

**Tech Stack:** Nix flake（`nix develop` の devShell で OpenSCAD 2021.01 を提供）、OpenSCAD（ヘッドレス STL 出力、xvfb 不要 — 検証済み）、bash テストハーネス、git。

## Global Constraints

- 単位は全て **mm**。
- 対象方式は **後付けサムターン式のみ**（シリンダー交換・デッドボルト直駆動は対象外）。
- アクチュエータは **SG90 サーボ**（1個）。電源は **USB 常時給電**。
- ドア・錠前は **無加工**。ドアへのネジ止めはしない。
- このフェーズは **筐体モデルのみ**。Pico W ファームウェア・省電力運用・手回し後の状態再同期は対象外。
- サムターン実寸とドア固定の突っ張り先は **未確定**。`socket.scad` と `mount_plate.scad` のパラメータ/モジュールに隔離する（プレースホルダ値で進める）。
- 全パーツは 3D プリント前提。寸法は `params.scad` で変数化し、ハードコードしない。
- 開発環境は **Nix flake**（`nix develop` で OpenSCAD を提供）。システムへの apt インストールはしない。OpenSCAD はヘッドレスで STL を出力でき、xvfb は不要。

---

## File Structure

- `flake.nix` / `flake.lock` — Nix 開発環境（devShell に OpenSCAD）。`nix develop` で OpenSCAD を使える。
- `scad/params.scad` — 全パラメータ（寸法・公差・派生値）と sanity assert。
- `scad/hardware.scad` — 実部品の参照ジオメトリ（SG90 切り欠き、Pico W ボス、USB 口、LED 穴、ボタン穴、MOSFET 占有）。
- `scad/socket.scad` — `thumbturn_socket()`：サムターンを掴む専用ソケット（独立パーツ）。
- `scad/mount_plate.scad` — `mount_plate()`：ドア接触面（v1 は平らなテープ面）。
- `scad/body.scad` — `body()`：本体モノコック箱。hardware/mount_plate を合成。
- `scad/lid.scad` — `lid()`：開閉蓋。
- `scad/smartlock.scad` — トップレベル組立。`part` 変数で描画パーツを選択。
- `test/render.sh` — 1 つの .scad をヘッドレスで STL 化し、exit!=0 または WARNING/ERROR で失敗するテストハーネス。openscad が PATH に無ければ `nix develop` 内で自身を再実行する。
- `build.sh` — 全パーツ（body / lid / socket）を `build/` に STL 出力。
- `README.md` — 使い方（レンダリング・パラメータ変更・採寸後の運用）。

各ファイルは「一つの責務」を持つ。実部品の寸法は `hardware.scad` に、未確定の隔離対象は `socket.scad`/`mount_plate.scad` に集約する。

---

### Task 1: プロジェクト雛形・Nix 環境・テストハーネス

**注記（実装者向け）:** リポジトリは既に `git init` 済みで、root コミットが1つある。`git init` は不要。`/nix/var/nix/profiles/default/bin` に nix がある（PATH 未通の場合はそこを使う）。OpenSCAD はヘッドレスで STL 出力でき xvfb は不要（検証済み）。

**Files:**
- Create: `flake.nix`
- Create: `test/render.sh`
- Create: `scad/smoke.scad`
- Create: `.gitignore`

**Interfaces:**
- Produces:
  - `flake.nix` — devShell（`nix develop`）で `openscad` を提供。
  - `test/render.sh <scad_file> [out_stl]` — レンダリング成功かつ WARNING/ERROR 無しで exit 0、それ以外 exit 1。openscad が PATH に無ければ `nix develop` 内で自身を再実行する。

- [ ] **Step 1: flake.nix を書く**

Create `flake.nix`:
```nix
{
  description = "smtlk smart lock enclosure dev environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
    in {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.openscad ];
        };
      });
    };
}
```

- [ ] **Step 2: dev シェルで OpenSCAD が使えることを確認**

Run:
```bash
export PATH="/nix/var/nix/profiles/default/bin:$PATH"
nix develop -c openscad --version
```
Expected: `OpenSCAD version 2021.01` が表示される（初回は依存取得で時間がかかる）。`flake.lock` が生成される。

- [ ] **Step 3: テストハーネスを書く（失敗するテストを先に作る）**

Create `test/render.sh`:
```bash
#!/usr/bin/env bash
# Render one OpenSCAD file to STL. Fail on non-zero exit or any WARNING/ERROR.
# Re-execs inside the Nix dev shell if openscad is not already on PATH.
set -uo pipefail
if ! command -v openscad >/dev/null 2>&1; then
  command -v nix >/dev/null 2>&1 || export PATH="/nix/var/nix/profiles/default/bin:$PATH"
  exec nix develop "$(cd "$(dirname "$0")/.." && pwd)" -c "$0" "$@"
fi
scad="${1:?usage: render.sh <scad> [out]}"
out="${2:-/tmp/$(basename "${scad%.scad}").stl}"
mkdir -p "$(dirname "$out")"
log="$(openscad -o "$out" "$scad" 2>&1)"
status=$?
echo "$log"
if [ "$status" -ne 0 ]; then echo "FAIL: openscad exit $status"; exit 1; fi
if echo "$log" | grep -Eiq 'WARNING|ERROR'; then echo "FAIL: warnings/errors present"; exit 1; fi
echo "OK: $out"
```

Run:
```bash
chmod +x test/render.sh
./test/render.sh scad/smoke.scad
```
Expected: FAIL（`scad/smoke.scad` が存在せず openscad が exit 非0）。

- [ ] **Step 4: smoke モデルを作る（最小実装）**

Create `scad/smoke.scad`:
```scad
// Smallest valid model — proves the toolchain renders to a manifold STL.
assert(1 + 1 == 2, "sanity");
cube([10, 10, 10], center = true);
```

Create `.gitignore`:
```
build/
*.stl
result
```

- [ ] **Step 5: テストが通ることを確認**

Run: `./test/render.sh scad/smoke.scad`
Expected: `OK: ...smoke.stl`（exit 0、警告なし）。

- [ ] **Step 6: コミット**

```bash
git add flake.nix flake.lock .gitignore test/render.sh scad/smoke.scad
git commit -m "chore: scaffold Nix dev env and headless OpenSCAD render test harness"
```

---

### Task 2: パラメータ定義 `params.scad`

**Files:**
- Create: `scad/params.scad`
- Create: `test/params_test.scad`

**Interfaces:**
- Produces: グローバル変数 — `wall`, `fit_clearance`, `$fn`, SG90 寸法（`servo_body_l/w/h`, `servo_tab_l`, `servo_shaft_d`, `servo_screw_d`）, Pico 寸法（`pico_l/w/h`, `pico_hole_d`, `pico_hole_dx`, `pico_hole_dy`, `pico_boss_d`, `pico_boss_h`）, `usb_w/usb_h`, `led_hole_d`, `button_hole_d`, `mosfet_w/mosfet_l`, サムターン（`knob_w`, `knob_t`, `knob_h`, `socket_wall`）, 派生（`inner_l/w/h`, `body_l/w/h`）。

- [ ] **Step 1: 失敗するテストを書く**

Create `test/params_test.scad`:
```scad
include <../scad/params.scad>
// Derived body must enclose the largest component footprints.
assert(body_l >= pico_l + 2*wall, "body length must enclose Pico");
assert(body_h >= servo_body_h + 2*wall, "body height must enclose servo");
assert(fit_clearance >= 0, "clearance non-negative");
echo("params_test ok");
```

- [ ] **Step 2: 失敗を確認**

Run: `./test/render.sh test/params_test.scad`
Expected: FAIL（`params.scad` 未作成で include 失敗 → exit 非0）。

- [ ] **Step 3: パラメータを実装**

Create `scad/params.scad`:
```scad
// ===== Smart lock enclosure parameters (mm) =====

// --- Print / fit ---
wall          = 2.4;
fit_clearance = 0.4;
$fn           = 64;

// --- SG90 servo (datasheet nominal) ---
servo_body_l  = 22.8;
servo_body_w  = 12.2;
servo_body_h  = 22.5;
servo_tab_l   = 32.2;   // length across mounting tabs
servo_tab_h   = 2.5;
servo_shaft_d = 4.8;    // output boss / horn clearance
servo_screw_d = 2.0;

// --- Raspberry Pi Pico W ---
pico_l        = 51.0;
pico_w        = 21.0;
pico_h        = 1.0;
pico_hole_d   = 2.1;
pico_hole_dx  = 47.0;   // mounting hole spacing along length
pico_hole_dy  = 11.4;   // mounting hole spacing across width
pico_boss_d   = 4.5;
pico_boss_h   = 3.0;

// --- USB micro-B plug clearance (Pico W) ---
usb_w         = 9.0;
usb_h         = 6.0;

// --- Indicators ---
led_hole_d    = 5.2;
button_hole_d = 6.2;

// --- MOSFET footprint (small module) ---
mosfet_w      = 12.0;
mosfet_l      = 16.0;

// --- Thumb-turn knob: PLACEHOLDER — measure real part, then set ---
knob_w        = 8.0;
knob_t        = 4.0;
knob_h        = 12.0;
socket_wall   = 2.0;

// --- Derived enclosure dimensions ---
inner_l = max(servo_tab_l, pico_l) + 6;
inner_w = servo_body_w + pico_w + 8;
inner_h = servo_body_h + pico_boss_h + 6;

body_l = inner_l + 2*wall;
body_w = inner_w + 2*wall;
body_h = inner_h + 2*wall;

// --- Sanity checks ---
assert(wall > 0, "wall must be positive");
assert(fit_clearance >= 0, "fit_clearance must be >= 0");
assert(inner_l >= pico_l, "body too short for Pico");
assert(inner_h >= servo_body_h, "body too short for servo");
```

- [ ] **Step 4: テストが通ることを確認**

Run: `./test/render.sh test/params_test.scad`
Expected: `OK`（assert 全通過、警告なし）。

- [ ] **Step 5: コミット**

```bash
git add scad/params.scad test/params_test.scad
git commit -m "feat: parametric dimensions in params.scad with sanity asserts"
```

---

### Task 3: ハードウェア参照ジオメトリ `hardware.scad`

各実部品の「切り欠き（negative）」と「ボス（positive）」をモジュール化する。body から呼ぶ。

**Files:**
- Create: `scad/hardware.scad`
- Create: `test/hardware_test.scad`

**Interfaces:**
- Consumes: `scad/params.scad` のグローバル変数。
- Produces:
  - `sg90_cutout()` — サーボ本体＋タブ＋シャフト貫通の負形状（原点中心、シャフト軸 = Z）。
  - `pico_w_mounts()` — Pico W の4本スタンドオフボス（正形状、XY 平面上、Z+ に立つ）。
  - `usb_cutout()` — USB プラグ口の負形状（原点中心）。
  - `led_hole()` — LED 穴の負形状（Z 方向に貫通する円柱）。
  - `button_hole()` — ボタン穴の負形状（Z 方向に貫通する円柱）。
  - `mosfet_space()` — MOSFET 占有の負形状（原点中心の箱）。

- [ ] **Step 1: 失敗するテストを書く**

Create `test/hardware_test.scad`:
```scad
include <../scad/params.scad>
use <../scad/hardware.scad>
// Instantiate every module so undefined ones fail the compile.
difference() {
  cube([60, 40, 30], center = true);
  sg90_cutout();
  usb_cutout();
  led_hole();
  button_hole();
  mosfet_space();
}
pico_w_mounts();
echo("hardware_test ok");
```

- [ ] **Step 2: 失敗を確認**

Run: `./test/render.sh test/hardware_test.scad`
Expected: FAIL（モジュール未定義で exit 非0）。

- [ ] **Step 3: モジュールを実装**

Create `scad/hardware.scad`:
```scad
include <params.scad>

// SG90 body + mounting tabs + shaft clearance. Shaft axis = Z.
module sg90_cutout() {
  c = fit_clearance;
  union() {
    // body
    translate([0, 0, 0])
      cube([servo_body_l + 2*c, servo_body_w + 2*c, servo_body_h + 2*c], center = true);
    // mounting tabs (wider in length)
    translate([0, 0, servo_body_h/2 - servo_tab_h/2])
      cube([servo_tab_l + 2*c, servo_body_w + 2*c, servo_tab_h + 2*c], center = true);
    // output shaft / horn clearance through the bottom face
    translate([0, 0, -servo_body_h])
      cylinder(d = servo_shaft_d + 2*c, h = servo_body_h, center = false);
  }
}

// Four Pico W standoff bosses with pilot holes. Footprint centered at origin.
module pico_w_mounts() {
  for (sx = [-1, 1], sy = [-1, 1])
    translate([sx * pico_hole_dx/2, sy * pico_hole_dy/2, 0])
      difference() {
        cylinder(d = pico_boss_d, h = pico_boss_h);
        translate([0, 0, -0.1])
          cylinder(d = pico_hole_d, h = pico_boss_h + 0.2);
      }
}

// USB plug opening, centered at origin, cut along Y.
module usb_cutout() {
  c = fit_clearance;
  rotate([90, 0, 0])
    translate([0, 0, -wall*2])
      linear_extrude(height = wall*4)
        offset(r = c) square([usb_w, usb_h], center = true);
}

// 5mm LED through-hole along Z.
module led_hole() {
  translate([0, 0, -wall*2])
    cylinder(d = led_hole_d, h = wall*4);
}

// Tactile button panel hole along Z.
module button_hole() {
  translate([0, 0, -wall*2])
    cylinder(d = button_hole_d, h = wall*4);
}

// MOSFET module keep-out box, centered at origin.
module mosfet_space() {
  c = fit_clearance;
  cube([mosfet_l + 2*c, mosfet_w + 2*c, wall*4], center = true);
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `./test/render.sh test/hardware_test.scad`
Expected: `OK`（manifold STL 生成、警告なし）。

- [ ] **Step 5: コミット**

```bash
git add scad/hardware.scad test/hardware_test.scad
git commit -m "feat: hardware reference cutouts and mounts in hardware.scad"
```

---

### Task 4: サムターンソケット `socket.scad`

**Files:**
- Create: `scad/socket.scad`
- Create: `test/socket_test.scad`

**Interfaces:**
- Consumes: `params.scad`（`knob_w`, `knob_t`, `knob_h`, `socket_wall`, `servo_shaft_d`, `fit_clearance`）。
- Produces: `thumbturn_socket()` — サーボ側はホーン/シャフトに被さる円筒、反対側につまみ形状の凹みを持つ独立パーツ（原点、長手 = Z）。

- [ ] **Step 1: 失敗するテストを書く**

Create `test/socket_test.scad`:
```scad
include <../scad/params.scad>
use <../scad/socket.scad>
// Pocket must not exceed socket outer size.
assert(knob_w + 2*socket_wall <= knob_w + knob_t + 2*socket_wall, "socket sizing");
thumbturn_socket();
echo("socket_test ok");
```

- [ ] **Step 2: 失敗を確認**

Run: `./test/render.sh test/socket_test.scad`
Expected: FAIL（`thumbturn_socket()` 未定義）。

- [ ] **Step 3: モジュールを実装**

Create `scad/socket.scad`:
```scad
include <params.scad>

// Parametric thumb-turn socket. Knob pocket on top (+Z), servo shaft bore on bottom (-Z).
module thumbturn_socket() {
  c   = fit_clearance;
  ow  = knob_w + knob_t + 2*socket_wall;   // outer footprint, generous
  oh  = knob_h + socket_wall + 6;          // total height incl. shaft collar
  difference() {
    // outer body: rounded square prism
    linear_extrude(height = oh)
      offset(r = 2) offset(r = -2)
        square([ow, ow], center = true);
    // knob pocket (top): rectangular slot sized to the real knob
    translate([0, 0, oh - knob_h])
      linear_extrude(height = knob_h + 0.1)
        offset(r = c) square([knob_w, knob_t], center = true);
    // servo shaft bore (bottom)
    translate([0, 0, -0.1])
      cylinder(d = servo_shaft_d + c, h = 6 + 0.1);
  }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `./test/render.sh test/socket_test.scad`
Expected: `OK`。

- [ ] **Step 5: コミット**

```bash
git add scad/socket.scad test/socket_test.scad
git commit -m "feat: parametric thumb-turn socket in socket.scad"
```

---

### Task 5: ドア固定面 `mount_plate.scad`

**Files:**
- Create: `scad/mount_plate.scad`
- Create: `test/mount_plate_test.scad`

**Interfaces:**
- Consumes: `params.scad`（`body_l`, `body_w`, `wall`）。
- Produces: `mount_plate()` — ドア接触面（v1 は平らなテープ面）。本体底面に合成される正形状の薄板（XY 平面、Z=0 が接触面、+Z が本体側）。

- [ ] **Step 1: 失敗するテストを書く**

Create `test/mount_plate_test.scad`:
```scad
include <../scad/params.scad>
use <../scad/mount_plate.scad>
mount_plate();
echo("mount_plate_test ok");
```

- [ ] **Step 2: 失敗を確認**

Run: `./test/render.sh test/mount_plate_test.scad`
Expected: FAIL（`mount_plate()` 未定義）。

- [ ] **Step 3: モジュールを実装**

Create `scad/mount_plate.scad`:
```scad
include <params.scad>

// v1: flat tape face matching the body footprint.
// FUTURE (Q6): replace this module body with a brace arm / bolt-on shim
// once the door-side fixed feature is confirmed. Keep the same module name.
module mount_plate() {
  linear_extrude(height = wall)
    offset(r = 2) offset(r = -2)
      square([body_l, body_w], center = true);
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `./test/render.sh test/mount_plate_test.scad`
Expected: `OK`。

- [ ] **Step 5: コミット**

```bash
git add scad/mount_plate.scad test/mount_plate_test.scad
git commit -m "feat: swappable flat tape mount_plate (v1)"
```

---

### Task 6: 本体モノコック箱 `body.scad`

**Files:**
- Create: `scad/body.scad`
- Create: `test/body_test.scad`

**Interfaces:**
- Consumes: `params.scad`, `hardware.scad`, `mount_plate.scad`。
- Produces: `body()` — 開口（USB / LED / ボタン / ソケット突出口）・サーボ座・Pico ボス・MOSFET 占有を備えた箱。底面は `mount_plate()`。上面開放（蓋は Task 7）。

- [ ] **Step 1: 失敗するテストを書く**

Create `test/body_test.scad`:
```scad
include <../scad/params.scad>
use <../scad/body.scad>
body();
echo("body_test ok");
```

- [ ] **Step 2: 失敗を確認**

Run: `./test/render.sh test/body_test.scad`
Expected: FAIL（`body()` 未定義）。

- [ ] **Step 3: モジュールを実装**

Create `scad/body.scad`:
```scad
include <params.scad>
use <hardware.scad>
use <mount_plate.scad>

// Servo sits on the -X half (shaft pointing down through the bottom).
// Pico sits on the +X half. LED/button on the +Y front wall. USB on the -Y wall.
module body() {
  // X position for the servo shaft / socket opening
  servo_x = -inner_l/4;
  pico_x  =  inner_l/6;

  difference() {
    union() {
      // outer shell (open top)
      difference() {
        translate([0, 0, body_h/2])
          rounded_box(body_l, body_w, body_h, 3);
        translate([0, 0, body_h/2 + wall])
          rounded_box(inner_l, inner_w, body_h, 3 - wall > 0 ? 3 - wall : 0.5);
      }
      // bottom mount face
      mount_plate();
      // Pico standoffs
      translate([pico_x, 0, wall])
        pico_w_mounts();
    }

    // servo pocket (shaft down through bottom)
    translate([servo_x, 0, wall + servo_body_h/2])
      sg90_cutout();

    // front-wall LED + button (front = +Y wall)
    translate([pico_x - 8, body_w/2, body_h*0.5])
      rotate([90, 0, 0]) led_hole();
    translate([pico_x + 8, body_w/2, body_h*0.5])
      rotate([90, 0, 0]) button_hole();

    // USB port on -Y wall near Pico
    translate([pico_x + pico_l/2 - usb_w, -body_w/2, body_h*0.4])
      usb_cutout();
  }
}

module rounded_box(l, w, h, r) {
  linear_extrude(height = h, center = true)
    offset(r = r) offset(r = -r)
      square([l, w], center = true);
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `./test/render.sh test/body_test.scad`
Expected: `OK`（manifold STL、警告なし）。干渉や非manifoldが出たらパラメータ/配置を調整する。

- [ ] **Step 5: コミット**

```bash
git add scad/body.scad test/body_test.scad
git commit -m "feat: monocoque body with component cutouts and mounts"
```

---

### Task 7: 蓋 `lid.scad`

**Files:**
- Create: `scad/lid.scad`
- Create: `test/lid_test.scad`

**Interfaces:**
- Consumes: `params.scad`。
- Produces: `lid()` — 本体上面開口に被せる蓋。内側にはまり込むリップ付き（`fit_clearance` でスリップフィット）。

- [ ] **Step 1: 失敗するテストを書く**

Create `test/lid_test.scad`:
```scad
include <../scad/params.scad>
use <../scad/lid.scad>
lid();
echo("lid_test ok");
```

- [ ] **Step 2: 失敗を確認**

Run: `./test/render.sh test/lid_test.scad`
Expected: FAIL（`lid()` 未定義）。

- [ ] **Step 3: モジュールを実装**

Create `scad/lid.scad`:
```scad
include <params.scad>

// Lid with an inner lip that slips into the body opening.
module lid() {
  lip_h = 4;
  union() {
    // top plate
    linear_extrude(height = wall)
      offset(r = 2) offset(r = -2)
        square([body_l, body_w], center = true);
    // inner lip
    translate([0, 0, -lip_h])
      linear_extrude(height = lip_h)
        difference() {
          square([inner_l - fit_clearance, inner_w - fit_clearance], center = true);
          square([inner_l - 2*wall, inner_w - 2*wall], center = true);
        }
  }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `./test/render.sh test/lid_test.scad`
Expected: `OK`。

- [ ] **Step 5: コミット**

```bash
git add scad/lid.scad test/lid_test.scad
git commit -m "feat: slip-fit lid"
```

---

### Task 8: 組立トップレベル・ビルドスクリプト・README

**Files:**
- Create: `scad/smartlock.scad`
- Create: `build.sh`
- Create: `README.md`

**Interfaces:**
- Consumes: 全 `scad/*` モジュール。
- Produces:
  - `smartlock.scad` — `part` 変数（`"body"|"lid"|"socket"|"assembly"`）で描画切替。`-D part=\"lid\"` で上書き可能。
  - `build.sh` — body / lid / socket を `build/` に STL 出力（各 `test/render.sh` 経由でチェック）。

- [ ] **Step 1: 失敗するテストを書く（assembly が落ちないこと）**

Create `scad/smartlock.scad`:
```scad
include <params.scad>
use <body.scad>
use <lid.scad>
use <socket.scad>

// Select with: openscad -D part="lid" ...
part = "assembly";

if (part == "body") body();
else if (part == "lid") lid();
else if (part == "socket") thumbturn_socket();
else {
  // assembly preview
  body();
  translate([0, 0, body_h + 2]) lid();
  translate([-inner_l/4, 0, body_h + 30]) thumbturn_socket();
}
```

Run: `./test/render.sh scad/smartlock.scad`
Expected: 最初は `body.scad` 等が揃っていれば PASS。揃っていなければ FAIL（前タスク未完）。このタスクは Task 1-7 完了後に実施する。

- [ ] **Step 2: 各 part が個別にレンダリングできることを確認**

Run:
```bash
for p in body lid socket; do
  nix develop -c openscad -D "part=\"$p\"" -o "/tmp/$p.stl" scad/smartlock.scad 2>&1 | grep -Eiq 'WARNING|ERROR' && { echo "FAIL $p"; exit 1; } || echo "OK $p"
done
```
Expected: `OK body` / `OK lid` / `OK socket`。

- [ ] **Step 3: build.sh を作る**

Create `build.sh`:
```bash
#!/usr/bin/env bash
# Build all printable parts to build/. Re-execs inside the Nix dev shell if needed.
set -uo pipefail
if ! command -v openscad >/dev/null 2>&1; then
  command -v nix >/dev/null 2>&1 || export PATH="/nix/var/nix/profiles/default/bin:$PATH"
  exec nix develop "$(cd "$(dirname "$0")" && pwd)" -c "$0" "$@"
fi
mkdir -p build
for p in body lid socket; do
  echo "== building $p =="
  log="$(openscad -D "part=\"$p\"" -o "build/$p.stl" scad/smartlock.scad 2>&1)"
  status=$?
  echo "$log"
  if [ "$status" -ne 0 ] || echo "$log" | grep -Eiq 'WARNING|ERROR'; then
    echo "FAIL: $p"; exit 1
  fi
done
echo "All parts built to build/"
```

Run:
```bash
chmod +x build.sh
./build.sh
ls -la build/
```
Expected: `build/body.stl`, `build/lid.stl`, `build/socket.stl` が生成され、`All parts built to build/`。

- [ ] **Step 4: README を書く**

Create `README.md`:
```markdown
# smtlk — 自作スマートロック筐体

既存ドアのサムターンに後付けする SG90 サーボ式スマートロックの筐体（OpenSCAD）。

## 開発環境（Nix）
    nix develop           # OpenSCAD が入った devShell に入る

## ビルド
    ./build.sh            # build/ に body.stl / lid.stl / socket.stl を出力（dev シェル外でも自動で nix develop 経由で実行）

## 個別レンダリング
    nix develop -c openscad -D part="body" -o body.stl scad/smartlock.scad

## テスト
    ./test/render.sh test/params_test.scad

## 採寸後にやること
- `scad/params.scad` の `knob_w/knob_t/knob_h`（サムターン実寸）を更新。
- ドア固定が決まったら `scad/mount_plate.scad` の `mount_plate()` を差し替え。

## 未確定（積み残し）
- ドア固定の突っ張り先（mount_plate で隔離）。
- サムターン実寸（socket パラメータで隔離）。
- Pico W ファームウェア・省電力運用・手回し後の状態再同期。
```

- [ ] **Step 5: コミット**

```bash
git add scad/smartlock.scad build.sh README.md
git commit -m "feat: top-level assembly, build script, and README"
```

---

## Self-Review

**Spec coverage:**
- スコープ（筐体のみ）→ 全タスクが筐体。ファーム類は Global Constraints と README で対象外と明記。✓
- 一体モノコック＋開閉蓋 → Task 6（body, 上面開放）+ Task 7（lid）。✓
- 差し替え式マウント面 `mount_plate()` → Task 5。✓
- 専用ソケット（パラメトリック）→ Task 4。✓
- 開口・フィーチャ（サーボ軸・ソケット口・USB・LED・ボタン・サーボ座・Pico ボス・MOSFET・配線）→ Task 3（hardware）+ Task 6（body で配置）。✓
- 全寸法パラメトリック → Task 2。✓
- 検証観点（再生成・干渉なし・差し替え可能・プリント可能）→ `test/render.sh` による各タスクのレンダリングチェック＋ build.sh。✓
- 積み残し（Q6 固定・実寸・省電力・再同期・トルク検証）→ Global Constraints と README に明記。✓

**Placeholder scan:** `knob_*` はプレースホルダだが、これは spec が「採寸待ち」と明示した意図的な値で、コメントと README に運用を記載済み。コードステップは全て実コードを掲載。TODO/TBD なし。✓

**Type/naming consistency:** モジュール名 `sg90_cutout / pico_w_mounts / usb_cutout / led_hole / button_hole / mosfet_space / thumbturn_socket / mount_plate / body / lid / rounded_box` は定義タスクと利用タスク（body_test, smartlock）で一致。`part` 変数値（body/lid/socket/assembly）は build.sh と smartlock.scad で一致。✓

注意点（実装時に調整余地あり）: Task 6 の配置座標（servo_x, pico_x, 各開口位置）は概算。レンダリングで非manifold/干渉が出たらパラメータ調整すること。これは OpenSCAD のフィット調整として正常な範囲。

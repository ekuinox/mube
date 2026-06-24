# スマートロック筐体 v2（実採寸反映）実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 実採寸（台形サムターン・座 Ø46・左30/下40 クリアランス）を OpenSCAD モデルに反映し、ソケットの台形化・本体の再レイアウト・座位置決め＋下方向ブレースの「フィット確認ビルド」を作る。

**Architecture:** 原点＝サムターン/サーボ軸（座の中心）に再定義。本体は右(+X)・上(+Y)へ展開し、軸は左下寄りに置いて -X≤clear_left, -Y≤clear_down を守る。全寸法は params.scad に集約し、クリアランス違反は assert で弾く。固定詳細は mount_plate() に隔離（座ぐり＋下方向スタブ）。

**Tech Stack:** OpenSCAD 2021.01（devShell: openscad/uv/cloudflared）、`./test/render.sh` ハーネス（exit!=0 または WARNING/ERROR で失敗、manifold STL 必須）、git。

## Global Constraints

- 単位は mm。寸法は params.scad の変数を使い、ハードコードしない（slop 0.1 等は可）。
- 原点 = サムターン/サーボ回転軸（座中心）。サーボ出力軸はこの原点に同軸。
- クリアランス: 軸から -X(左) ≤ `clear_left=30`、-Y(下) ≤ `clear_down=40`。+X(右)・+Y(上)は自由。
- サムターンは台形: 幅 `knob_w_base=28`(根元)→`knob_w_top=25`(先端)、厚み `knob_t=3`、突き出し `knob_h=11`、係合 `knob_engage=10`。
- 回転 90°（縦=解錠/横=施錠）。角度割り当てはファーム側（範囲外）。
- 座 Ø46 は回転対称ゆえ位置決め専用（トルク反力は受けない）。トルク対策は次フェーズ（現物合わせ）。
- 全 `.scad` は manifold STL を WARNING/ERROR ゼロで出すこと。内部部品の座標は近似（実機フィットで調整可）。

---

## File Structure

- `scad/params.scad` — 台形サムターン寸法、クリアランス、軸基準の内部 extents と派生寸法、clearance assert。
- `scad/socket.scad` — `thumbturn_socket()` を台形ポケット化。
- `scad/body.scad` — 原点=軸の「左下アンカー＋右上展開」レイアウトに再構成。
- `scad/mount_plate.scad` — 座位置決め穴（Ø46+clr）＋下方向ブレーススタブ。
- `test/params_test.scad`, `test/socket_test.scad` — 新パラメータに追従。
- `test/body_test.scad`, `test/mount_plate_test.scad` — レンダリング確認（変更なしで追従）。

各タスク完了時に全テストが緑であること（タスク間で knob_w を一時保持して互換を保つ）。

---

### Task 1: params.scad を v2 寸法・レイアウトに更新

**Files:**
- Modify: `scad/params.scad`
- Modify: `test/params_test.scad`

**Interfaces:**
- Produces（新規/変更グローバル）: `knob_w_base=28`, `knob_w_top=25`, `knob_t=3`, `knob_h=11`, `knob_engage=10`, `clear_left=30`, `clear_down=40`, `rosette_d=46`, `ext_left=20`, `ext_right=30`, `ext_down=14`, `ext_up=64`, `inner_l/inner_w/inner_h`, `body_l/body_w/body_h`, `center_x`, `center_y`。`knob_w=28` は socket タスクまで一時保持。

- [ ] **Step 1: 失敗するテストを書く**

`test/params_test.scad` を以下に置き換え:
```scad
include <../scad/params.scad>
assert(body_l > 0 && body_w > 0 && body_h > 0, "positive body dims");
assert(ext_left <= clear_left, "left extent within door clearance");
assert(ext_down <= clear_down, "down extent within handle clearance");
assert(knob_w_top <= knob_w_base, "knob tapers base->top");
assert(knob_engage < knob_h, "engagement shallower than protrusion");
echo("params_test ok");
sphere(0.01, $fn = 3);
```

- [ ] **Step 2: 失敗を確認**

Run: `./test/render.sh test/params_test.scad`
Expected: FAIL（`ext_left` などが未定義で assert/参照エラー → exit 非0）。

- [ ] **Step 3: params.scad を更新**

`scad/params.scad` の「Thumb-turn knob」節と「Derived enclosure dimensions」節、末尾の Sanity checks を、以下に置き換える（Print/fit・SG90・Pico・USB・Indicators・MOSFET の各節はそのまま残す）:
```scad
// --- Door-fit clearances from the thumb-turn axis (origin = rosette center) ---
clear_left  = 30;   // -X to door edge/frame
clear_down  = 40;   // -Y to door handle
rosette_d   = 46;   // circular escutcheon diameter (registration only)

// --- Thumb-turn knob (measured; trapezoid) ---
knob_w_base = 28;   // width at the door (base, wider)
knob_w_top  = 25;   // width at the tip (narrower)
knob_t      = 3;    // thickness
knob_h      = 11;   // protrusion from the door
knob_engage = 10;   // socket engagement depth (< knob_h)
socket_wall = 2.0;
knob_w      = knob_w_base;  // TEMP: removed in the socket task; keeps old socket.scad valid

// --- Interior extents from the axis at origin (mm) ---
ext_left  = 20;   // -X toward frame; must be <= clear_left
ext_right = 30;   // +X free
ext_down  = 14;   // -Y toward handle; must be <= clear_down
ext_up    = 64;   // +Y free; houses the Pico

inner_l = ext_left + ext_right;          // 50
inner_w = ext_down + ext_up;             // 78
inner_h = servo_body_h + pico_boss_h + 6;

body_l = inner_l + 2*wall;
body_w = inner_w + 2*wall;
body_h = inner_h + 2*wall;

// body center relative to the axis (axis sits low-left, body grows up-right)
center_x = (ext_right - ext_left) / 2;   // 5
center_y = (ext_up - ext_down) / 2;      // 25

// --- Sanity / clearance checks ---
assert(wall > 0, "wall must be positive");
assert(fit_clearance >= 0, "fit_clearance must be >= 0");
assert(ext_left <= clear_left, "left extent exceeds door clearance");
assert(ext_down <= clear_down, "down extent exceeds handle clearance");
assert(knob_w_top <= knob_w_base, "knob tapers base->top");
assert(knob_engage < knob_h, "engagement shallower than protrusion");
```

Note: 旧 `knob_w/knob_t/knob_h` 行と旧 `inner_l/inner_w/inner_h`・旧 sanity assert（`inner_l >= pico_l` 等）は上記で置き換え/削除する。

- [ ] **Step 4: テストが通ることを確認**

Run: `./test/render.sh test/params_test.scad`
Expected: `OK`（assert 全通過）。

- [ ] **Step 5: 既存テストが壊れていないか確認**

Run:
```bash
for t in test/hardware_test.scad test/socket_test.scad test/mount_plate_test.scad test/lid_test.scad; do ./test/render.sh "$t"; done
```
Expected: 全て `OK`（`knob_w` 一時保持で socket 系も緑、body は別タスクで触るが現状維持）。

- [ ] **Step 6: コミット**

```bash
git add scad/params.scad test/params_test.scad
git commit -m "feat: params v2 — trapezoid knob, door clearances, axis-anchored extents"
```

---

### Task 2: socket.scad を台形ポケット化

**Files:**
- Modify: `scad/socket.scad`
- Modify: `test/socket_test.scad`
- Modify: `scad/params.scad`（一時 `knob_w` を削除）

**Interfaces:**
- Consumes: `knob_w_base`, `knob_w_top`, `knob_t`, `knob_engage`, `socket_wall`, `servo_shaft_d`, `fit_clearance`。
- Produces: `thumbturn_socket()`（台形ポケット：開口=根元28、奥=先端25 にすぼまる。深さ `knob_engage`。底にサーボ軸穴）。

- [ ] **Step 1: 失敗するテストを書く**

`test/socket_test.scad` を以下に置き換え:
```scad
include <../scad/params.scad>
use <../scad/socket.scad>
// outer footprint must exceed the widest knob dimension with positive walls
assert(knob_w_base + 2*fit_clearance < knob_w_base + knob_t + 2*socket_wall, "pocket fits outer (Y)");
assert(knob_t + 2*fit_clearance < knob_w_base + knob_t + 2*socket_wall, "pocket fits outer (X)");
thumbturn_socket();
echo("socket_test ok");
```

- [ ] **Step 2: 失敗を確認**

Run: `./test/render.sh test/socket_test.scad`
Expected: 現状の socket.scad は通るが、まず Step 3 で `knob_w` を params から消すと `socket.scad`（旧 `knob_w` 参照）が壊れる。手順上は Step 3 を先に行い、その後この test で FAIL→GREEN を確認する。
（TDD 確認のため Step 3 実施直後に Run: `./test/render.sh test/socket_test.scad` → FAIL（`knob_w` undefined）を確認する。）

- [ ] **Step 3: socket.scad を台形化し、params から一時 knob_w を削除**

`scad/socket.scad` を以下に置き換え:
```scad
include <params.scad>

// Thumb-turn socket. Knob pocket on top (+Z) tapers from the tip (deep) to the
// base (opening); servo shaft bore on the bottom (-Z).
module thumbturn_socket() {
  c   = fit_clearance;
  ow  = knob_w_base + knob_t + 2*socket_wall;   // outer footprint (use widest)
  oh  = knob_engage + socket_wall + 6;          // total height incl. shaft collar
  difference() {
    // outer body: rounded square prism
    linear_extrude(height = oh)
      offset(r = 2) offset(r = -2)
        square([ow, ow], center = true);
    // tapered knob pocket: base (knob_w_base) at the top opening, narrowing to
    // the tip (knob_w_top) at depth. Built tip-square at bottom, scaled up to base.
    translate([0, 0, oh - knob_engage])
      linear_extrude(height = knob_engage + 0.1, scale = [knob_w_base/knob_w_top, 1])
        offset(r = c) square([knob_w_top, knob_t], center = true);
    // servo shaft bore (bottom)
    translate([0, 0, -0.1])
      cylinder(d = servo_shaft_d + c, h = 6 + 0.1);
  }
}
```

`scad/params.scad` から一時行 `knob_w = knob_w_base;  // TEMP...` を削除する。

- [ ] **Step 4: テストが通ることを確認**

Run: `./test/render.sh test/socket_test.scad`
Expected: `OK`、`Simple: yes`（manifold）。

- [ ] **Step 5: params_test も緑のままか確認**

Run: `./test/render.sh test/params_test.scad`
Expected: `OK`（knob_w 削除の影響なし）。

- [ ] **Step 6: コミット**

```bash
git add scad/socket.scad test/socket_test.scad scad/params.scad
git commit -m "feat: trapezoidal socket pocket (28->25 x 3), drop temp knob_w"
```

---

### Task 3: body.scad を軸アンカー・右上展開レイアウトに再構成

**Files:**
- Modify: `scad/body.scad`
- Test: `test/body_test.scad`（変更なし、レンダリング確認に使用）

**Interfaces:**
- Consumes: `params.scad`（`ext_*`, `center_x/y`, `inner_*`, `body_*`, `box_corner_r`, `wall`, `led_btn_spacing`）, `hardware.scad`（`sg90_cutout`, `pico_w_mounts`, `usb_cutout`, `led_hole`, `button_hole`, `mosfet_space`）, `mount_plate.scad`（`mount_plate`）。
- Produces: `body()`（原点=サーボ軸、本体中心を `(center_x, center_y)` にオフセット）, `rounded_box(l,w,h,r)`。

**重要（v1 と同様）:** 内部部品の座標は近似。`./test/render.sh test/body_test.scad` は **manifold STL・WARNING/ERROR ゼロ（`Simple: yes`）** が合格基準。干渉/非manifold が出たら、設計意図（サーボ軸=原点で底面貫通、Pico は +Y 上方、LED/ボタンは +X 壁、USB は +Y 上端壁、MOSFET は +X 側の空き）を保ちつつ座標を調整すること。クリアランス（`ext_left/ext_down`）は params の assert が守る。

- [ ] **Step 1: 失敗するテスト状態を作る（リネーム前提の確認）**

このタスクは body() を書き換えるだけなので、先に現行が緑であることを確認:
Run: `./test/render.sh test/body_test.scad`
Expected: 現行 body は通る（`OK`）。書き換え後に再度確認する（下記 Step 3）。

- [ ] **Step 2: body.scad を置き換え**

`scad/body.scad` を以下に置き換え:
```scad
include <params.scad>
use <hardware.scad>
use <mount_plate.scad>

// Origin = thumb-turn / servo axis (center of the door rosette).
// The body center is offset to (center_x, center_y): the axis sits low-left so
// -X stays within clear_left and -Y within clear_down; the body grows +X/+Y.
module body() {
  // Servo on the axis; shaft points down through the bottom.
  servo_x = 0;
  servo_y = 0;

  // Pico stacked above the servo in free +Y space; long axis along Y
  // (rotate the X-oriented pico_w_mounts by 90 deg).
  pico_x = 0;
  pico_y = servo_body_w/2 + 6 + pico_l/2;

  // MOSFET keep-out on the free +X side, clear of servo and Pico.
  mosfet_x = ext_right - mosfet_l/2 - 2;
  mosfet_y = center_y;

  // LED + button on the +X right wall, spaced around center_y.
  wall_x = center_x + inner_l/2;     // right interior wall plane
  led_y  = center_y - led_btn_spacing/2;
  btn_y  = center_y + led_btn_spacing/2;

  // USB on the +Y top wall, aligned to the Pico's top end.
  wall_y_top = center_y + inner_w/2;

  difference() {
    union() {
      // outer shell (open top), centered at (center_x, center_y)
      difference() {
        translate([center_x, center_y, body_h/2])
          rounded_box(body_l, body_w, body_h, box_corner_r);
        translate([center_x, center_y, body_h/2 + wall])
          rounded_box(inner_l, inner_w, body_h,
                      box_corner_r - wall > 0 ? box_corner_r - wall : 0.5);
      }
      // bottom mount face (also centered at center_x/center_y internally)
      mount_plate();
      // Pico standoffs, long axis along Y
      translate([pico_x, pico_y, wall*0.5])
        rotate([0, 0, 90]) pico_w_mounts();
    }

    // servo pocket at the axis (shaft down through the bottom)
    translate([servo_x, servo_y, wall + servo_body_h/2])
      sg90_cutout();

    // MOSFET floor clearance (lifted off the floor like v1)
    translate([mosfet_x, mosfet_y, wall + wall*2])
      mosfet_space();

    // LED + button on the +X right wall (pierce along X)
    translate([wall_x, led_y, body_h*0.5])
      rotate([0, 90, 0]) led_hole();
    translate([wall_x, btn_y, body_h*0.5])
      rotate([0, 90, 0]) button_hole();

    // USB on the +Y top wall (pierce along Y), at the Pico's top end
    translate([pico_x, wall_y_top, body_h*0.4])
      usb_cutout();
  }
}

module rounded_box(l, w, h, r) {
  linear_extrude(height = h, center = true)
    offset(r = r) offset(r = -r)
      square([l, w], center = true);
}
```

- [ ] **Step 3: レンダリングして manifold を確認（必要なら座標調整）**

Run: `./test/render.sh test/body_test.scad`
Expected: `OK`、`Simple: yes`、WARNING/ERROR なし。
もし WARNING（非manifold/empty 等）や干渉が出たら、上記「重要」の方針に従って `pico_y` / `mosfet_x,y` / 各 wall 開口位置を調整して再レンダリングし、`Simple: yes` を得てからコミットする。調整内容は report に記載する。

- [ ] **Step 4: 軸クリアランスの目視確認**

Run:
```bash
nix develop "$(git rev-parse --show-toplevel)" -c openscad -o /tmp/body_v2.stl scad/body_test.scad 2>/dev/null || true
echo "left extent = ext_left, down extent = ext_down (asserted in params)"
```
Expected: params の assert により `ext_left<=clear_left` / `ext_down<=clear_down` は保証済み（追加作業不要、確認のみ）。

- [ ] **Step 5: コミット**

```bash
git add scad/body.scad
git commit -m "feat: re-layout body around the thumb-turn axis (low-left anchor, grows up-right)"
```

---

### Task 4: mount_plate.scad に座位置決め＋下方向ブレースを追加

**Files:**
- Modify: `scad/mount_plate.scad`
- Modify: `scad/params.scad`（ブレース用パラメータ追加）
- Test: `test/mount_plate_test.scad`（変更なし、レンダリング確認）

**Interfaces:**
- Consumes: `params.scad`（`center_x/y`, `body_l/body_w`, `wall`, `rosette_d`, `fit_clearance`, `clear_down`, `ext_down`, `brace_stub_w`）。
- Produces: `mount_plate()`（本体フットプリントのフラット面＋原点の座位置決め穴＋下方向ブレーススタブ）。

- [ ] **Step 1: params にブレース用パラメータを追加**

`scad/params.scad` の clearances 節に追記:
```scad
brace_stub_w = 12;  // width of the downward torque-brace stub (toward the handle)
```

- [ ] **Step 2: 失敗するテストを確認（現行 mount_plate は新パラメータ未使用）**

Run: `./test/render.sh test/mount_plate_test.scad`
Expected: 現行は通る。Step 3 置換後に再確認する。

- [ ] **Step 3: mount_plate.scad を置き換え**

`scad/mount_plate.scad` を以下に置き換え:
```scad
include <params.scad>

// Fit-check mount face:
//  - flat tape face over the body footprint (centered at the body center)
//  - rosette registration hole at the axis (origin) — Ø46+clearance through the
//    plate; the raised escutcheon pokes through and sets coaxial position
//    (circular => registration only, no torque reaction)
//  - downward brace stub toward the door handle (-Y); a fit-check placeholder
//    for the torque reaction, refined against the real handle next phase
// FUTURE (Q6): replace the brace stub with the measured handle/frame engagement.
module mount_plate() {
  difference() {
    union() {
      // flat footprint
      translate([center_x, center_y, 0])
        linear_extrude(height = wall)
          offset(r = 2) offset(r = -2)
            square([body_l, body_w], center = true);
      // downward brace stub: from the bottom wall toward the handle, stopping
      // 4mm short of clear_down. Overlaps the floor by 1mm to fuse.
      translate([-brace_stub_w/2, -(clear_down - 4), 0])
        cube([brace_stub_w, (clear_down - 4) - ext_down + 1, wall]);
    }
    // rosette registration / clearance hole at the axis
    translate([0, 0, -0.1])
      cylinder(d = rosette_d + fit_clearance, h = wall + 0.2);
  }
}
```

- [ ] **Step 4: レンダリングして manifold を確認**

Run: `./test/render.sh test/mount_plate_test.scad`
Expected: `OK`、`Simple: yes`、WARNING/ERROR なし。
（非manifold が出たらブレーススタブの床オーバーラップ量や座ぐり径を調整して `Simple: yes` を得る。）

- [ ] **Step 5: body も緑のままか確認（mount_plate を内包するため）**

Run: `./test/render.sh test/body_test.scad`
Expected: `OK`、`Simple: yes`。

- [ ] **Step 6: コミット**

```bash
git add scad/mount_plate.scad scad/params.scad
git commit -m "feat: rosette registration hole + downward brace stub (fit-check mount)"
```

---

### Task 5: 全パーツ検証と README/spec の寸法追記

**Files:**
- Modify: `README.md`
- Test: 全 `.scad`（レンダリング確認）

**Interfaces:**
- Consumes: 既存の `build.sh` / `smartlock.scad`（変更不要、`part` 切替で全パーツを出す）。

- [ ] **Step 1: 全テスト＋全パーツのレンダリングを確認**

Run:
```bash
for t in test/params_test.scad test/hardware_test.scad test/socket_test.scad test/mount_plate_test.scad test/body_test.scad test/lid_test.scad scad/smartlock.scad; do ./test/render.sh "$t"; done
./build.sh
```
Expected: 全 `OK`／`Simple: yes`、`./build.sh` が `All parts built to build/` を表示し body/lid/socket STL を生成。

- [ ] **Step 2: README に v2 の寸法メモを追記**

`README.md` の「採寸後にやること」節を、確定値を反映した内容に置き換える:
```markdown
## 採寸（反映済み・v2）
- サムターン: 台形 幅 28(根元)→25(先端) × 厚み 3、突き出し 11（`params.scad` の `knob_*`）。
- 座 Ø46（`rosette_d`）= 位置決め専用（回転対称ゆえトルクは受けない）。
- クリアランス: 左 30 / 下 40（`clear_left` / `clear_down`）。本体は右・上へ展開。

## 次フェーズ（トルク対策・現物合わせ）
- `mount_plate()` の下方向ブレーススタブを、実ノブ/枠の形状に合わせて確定する。
- 必要ならドア写真を `docs/superpowers/assets/` に追加。
```

- [ ] **Step 3: コミット**

```bash
git add README.md
git commit -m "docs: record v2 measurements and next-phase mounting note"
```

---

## Self-Review

**Spec coverage（v2 spec 各項目 → タスク）:**
- §3.1 ソケット台形化 → Task 2 ✓
- §3.2 サーボ同軸・90° → Task 3（servo at origin, 底面貫通）✓（角度割当はファーム範囲外と明記）
- §3.3 本体サイズ・向き（左下アンカー/右上展開、clear_left/down 反映） → Task 1（extents+assert）+ Task 3（配置）✓
- §3.4 固定（座位置決め＋下方向スタブ、mount_plate 隔離） → Task 4 ✓
- §4 ファイル変更 → Task 1–5 が params/socket/body/mount_plate/tests/README を網羅 ✓
- §5 検証観点（全 manifold、台形ポケット、クリアランス内、座ぐり同軸、固定隔離） → 各 Task の render gate + Task 5 一括検証 ✓

**Placeholder scan:** TODO/TBD なし。各コードステップは実コードを掲載。内部座標の「近似・調整可」は v1 同様の正当な render-fit 指示で、プレースホルダではない。

**Type/naming consistency:** `knob_w_base/knob_w_top/knob_t/knob_h/knob_engage`、`clear_left/clear_down`、`ext_left/ext_right/ext_down/ext_up`、`center_x/center_y`、`rosette_d`、`brace_stub_w` は params 定義と socket/body/mount_plate の利用で一致。`thumbturn_socket / mount_plate / body / rounded_box / sg90_cutout / pico_w_mounts / usb_cutout / led_hole / button_hole / mosfet_space` は既存モジュール名と一致。一時 `knob_w` は Task 1 で追加し Task 2 で除去（タスク間の緑を維持）。

注意（実装時）: Task 3 の内部座標は近似。`Simple: yes` を満たすよう調整し、`ext_left/ext_down` の assert（クリアランス）は維持すること。`pico_w_mounts` は X 基準なので Pico を Y 長手にするため `rotate([0,0,90])` を付与している。`usb_cutout` は既定で Y 法線壁を貫くため +Y 上端壁ではそのまま、X 壁の `led_hole/button_hole` は `rotate([0,90,0])` で貫く。

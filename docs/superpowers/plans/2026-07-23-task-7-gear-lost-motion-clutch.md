# TASK-7 ギア伝達＋ロストモーション・フォーク 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 手動でサムターンを「掴んで回すだけ」にする。サーボとサムターンの剛結ソケットを、遊び付きフォークを持つリングギア＋オフセット配置のサーボ（平歯車 1 段）に置き換える。

**Architecture:** サーボはロゼット中心から `-30°` 方向（+X 寄り、-Y 側へ振る）へ 52.5mm オフセットし、駆動ギア（42T）→ 従動リングギア（28T、増速比 1.5）で伝達する。リングギアは下面のフォーク爪でノブ根元だけを押し、ペデスタルの下受けカラーで軸受けする（ノブ先端は露出）。ファームは動作後に毎回ニュートラル角へ退避してから給電断する。

**Tech Stack:** OpenSCAD（自作インボリュート平歯車）、Rust（mube-core / mube-firmware、Embassy）、bun スクリプト（render / clash）。

**Spec:** `docs/superpowers/specs/2026-07-23-task-7-gear-lost-motion-clutch-design.md`

## Global Constraints

- コマンドは全て `nix develop -c` を前置する（openscad / cargo / bun / just が非対話シェルの PATH に無い）。
- Rust 変更後はコミット前に `nix develop -c cargo host-test` を必ず通す。
- `enclosure/build/` と `*.stl` は派生物。コミットしない。
- キャリブ定数（`SERVO_MIN_US=1000` / `SERVO_MAX_US=2000`）は実機確定まで変更しない。低パルス側 1000µs はメカ端（実機確定 2026-07-19）。
- 印刷は A1 mini（0.4 ノズル）。小径縦穴は約 0.4mm 細く出る（既存 params のコメント参照）。
- コミットメッセージは日本語。既存の流儀（`TASK-7 ...:` 接頭辞など）に合わせる。
- 幾何の初期値は本計画の値を使い、実機・クーポンで確定するまで params のコメントに「暫定」と明記する。

## レイアウトの前提（全タスク共通の座標系）

プレート座標（`z=0` = プレート床下面、ドア面は `z=-mount_pad_t=-6`）。ノブは根元 `z=-6`、先端 `z=24`（`knob_h=30`）。

| 高さ帯 (z) | 部品 |
|---|---|
| 4 .. 12 | フォーク爪（ノブ根元へ 8mm 掛かり） |
| 6.4 .. 11 | ペデスタルの下受けカラー（軸受け） |
| 10 .. 15 | リングギア歯付き盤・駆動ギア（歯幅 5） |
| 15 .. 24 | ノブ先端の露出部（9mm。ここを指で掴む） |
| 21.9 .. 25.4 | サーボ天板（駆動ギア上のホーン嵌合から逆算） |

配置方向を `-30°` にする理由: `+X` 純方向は駆動ギア（先端半径 33）がブレッドボードポケット（y≥30.05、BB 上面 z≈14.4 とジャンパ線）に重なり、`-45°` はドアハンドルクリアランス（`clear_down=65`）を超える。`-30°` なら -Y 突出 ≈ 52.5·sin30 + 33 = 59.25 ≤ 65、+X 突出 ≈ 78.5 ≤ 86 で両方収まる。

---

### Task 1: mube-core にニュートラル角と押し切り角を追加

**Files:**
- Modify: `crates/mube-core/src/servo_math.rs`

**Interfaces:**
- Consumes: `crate::lock::LockState`（既存）
- Produces: `pub const fn pulse_us_neutral() -> u16`、既存 `pulse_us_for(state)` は「押し切り角」のパルスを返す（シグネチャ不変）

- [ ] **Step 1: 失敗するテストを書く**

`crates/mube-core/src/servo_math.rs` の `mod tests` に追加:

```rust
    #[test]
    fn neutral_between_push_angles() {
        // ニュートラルは両押し切りの間（フォーク退避位置）
        let lo = pulse_us_for(LockState::Unlocked).min(pulse_us_for(LockState::Locked));
        let hi = pulse_us_for(LockState::Unlocked).max(pulse_us_for(LockState::Locked));
        assert!(lo < pulse_us_neutral() && pulse_us_neutral() < hi);
    }

    #[test]
    fn neutral_pulse_value() {
        assert_eq!(pulse_us_neutral(), 1500);
    }
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `nix develop -c cargo host-test`
Expected: FAIL（`pulse_us_neutral` 未定義のコンパイルエラー）

- [ ] **Step 3: 実装**

`servo_math.rs` の定数ブロックを次に置き換え（値は現行と互換。方向反転・比の実機確定で変わるため「暫定」を明記）:

```rust
// --- キャリブ定数（実機合わせはここだけ触る） ---
// TASK-7 ギア化: サーボ→リングギアは外歯 1 段で回転が反転し、増速比(初期 1.5)ぶん
// フォークが大きく振れる。押し切り角・ニュートラル角は実機（ギアクーポン）で確定する。
// それまで LOCK/UNLOCK の押し切りは従来値を暫定で使う。
const SERVO_MIN_US: u16 = 1000; // フルストローク下端のパルス幅[µs]（メカ端。実機確定 2026-07-19）
const SERVO_MAX_US: u16 = 2000; // フルストローク上端のパルス幅[µs]（高パルス側の実測拡張は実機で）
const LOCK_PUSH_DEG: u16 = 180; // 施錠の押し切り角（暫定。ギア反転で入れ替わる可能性あり）
const UNLOCK_PUSH_DEG: u16 = 0; // 解錠の押し切り角（暫定）
const NEUTRAL_DEG: u16 = 90; // 動作後の退避角（フォーク爪がノブ経路外に立つ位置）
```

`pulse_us_for` の match を `LOCK_PUSH_DEG` / `UNLOCK_PUSH_DEG` に追従させ、以下を追加:

```rust
/// 退避（ニュートラル）位置のパルス幅[µs]。動作後は毎回ここへ戻して給電を断つ。
pub const fn pulse_us_neutral() -> u16 {
    pulse_us(NEUTRAL_DEG)
}
```

モジュール先頭の doc コメントも「押し切り → ニュートラル退避」の説明へ更新する。

- [ ] **Step 4: テストが通ることを確認**

Run: `nix develop -c cargo host-test`
Expected: PASS（既存 4 件 + 新規 2 件）

- [ ] **Step 5: コミット**

```bash
git add crates/mube-core/src/servo_math.rs
git commit -m "TASK-7 core: ニュートラル退避角と押し切り角を servo_math に追加"
```

---

### Task 2: ファームの動作シーケンスをニュートラル復帰付きに変更

**Files:**
- Modify: `crates/mube-firmware/src/servo.rs`

**Interfaces:**
- Consumes: `mube_core::servo_math::{pulse_us_for, pulse_us_neutral}`（Task 1）
- Produces: `Servo::move_to(&mut self, state: LockState)`（シグネチャ不変。呼び出し側の変更なし）

- [ ] **Step 1: `move_to` をシーケンス化**

`servo.rs` の `move_to` を置き換え、パルス送出を private ヘルパへ抽出:

```rust
    /// ワンショット駆動: 給電 → 押し切り → ニュートラル退避 → PWM 停止 → 給電断。
    /// 退避により爪がノブの回転経路から外れ、手動操作がサーボに触れない。
    pub async fn move_to(&mut self, state: LockState) {
        self.gate.set_high(); // Q1 ON = サーボに給電
        self.pulse(pulse_us_for(state)).await; // 押し切り
        self.pulse(pulse_us_neutral()).await; // ニュートラル退避
        self.cfg.enable = false;
        self.pwm.set_config(&self.cfg); // PWM 停止
        self.gate.set_low(); // 給電断（唸り・消費電力・寿命対策）
    }

    /// 指定パルス幅を送出して整定を待つ。
    async fn pulse(&mut self, us: u16) {
        self.cfg.compare_b = us;
        self.cfg.enable = true;
        self.pwm.set_config(&self.cfg);
        Timer::after(Duration::from_millis(SETTLE_MS)).await;
    }
```

use 行に `pulse_us_neutral` を追加。ファイル先頭 doc コメントの「給電 → 目標角 → 整定 → 給電断」をニュートラル退避込みの記述へ更新。`SETTLE_MS` のコメントに「移動量が増えたため実機で不足なら延長」と追記。

- [ ] **Step 2: ビルド確認**

Run: `nix develop -c cargo check -p mube-firmware --target thumbv6m-none-eabi`
Expected: PASS（CYW43 ブロブ未取得で include_bytes エラーになる場合は先に `nix develop -c just firmware` でブロブ取得込みのビルドを回す）

- [ ] **Step 3: host テストのリグレッション確認**

Run: `nix develop -c cargo host-test`
Expected: PASS

- [ ] **Step 4: コミット**

```bash
git add crates/mube-firmware/src/servo.rs
git commit -m "TASK-7 firmware: 動作後にニュートラルへ退避してから給電断するシーケンスに変更"
```

---

### Task 3: params.scad にギア・フォーク定数と整合チェックを追加

**Files:**
- Modify: `enclosure/models/params.scad`

**Interfaces:**
- Produces: 後続タスクが参照する定数一式（下記コードの名前がそのまま公開インターフェース）

- [ ] **Step 1: 定数ブロックを追加**

`params.scad` の「--- Servo horn + pedestal ---」ブロックの後に追加:

```scad
// --- TASK-7 ギア伝達＋ロストモーション・フォーク（全値暫定。クーポン・実機で確定） ---
// サーボを -30° 方向へオフセットし、駆動ギア(大)→リングギア(小)の外歯 1 段で増速伝達。
// リングギア下面のフォーク爪がノブ根元だけを押し、爪間の回廊が手動 90° の遊びを作る。
gear_module   = 1.5;   // 歯車モジュール（0.4 ノズル FDM の実績帯）
gear_pa       = 20;    // 圧力角[deg]
gear_z_ring   = 28;    // 従動（リング）歯数 → ピッチ径 42
gear_z_drive  = 42;    // 駆動歯数 → ピッチ径 63、増速比 1.5
gear_backlash = 0.15;  // 歯厚の弧長を片歯車あたりこの分だけ痩せさせる（印刷嵌合、クーポンで確定）
gear_t        = 5;     // 歯幅（Z）
gear_axis_dist = gear_module * (gear_z_ring + gear_z_drive) / 2;  // 軸間距離 52.5
gear_dir_deg  = -30;   // オフセット方向。+X 純方向は BB ポケット/ジャンパと干渉、-45° はハンドルクリアランス超過
gear_axis_pos = [gear_axis_dist * cos(gear_dir_deg), gear_axis_dist * sin(gear_dir_deg)];  // ≈ (45.5, -26.3)
gear_ratio    = gear_z_drive / gear_z_ring;  // 1.5

// リングギア（従動）
ring_bore_d   = 29;    // 中央開口。ノブ回転包絡 2*sqrt((knob_w_base/2)^2+(knob_t/2)^2) ≈ 28.1 + すき間
ring_z0       = 10;    // 歯付き盤の下面（プレート座標）
ring_skirt_od = 36;    // 下向きベアリングスカート外径（歯底 38.25 の内側）
ring_skirt_wt = 1.6;   // スカート壁厚
gear_bearing_fit = 0.3; // スカート内面 ⇔ 受けカラー外面の径すき間（クーポンで確定）

// フォーク爪（リングギア下面）
fork_z0        = 4;    // 爪下端（プレート座標。ロゼットの出っ張りと要実機確認）
fork_engage    = 8;    // ノブ根元への掛かり深さ
fork_claw_ang  = 60;   // 爪 1 本の角幅[deg]（対向 2 本。回廊 = 180 - fork_claw_ang）
fork_claw_ri   = 9;    // 爪の内半径（ノブ半幅 13.9 と重なって接触面を作る）
fork_margin    = 15;   // 手動 90° に上乗せする退避マージン[deg]
knob_env_r     = sqrt(pow(knob_w_base/2, 2) + pow(knob_t/2, 2));  // ノブ回転包絡半径 ≈ 14.05
knob_ang       = 2 * asin((knob_t/2 + fit_clearance) / (ring_bore_d/2));  // 接触半径でのノブ角幅 ≈ 15
fork_corridor  = 180 - fork_claw_ang;                 // 爪間の回廊角 120
fork_free_play = fork_corridor - knob_ang;            // 手動の自由角 ≈ 105
fork_range     = 90 + fork_free_play;                 // フォーク必要可動域 ≈ 195

// 受けカラー（ペデスタル側・下受け）
collar_or     = ring_skirt_od/2 - ring_skirt_wt - gear_bearing_fit/2;  // カラー外半径 ≈ 16.25
collar_z0     = 6.4;   // カラー下端（棚フランジ上面）
collar_z1     = ring_z0 + 1;  // カラー上端（盤下面へ 1mm 差し込み、スカートの倒れを防ぐ）

// 駆動ギア・サーボ位置（Z は既存のホーンスタック定数から逆算）
drive_top_z    = ring_z0 + gear_t;                    // 駆動ギア上面 15（ホーンポケットはここに彫る）
servo_ears_z   = drive_top_z + horn_h;                // サーボ耳の載る面 ≈ 25.4
```

- [ ] **Step 2: 整合チェックを追加**

`params.scad` 末尾の assert 群に追加:

```scad
// --- TASK-7 ギア・フォーク整合チェック ---
assert(fork_free_play >= 90 + fork_margin, "フォーク回廊の遊びが手動 90°+マージンに足りない");
// サーボ実効可動域の想定 140°（1000µs メカ端〜2400µs、実測前の安全側仮定）で押し切れること
assert(fork_range <= 140 * gear_ratio, "フォーク必要可動域がギア比で賄えない（比を上げるか実測可動域で見直す）");
assert(ring_bore_d/2 > knob_env_r + 0.5, "リング開口がノブ回転包絡と干渉");
assert((gear_module * gear_z_ring / 2 - 1.25 * gear_module) - ring_bore_d/2 >= 1.5, "リング歯底とボアのリム肉厚 >= 1.5mm");
assert(fork_claw_ri < knob_w_base/2, "爪の内半径がノブ半幅の外（押せない）");
assert(collar_or - rosette_d/2 > -8, "カラーがロゼット開口の真上に張り出しすぎない目安");
assert(gear_axis_dist * sin(-gear_dir_deg) + (gear_module * gear_z_drive / 2 + gear_module) <= clear_down, "駆動ギアがドアハンドルクリアランスを超える");
assert(gear_axis_dist * cos(gear_dir_deg) + (gear_module * gear_z_drive / 2 + gear_module) <= ext_right + 10, "駆動ギアが +X に張り出しすぎ");
assert(drive_top_z + horn_h == servo_ears_z, "サーボ耳面はホーンスタックから逆算した値");
assert(knob_h - mount_pad_t - drive_top_z >= 8, "ノブ先端の露出（掴み代）>= 8mm");
```

- [ ] **Step 3: レンダリングで assert を検証**

Run: `nix develop -c bun enclosure/scripts/render.ts enclosure/models/smoke.scad /tmp/smoke.stl`
Expected: PASS（assert 失敗が無いこと。失敗したら数値を本計画の意図に合わせて修正）

- [ ] **Step 4: コミット**

```bash
git add enclosure/models/params.scad
git commit -m "TASK-7 enclosure: ギア・フォーク・受けカラーのパラメータと整合チェックを追加"
```

---

### Task 4: インボリュート平歯車の 2D モジュール

**Files:**
- Create: `enclosure/models/gears.scad`
- Create: `enclosure/models/gears_test.scad`

**Interfaces:**
- Consumes: `params.scad` の `gear_module` / `gear_pa` / `gear_backlash`
- Produces: `module spur_gear_2d(m, z, pa, bl)`（歯車 1 枚の 2D 形状、歯 1 本の中心が +X 軸上）、`function gear_rp(m, z)`, `gear_ra(m, z)`, `gear_rr(m, z)`

- [ ] **Step 1: 失敗するテストを書く**

`enclosure/models/gears_test.scad`:

```scad
include <params.scad>
use <gears.scad>
// 半径の順序: 歯底 < ピッチ < 歯先
assert(gear_rr(gear_module, gear_z_ring) < gear_rp(gear_module, gear_z_ring), "rr < rp");
assert(gear_rp(gear_module, gear_z_ring) < gear_ra(gear_module, gear_z_ring), "rp < ra");
// リング歯底の内側にボア用のリムが残る
assert(gear_rr(gear_module, gear_z_ring) - ring_bore_d/2 >= 1.5, "ring rim >= 1.5");
// 噛み合い確認: 軸間距離に置いた 2 枚（位相合わせ済み）が重ならない
render() {
  difference() {
    intersection() {
      linear_extrude(height = 1) spur_gear_2d(gear_module, gear_z_ring);
      translate([gear_axis_dist, 0, 0])
        linear_extrude(height = 1)
          rotate(180/gear_z_drive)  // 駆動側を半歯ずらしてリングの歯と谷を合わせる
            spur_gear_2d(gear_module, gear_z_drive);
    }
  }
}
linear_extrude(height = 1) spur_gear_2d(gear_module, gear_z_ring);
echo("gears_test ok");
```

- [ ] **Step 2: レンダリングして失敗を確認**

Run: `nix develop -c bun enclosure/scripts/render.ts enclosure/models/gears_test.scad /tmp/gears_test.stl`
Expected: FAIL（`spur_gear_2d` / `gear_rp` 未定義）

- [ ] **Step 3: 実装**

`enclosure/models/gears.scad`:

```scad
include <params.scad>

// ===== インボリュート平歯車（標準・転位なし・圧力角 20°） =====
// 参考式: involute 点 = rb*(cos t + t·sin t, sin t - t·cos t)（t はラジアン。OpenSCAD は
// 度なので PI*t/180 を掛ける）。歯 1 本の中心を +X 軸に置く。

function gear_rp(m, z) = m * z / 2;              // ピッチ円半径
function gear_rb(m, z, pa) = gear_rp(m, z) * cos(pa);  // 基礎円半径
function gear_ra(m, z) = gear_rp(m, z) + m;      // 歯先円半径
function gear_rr(m, z) = gear_rp(m, z) - 1.25 * m;  // 歯底円半径

function _inv_deg(pa) = tan(pa) * 180 / PI - pa;    // involute 関数 inv(α) [deg]
function _inv_pt(rb, t) = [rb * (cos(t) + PI * t / 180 * sin(t)),
                           rb * (sin(t) - PI * t / 180 * cos(t))];
function _t_at(rb, r) = sqrt(max(pow(r / rb, 2) - 1, 0)) * 180 / PI;  // 半径 r に届く展開角

module spur_gear_2d(m, z, pa = gear_pa, bl = gear_backlash) {
  rp = gear_rp(m, z);
  rb = gear_rb(m, z, pa);
  ra = gear_ra(m, z);
  rr = gear_rr(m, z);
  r0 = max(rr, rb);   // フランク開始半径（基礎円未満は involute 未定義）
  // 歯中心から片フランクまでの回し角: ピッチ点の歯厚半角 + inv(pa) - バックラッシュ分
  half = 90 / z + _inv_deg(pa) - (bl / 2) / rp * 180 / PI;
  fl = [for (i = [0:8]) _inv_pt(rb, _t_at(rb, r0 + (ra - r0) * i / 8))];
  union() {
    circle(r = rr, $fn = 96);
    for (k = [0:z - 1]) rotate(360 * k / z)
      polygon(concat(
        [[0.6 * rr, 0]],  // 歯底側の閉じ点（根元を実体へ食い込ませる）
        [for (p = fl) [p[0] * cos(-half) - p[1] * sin(-half),
                       p[0] * sin(-half) + p[1] * cos(-half)]],
        [for (i = [len(fl) - 1:-1:0]) let (p = fl[i])
          [p[0] * cos(half) + p[1] * sin(half),
           p[0] * sin(half) - p[1] * cos(half)]]
      ));
  }
}
```

（ミラー側フランクは `(x, -y)` を `+half` 回転したもの。上の式はそれを展開した形。）

- [ ] **Step 4: レンダリングして通ることを確認**

Run: `nix develop -c bun enclosure/scripts/render.ts enclosure/models/gears_test.scad /tmp/gears_test.stl`
Expected: PASS（assert 通過・STL 出力）。`/tmp/gears_test.stl` を viewer か openscad プレビューで目視し、歯形が涙滴状に破綻していないこと・噛み合い intersection が実質空であることを確認。噛み合いが食い込む場合は `gear_backlash` を 0.2 へ上げて再確認。

- [ ] **Step 5: コミット**

```bash
git add enclosure/models/gears.scad enclosure/models/gears_test.scad
git commit -m "TASK-7 enclosure: インボリュート平歯車の 2D モジュールを追加"
```

---

### Task 5: ホーン嵌合インターフェースを hardware.scad へ共有化

**Files:**
- Modify: `enclosure/models/hardware.scad`
- Modify: `enclosure/models/socket.scad`

**Interfaces:**
- Consumes: `socket.scad` の既存ホーンポケット実装（`horn_bar_2d` / スタブ / 押さえ爪 / 逃がし溝）
- Produces: `hardware.scad` に `function sock_bar_hw(x)`, `module horn_bar_2d()`, `module horn_pocket_cuts()`（difference 側: バー+ハブポケット & 爪逃がし溝）, `module horn_pocket_adds()`（union 側: 中心スタブ & 押さえ爪 4 本）。ローカル座標は現行 socket と同じ（ポケット底 z=0 相当、バー面 -Z 側）

- [ ] **Step 1: 移設**

`socket.scad` から次を `hardware.scad` へ移動する（コードは現行のまま。名前だけ整理):
- `function sock_bar_hw(x)`、`module horn_bar_2d()`、`module sock_claw_slots()`、`module sock_claw(cx)`
- 新設 `module horn_pocket_cuts()` = 現行 socket の difference 側にあるバーポケット彫り込み（`translate([0,0,-0.1]) linear_extrude(horn_thick + hc + 0.1) offset(r=hc) union(){ horn_bar_2d(); circle(d=horn_hub_d); }`）と `sock_claw_slots()` をまとめたもの
- 新設 `module horn_pocket_adds()` = 中心スタブ（`translate([0,0,(horn_thick+hc)-horn_thick/2]) cylinder(d=horn_stub_d, h=horn_thick/2+0.1)`）と押さえ爪 4 本（`if (socket_claws) for (sx=[-1,1], sy=[0,1]) mirror([0,sy,0]) sock_claw(sx*sock_claw_x);`）をまとめたもの

`socket.scad` は移動した定義を削除し、`use <hardware.scad>` を足して `horn_pocket_cuts()` / `horn_pocket_adds()` を呼ぶ形に書き換える（キャプチャ壁は socket 固有なので残す）。

- [ ] **Step 2: 既存テストで回帰確認**

Run: `nix develop -c bun enclosure/scripts/render.ts enclosure/models/socket_test.scad /tmp/socket_test.stl`
Expected: PASS（形状回帰は STL のサイズ・目視で確認）

- [ ] **Step 3: コミット**

```bash
git add enclosure/models/hardware.scad enclosure/models/socket.scad
git commit -m "TASK-7 enclosure: ホーン嵌合ポケットを hardware.scad へ共有化"
```

---

### Task 6: 駆動ギア（ホーン嵌合付き）

**Files:**
- Modify: `enclosure/models/gears.scad`
- Modify: `enclosure/models/gears_test.scad`

**Interfaces:**
- Consumes: `spur_gear_2d`（Task 4）、`horn_pocket_cuts` / `horn_pocket_adds`（Task 5）
- Produces: `module drive_gear()`（ローカル座標: 盤下面 z=0、上面 z=gear_t にホーンポケット。組立時は `gear_axis_pos` へ translate し `z=ring_z0` に置く）

- [ ] **Step 1: テスト追加**

`gears_test.scad` に追加:

```scad
drive_gear();  // レンダリング可能なこと（アサートは params 側で担保）
```

- [ ] **Step 2: 実装**

`gears.scad` に追加:

```scad
use <hardware.scad>

// 駆動ギア。サーボホーン（一文字バー）を上面ポケットへ嵌合し、押さえ爪でクリップする。
// ローカル座標: 盤下面 z=0。ホーンポケットのローカル系（バー面が -Z 側）に合わせるため
// 上面へ反転して配置する。
module drive_gear() {
  difference() {
    union() {
      linear_extrude(height = gear_t)
        spur_gear_2d(gear_module, gear_z_drive);
      // ポケットまわりの加算形状（スタブ・爪）は socket と同じ向き（バー面が上）
      translate([0, 0, gear_t]) rotate([180, 0, 0]) horn_pocket_adds();
    }
    translate([0, 0, gear_t]) rotate([180, 0, 0]) horn_pocket_cuts();
  }
}
```

（`horn_pocket_*` のローカル z の向きが逆なら `rotate([180,0,0])` を外して `translate` のみで合わせる。判断基準: バーポケットの開口が駆動ギア上面に出ること。）

- [ ] **Step 3: レンダリング確認**

Run: `nix develop -c bun enclosure/scripts/render.ts enclosure/models/gears_test.scad /tmp/gears_test.stl`
Expected: PASS。目視でポケット開口が上面にあること。

- [ ] **Step 4: コミット**

```bash
git add enclosure/models/gears.scad enclosure/models/gears_test.scad
git commit -m "TASK-7 enclosure: ホーン嵌合付き駆動ギアを追加"
```

---

### Task 7: フォーク付きリングギア

**Files:**
- Modify: `enclosure/models/gears.scad`
- Modify: `enclosure/models/gears_test.scad`

**Interfaces:**
- Consumes: `spur_gear_2d`（Task 4）、params の ring/fork 定数（Task 3）
- Produces: `module ring_gear()`（**ワールド Z** で定義: 歯付き盤 z=ring_z0..ring_z0+gear_t、スカート z=collar_z0..ring_z0、爪 z=fork_z0..fork_z0+fork_engage。XY はロゼット軸原点）

- [ ] **Step 1: テスト追加**

`gears_test.scad` に追加:

```scad
ring_gear();
// 爪がノブ側面を押せる重なりを持つ（半径方向）
assert(fork_claw_ri < knob_w_base/2 - 1, "claw overlaps knob");
```

- [ ] **Step 2: 実装**

`gears.scad` に追加:

```scad
// フォーク付きリングギア（従動）。中央開口をノブが貫通し、下面の対向 2 爪が
// ノブ根元を押す。下向きスカートがペデスタルの受けカラーに被さって軸受けになる。
// 回廊（爪間の空き）が手動 90° の遊び。ニュートラルで爪は ±(fork_corridor/2) に立つ。
module ring_gear() {
  // 歯付き盤（ボア抜き）
  translate([0, 0, ring_z0])
    linear_extrude(height = gear_t)
      difference() {
        spur_gear_2d(gear_module, gear_z_ring);
        circle(d = ring_bore_d);
      }
  // ベアリングスカート（盤下面から受けカラーへ被さる）
  translate([0, 0, collar_z0])
    linear_extrude(height = ring_z0 - collar_z0 + 0.1)
      difference() {
        circle(d = ring_skirt_od);
        circle(d = ring_skirt_od - 2 * ring_skirt_wt);
      }
  // フォーク爪（対向 2 本のセクター柱。回廊中心を ±Y に置く＝爪中心が ±X）
  for (k = [0, 1]) rotate(180 * k)
    translate([0, 0, fork_z0])
      linear_extrude(height = ring_z0 - fork_z0 + 0.1)  // 盤まで伸ばして融合
        intersection() {
          difference() {
            circle(d = ring_bore_d + 2 * 2.4);  // 爪の外側はボア縁に 2.4mm 被せて盤と繋ぐ
            circle(r = fork_claw_ri);
          }
          // 角幅 fork_claw_ang のセクター（+X 中心）
          polygon([[0, 0],
                   [50 * cos(fork_claw_ang/2),  50 * sin(fork_claw_ang/2)],
                   [50, 0],
                   [50 * cos(fork_claw_ang/2), -50 * sin(fork_claw_ang/2)]]);
        }
}
```

注意: 爪はボア縁（`ring_bore_d/2`）より内側へ `fork_claw_ri` まで張り出す。盤のボアはノブ包絡より広い（29 > 28.1）ので、ノブは盤を貫通し、爪だけが根元の高さ（z 4..12）で経路に立つ。

- [ ] **Step 3: レンダリング確認**

Run: `nix develop -c bun enclosure/scripts/render.ts enclosure/models/gears_test.scad /tmp/gears_test.stl`
Expected: PASS。目視: 盤中央にノブより広い開口、下面に対向 2 爪、スカートが盤下面から垂下。

- [ ] **Step 4: コミット**

```bash
git add enclosure/models/gears.scad enclosure/models/gears_test.scad
git commit -m "TASK-7 enclosure: フォーク付きリングギアを追加"
```

---

### Task 8: ペデスタル v3（受けカラー＋噛み合い窓＋オフセットサーボ天板）

**Files:**
- Modify: `enclosure/models/pedestal.scad`
- Modify: `enclosure/models/pedestal_test.scad`
- Modify: `enclosure/models/params.scad`（このタスクで使う追加定数）

**Interfaces:**
- Consumes: params のギア定数（Task 3）、`sg90_cutout` / `m2_sleeve_solid` / `m2_sleeve_cuts`（既存 hardware.scad）
- Produces: `module pedestal()`（ローカル z=0 = フランジ底面。ボルトオン・インターフェース＝底フランジ・ローブ・スリーブ 4 点は**現行と不変**。body.scad は変更しない）

- [ ] **Step 1: 追加定数**

`params.scad` の TASK-7 ブロックに追加:

```scad
// ペデスタル v3（ギアデッキ）
ped_cyl_ri     = 23.2;  // 筒内半径（リング歯先 22.5 + 0.7 逃げ）
ped_cyl_ro     = 25.6;  // 筒外半径
ped_shelf_z0   = 4;     // 内フランジ棚の下面（ローカル。カラーの土台）
ped_window_ang = 55;    // 噛み合い窓の半角[deg]（gear_dir_deg 中心。駆動歯の通過幅から）
ped_window_z0  = 9 - wall;   // 窓下端（ローカル）。ワールド 9（歯帯 10..15 の下 1mm）
ped_window_z1  = 16 - wall;  // 窓上端（ローカル）。ワールド 16（歯帯の上 1mm）
ped_arm_w      = 18;    // サーボ天板への持ち出し梁の幅
assert(ped_cyl_ri >= gear_module * gear_z_ring / 2 + gear_module + 0.5, "筒内面がリング歯先に触れる");
```

- [ ] **Step 2: テストを先に更新**

`pedestal_test.scad`（現行の内容に追記）:

```scad
// v3: サーボ天板がオフセット位置にあり、カラーが定義されること
assert(servo_ears_z - wall > ped_window_z1, "サーボ天板が窓より上");
pedestal();
echo("pedestal_test ok");
```

Run: `nix develop -c bun enclosure/scripts/render.ts enclosure/models/pedestal_test.scad /tmp/ped_test.stl`
Expected: 現行 pedestal のままなら PASS するが、Step 3 の実装後に v3 形状で PASS することが本題。

- [ ] **Step 3: 実装**

`pedestal.scad` の `module pedestal()` を v3 へ書き換え。保持するもの: 底フランジ＋ローブ＋スリーブ（コード不変）、中央ロゼット通し。置き換えるもの: 筒と天板。

```scad
module pedestal() {
  c = fit_clearance;
  top_local = servo_ears_z - wall;  // サーボ天板上面（ローカル ≈ 23）
  difference() {
    union() {
      // --- 底フランジ＋ローブ（現行と同一。ボルトオン・インターフェース不変） ---
      linear_extrude(height = ped_flange_t)
        union() {
          circle(r = rosette_d/2 + pedestal_wall_t + c);
          for (p = ped_fix_pts)
            hull() {
              translate([p[0]/2, p[1]/2]) circle(d = ped_lobe_w);
              translate([p[0],   p[1]])   circle(d = ped_lobe_w);
            }
        }
      // --- 筒（内半径をリング歯先逃げまで拡大） ---
      linear_extrude(height = top_local)
        difference() { circle(r = ped_cyl_ro); circle(r = ped_cyl_ri); }
      // --- 内フランジ棚＋受けカラー（リングギアの下受け軸受け） ---
      translate([0, 0, ped_shelf_z0])
        linear_extrude(height = (collar_z0 - wall) - ped_shelf_z0)
          difference() { circle(r = ped_cyl_ri + 0.1); circle(r = collar_or - 2); }
      translate([0, 0, collar_z0 - wall])
        linear_extrude(height = collar_z1 - collar_z0)
          difference() { circle(r = collar_or); circle(r = collar_or - 2); }
      // --- サーボ天板（オフセット位置）＋持ち出し梁 ---
      translate([gear_axis_pos[0], gear_axis_pos[1], top_local - servo_plate_t])
        linear_extrude(height = servo_plate_t)
          difference() {
            circle(r = 20);
            circle(d = servo_shaft_d + 2*c);
            for (sx = [-1, 1])
              translate([servo_shaft_offset + sx * servo_screw_span/2, 0])
                circle(d = servo_screw_pilot);
          }
      // 梁: 筒の上端帯からサーボ天板まで（セパレーション反力方向なのでリブ付き）
      translate([0, 0, top_local - servo_plate_t - 4])
        linear_extrude(height = servo_plate_t + 4)
          intersection() {
            hull() { circle(r = ped_cyl_ro); translate(gear_axis_pos) circle(r = 20); }
            rotate(gear_dir_deg) translate([0, -ped_arm_w/2]) square([100, ped_arm_w]);
          }
      // 固定スリーブ（現行と同一）
      for (p = ped_fix_pts)
        translate([p[0], p[1], 0]) m2_sleeve_solid();
    }
    // サーボポケット（オフセット位置の天板に耳が載る）
    translate([gear_axis_pos[0], gear_axis_pos[1], top_local + servo_body_h/2])
      sg90_cutout();
    // 噛み合い窓（gear_dir_deg 方向の筒壁を歯帯の高さだけ切り欠く）
    rotate(gear_dir_deg)
      translate([0, 0, ped_window_z0])
        linear_extrude(height = ped_window_z1 - ped_window_z0)
          polygon([[0, 0],
                   [60 * cos(ped_window_ang),  60 * sin(ped_window_ang)],
                   [60, 0],
                   [60 * cos(ped_window_ang), -60 * sin(ped_window_ang)]]);
    // 梁の下面から駆動ギア上面までの逃げ（梁と歯の接触防止は clash で担保）
    // 中央ロゼット通し（現行と同一）
    translate([0, 0, -0.1])
      cylinder(d = rosette_d + c, h = ped_flange_t + 0.2);
    // スリーブの内側カット（現行と同一）
    for (p = ped_fix_pts)
      translate([p[0], p[1], 0]) m2_sleeve_cuts();
  }
}
```

リングギアの組み込み手順（コメントとしてファイル冒頭に書く）: リングギアは筒の上からドア側へ落とし込み、スカートがカラーに被さる。軸方向下向きは棚（カラー土台）が受け、上向きは初版では自重＋駆動ギアの噛み合いのみ（浮き対策のバヨネットタブはクーポン後に追加検討）。

- [ ] **Step 4: レンダリング確認**

Run: `nix develop -c bun enclosure/scripts/render.ts enclosure/models/pedestal_test.scad /tmp/ped_test.stl`
Expected: PASS。目視: 筒の -30° 方向に窓、中央に棚＋カラー、オフセット位置に天板。

- [ ] **Step 5: コミット**

```bash
git add enclosure/models/pedestal.scad enclosure/models/pedestal_test.scad enclosure/models/params.scad
git commit -m "TASK-7 enclosure: ペデスタル v3（受けカラー・噛み合い窓・オフセットサーボ天板）"
```

---

### Task 9: 組立・クーポン・干渉チェック統合と socket の廃止

**Files:**
- Modify: `enclosure/models/smartlock.scad`
- Modify: `enclosure/models/clash_check.scad`
- Modify: `enclosure/scripts/build.ts`
- Delete: `enclosure/models/socket.scad`, `enclosure/models/socket_test.scad`

**Interfaces:**
- Consumes: `drive_gear` / `ring_gear`（Task 6, 7）、`pedestal`（Task 8）
- Produces: build 部品名 `gear_drive` / `gear_ring`、組立 `asm_gear_drive` / `asm_gear_ring`、クーポン `gear_mesh_coupon`

- [ ] **Step 1: smartlock.scad の部品切り替えを更新**

- `use <socket.scad>` → `use <gears.scad>`
- `part == "socket"` 分岐と `asm_socket` 分岐、`socket_coupon` を削除
- 追加:

```scad
else if (part == "gear_ring") translate([0, 0, -collar_z0]) ring_gear();  // 印刷向き: スカート下端接地
else if (part == "gear_drive") drive_gear();
// 噛み合いクーポン: 両ギアを軸間距離で並べた薄板（歯当たり・バックラッシュ実測用）
else if (part == "gear_mesh_coupon") {
  intersection() { translate([0, 0, -ring_z0]) ring_gear(); cylinder(r = 60, h = gear_t); }
  translate([gear_axis_dist, 0, 0]) rotate(180/gear_z_drive)
    intersection() { drive_gear(); cylinder(r = 60, h = gear_t); }
}
else if (part == "asm_gear_ring")
  color("SandyBrown") translate([0, 0, exp * -12]) ring_gear();
else if (part == "asm_gear_drive")
  color("Orange")
    translate([gear_axis_pos[0], gear_axis_pos[1], ring_z0 + exp * 12]) drive_gear();
```

full assembly 分岐でも socket の代わりに `ring_gear()`（ワールド座標のまま）と `drive_gear()`（`gear_axis_pos`, `z=ring_z0`）を置く。`socket_z` 変数は不要になるので削除。

- [ ] **Step 2: clash_check.scad にギア系ペアを追加**

```scad
use <gears.scad>

// pedestal × ring_gear（リングは組立位置。カラー⇔スカートは径すき間で非接触のはず）
intersection() {
  translate([0, 0, wall]) pedestal();
  translate([0, 0, clash_eps]) ring_gear();
}
// pedestal × drive_gear（窓・梁と歯の接触検出）
intersection() {
  translate([0, 0, wall]) pedestal();
  translate([gear_axis_pos[0], gear_axis_pos[1], ring_z0 + clash_eps]) drive_gear();
}
// ring_gear × drive_gear（噛み合い部の食い込み検出。半歯位相合わせ）
intersection() {
  ring_gear();
  translate([gear_axis_pos[0], gear_axis_pos[1], ring_z0 + clash_eps])
    rotate(180/gear_z_drive) drive_gear();
}
// tray × drive_gear（BB/トレイ側との干渉検出）
intersection() {
  translate([0, 0, wall]) tray();
  translate([gear_axis_pos[0], gear_axis_pos[1], ring_z0 + clash_eps]) drive_gear();
}
```

- [ ] **Step 3: build.ts の部品リスト更新**

```ts
const parts = [
  "body", "pedestal", "gear_ring", "gear_drive", "tray",
  "asm_body", "asm_pedestal", "asm_gear_ring", "asm_gear_drive", "asm_tray",
  "gear_mesh_coupon",
];
```

- [ ] **Step 4: socket の削除**

```bash
git rm enclosure/models/socket.scad enclosure/models/socket_test.scad
```

socket 由来で params に残る定数（`socket_oh` / `sock_wall_*` / `sock_claw_*` / `socket_claws` / `knob_engage` ほか）は、ホーン爪共有化（Task 5）で使う `sock_claw_*` と `socket_claws` を**残し**、キャプチャ壁系（`sock_wall_*`, `sock_funnel`, `socket_oh`）とその assert を削除する。`knob_engage` は露出量チェックに使わなくなったら削除。params の assert が greenlight するまで整理する。

- [ ] **Step 5: フルビルドと干渉チェック**

Run: `nix develop -c just enclosure`
Expected: 全部品ビルド成功
Run: `nix develop -c just clash`
Expected: `OK: no interference`（FAIL したら窓の高さ・梁の底面・カラー径を params で調整して再実行）
Run: `nix develop -c just test-enclosure`
Expected: PASS

- [ ] **Step 6: コミット**

```bash
git add -A enclosure/
git commit -m "TASK-7 enclosure: ギア組立・噛み合いクーポン・干渉チェックを統合し socket を廃止"
```

---

### Task 10: ドキュメントと backlog の更新

**Files:**
- Modify: `docs/firmware.md`
- Modify: `backlog/tasks/task-7 - manual-unlock-clutch-and-exposed-thumbturn.md`
- Modify: `CLAUDE.md`（キャリブ定数の案内行）

**Interfaces:**
- Consumes: Task 1-2 の定数名

- [ ] **Step 1: docs/firmware.md のキャリブ手順更新**

サーボ動作確認の節に追記: 動作シーケンスが「押し切り → ニュートラル退避 → 給電断」であること、キャリブ定数に `NEUTRAL_DEG` / `LOCK_PUSH_DEG` / `UNLOCK_PUSH_DEG` が増えたこと、ギア反転で施錠/解錠の対応が直結時代と入れ替わる可能性があり実機で確認すること。

- [ ] **Step 2: CLAUDE.md の定数案内を追従**

「サーボ実機合わせ」の行の `LOCK_DEG` / `UNLOCK_DEG` を `LOCK_PUSH_DEG` / `UNLOCK_PUSH_DEG` / `NEUTRAL_DEG` に更新。

- [ ] **Step 3: backlog タスクの AC 更新**

`task-7 - manual-unlock-clutch-and-exposed-thumbturn.md` の AC #2（方式決定）を `[x]` にする。AC #1 / #3 は実機検証後にチェックするため残す。Implementation Notes 節が無ければ追記し、スペックと本計画へのパスを書く。

- [ ] **Step 4: コミット**

```bash
git add docs/firmware.md CLAUDE.md "backlog/tasks/task-7 - manual-unlock-clutch-and-exposed-thumbturn.md"
git commit -m "TASK-7 docs: キャリブ手順・定数案内を更新し AC#2 を消化"
```

---

## 実機検証チェックリスト（コード外・ユーザーと一緒に）

計画のコード部分が終わったら、スペック「実機検証の順序」に沿って進める。ここは自動化できない。

1. [ ] 逆駆動トルクの切り分け（AC #3）: サーボ単体（配線なし）と現回路組み込み（ゲート OFF）で手回しの重さを比較し、phantom 給電の寄与を記録する
2. [ ] 高パルス側の実効上限の実測: `SERVO_MAX_US` を 2000 → 2100 → … と刻んで焼き、唸り・メカ端の手前で止める。実効可動域からギア比の要否を再計算（`fork_range <= 実効角 × gear_ratio`）
3. [ ] `gear_mesh_coupon` を印刷して噛み合い・バックラッシュ確認（渋ければ `gear_backlash` を上げる）
4. [ ] `gear_ring` + `pedestal` + `gear_drive` を印刷・組み付けし、手動 90° が無抵抗で回ること（AC #1）、電動の押し切り → ニュートラル復帰、施錠負荷での完遂を確認
5. [ ] 施錠/解錠の方向（ギア反転）を確認し、`LOCK_PUSH_DEG` / `UNLOCK_PUSH_DEG` / `NEUTRAL_DEG` / `SETTLE_MS` を確定
6. [ ] トルク不足なら: ギア比を下げる → それでも不足なら MG90S（同寸・金属ギア 2.2kg·cm）へ換装
7. [ ] AC を全て満たしたら `backlog task complete TASK-7`

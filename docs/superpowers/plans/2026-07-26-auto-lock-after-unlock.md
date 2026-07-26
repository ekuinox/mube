# 解錠後オートロック 実装プラン

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 解錠してから config で指定した `Duration`（既定 60 秒）が経過したら自動で施錠する。

**Architecture:** 施錠/解錠の唯一の入口 `apply_target()` から状態変化を伝えるシグナル `AUTO_LOCK_CMD` を足し、専用の `auto_lock_task` がそれを見張って `with_timeout` でタイマーを回す。再解錠でリセット、手動施錠でキャンセル。純ロジックは firmware 側のタイマー依存で、`mube-core` へ切り出す部分はない。

**Tech Stack:** Rust / Embassy（embassy-executor タスク・embassy-time の `Duration` / `with_timeout` / `Signal`）、thumbv6m-none-eabi。

## Global Constraints

- Rust コードを変更したらコミット前に host テスト（`nix develop -c cargo host-test`）を通す。落ちたまま完了扱いにしない。
- 待ち時間の既定値は `Duration::from_secs(60)`。
- 待ち時間は `crates/mube-firmware/src/config.rs` の `AUTO_LOCK_AFTER: Duration` 定数で指定する。
- オンオフ切り替えは作らない（YAGNI）。
- この開発機の非対話シェルでは各コマンドに `nix develop -c` を前置する（`cargo` 等が PATH に無い）。
- 秘密（WiFi 認証）・CYW43 ブロブの実値を会話やコミットに載せない。

## File Structure

- `crates/mube-firmware/src/config.rs` — 接続設定に加え、オートロックの待ち時間定数 `AUTO_LOCK_AFTER` を持つ。
- `crates/mube-firmware/src/main.rs` — `AUTO_LOCK_CMD` シグナル・`apply_target` からの通知・`auto_lock_task`・spawn を持つ。

参照専用（変更なし）: `crates/mube-firmware/src/servo.rs`（`SERVO_CMD` 経由の駆動口）、`crates/mube-core/src/lock.rs`（`LockState`）。

---

### Task 1: config に待ち時間定数を追加

**Files:**
- Modify: `crates/mube-firmware/src/config.rs`

**Interfaces:**
- Consumes: `embassy_time::Duration`（firmware の既存依存 embassy-time 0.5）。
- Produces: `pub const AUTO_LOCK_AFTER: embassy_time::Duration`（Task 2 の `auto_lock_task` が参照する）。

- [ ] **Step 1: 定数を追加する**

`crates/mube-firmware/src/config.rs` の末尾に追記する。ファイル先頭の doc コメント群の後、既存の `WIFI_*` 定数の下に置く。

```rust
use embassy_time::Duration;

/// 解錠してから自動で施錠するまでの待ち時間。
/// ここを変えればオートロックの間隔を調整できる。`Duration::from_secs` は
/// const fn なので const 定数として置ける。
pub const AUTO_LOCK_AFTER: Duration = Duration::from_secs(60);
```

- [ ] **Step 2: host テストがリグレッションで通ることを確認する**

Run: `nix develop -c cargo host-test`
Expected: PASS（既存テストが全て green。config.rs は firmware クレートだが workspace ビルドで型が通ること）

- [ ] **Step 3: コミット**

```bash
git add crates/mube-firmware/src/config.rs
git commit -m "feat(firmware): オートロック待ち時間 AUTO_LOCK_AFTER を config に追加"
```

---

### Task 2: オートロックタスクを追加して配線する

**Files:**
- Modify: `crates/mube-firmware/src/main.rs`

**Interfaces:**
- Consumes: `config::AUTO_LOCK_AFTER`（Task 1）、既存の `apply_target` / `current_state` / `LockState` / `Signal` / `CriticalSectionRawMutex`。
- Produces: 追加の外部インターフェースなし（内部タスク・内部シグナル）。

- [ ] **Step 1: `with_timeout` を import に追加する**

`crates/mube-firmware/src/main.rs` の既存 import 行を差し替える。

変更前:
```rust
use embassy_time::{Duration, Timer};
```
変更後:
```rust
use embassy_time::{with_timeout, Duration, Timer};
```

- [ ] **Step 2: 状態変化シグナル `AUTO_LOCK_CMD` を追加する**

既存の `SERVO_CMD` 定義の直後に追記する。

```rust
/// 状態変化をオートロックタスクへ伝えるシグナル。apply_target が叩く。
/// Signal は最新値のみ保持するため、連続通知でも最新状態へ収束する。
static AUTO_LOCK_CMD: Signal<CriticalSectionRawMutex, LockState> = Signal::new();
```

- [ ] **Step 3: `apply_target` から通知する**

既存の `apply_target` に 1 行足す。

変更前:
```rust
pub(crate) fn apply_target(target: LockState) {
    LOCK_STATE.lock(|c| c.set(target));
    SERVO_CMD.signal(target);
}
```
変更後:
```rust
pub(crate) fn apply_target(target: LockState) {
    LOCK_STATE.lock(|c| c.set(target));
    SERVO_CMD.signal(target);
    AUTO_LOCK_CMD.signal(target); // オートロックタスクへ状態変化を通知
}
```

- [ ] **Step 4: `auto_lock_task` を追加する**

`button_task` の定義の後（他の `#[embassy_executor::task]` 群の並び）に追記する。

```rust
/// 解錠を検知して config::AUTO_LOCK_AFTER 後に自動施錠するタスク。
/// 再解錠でタイマーをリセットし、手動施錠でキャンセルする。自タスクが
/// apply_target(Locked) を呼んで飛ぶ AUTO_LOCK_CMD(Locked) は、次のループ先頭で
/// 受けて while に入らず無害に待機へ戻る（ループ暴走しない）。
#[embassy_executor::task]
async fn auto_lock_task() -> ! {
    loop {
        let mut target = AUTO_LOCK_CMD.wait().await;
        while target == LockState::Unlocked {
            match with_timeout(config::AUTO_LOCK_AFTER, AUTO_LOCK_CMD.wait()).await {
                // 時間切れ前に新コマンド：施錠なら while を抜けて待機へ、
                // 再解錠ならこのまま while を回してタイマーを測り直す。
                Ok(new_target) => target = new_target,
                // 時間切れ：まだ解錠中なら自動施錠（競合で施錠済みなら何もしない）。
                Err(_) => {
                    if current_state() == LockState::Unlocked {
                        info!("auto-lock: firing after timeout");
                        apply_target(LockState::Locked);
                    }
                    break;
                }
            }
        }
    }
}
```

- [ ] **Step 5: `main` で spawn する**

既存の `button_task` を spawn している行の直後に追記する。

```rust
spawner.spawn(auto_lock_task().unwrap());
```

- [ ] **Step 6: host テストがリグレッションで通ることを確認する**

Run: `nix develop -c cargo host-test`
Expected: PASS（既存テストが全て green。ロジック変更は firmware 側のみだが、workspace で型が壊れていないこと）

- [ ] **Step 7: firmware がビルドできることを確認する**

Run: `nix develop -c just firmware`
Expected: ビルド成功（blob→webui→cargo build が通る）。
注: WiFi 認証未設定でもビルドは通る（プレースホルダにフォールバック）。CYW43 ブロブが未取得だとここで失敗する — その場合は README のブロブ取得手順を先に済ませること。実機焼きまではこのプランの範囲外。

- [ ] **Step 8: コミット**

```bash
git add crates/mube-firmware/src/main.rs
git commit -m "feat(firmware): 解錠後 AUTO_LOCK_AFTER で自動施錠する auto_lock_task を追加"
```

---

## 実機確認チェックリスト（焼いた後に手動）

タイマー実機ロジックのため host テストでは検証できない。実機で以下を確認する。

- [ ] 解錠（HTTP `/api/unlock` またはボタン）→ 60 秒放置 → 自動で施錠される。
- [ ] 解錠 → 30 秒時点で再解錠 → そこから 60 秒後に施錠される（リセットされる）。
- [ ] 解錠 → 途中で手動施錠 → その後に勝手な再駆動が起きない（キャンセルされる）。
- [ ] defmt ログに `auto-lock: firing after timeout` が発火時のみ出る。

## Self-Review

- **Spec coverage:** 既定 60 秒（Task 1）・config の Duration 定数（Task 1）・全経路の解錠で作動（Task 2 の apply_target 通知）・再解錠リセット（Task 2 の while 継続）・手動施錠キャンセル（Task 2 の Ok(Locked) で break）・オンオフ無し（未実装＝YAGNI）。全てタスクに対応済み。
- **Placeholder scan:** プレースホルダなし。全ステップに実コードあり。
- **Type consistency:** `AUTO_LOCK_AFTER: Duration`（Task 1 で定義、Task 2 Step 4 で `config::AUTO_LOCK_AFTER` 参照）、`AUTO_LOCK_CMD: Signal<CriticalSectionRawMutex, LockState>`（Task 2 Step 2 定義・Step 3/4 参照）、`with_timeout`（Step 1 import・Step 4 使用）で一貫。

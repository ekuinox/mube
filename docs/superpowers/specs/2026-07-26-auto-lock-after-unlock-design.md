# 解錠後オートロック設計

## 目的

解錠した後、一定時間が経過したら自動で施錠する。閉め忘れ防止と防犯性の底上げが狙い。
待ち時間は `crates/mube-firmware/src/config.rs` に `embassy_time::Duration` の定数として置き、
そこを書き換えるだけで調整できるようにする。

## 要件

- 解錠してから既定 **60 秒** で自動施錠する。
- 待ち時間は config の `Duration` 定数で指定・変更できる。
- HTTP API（`/api/unlock`・`/api/toggle`）でもボタン（GP17 トグル）でも、どの経路の解錠でも作動する。
- 待ち時間の途中で再度解錠されたら、タイマーをリセットして 60 秒を測り直す。
- 待ち時間の途中で手動施錠されたら、オートロックはキャンセルする（二重に施錠駆動しない）。
- オンオフ切り替えは今回は作らない（常に有効の素の `Duration`）。

## アーキテクチャ

施錠/解錠は今も `apply_target(target: LockState)` が唯一の入口で、
`LOCK_STATE`（現在状態の単一ソース）を更新し `SERVO_CMD` シグナルでサーボタスクを駆動する。
HTTP ハンドラ（`http.rs` の `drive`）もボタンタスクも必ずここを通る。

この入口に **状態変化を知らせるシグナルをもう 1 本** 足し、専用の
オートロックタスクがそれを見張ってタイマーを回す。純ロジックとして
`mube-core` に切り出す部分はない（タイマー依存で firmware 側の実機ロジックのため）。

### 変更点

**`crates/mube-firmware/src/config.rs`** — 定数を追加する。

```rust
use embassy_time::Duration;

/// 解錠してから自動で施錠するまでの待ち時間。
/// ここを変えればオートロックの間隔を調整できる（0 に近い値は避ける）。
pub const AUTO_LOCK_AFTER: Duration = Duration::from_secs(60);
```

`Duration::from_secs` は const fn なので const 定数として置ける。
`embassy-time` は firmware の既存依存（Cargo.toml にあり）。

**`crates/mube-firmware/src/main.rs`** — シグナル・通知・タスクを追加する。

1. 状態変化を伝えるシグナルを追加：

```rust
/// 状態変化をオートロックタスクへ伝えるシグナル。apply_target が叩く。
static AUTO_LOCK_CMD: Signal<CriticalSectionRawMutex, LockState> = Signal::new();
```

2. `apply_target` から通知する（既存 2 行の直後に 1 行足すだけ）：

```rust
pub(crate) fn apply_target(target: LockState) {
    LOCK_STATE.lock(|c| c.set(target));
    SERVO_CMD.signal(target);
    AUTO_LOCK_CMD.signal(target); // 追加：オートロックタスクへ状態変化を通知
}
```

3. オートロックタスクを追加する：

```rust
use embassy_time::with_timeout;

/// 解錠を検知して AUTO_LOCK_AFTER 後に自動施錠するタスク。
/// 再解錠でタイマーをリセットし、手動施錠でキャンセルする。
#[embassy_executor::task]
async fn auto_lock_task() -> ! {
    loop {
        let mut target = AUTO_LOCK_CMD.wait().await;
        while target == LockState::Unlocked {
            match with_timeout(config::AUTO_LOCK_AFTER, AUTO_LOCK_CMD.wait()).await {
                // 時間切れ前に新しいコマンド：施錠なら while を抜けて待機に戻り、
                // 再解錠ならこのまま while を回してタイマーを測り直す。
                Ok(new_target) => target = new_target,
                // 時間切れ：まだ解錠中なら自動施錠する（競合で既に施錠済みなら何もしない）。
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

4. `main` で spawn する（他タスクと同様）：

```rust
spawner.spawn(auto_lock_task().unwrap());
```

## データフロー

```
解錠（HTTP or ボタン）
  → apply_target(Unlocked)
      → LOCK_STATE=Unlocked / SERVO_CMD 駆動 / AUTO_LOCK_CMD.signal(Unlocked)
  → auto_lock_task が Unlocked を受けて with_timeout でタイマー開始
      ├─ 60 秒経過（Err）      → まだ Unlocked なら apply_target(Locked) → 自動施錠
      ├─ 途中で再解錠（Ok Unlocked） → while 継続でタイマー再スタート
      └─ 途中で手動施錠（Ok Locked） → while を抜けて次の解錠を待機（キャンセル）
```

`apply_target(Locked)` を自タスクが呼ぶと `AUTO_LOCK_CMD.signal(Locked)` も飛ぶが、
次のループ先頭で受けて `target == Locked` により while に入らず、無害に待機へ戻る（ループ暴走しない）。
`Signal` は最新値のみ保持するため、通知が連続しても最新状態へ収束する。

## エラー処理・エッジケース

- **競合（時間切れ発火の瞬間に他経路が施錠）**：発火時に `current_state()` を再確認してから
  施錠するので、既に施錠済みなら駆動しない。
- **連続解錠**：`Signal` は最新のみ保持。再解錠のたびタイマーがリセットされ、
  最後の解錠から 60 秒で施錠される。
- **タスク増加のコスト**：`#[embassy_executor::task]` は静的プールをコンパイル時に確保。
  アイドル時は wait で寝ており CPU コストはゼロ、追加 RAM もごく小さい。

## テスト

- オートロックはタイマー依存の firmware 実機ロジックで、`mube-core` へ切り出す純関数はない。
- 既存の host テスト（`cargo host-test`）がリグレッションとして引き続き通ることを確認する。
- 実機確認（手動）：解錠 → 60 秒放置で施錠されること、途中の再解錠でリセットされること、
  途中の手動施錠でキャンセルされること。

## 触るファイル

- `crates/mube-firmware/src/config.rs` — `AUTO_LOCK_AFTER: Duration` 追加
- `crates/mube-firmware/src/main.rs` — `AUTO_LOCK_CMD` シグナル追加・`apply_target` で通知・
  `auto_lock_task` 追加・spawn・`with_timeout` import

## やらないこと（YAGNI）

- オンオフ切り替え・実行時変更（config 定数の変更＝再ビルドで足りる）。
- 状態の永続化やタイマーの EEPROM 保存。
- WebUI 側のカウントダウン表示。

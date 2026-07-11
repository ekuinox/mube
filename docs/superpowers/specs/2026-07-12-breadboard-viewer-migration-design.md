# ブレッドボード配線図ビューア 移植（workstream A / issue #70）

- 日付: 2026-07-12
- ブランチ: `feat/breadboard-viewer`（`origin/master` = eb407af / #68 から作成済み）
- 対応 issue: #70（クローズ予定）
- 位置づけ: perfboard→ブレッドボード方針転換に伴い、branch 固有の keeper だったブラウザビューアを clean（perfboard 抜き）で master 系に移植する。

## 背景

perfboard（ユニバーサル基板・両面はんだ・Pico スタック前提）は実機試作で「素人ハンドメイドに困難」と判明し退役。ブレッドボード実装に寄せる（issue #70）。electrical 設計（firmware / `circuit/parts.ts` の NETS / ERC / `circuit/breadboard/` 生成系）は全て生存。GPIO は perfboard 都合の再配置を破棄し master の元割り当て（GP15/14/16/18/17）に戻す＝**master から仕切り直すだけで自動達成**（ファーム変更不要）。

## スコープ（この spec）

ビューア3ファイル ＋ README 1節のみ。**perfboard は一切持ち込まない**。

## 変更内容

`feat/perfboard-wiring-diagram` の **commit `cc940f5`**（ビューア初版・perfboard 統合前）から以下3ファイルをそのまま持ってくる（3ファイルとも perfboard 参照ゼロを grep で確認済み）:

- `circuit/breadboard-viewer.html` — プリセット切替（SERVO_DRIVE / LED_BUTTON / FULL）・ドラッグ移動・ホイールズーム。参照する SVG は `breadboard-<preset>.svg` のみ。
- `circuit/breadboard-serve.py` — `breadboard-auto.ts` で全プリセット SVG を `build/` に生成 → ローカル配信 → cloudflared quick tunnel で公開。`NO_TUNNEL=1` でローカルのみ（`http://127.0.0.1:8766`）。`PORT` で変更可。
- `circuit/breadboard.sh` — bun が無ければ nix dev シェルに再突入する薄いラッパ。実行権 (`chmod +x`) を付ける。

README（master 版）の「回路（tscircuit / TS）」節の直後に「ブレッドボード配線図をブラウザで確認」節を追加（`cc940f5` の clean 版ベース。ユニバーサル基板の記述は入れない）。

## 依存整合（確認済み）

- `breadboard-serve.py` が叩く `circuit/breadboard-auto.ts` とプリセット `SERVO_DRIVE / LED_BUTTON / FULL` は master に存在・キー一致（`circuit/breadboard/subcircuit.ts` の `PRESETS`）。
- 生成 SVG は `build/`（.gitignore 済み・非コミット）。

## やらないこと（YAGNI）

- `circuit/perfboard*` の移植、perfboard スクリプト、GPIO 再配置、perfboard の spec/plan の持ち込み。全部なし。

## perfboard の保存方針（決定：パークのまま保存）

- perfboard 生成系は **master に持ち込まない**。`feat/perfboard-wiring-diagram` ブランチ（tip `507f7e9`、origin にもあり）に残す。
- 将来の**片面ユニバーサル基板**作業の復活点として、この tip に**タグを打つ**（例: `perfboard-parked`）。
- 復活時の注意: 今の perfboard レイアウトは「Pico スタック＋両面配線」前提。片面基板は前提が違うため**レイアウト部分は作り直し**になる。再利用できるのは格子・フットプリント・ネット配線の芯。

## 検証

- `cd circuit && bun test`（ERC 含む・移植では circuit ロジック不変なので緑のはず）。
- `NO_TUNNEL=1 ./circuit/breadboard.sh` を実行し、3プリセットの SVG が `build/` に生成され `http://127.0.0.1:8766/breadboard.html` で配信されることを確認（トンネルは張らない）。

## 完了条件

- 上記3ファイル＋README節が追加され、`bun test` 緑、`NO_TUNNEL=1` ビューアがローカルで表示できる。
- PR を出して #70 をクローズ。

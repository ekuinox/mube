---
name: creating-backlog-tasks
description: >-
  残タスク・TODO・アイデアをこのリポジトリの backlog に積むときに使う。
  「タスク積んでおいて」「backlog に追加して」「タスク化して」「あとでやることにして」
  などの依頼や、issue からの移管、作業中に見つけた残件の記録が対象。
  タスクの編集・クローズ・アーカイブにも適用する。
---

# creating-backlog-tasks

残タスクは Backlog.md（`backlog/tasks/` の markdown）で管理する。
作成・編集は必ず devShell の `backlog` CLI で行う。

## 手順

1. 重複確認: `nix develop -c backlog search "<キーワード>" --plain`。既存タスクに足すべき内容なら `backlog task edit` で済ませる。
2. 作成:

```
nix develop -c backlog task create "<タイトル>" -d "<本文>" -l "<ラベル>" --ac "<受け入れ基準>"
```

- タイトル・本文は日本語。受け入れ基準は `--ac`（複数可）で渡す。
- 長い本文は一時ファイルに書き、`DESC="$(cat /tmp/desc.md)"` を経由して `-d "$DESC"` で渡す（本文のバッククォートを bash に評価させないため）。
- 決まった書き方に迷ったら公式ガイド: `nix develop -c backlog instructions task-creation`

3. リネーム: 作成直後にファイル名を `task-N-<英語のkebab-case>.md` へ `mv` する（小文字・ハイフン区切り。スペースと非 ASCII を排除。作成直後は未コミットなので `git mv` は使えない）。ツールは frontmatter の id でタスクを解決し、既存ファイル名は編集後も保持されるので、リネームしても壊れない。
4. 検証: `nix develop -c backlog task list --plain` に新タスクが出ることを確認する。
5. `backlog/` の変更はコミット対象（派生物ではない）。

## やらないこと

- `backlog/tasks/*.md` を Write で直接新規作成しない。セクションマーカー・ordinal・日付は CLI が正しく生成するもので、既存ファイルの模倣はツールの形式変更に追従できない。既存タスクの本文修正も原則 `backlog task edit`（`-d` / `--notes` / `--ac`）を使う。
- タイトルを英語にしない。英語にするのは kebab のファイル名だけ。

## クローズ・統合

- 完了は `backlog task edit <id> -s Done`。重複や統合で消すときは `--notes` で統合先を書いてから `backlog task archive <id>`（`backlog/archive/tasks/` へ移る）。
- Done タスクの `backlog/completed/` への片付けは、本来 `backlog task complete <id>`。ただし complete は view/edit と違い **`task-N - <タイトル>.md` というファイル名パターンで対象を探す**ため、このリポジトリの kebab-case リネーム規約（`task-N-<kebab>.md`、`task-N - ` 接頭辞が無い）だと "Failed to complete task" で失敗する（v1.48.0、素の命名なら成功・kebab リネーム後は失敗・`task-N - 別名.md` なら成功を最小再現で確認。2026-07-21）。このリポジトリでは代わりに `git mv backlog/tasks/<file> backlog/completed/` で直接移す（complete の移動先と同一。一覧・集計は正しく扱われる）。completed/archive のタスクは `backlog task view <id>` で解決できなくなる点に注意（ファイルは残る）。

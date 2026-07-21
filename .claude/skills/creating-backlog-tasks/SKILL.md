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

3. リネーム: 作成直後にファイル名を `task-N - <英語のkebab-case>.md` へ `mv` する（例: `task-14 - servo-torque-check.md`。後半は小文字ハイフン区切りで非 ASCII を排除。作成直後は未コミットなので `git mv` は使えない）。**`task-N - ` 接頭辞（スペース・ハイフン・スペース）は必ず残す**: view/edit は frontmatter の id で解決するが、`task complete` だけは `task-N - *.md` のファイル名パターンで対象を探すため、接頭辞を崩すと "Failed to complete task" で失敗する（v1.48.0 で最小再現により確認。2026-07-21）。
4. 検証: `nix develop -c backlog task list --plain` に新タスクが出ることを確認する。
5. `backlog/` の変更はコミット対象（派生物ではない）。

## やらないこと

- `backlog/tasks/*.md` を Write で直接新規作成しない。セクションマーカー・ordinal・日付は CLI が正しく生成するもので、既存ファイルの模倣はツールの形式変更に追従できない。既存タスクの本文修正も原則 `backlog task edit`（`-d` / `--notes` / `--ac`）を使う。
- タイトルを英語にしない。英語にするのは kebab のファイル名だけ。

## クローズ・統合

- 完了は `backlog task edit <id> -s Done`。重複や統合で消すときは `--notes` で統合先を書いてから `backlog task archive <id>`（`backlog/archive/tasks/` へ移る）。
- Done タスクの `backlog/completed/` への片付けは `backlog task complete <id>`（手順 3 の `task-N - ` 接頭辞が保たれていれば動く）。completed/archive のタスクは `backlog task view <id>` で解決できなくなる点に注意（ファイルは残る。集計・一覧は正常）。

# Claude Code マルチエージェント セットアップ

Windows 11 ARM64 環境で、Claude アカウントと GitHub アカウントを任意に組み合わせて
Claude Code のマルチエージェント環境を構築するスクリプトです。

## クイックスタート

PowerShell を **管理者として** 開いて実行：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup-claude-multiagent.ps1
```

## 特徴

- **Claudeアカウント と GitHubアカウント を別々に設定可能**
  - 例: 個人のClaudeアカウント + 会社のGitHub Organization
  - 例: 会社のClaudeアカウント + 個人のGitHub
- **3つの環境に対応**: CLI / Claude Desktop / Claude Code Web
- **インストール済みツールは自動スキップ** — 何度実行しても安全
- **別のPCでも同じスクリプトで再セットアップ可能**

## スクリプトがやること（全9ステップ）

| STEP | 内容 | 詳細 |
|------|------|------|
| 1 | Node.js | ARM64ネイティブ版をwingetでインストール |
| 2 | Git | Git for Windowsをインストール |
| 3 | GitHub CLI | リポジトリ作成等に使用 |
| 4 | Claude Code (CLI) | npmでグローバルインストール |
| 5 | Claude Desktop | 自動検出 / wingetでインストール |
| 6 | **Claudeアカウント設定** | 3つのモードから選択（下記参照） |
| 7 | **GitHubアカウント設定** | 任意のGitHubアカウントのPATを設定 |
| 8 | プロジェクト作成 | リポジトリ作成 + Git認証（CLI/Desktop両対応） |
| 9 | ヘルパーコマンド | PowerShellプロファイルに便利コマンドを登録 |

## Claudeアカウントのモード（STEP 6）

セットアップ時に以下から選択します：

| モード | 用途 |
|--------|------|
| 1. そのまま使う | 現在ログイン中のClaudeアカウントを使用（デフォルト） |
| 2. 切り替える | 次回起動時に別アカウントで再ログイン |
| 3. プロファイル分離 | 複数のClaudeアカウントを名前付きで使い分け |

モード3を選ぶと、プロファイルごとに専用コマンドが生成されます：

```powershell
claude-personal    # 個人アカウントで起動
claude-work        # 仕事用アカウントで起動
```

## セットアップ後に使えるコマンド

### 基本操作

```powershell
# プロジェクトフォルダで Claude Code を起動
cd my-project
claude

# Claude Desktop の場合
# → Desktop起動 → + → Claude Code → フォルダ選択
```

### マルチエージェント起動

```powershell
# CLI で2つ同時起動
claude-agents -Count 2

# ブランチを分けて3つ同時起動
claude-agents -Count 3 -Branches @("feature/ui","feature/api","feature/docs")

# Claude Desktop で2つ起動
claude-agents -Count 2 -Desktop

# Claudeプロファイルを指定して起動（モード3の場合）
claude-agents -Count 2 -Profile personal
```

### リポジトリ管理

```powershell
# 新しい Public リポジトリを作成してセットアップ
claude-setup-repo my-new-project

# Private リポジトリとして作成
claude-setup-repo secret-project -Private
```

### 環境確認

```powershell
# インストール状況 / アカウント構成 / Git設定を一覧表示
claude-status
```

### ショートカット

| コマンド | ショートカット |
|----------|---------------|
| `claude-agents` | `cma` |
| `claude-setup-repo` | `csr` |
| `claude-status` | `cs` |

## アカウント構成の例

### 例1: 個人Claude + 会社GitHub

```
Claude: 個人の Anthropic アカウント（モード1）
GitHub: company-org の PAT
→ company-org/project にpush
```

### 例2: 会社Claude + 個人GitHub

```
Claude: 会社の Anthropic Teams アカウント（モード1）
GitHub: my-personal-account の PAT
→ my-personal-account/side-project にpush
```

### 例3: 複数Claude + 1つのGitHub

```
Claude: personal / work の2プロファイル（モード3）
GitHub: oss9-code の PAT
→ claude-personal で起動 → oss9-code にpush
→ claude-work で起動 → oss9-code にpush
```

### 例4: 1つのClaude + 複数GitHub（スクリプト再実行）

```
1回目: Claude デフォルト + github-account-A の PAT → project-A をセットアップ
2回目: Claude デフォルト + github-account-B の PAT → project-B をセットアップ
※ 各プロジェクトフォルダにGitHub認証が紐づくため混在可能
```

## ファイル構成

セットアップ後に作成されるファイル：

```
~/.claude-multiagent-config.json   ← アカウント設定（PAT等）
~/.git-credentials                 ← Git認証情報（Desktop用）
~/.claude-personal/                ← Claudeプロファイル（モード3の場合）
~/.claude-work/                    ← Claudeプロファイル（モード3の場合）
<プロジェクト>/CLAUDE.md           ← Claude Code用のプロジェクト設定
<プロジェクト>/.git/config         ← プロジェクト単位のGit認証
$PROFILE                           ← ヘルパーコマンド（PowerShellプロファイル）
```

## 各環境での認証の仕組み

| 環境 | Claude認証 | GitHub認証 |
|------|-----------|-----------|
| CLI（ターミナル） | `claude` 起動時にログイン | リモートURLにトークン埋め込み |
| Claude Desktop | Desktop アプリでログイン | `.git-credentials` 経由 |
| Claude Code Web | claude.ai のアカウント | コラボレーター追加 or フォーク |

## トラブルシューティング

| 問題 | 解決策 |
|------|--------|
| スクリプトが文字化けする | UTF-8 BOM付きで保存されているか確認 |
| winget が見つからない | Microsoft Store で「アプリ インストーラー」を更新 |
| `claude` コマンドが見つからない | PowerShellを再起動してから再実行 |
| `git push` で認証エラー | `git remote -v` でURLにトークンが含まれているか確認 |
| Claude Desktop でpushできない | `claude-status` で .git-credentials の状態を確認 |
| PATの期限切れ | スクリプトを再実行してSTEP 7で新しいPATを入力 |
| 複数エージェントがコンフリクト | ブランチを分けて作業し、後でマージ |
| プロファイル切替でエラー | `$env:CLAUDE_CONFIG_DIR` を確認 |

## 必要な情報

- Push先 GitHub アカウントの PAT（`ghp_` で始まるトークン）
- そのアカウントのメールアドレス（任意、デフォルト値あり）
- Claudeプロファイル分離を使う場合は各アカウントのログイン情報
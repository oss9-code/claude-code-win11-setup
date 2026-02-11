# Claude Code マルチエージェント セットアップ

## クイックスタート

PowerShell を **管理者として** 開いて、以下を実行：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup-claude-multiagent.ps1
```

## このスクリプトがやること

1. **環境チェック** — 既にインストール済みのツールを自動検出してスキップ
2. **Node.js / Git / GitHub CLI / Claude Code** — 未導入のもののみインストール
3. **GitHub PAT 設定** — oss9-code のトークンを安全に保存・検証
4. **リポジトリ作成** — GitHub上に新規作成 or 既存をclone（自動判定）
5. **Git認証設定** — プロジェクト単位でoss9-codeの認証を設定
6. **ヘルパーコマンド登録** — マルチエージェント起動コマンドをPowerShellに追加

## セットアップ後に使えるコマンド

| コマンド | ショートカット | 説明 |
|----------|--------------|------|
| `claude-agents -Count 2` | `cma -Count 2` | 2エージェント同時起動 |
| `claude-agents -Count 3 -Branches @("feature/ui","feature/api","feature/docs")` | — | ブランチ指定で3エージェント |
| `claude-setup-repo my-app` | `csr my-app` | 新しいリポジトリを作成＆設定 |
| `claude-status` | `cs` | 環境の状態確認 |

## 別のPCでセットアップする場合

同じスクリプトをコピーして実行するだけでOKです。
インストール済みのツールは自動スキップされます。

## 必要な情報

- oss9-code の GitHub PAT（`ghp_`で始まるトークン）
- oss9-code のメールアドレス

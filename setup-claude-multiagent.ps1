# ============================================================
# Claude Code マルチエージェント セットアップスクリプト
# 対象: Windows 11 ARM64
# Claudeアカウント と GitHubアカウント を任意に組み合わせ可能
# ============================================================
# 使い方:
#   1. このファイルを任意のフォルダに保存
#   2. PowerShell を管理者として開く
#   3. 以下を実行:
#      Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#      .\setup-claude-multiagent.ps1
# ============================================================

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# --- 色付きメッセージ用ヘルパー ---
function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
}

function Write-OK {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Skip {
    param([string]$Message)
    Write-Host "  [SKIP] $Message (既にインストール済み)" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "  [INFO] $Message" -ForegroundColor Gray
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [WARN] $Message" -ForegroundColor Magenta
}

function Write-Err {
    param([string]$Message)
    Write-Host "  [ERROR] $Message" -ForegroundColor Red
}

function Confirm-Continue {
    param([string]$Message = "続行しますか？")
    $choice = Read-Host "  $Message (Y/n)"
    if ($choice -eq "n" -or $choice -eq "N") {
        Write-Info "スキップしました"
        return $false
    }
    return $true
}

function Test-Command {
    param([string]$Command)
    try {
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Refresh-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Test-ClaudeDesktop {
    $paths = @(
        (Join-Path $env:LOCALAPPDATA "Programs\claude-desktop\Claude.exe"),
        (Join-Path $env:LOCALAPPDATA "AnthropicClaude\Claude.exe"),
        (Join-Path ${env:ProgramFiles} "Claude\Claude.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Claude\Claude.exe")
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    try {
        $reg = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
               Where-Object { $_.DisplayName -like "*Claude*" }
        if ($reg -and $reg.InstallLocation) {
            $exe = Join-Path $reg.InstallLocation "Claude.exe"
            if (Test-Path $exe) { return $exe }
        }
    } catch {}
    return $null
}

# ============================================================
# メイン処理開始
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor White
Write-Host "  Claude Code マルチエージェント セットアップ" -ForegroundColor White
Write-Host "  Windows 11 ARM64" -ForegroundColor White
Write-Host "========================================================" -ForegroundColor White
Write-Host ""
Write-Host "  このスクリプトは以下をセットアップします:" -ForegroundColor Gray
Write-Host "    1. Node.js (LTS)" -ForegroundColor Gray
Write-Host "    2. Git for Windows" -ForegroundColor Gray
Write-Host "    3. GitHub CLI" -ForegroundColor Gray
Write-Host "    4. Claude Code (CLI)" -ForegroundColor Gray
Write-Host "    5. Claude Desktop の検出と設定" -ForegroundColor Gray
Write-Host "    6. Claude アカウント設定" -ForegroundColor Gray
Write-Host "    7. GitHub アカウント + PAT の設定" -ForegroundColor Gray
Write-Host "    8. プロジェクトの作成と Git 認証設定" -ForegroundColor Gray
Write-Host "    9. マルチエージェント用プロファイル設定" -ForegroundColor Gray
Write-Host ""
Write-Host "  Claudeアカウント と GitHubアカウント は別々に設定できます。" -ForegroundColor Yellow
Write-Host "  既にインストール済みの項目は自動でスキップします。" -ForegroundColor Yellow
Write-Host ""

if (-not (Confirm-Continue "セットアップを開始しますか？")) {
    Write-Host "セットアップを中止しました。" -ForegroundColor Red
    exit 0
}

# --- 状態チェック ---
Write-Step "STEP 0/9: 現在の環境をチェック中..."

$status = @{
    NodeJS        = Test-Command "node"
    Npm           = Test-Command "npm"
    Git           = Test-Command "git"
    GhCli         = Test-Command "gh"
    ClaudeCLI     = Test-Command "claude"
    ClaudeDesktop = Test-ClaudeDesktop
    Winget        = Test-Command "winget"
}

Write-Host ""
Write-Host "  現在の状態:" -ForegroundColor White
Write-Host "  +--------------------+-----------+" -ForegroundColor Gray
Write-Host "  | ツール             | 状態      |" -ForegroundColor Gray
Write-Host "  +--------------------+-----------+" -ForegroundColor Gray

$toolChecks = @(
    @{ Key = "NodeJS";        Label = "Node.js            "; VerCmd = { node -v } },
    @{ Key = "Npm";           Label = "npm                "; VerCmd = { npm -v } },
    @{ Key = "Git";           Label = "Git                "; VerCmd = { (git --version) -replace "git version ", "" } },
    @{ Key = "GhCli";         Label = "GitHub CLI (gh)    "; VerCmd = { (gh --version | Select-Object -First 1) -replace "gh version ", "" -replace " \(.*", "" } },
    @{ Key = "ClaudeCLI";     Label = "Claude Code (CLI)  "; VerCmd = { "installed" } },
    @{ Key = "ClaudeDesktop"; Label = "Claude Desktop     "; VerCmd = { "found" } }
)

foreach ($tool in $toolChecks) {
    $val = $status[$tool.Key]
    $installed = if ($tool.Key -eq "ClaudeDesktop") { $null -ne $val } else { $val }
    if ($installed) {
        $ver = try { & $tool.VerCmd } catch { "?" }
        Write-Host "  | $($tool.Label)| OK $ver" -ForegroundColor Green
    } else {
        Write-Host "  | $($tool.Label)| 未導入" -ForegroundColor Red
    }
}
Write-Host "  +--------------------+-----------+" -ForegroundColor Gray

if (-not $status.Winget) {
    Write-Err "winget が見つかりません。Microsoft Store から 'アプリ インストーラー' を更新してください。"
    Write-Host "  https://apps.microsoft.com/detail/9NBLGGH4NNS1" -ForegroundColor Cyan
    exit 1
}

# ============================================================
# STEP 1: Node.js
# ============================================================
Write-Step "STEP 1/9: Node.js のインストール"

if ($status.NodeJS) {
    Write-Skip "Node.js $(node -v)"
} else {
    Write-Info "Node.js LTS をインストールします（ARM64ネイティブ版）"
    if (Confirm-Continue) {
        winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
        Refresh-Path
        if (Test-Command "node") {
            Write-OK "Node.js $(node -v) をインストールしました"
        } else {
            Write-Warn "インストール後にPATHが反映されない場合があります"
            Write-Warn "PowerShell を再起動してからスクリプトを再実行してください"
            exit 1
        }
    }
}

# ============================================================
# STEP 2: Git
# ============================================================
Write-Step "STEP 2/9: Git のインストール"

if ($status.Git) {
    Write-Skip "Git $(git --version)"
} else {
    Write-Info "Git for Windows をインストールします"
    if (Confirm-Continue) {
        winget install Git.Git --accept-source-agreements --accept-package-agreements
        Refresh-Path
        if (Test-Command "git") {
            Write-OK "Git をインストールしました"
        } else {
            Write-Warn "PowerShell を再起動してからスクリプトを再実行してください"
            exit 1
        }
    }
}

# ============================================================
# STEP 3: GitHub CLI
# ============================================================
Write-Step "STEP 3/9: GitHub CLI のインストール"

if ($status.GhCli) {
    Write-Skip "GitHub CLI $(gh --version | Select-Object -First 1)"
} else {
    Write-Info "GitHub CLI をインストールします（リポジトリ作成に使用）"
    if (Confirm-Continue) {
        winget install GitHub.cli --accept-source-agreements --accept-package-agreements
        Refresh-Path
        if (Test-Command "gh") {
            Write-OK "GitHub CLI をインストールしました"
        } else {
            Write-Warn "PowerShell を再起動してからスクリプトを再実行してください"
            exit 1
        }
    }
}

# ============================================================
# STEP 4: Claude Code (CLI)
# ============================================================
Write-Step "STEP 4/9: Claude Code (CLI) のインストール"

if ($status.ClaudeCLI) {
    Write-Skip "Claude Code (CLI)"
} else {
    if (-not (Test-Command "npm")) {
        Write-Err "npm が見つかりません。Node.js を先にインストールしてください。"
        Write-Err "PowerShell を再起動してからスクリプトを再実行してください。"
        exit 1
    }
    Write-Info "Claude Code (CLI) をインストールします"
    if (Confirm-Continue) {
        npm install -g @anthropic-ai/claude-code
        Refresh-Path
        if (Test-Command "claude") {
            Write-OK "Claude Code (CLI) をインストールしました"
        } else {
            Write-Warn "インストールは完了しましたが、PATHに反映されていない可能性があります"
            Write-Warn "PowerShell を再起動してからスクリプトを再実行してください"
        }
    }
}

# ============================================================
# STEP 5: Claude Desktop の検出と設定
# ============================================================
Write-Step "STEP 5/9: Claude Desktop の検出と設定"

$claudeDesktopPath = Test-ClaudeDesktop

if ($claudeDesktopPath) {
    Write-OK "Claude Desktop を検出しました: $claudeDesktopPath"
} else {
    Write-Info "Claude Desktop が見つかりません"
    Write-Host ""
    Write-Host "  Claude Desktop をインストールする場合:" -ForegroundColor Yellow
    Write-Host "    https://claude.ai/download からダウンロード" -ForegroundColor Gray
    Write-Host "    または winget install Anthropic.Claude" -ForegroundColor Gray
    Write-Host ""
    if (Confirm-Continue "Claude Desktop を winget でインストールしますか？") {
        winget install Anthropic.Claude --accept-source-agreements --accept-package-agreements
        Refresh-Path
        $claudeDesktopPath = Test-ClaudeDesktop
        if ($claudeDesktopPath) {
            Write-OK "Claude Desktop をインストールしました"
        } else {
            Write-Warn "インストールは完了しましたが、検出できませんでした"
            Write-Warn "手動でインストールした場合は問題ありません"
        }
    }
}

# ============================================================
# STEP 6: Claude アカウント設定
# ============================================================
Write-Step "STEP 6/9: Claude アカウント設定"

$configFile = Join-Path $env:USERPROFILE ".claude-multiagent-config.json"
$existingConfig = $null
if (Test-Path $configFile) {
    try { $existingConfig = Get-Content $configFile -Raw | ConvertFrom-Json } catch {}
}

Write-Host ""
Write-Host "  Claude Code で使用する Anthropic アカウントを設定します。" -ForegroundColor White
Write-Host ""
Write-Host "  Claude アカウントの認証方法:" -ForegroundColor Yellow
Write-Host "    1. 現在ログイン中のアカウントをそのまま使う（デフォルト）" -ForegroundColor Gray
Write-Host "    2. 別のアカウントに切り替える（claude を起動時に再ログイン）" -ForegroundColor Gray
Write-Host "    3. 複数のClaudeアカウントを使い分ける（プロファイル分離）" -ForegroundColor Gray
Write-Host ""

$claudeMode = Read-Host "  選択してください (1/2/3、デフォルト: 1)"
if ([string]::IsNullOrEmpty($claudeMode)) { $claudeMode = "1" }

$claudeProfiles = @()

switch ($claudeMode) {
    "1" {
        Write-OK "現在のClaudeアカウントを使用します"
        Write-Info "まだログインしていない場合は、後で 'claude' 実行時にログインしてください"
        $claudeProfiles += @{
            name      = "default"
            configDir = ""
            note      = "デフォルト（現在のアカウント）"
        }
    }
    "2" {
        Write-Info "Claude Code を次回起動時に再ログインしてアカウントを切り替えてください"
        Write-Host ""
        Write-Host "  手順:" -ForegroundColor Yellow
        Write-Host "    1. claude --logout を実行してログアウト" -ForegroundColor Gray
        Write-Host "    2. claude を実行して新しいアカウントでログイン" -ForegroundColor Gray
        Write-Host ""
        $claudeProfiles += @{
            name      = "default"
            configDir = ""
            note      = "再ログインが必要"
        }
    }
    "3" {
        Write-Host ""
        Write-Host "  複数のClaudeアカウントを使い分けます。" -ForegroundColor White
        Write-Host "  各プロファイルに名前を付けてください。" -ForegroundColor Gray
        Write-Host ""

        $profileCount = Read-Host "  プロファイル数を入力してください (2-5、デフォルト: 2)"
        if ([string]::IsNullOrEmpty($profileCount)) { $profileCount = "2" }
        $profileCount = [int]$profileCount
        if ($profileCount -lt 2) { $profileCount = 2 }
        if ($profileCount -gt 5) { $profileCount = 5 }

        for ($i = 1; $i -le $profileCount; $i++) {
            $defaultName = if ($i -eq 1) { "personal" } elseif ($i -eq 2) { "work" } else { "profile$i" }
            $profileName = Read-Host "  プロファイル $i の名前 (デフォルト: $defaultName)"
            if ([string]::IsNullOrEmpty($profileName)) { $profileName = $defaultName }

            $configDir = Join-Path $env:USERPROFILE ".claude-$profileName"
            if (-not (Test-Path $configDir)) {
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
                Write-OK "設定ディレクトリを作成しました: $configDir"
            } else {
                Write-Skip "設定ディレクトリ: $configDir"
            }

            $claudeProfiles += @{
                name      = $profileName
                configDir = $configDir
                note      = "CLAUDE_CONFIG_DIR=$configDir"
            }
        }

        Write-Host ""
        Write-Info "各プロファイルで初回起動時にログインが必要です:"
        foreach ($p in $claudeProfiles) {
            Write-Info "  claude-$($p.name) → $($p.name) のアカウントでログイン"
        }
    }
}

# ============================================================
# STEP 7: GitHub アカウント + PAT 設定
# ============================================================
Write-Step "STEP 7/9: GitHub アカウント + PAT の設定"

Write-Host ""
Write-Host "  GitHub の認証設定を行います。" -ForegroundColor White
Write-Host "  ※ Claude のアカウントとは別の GitHub アカウントを使えます。" -ForegroundColor Yellow
Write-Host ""

# 既存設定の確認
$savedPat = ""
$savedEmail = ""
$ghUser = ""

if ($existingConfig) {
    $savedPat = $existingConfig.pat
    $savedEmail = $existingConfig.email
    $ghUser = $existingConfig.ghUser
    if ($savedPat) {
        $maskedPat = $savedPat.Substring(0, 7) + "..." + $savedPat.Substring($savedPat.Length - 4)
        Write-Info "保存済みの設定が見つかりました:"
        Write-Info "  GitHubユーザー: $ghUser"
        Write-Info "  PAT: $maskedPat"
        if (-not (Confirm-Continue "この設定を使いますか？")) {
            $savedPat = ""
            $savedEmail = ""
            $ghUser = ""
        }
    }
}

if ([string]::IsNullOrEmpty($savedPat)) {
    Write-Host ""
    Write-Host "  Push先の GitHub アカウントの Personal Access Token (classic) が必要です。" -ForegroundColor White
    Write-Host ""
    Write-Host "  PATの作成手順:" -ForegroundColor Yellow
    Write-Host "    1. Push先のGitHubアカウントでログイン" -ForegroundColor Gray
    Write-Host "    2. https://github.com/settings/tokens にアクセス" -ForegroundColor Gray
    Write-Host "    3. [Generate new token] > [Generate new token (classic)]" -ForegroundColor Gray
    Write-Host "    4. Note: claude-code-access（任意の名前）" -ForegroundColor Gray
    Write-Host "    5. Expiration: 90 days（推奨）" -ForegroundColor Gray
    Write-Host "    6. Scopes: [repo] にチェック（一番上の項目）" -ForegroundColor Gray
    Write-Host "    7. [Generate token] をクリック" -ForegroundColor Gray
    Write-Host "    8. 表示されたトークン (ghp_...) をコピー" -ForegroundColor Gray
    Write-Host ""

    $inputPat = Read-Host "  GitHub PAT を入力してください (ghp_...)"

    if ([string]::IsNullOrEmpty($inputPat)) {
        Write-Err "PATが入力されませんでした。"
        Write-Info "PAT を作成してからスクリプトを再実行してください。"
        exit 1
    }

    if (-not $inputPat.StartsWith("ghp_")) {
        Write-Warn "PAT は通常 'ghp_' で始まります。入力を確認してください。"
        if (-not (Confirm-Continue "この値でそのまま続行しますか？")) {
            exit 1
        }
    }

    $savedPat = $inputPat

    # PAT の有効性をテスト
    Write-Info "PAT の有効性を確認中..."
    try {
        $headers = @{ Authorization = "token $savedPat" }
        $response = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -ErrorAction Stop
        $ghUser = $response.login
        Write-OK "認証成功: GitHub ユーザー = $ghUser"
    } catch {
        Write-Err "PAT の認証に失敗しました。トークンが正しいか確認してください。"
        Write-Err "エラー: $_"
        if (-not (Confirm-Continue "PAT検証をスキップして続行しますか？（非推奨）")) {
            exit 1
        }
        $ghUser = Read-Host "  GitHub ユーザー名を手動で入力してください"
    }

    $savedEmail = Read-Host "  $ghUser のメールアドレスを入力してください（Enterでデフォルト）"
    if ([string]::IsNullOrEmpty($savedEmail)) {
        $savedEmail = "$ghUser@users.noreply.github.com"
        Write-Info "デフォルトのメール ($savedEmail) を使用します"
    }
}

Write-Host ""
Write-Host "  ┌─────────────────────────────────────┐" -ForegroundColor White
Write-Host "  │ アカウント構成                       │" -ForegroundColor White
Write-Host "  ├─────────────────────────────────────┤" -ForegroundColor White
Write-Host "  │ Claude: $(if($claudeProfiles.Count -eq 1){"$($claudeProfiles[0].note)"}else{"$($claudeProfiles.Count) プロファイル"})" -ForegroundColor Gray
Write-Host "  │ GitHub: $ghUser" -ForegroundColor Gray
Write-Host "  └─────────────────────────────────────┘" -ForegroundColor White
Write-Host ""

if (-not (Confirm-Continue "この構成で続行しますか？")) {
    Write-Host "セットアップを中止しました。スクリプトを再実行してください。" -ForegroundColor Red
    exit 0
}

# 設定を保存
$configObj = @{
    pat            = $savedPat
    email          = $savedEmail
    ghUser         = $ghUser
    claudeDesktop  = if ($claudeDesktopPath) { $claudeDesktopPath } else { "" }
    claudeMode     = $claudeMode
    claudeProfiles = $claudeProfiles
    updated        = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}
$configObj | ConvertTo-Json -Depth 5 | Set-Content -Path $configFile -Encoding UTF8
Write-OK "設定を保存しました: $configFile"

# ============================================================
# STEP 8: プロジェクトの作成と Git 認証設定
# ============================================================
Write-Step "STEP 8/9: プロジェクトの作成と Git 認証設定"

Write-Host ""
Write-Host "  ここで設定したプロジェクトは以下の全てで使えます:" -ForegroundColor White
Write-Host "    - ターミナルの Claude Code (CLI)" -ForegroundColor Gray
Write-Host "    - Claude Desktop の Claude Code" -ForegroundColor Gray
Write-Host "    - Claude Code Web (コラボレーター追加が必要)" -ForegroundColor Gray
Write-Host ""

$projectName = Read-Host "  作成するリポジトリ名を入力してください（例: my-project、Enterでスキップ）"

if ([string]::IsNullOrEmpty($projectName)) {
    Write-Info "リポジトリ作成はスキップします。後から claude-setup-repo <名前> で作成できます。"
} else {
    $projectDir = Join-Path (Get-Location) $projectName

    if (Test-Path $projectDir) {
        Write-Info "ディレクトリ '$projectName' は既に存在します"

        if (Test-Path (Join-Path $projectDir ".git")) {
            Write-Info "既存の Git リポジトリを検出しました"
            Set-Location $projectDir
        } else {
            Write-Info "Git リポジトリではありません。初期化します。"
            Set-Location $projectDir
            git init
        }
    } else {
        Write-Info "GitHub 上のリポジトリを確認中..."
        $repoExists = $false
        try {
            $headers = @{ Authorization = "token $savedPat" }
            $null = Invoke-RestMethod -Uri "https://api.github.com/repos/$ghUser/$projectName" -Headers $headers -ErrorAction Stop
            $repoExists = $true
            Write-Info "GitHub にリポジトリが見つかりました。clone します。"
        } catch {
            Write-Info "GitHub にリポジトリが見つかりません。新規作成します。"
        }

        if ($repoExists) {
            git clone "https://${ghUser}:${savedPat}@github.com/${ghUser}/${projectName}.git"
            Set-Location $projectDir
        } else {
            Write-Host ""
            Write-Host "  リポジトリの公開設定:" -ForegroundColor White
            Write-Host "    1. Public（公開）" -ForegroundColor Gray
            Write-Host "    2. Private（非公開）" -ForegroundColor Gray
            $visibility = Read-Host "  選択してください (1/2、デフォルト: 1)"
            $isPrivate = $visibility -eq "2"

            Write-Info "リポジトリを作成中..."
            try {
                $body = @{
                    name      = $projectName
                    private   = $isPrivate
                    auto_init = $true
                } | ConvertTo-Json

                $headers = @{
                    Authorization  = "token $savedPat"
                    "Content-Type" = "application/json"
                }
                $null = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Method Post -Headers $headers -Body $body -ErrorAction Stop
                Write-OK "GitHub にリポジトリを作成しました: $ghUser/$projectName"

                Start-Sleep -Seconds 2
                git clone "https://${ghUser}:${savedPat}@github.com/${ghUser}/${projectName}.git"
                Set-Location $projectDir
            } catch {
                Write-Err "リポジトリの作成に失敗しました: $_"
                Write-Info "手動でリポジトリを作成してからスクリプトを再実行してください。"
                Write-Info "URL: https://github.com/new"
            }
        }
    }

    # Git ユーザー設定（プロジェクト単位）
    if (Test-Path (Join-Path (Get-Location) ".git")) {
        Write-Info "Git ユーザー情報を設定中..."
        git config user.name $ghUser
        git config user.email $savedEmail

        $currentRemote = git remote get-url origin 2>$null
        if ($currentRemote) {
            $newRemote = "https://${ghUser}:${savedPat}@github.com/${ghUser}/${projectName}.git"
            git remote set-url origin $newRemote
            Write-OK "リモートURLを設定しました（CLI / Desktop 共通）"
        }

        # Git Credential Manager に認証情報を保存
        if (Test-Command "git") {
            Write-Info "Git Credential に認証情報を保存中..."
            git config credential.useHttpPath true

            $gitCredFile = Join-Path $env:USERPROFILE ".git-credentials"
            $credLine = "https://${ghUser}:${savedPat}@github.com"
            $existingCreds = ""
            if (Test-Path $gitCredFile) {
                $existingCreds = Get-Content $gitCredFile -Raw -ErrorAction SilentlyContinue
            }
            if (-not $existingCreds -or -not $existingCreds.Contains($credLine)) {
                Add-Content -Path $gitCredFile -Value $credLine -Encoding UTF8
                Write-OK ".git-credentials に認証情報を追加しました"
            } else {
                Write-Skip ".git-credentials（既に登録済み）"
            }

            $currentHelper = git config --global credential.helper 2>$null
            if (-not $currentHelper) {
                git config --global credential.helper store
                Write-OK "credential.helper = store を設定しました"
            } else {
                Write-Info "credential.helper = $currentHelper（既存設定を維持）"
            }
        }

        Write-OK "Git 設定完了:"
        Write-Info "  user.name  = $(git config user.name)"
        Write-Info "  user.email = $(git config user.email)"
        Write-Info "  remote     = $ghUser/$projectName (トークン認証)"
        Write-Info "  credential = CLI / Desktop 両対応"

        # CLAUDE.md を作成
        $claudeMdPath = Join-Path (Get-Location) "CLAUDE.md"
        if (-not (Test-Path $claudeMdPath)) {
            Write-Info "CLAUDE.md を作成中..."
            $claudeMdContent = @"
# プロジェクト設定

## リポジトリ情報
- GitHub: https://github.com/$ghUser/$projectName
- オーナー: $ghUser

## 開発ルール
- ブランチ戦略: feature/* ブランチで開発し、main にPRを送る
- コミットメッセージ: 日本語OK
- プッシュ先: origin ($ghUser/$projectName)

## 環境
- CLI: ターミナルから claude を起動
- Desktop: Claude Desktop から Claude Code でこのフォルダを指定
- Web: claude.com/code からこのリポジトリを開く
"@
            [System.IO.File]::WriteAllText($claudeMdPath, $claudeMdContent, [System.Text.UTF8Encoding]::new($true))
            git add CLAUDE.md
            git commit -m "Add CLAUDE.md" 2>$null
            Write-OK "CLAUDE.md を作成しました"
        } else {
            Write-Skip "CLAUDE.md"
        }
    }
}

# ============================================================
# STEP 9: マルチエージェント用ヘルパースクリプト
# ============================================================
Write-Step "STEP 9/9: マルチエージェント用ヘルパーの作成"

$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Claudeプロファイル用の関数を動的に生成
$profileFunctions = ""
if ($claudeMode -eq "3") {
    foreach ($p in $claudeProfiles) {
        $profileFunctions += @"

function claude-$($p.name) {
    `$env:CLAUDE_CONFIG_DIR = "$($p.configDir)"
    claude @args
}

"@
    }
}

$helperBlock = @"

# ============================================================
# Claude Code Multi-Agent Helpers (auto-generated)
# ============================================================
$profileFunctions
function claude-agents {
    param(
        [Parameter(Mandatory=`$true)]
        [int]`$Count,

        [Parameter(Mandatory=`$false)]
        [string]`$ProjectDir = (Get-Location),

        [Parameter(Mandatory=`$false)]
        [string[]]`$Branches,

        [Parameter(Mandatory=`$false)]
        [switch]`$Desktop,

        [Parameter(Mandatory=`$false)]
        [string]`$Profile = ""
    )

    <#
    .SYNOPSIS
    Claude Code を複数同時に起動します（マルチエージェント）

    .EXAMPLE
    claude-agents -Count 2
    claude-agents -Count 3 -Branches @("feature/frontend","feature/api","feature/docs")
    claude-agents -Count 2 -Desktop
    claude-agents -Count 2 -Profile personal
    #>

    if (-not (Test-Path `$ProjectDir)) {
        Write-Host "[ERROR] ディレクトリが見つかりません: `$ProjectDir" -ForegroundColor Red
        return
    }

    `$mode = if (`$Desktop) { "Claude Desktop" } else { "Claude Code CLI" }
    Write-Host ""
    Write-Host "  Claude Code マルチエージェント起動" -ForegroundColor Cyan
    Write-Host "  モード: `$mode" -ForegroundColor Gray
    if (`$Profile) { Write-Host "  プロファイル: `$Profile" -ForegroundColor Gray }
    Write-Host "  エージェント数: `$Count" -ForegroundColor Gray
    Write-Host "  プロジェクト: `$ProjectDir" -ForegroundColor Gray
    Write-Host ""

    for (`$i = 1; `$i -le `$Count; `$i++) {
        `$branch = ""
        if (`$Branches -and `$Branches.Count -ge `$i) {
            `$branch = `$Branches[`$i - 1]
        }

        if (`$Desktop) {
            `$configFile = Join-Path `$env:USERPROFILE ".claude-multiagent-config.json"
            if (Test-Path `$configFile) {
                `$config = Get-Content `$configFile -Raw | ConvertFrom-Json
                `$desktopPath = `$config.claudeDesktop
                if (`$desktopPath -and (Test-Path `$desktopPath)) {
                    Start-Process `$desktopPath
                    Write-Host "  [Agent `$i] Claude Desktop を起動しました" -ForegroundColor Green
                    Write-Host "           プロジェクトフォルダ: `$ProjectDir" -ForegroundColor Gray
                } else {
                    Write-Host "  [WARN] Claude Desktop のパスが見つかりません" -ForegroundColor Yellow
                }
            }
        } else {
            `$script = ""
            if (`$Profile) {
                `$profileDir = Join-Path `$env:USERPROFILE ".claude-`$Profile"
                `$script += "`$env:CLAUDE_CONFIG_DIR = '`$profileDir'; "
            }
            `$script += "Set-Location '`$ProjectDir'; "
            `$script += "Write-Host '=== Claude Agent `$i ===' -ForegroundColor Cyan; "
            if (`$Profile) {
                `$script += "Write-Host 'Profile: `$Profile' -ForegroundColor Magenta; "
            }
            if (`$branch) {
                `$script += "git checkout -B '`$branch' 2>`$null; "
                `$script += "Write-Host 'Branch: `$branch' -ForegroundColor Yellow; "
            }
            `$script += "claude"

            Start-Process pwsh -ArgumentList "-NoExit", "-Command", `$script
            Write-Host "  [Agent `$i] 起動しました $(if(`$branch){"(branch: `$branch) "})$(if(`$Profile){"[`$Profile]"})" -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "  全エージェントを起動しました。" -ForegroundColor White
}

function claude-setup-repo {
    param(
        [Parameter(Mandatory=`$true)]
        [string]`$RepoName,

        [Parameter(Mandatory=`$false)]
        [switch]`$Private
    )

    <#
    .SYNOPSIS
    GitHub に新しいリポジトリをセットアップします（CLI/Desktop両対応）

    .EXAMPLE
    claude-setup-repo my-new-project
    claude-setup-repo my-secret-project -Private
    #>

    `$configFile = Join-Path `$env:USERPROFILE ".claude-multiagent-config.json"
    if (-not (Test-Path `$configFile)) {
        Write-Host "[ERROR] 設定ファイルが見つかりません。setup-claude-multiagent.ps1 を先に実行してください。" -ForegroundColor Red
        return
    }

    `$config = Get-Content `$configFile -Raw | ConvertFrom-Json
    `$pat = `$config.pat
    `$email = `$config.email
    `$ghUser = `$config.ghUser

    Write-Host "  リポジトリ作成中: `$ghUser/`$RepoName ..." -ForegroundColor Cyan

    try {
        `$body = @{ name = `$RepoName; private = [bool]`$Private; auto_init = `$true } | ConvertTo-Json
        `$headers = @{ Authorization = "token `$pat"; "Content-Type" = "application/json" }
        `$null = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Method Post -Headers `$headers -Body `$body
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "  [WARN] 作成失敗（既に存在する可能性があります）: `$_" -ForegroundColor Yellow
    }

    git clone "https://`${ghUser}:`${pat}@github.com/`${ghUser}/`${RepoName}.git"
    Set-Location `$RepoName
    git config user.name `$ghUser
    git config user.email `$email
    git config credential.useHttpPath true

    `$gitCredFile = Join-Path `$env:USERPROFILE ".git-credentials"
    `$credLine = "https://`${ghUser}:`${pat}@github.com"
    `$existingCreds = ""
    if (Test-Path `$gitCredFile) {
        `$existingCreds = Get-Content `$gitCredFile -Raw -ErrorAction SilentlyContinue
    }
    if (-not `$existingCreds -or -not `$existingCreds.Contains(`$credLine)) {
        Add-Content -Path `$gitCredFile -Value `$credLine -Encoding UTF8
    }

    Write-Host "  [OK] セットアップ完了: `$ghUser/`$RepoName" -ForegroundColor Green
    Write-Host ""
    Write-Host "  使い方:" -ForegroundColor White
    Write-Host "    CLI:     このフォルダで 'claude' を実行" -ForegroundColor Gray
    Write-Host "    Desktop: Claude Desktop でこのフォルダを開く" -ForegroundColor Gray
}

function claude-status {
    <#
    .SYNOPSIS
    現在のマルチエージェント環境の状態を表示します
    #>

    Write-Host ""
    Write-Host "  Claude Code マルチエージェント 環境状態" -ForegroundColor Cyan
    Write-Host "  ==============================" -ForegroundColor Gray

    `$tools = @(
        @{ Name = "Node.js";        Cmd = "node";   Ver = { node -v } },
        @{ Name = "npm";            Cmd = "npm";    Ver = { npm -v } },
        @{ Name = "Git";            Cmd = "git";    Ver = { (git --version) -replace "git version ","" } },
        @{ Name = "GitHub CLI";     Cmd = "gh";     Ver = { (gh --version | Select-Object -First 1) -replace "gh version ","" -replace " \(.*","" } },
        @{ Name = "Claude Code CLI";Cmd = "claude"; Ver = { "installed" } }
    )

    foreach (`$tool in `$tools) {
        `$installed = `$null -ne (Get-Command `$tool.Cmd -ErrorAction SilentlyContinue)
        if (`$installed) {
            `$ver = try { & `$tool.Ver } catch { "?" }
            Write-Host "  [OK]   `$(`$tool.Name): `$ver" -ForegroundColor Green
        } else {
            Write-Host "  [NG]   `$(`$tool.Name): 未インストール" -ForegroundColor Red
        }
    }

    `$configFile = Join-Path `$env:USERPROFILE ".claude-multiagent-config.json"
    if (Test-Path `$configFile) {
        `$config = Get-Content `$configFile -Raw | ConvertFrom-Json

        # Claude Desktop
        if (`$config.claudeDesktop -and (Test-Path `$config.claudeDesktop)) {
            Write-Host "  [OK]   Claude Desktop: `$(`$config.claudeDesktop)" -ForegroundColor Green
        } else {
            Write-Host "  [--]   Claude Desktop: 未検出" -ForegroundColor Yellow
        }

        # アカウント情報
        `$maskedPat = `$config.pat.Substring(0,7) + "..." + `$config.pat.Substring(`$config.pat.Length - 4)
        Write-Host ""
        Write-Host "  アカウント構成:" -ForegroundColor White
        Write-Host "    Claude モード: `$(switch(`$config.claudeMode){'1'{'単一アカウント'}'2'{'再ログイン切替'}'3'{'プロファイル分離'}})" -ForegroundColor Gray

        if (`$config.claudeProfiles) {
            foreach (`$p in `$config.claudeProfiles) {
                Write-Host "      - `$(`$p.name): `$(`$p.note)" -ForegroundColor Gray
            }
        }

        Write-Host "    GitHub: `$(`$config.ghUser)" -ForegroundColor Gray
        Write-Host "    Email:  `$(`$config.email)" -ForegroundColor Gray
        Write-Host "    PAT:    `$maskedPat" -ForegroundColor Gray
        Write-Host "    更新日: `$(`$config.updated)" -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "  [NG]   設定ファイルが未作成" -ForegroundColor Red
    }

    `$gitCredFile = Join-Path `$env:USERPROFILE ".git-credentials"
    if (Test-Path `$gitCredFile) {
        Write-Host "  [OK]   .git-credentials: 設定済み" -ForegroundColor Green
    } else {
        Write-Host "  [NG]   .git-credentials: 未設定" -ForegroundColor Red
    }

    if (Test-Path ".git") {
        `$remoteUrl = git remote get-url origin 2>`$null
        if (`$remoteUrl) {
            `$remoteUrl = `$remoteUrl -replace '://[^@]+@','://***@'
        }
        Write-Host ""
        Write-Host "  現在のリポジトリ:" -ForegroundColor White
        Write-Host "    ディレクトリ: `$(Get-Location)" -ForegroundColor Gray
        Write-Host "    ブランチ:     `$(git branch --show-current 2>`$null)" -ForegroundColor Gray
        Write-Host "    リモート:     `$remoteUrl" -ForegroundColor Gray
        Write-Host "    user.name:    `$(git config user.name 2>`$null)" -ForegroundColor Gray
        Write-Host "    user.email:   `$(git config user.email 2>`$null)" -ForegroundColor Gray
    }

    Write-Host ""
}

Set-Alias -Name cma -Value claude-agents -Description "Claude Multi-Agent"
Set-Alias -Name csr -Value claude-setup-repo -Description "Claude Setup Repo"
Set-Alias -Name cs -Value claude-status -Description "Claude Status"

"@

# プロファイルに追記（重複チェック）
if (Test-Path $PROFILE) {
    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($profileContent -and $profileContent.Contains("Claude Code Multi-Agent Helpers")) {
        Write-Info "ヘルパー関数は既にプロファイルに登録されています"
        $updateProfile = Confirm-Continue "上書き更新しますか？"
        if ($updateProfile) {
            $pattern = '(?s)# ={60,}\r?\n# Claude Code Multi-Agent Helpers.*?Set-Alias -Name cs -Value claude-status.*?\n'
            $profileContent = $profileContent -replace $pattern, ""
            $profileContent = $profileContent.TrimEnd() + "`n" + $helperBlock
            [System.IO.File]::WriteAllText($PROFILE, $profileContent, [System.Text.UTF8Encoding]::new($true))
            Write-OK "ヘルパー関数を更新しました"
        }
    } else {
        $profileContent = $profileContent + "`n" + $helperBlock
        [System.IO.File]::WriteAllText($PROFILE, $profileContent, [System.Text.UTF8Encoding]::new($true))
        Write-OK "ヘルパー関数をプロファイルに追加しました"
    }
} else {
    [System.IO.File]::WriteAllText($PROFILE, $helperBlock, [System.Text.UTF8Encoding]::new($true))
    Write-OK "プロファイルを作成し、ヘルパー関数を追加しました"
}

# 現在のセッションにも読み込み
Invoke-Expression $helperBlock

# ============================================================
# 完了
# ============================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  セットアップ完了！" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  ====== アカウント構成 ======" -ForegroundColor White
Write-Host "  Claude: $(if($claudeMode -eq '3'){"$($claudeProfiles.Count) プロファイル"}else{"デフォルト"})" -ForegroundColor Gray
Write-Host "  GitHub: $ghUser" -ForegroundColor Gray
Write-Host ""
Write-Host "  ====== 使い方一覧 ======" -ForegroundColor White
Write-Host ""
Write-Host "  [CLI] ターミナルから使う:" -ForegroundColor Cyan
Write-Host "    cd <プロジェクトフォルダ>" -ForegroundColor Gray
Write-Host "    claude" -ForegroundColor Gray

if ($claudeMode -eq "3") {
    Write-Host ""
    Write-Host "  [プロファイル切替]:" -ForegroundColor Cyan
    foreach ($p in $claudeProfiles) {
        Write-Host "    claude-$($p.name)    → $($p.name) のClaudeアカウントで起動" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "  [Desktop] Claude Desktop から使う:" -ForegroundColor Cyan
Write-Host "    1. Claude Desktop を起動" -ForegroundColor Gray
Write-Host "    2. チャット入力欄の + > Claude Code を使う" -ForegroundColor Gray
Write-Host "    3. セットアップ済みのプロジェクトフォルダを選択" -ForegroundColor Gray
Write-Host "    ※ git認証は自動で $ghUser が使われます" -ForegroundColor Gray
Write-Host ""
Write-Host "  [マルチエージェント] 複数同時起動:" -ForegroundColor Cyan
Write-Host "    claude-agents -Count 2                          (CLI x2)" -ForegroundColor Gray
Write-Host "    claude-agents -Count 2 -Desktop                 (Desktop x2)" -ForegroundColor Gray

if ($claudeMode -eq "3") {
    Write-Host "    claude-agents -Count 2 -Profile $($claudeProfiles[0].name)   (プロファイル指定)" -ForegroundColor Gray
}

Write-Host "    claude-agents -Count 3 -Branches @('feat/ui','feat/api','feat/docs')" -ForegroundColor Gray
Write-Host ""
Write-Host "  [リポジトリ追加]" -ForegroundColor Cyan
Write-Host "    claude-setup-repo new-project" -ForegroundColor Gray
Write-Host "    claude-setup-repo secret-project -Private" -ForegroundColor Gray
Write-Host ""
Write-Host "  [環境確認]" -ForegroundColor Cyan
Write-Host "    claude-status" -ForegroundColor Gray
Write-Host ""
Write-Host "  ショートカット: cma = claude-agents, csr = claude-setup-repo, cs = claude-status" -ForegroundColor Gray
Write-Host ""
Write-Host "  まず 'claude' を実行して Anthropic アカウントにログインしてください。" -ForegroundColor Yellow
Write-Host ""
#requires -Version 5.1
[CmdletBinding()]
param(
    [string] $VaultRoot = '',
    [string] $WorktreeRoot = '',
    [string] $CommitMessage = 'workbenchstatesync: update state',
    [string] $BaselineStorePath = '',
    [switch] $Force,
    [switch] $NoOverwrite,
    [switch] $DryRun,
    [switch] $SkipGitPull,
    [switch] $SkipGitPush
)

$ErrorActionPreference = 'Stop'

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PackageRoot)
$WorkbenchStateSyncScript = Join-Path $PackageRoot 'workbenchstatesync.ps1'

function Import-WorkbenchStateSyncConfig {
    $candidates = @(
        (Join-Path $PackageRoot 'workbenchstatesync.config.psd1'),
        (Join-Path $RepoRoot 'WorkbenchStateSync.local.psd1')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return Import-PowerShellDataFile -LiteralPath $candidate
        }
    }

    return @{}
}

function Invoke-Git([string] $Repo, [string[]] $GitArgs) {
    $safeRepo = $Repo.Replace('\', '/')
    & git -c "safe.directory=$safeRepo" -C $Repo @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArgs -join ' ') failed in $Repo"
    }
}

function Get-GitCurrentBranch([string] $Repo) {
    $safeRepo = $Repo.Replace('\', '/')
    $branch = (& git -c "safe.directory=$safeRepo" -C $Repo branch --show-current)
    if ($LASTEXITCODE -ne 0 -or -not $branch) {
        throw "Unable to resolve current branch in $Repo"
    }
    return $branch.Trim()
}

function Get-GitPorcelain([string] $Repo) {
    $safeRepo = $Repo.Replace('\', '/')
    $status = @(& git -c "safe.directory=$safeRepo" -C $Repo status --porcelain -- UserSettings Projects Reviews)
    if ($LASTEXITCODE -ne 0) {
        throw "git status failed in $Repo"
    }
    return @($status | Where-Object { $_ -notmatch '\.bak-' })
}

function Get-RelativePath([string] $Base, [string] $Path) {
    $baseUri = [Uri](([IO.Path]::GetFullPath($Base).TrimEnd('\', '/') + '\'))
    $pathUri = [Uri][IO.Path]::GetFullPath($Path)
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('/', '\')
}

function Test-BlockedStatePath([string] $RelativePath) {
    $norm = $RelativePath.Replace('/', '\')
    if ($norm -eq 'UserSettings\README.md') { return $true }
    if ($norm -eq 'Reviews\README.md') { return $true }
    if ($norm -eq 'Reviews\run-review.ps1') { return $true }
    if ($norm -match '^Reviews\\_TEMPLATE(\\|$)') { return $true }
    if ($norm -match '(^|\\)baseline(\\|$)') { return $true }
    if ($norm -match '(^|\\)edit(\\|$)') { return $true }
    # 백업 이름은 bak-<yyyyMMdd>-<HHmmssfff> 라 숫자 사이에 하이픈이 있다. 'bak-\d+' 로는 안 걸린다.
    if ($norm -match '\.(jsonl|db|sqlite|sqlite3|key|pem|pfx|env|user|log|bak-\d{8}-\d{9})$') { return $true }
    if ($norm -match '(^|\\)(auth\.json|config\.toml|\.git)(\\|$)') { return $true }
    return $false
}

function Add-StatePaths([string] $Repo) {
    $files = @()
    $userSettings = Join-Path $Repo 'UserSettings'
    if (Test-Path -LiteralPath $userSettings) {
        $files += Get-ChildItem -LiteralPath $userSettings -Filter '*.md' -Recurse -File |
            Where-Object { $_.Name -notmatch '\.bak-' }
    }

    $projects = Join-Path $Repo 'Projects'
    if (Test-Path -LiteralPath $projects) {
        $files += Get-ChildItem -LiteralPath $projects -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                $rule = Join-Path $_.FullName 'RULES.md'
                if (Test-Path -LiteralPath $rule) { Get-Item -LiteralPath $rule }
            }
    }

    $reviews = Join-Path $Repo 'Reviews'
    if (Test-Path -LiteralPath $reviews) {
        $files += Get-ChildItem -LiteralPath $reviews -Recurse -File
    }

    $relativePaths = @($files | ForEach-Object { Get-RelativePath $Repo $_.FullName } | Where-Object { -not (Test-BlockedStatePath $_) })
    if ($relativePaths.Count -eq 0) { return }
    Invoke-Git -Repo $Repo -GitArgs (@('add', '--') + $relativePaths)
}

$LocalConfig = Import-WorkbenchStateSyncConfig
if (-not $VaultRoot -and $LocalConfig.ContainsKey('VaultRoot')) { $VaultRoot = [string]$LocalConfig.VaultRoot }
if (-not $WorktreeRoot -and $LocalConfig.ContainsKey('WorktreeRoot')) { $WorktreeRoot = [string]$LocalConfig.WorktreeRoot }
if (-not $WorktreeRoot) { $WorktreeRoot = $RepoRoot }
if (-not $VaultRoot) { throw 'VaultRoot is required. Create ignored workbenchstatesync.config.psd1 or pass -VaultRoot.' }

$VaultRoot = [IO.Path]::GetFullPath($VaultRoot).TrimEnd('\', '/')
$WorktreeRoot = [IO.Path]::GetFullPath($WorktreeRoot).TrimEnd('\', '/')

Write-Host 'WorkbenchStateSync Finish' -ForegroundColor Cyan
Write-Host "  vault:   $VaultRoot"
Write-Host "  worktree: $WorktreeRoot"

if (-not $DryRun -and -not $SkipGitPull) {
    Invoke-Git -Repo $VaultRoot -GitArgs @('pull', '--ff-only')
}
elseif ($DryRun -and -not $SkipGitPull) {
    Write-Host 'dry-run: git pull --ff-only' -ForegroundColor DarkGray
}

# 예전에는 Push 를 항상 -Force 로 돌렸다. 기준점이 없어 정상적인 로컬 편집조차 충돌로
# 보였고, 그렇게 하지 않으면 Push 가 아무것도 못 올렸기 때문이다. 대신 반대편이 앞서 있어도
# 조용히 덮어쓰는 경로가 생겼다. 이제 기준점으로 앞뒤를 구분하므로 -Force 는 사용자가
# 명시할 때만 건다.
if ($NoOverwrite) { Write-Warning '-NoOverwrite is now the default; the flag has no effect.' }
& $WorkbenchStateSyncScript -Direction Push -VaultRoot $VaultRoot -WorktreeRoot $WorktreeRoot -BaselineStorePath $BaselineStorePath -Force:$Force -DryRun:$DryRun
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($DryRun) {
    Write-Host 'dry-run: git add/commit/push skipped' -ForegroundColor DarkGray
    Write-Host 'WorkbenchStateSync Finish dry-run complete.' -ForegroundColor Green
    exit 0
}

$changes = @(Get-GitPorcelain $VaultRoot)
if ($changes.Count -gt 0) {
    Add-StatePaths $VaultRoot
    Invoke-Git -Repo $VaultRoot -GitArgs @('commit', '-m', $CommitMessage)
}
else {
    Write-Host 'No workbench state changes to commit.' -ForegroundColor DarkGray
}

if (-not $SkipGitPush) {
    $branch = Get-GitCurrentBranch $VaultRoot
    Invoke-Git -Repo $VaultRoot -GitArgs @('push', 'origin', $branch)
}

Write-Host 'WorkbenchStateSync Finish complete.' -ForegroundColor Green

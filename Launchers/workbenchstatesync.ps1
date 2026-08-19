#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Pull', 'Push')]
    [string] $Direction,

    [string] $VaultRoot = '',
    [string] $WorktreeRoot = '',
    [string] $BaselineStorePath = '',
    [switch] $Force,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PackageRoot)

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

$LocalConfig = Import-WorkbenchStateSyncConfig
if (-not $VaultRoot -and $LocalConfig.ContainsKey('VaultRoot')) { $VaultRoot = [string]$LocalConfig.VaultRoot }
if (-not $WorktreeRoot -and $LocalConfig.ContainsKey('WorktreeRoot')) { $WorktreeRoot = [string]$LocalConfig.WorktreeRoot }
if (-not $WorktreeRoot) { $WorktreeRoot = $RepoRoot }
if (-not $VaultRoot) { throw 'VaultRoot is required. Pass -VaultRoot or create ignored workbenchstatesync.config.psd1 from workbenchstatesync.config.example.psd1.' }

$WorktreeRoot = [IO.Path]::GetFullPath($WorktreeRoot).TrimEnd('\', '/')
$VaultRoot = [IO.Path]::GetFullPath($VaultRoot).TrimEnd('\', '/')

$SecretPatterns = @(
    @{ Name = 'GitHub token'; Regex = '(?<![A-Za-z0-9_])gh[pousr]_[A-Za-z0-9]{36}(?![A-Za-z0-9_])' },
    @{ Name = 'GitHub fine-grained token'; Regex = '(?<![A-Za-z0-9_])github_pat_[A-Za-z0-9_]{20,}(?![A-Za-z0-9_])' },
    @{ Name = 'Anthropic API key'; Regex = '(?<![A-Za-z0-9_-])sk-ant-api\d{2,}-[A-Za-z0-9_-]{50,}(?![A-Za-z0-9_-])' },
    @{ Name = 'OpenAI API key'; Regex = '(?<![A-Za-z0-9_-])sk-(?!ant-)[A-Za-z0-9_-]{20,}(?![A-Za-z0-9_-])' }
)

function Get-RelativePath([string] $Base, [string] $Path) {
    $baseUri = [Uri](([IO.Path]::GetFullPath($Base).TrimEnd('\', '/') + '\'))
    $pathUri = [Uri][IO.Path]::GetFullPath($Path)
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('/', '\')
}

function Test-BlockedPath([string] $RelativePath) {
    $norm = $RelativePath.Replace('/', '\')
    if ($norm -eq 'UserSettings\README.md') { return $true }
    if ($norm -eq 'Reviews\README.md') { return $true }
    if ($norm -eq 'Reviews\run-review.ps1') { return $true }
    if ($norm -match '^Reviews\\_TEMPLATE(\\|$)') { return $true }
    if ($norm -match '(^|\\)baseline(\\|$)') { return $true }
    if ($norm -match '(^|\\)edit(\\|$)') { return $true }
    # 백업 이름은 bak-<yyyyMMdd>-<HHmmssfff> 라서 숫자 사이에 하이픈이 있다. 예전 패턴
    # 'bak-\d+' 는 그 하이픈에서 끊겨 실제 백업을 하나도 걸러내지 못했고, 그 결과 백업
    # 파일 자체가 양방향으로 운반돼 양쪽에 쌓였다.
    if ($norm -match '\.(jsonl|db|sqlite|sqlite3|key|pem|pfx|env|user|log|bak-\d{8}-\d{9})$') { return $true }
    if ($norm -match '(^|\\)(auth\.json|config\.toml|\.git)(\\|$)') { return $true }
    return $false
}

function Assert-NoSecrets([IO.FileInfo[]] $Files) {
    $findings = @()
    foreach ($file in $Files) {
        if (-not $file.Exists) { continue }
        $text = [IO.File]::ReadAllText($file.FullName)
        foreach ($pattern in $SecretPatterns) {
            if ([regex]::IsMatch($text, $pattern.Regex)) {
                $findings += [pscustomobject]@{ Type = $pattern.Name; File = $file.FullName }
            }
        }
    }
    if ($findings) {
        $findings | Sort-Object Type, File -Unique | Format-Table -AutoSize | Out-String | Write-Host
        throw 'WorkbenchStateSync secret scan found token-like content. Values were not printed.'
    }
}

function Get-WorkbenchStateFiles([string] $Root) {
    $files = @()
    $userSettings = Join-Path $Root 'UserSettings'
    if (Test-Path -LiteralPath $userSettings) {
        $files += Get-ChildItem -LiteralPath $userSettings -Filter '*.md' -Recurse -File
    }

    # Projects/<name>/ 아래에서 운반하는 것은 "프로젝트의 성질"을 적은 파일뿐이다.
    # baseline/ 과 edit/ 는 로컬 사본이라 Test-BlockedPath 가 막는다.
    #   RULES.md    - 프로젝트 규칙
    #   MirrorTargets.json - 미러 대상. 무엇을 baseline 으로 뜰지는 머신이 아니라 프로젝트의
    #                 성질이므로, 이것이 운반되지 않으면 머신마다 baseline 범위가 갈린다.
    $projectStateFiles = @('RULES.md', 'MirrorTargets.json')
    $projects = Join-Path $Root 'Projects'
    if (Test-Path -LiteralPath $projects) {
        $files += Get-ChildItem -LiteralPath $projects -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                $projectDir = $_.FullName
                foreach ($stateFile in $projectStateFiles) {
                    $candidate = Join-Path $projectDir $stateFile
                    if (Test-Path -LiteralPath $candidate) { Get-Item -LiteralPath $candidate }
                }
            }
    }

    $reviews = Join-Path $Root 'Reviews'
    if (Test-Path -LiteralPath $reviews) {
        $files += Get-ChildItem -LiteralPath $reviews -Recurse -File
    }

    return @($files | Where-Object {
        $rel = Get-RelativePath $Root $_.FullName
        -not (Test-BlockedPath $rel)
    })
}

function Get-FileHashText([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-BaselinePath([string] $Vault, [string] $Worktree) {
    <#
      마지막으로 동기화된 내용의 해시를 기록해 두는 머신 로컬 파일이다.
      이것이 없으면 "양쪽이 다르다"는 사실밖에 알 수 없어, 뒤처진 쪽조차 충돌로 취급된다.
      운반 대상이 아니므로 저장소가 아니라 LOCALAPPDATA 에 둔다.
    #>
    $store = $BaselineStorePath
    if (-not $store) { $store = Join-Path $env:LOCALAPPDATA 'WorkbenchStateSync' }
    $key = ($Vault + '|' + $Worktree).ToLowerInvariant()
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($key))
    }
    finally {
        $sha.Dispose()
    }
    $id = ([BitConverter]::ToString($bytes) -replace '-', '').Substring(0, 16)
    return (Join-Path $store "baseline-$id.json")
}

function Import-Baseline([string] $Path) {
    $map = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $map }
    try {
        $raw = Get-Content -Raw -LiteralPath $Path -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Write-Warning "Baseline record unreadable, starting fresh: $Path"
        return $map
    }
    foreach ($property in $raw.PSObject.Properties) { $map[$property.Name] = [string]$property.Value }
    return $map
}

function Export-Baseline([string] $Path, [hashtable] $Map) {
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
    ($Map | ConvertTo-Json -Depth 3) | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Copy-StateFile([string] $SourceRoot, [string] $DestinationRoot, [IO.FileInfo] $SourceFile) {
    $rel = Get-RelativePath $SourceRoot $SourceFile.FullName
    if (Test-BlockedPath $rel) {
        Write-Warning "Blocked path skipped: $rel"
        return
    }

    $destination = Join-Path $DestinationRoot $rel
    $destinationDir = Split-Path -Parent $destination
    $srcHash = Get-FileHashText $SourceFile.FullName
    $dstHash = Get-FileHashText $destination
    $baseHash = if ($Baseline.ContainsKey($rel)) { [string]$Baseline[$rel] } else { '' }

    if ($dstHash -and $srcHash -eq $dstHash) {
        # 같은 내용이면 그 자체가 새 공통 기준점이다.
        $script:Baseline[$rel] = $srcHash
        Write-Host "unchanged: $rel" -ForegroundColor DarkGray
        return
    }

    if ($dstHash) {
        if ($baseHash -and $dstHash -eq $baseHash) {
            # 목적지는 마지막 동기화 이후 그대로고 출발지만 앞섰다. 이건 충돌이 아니라
            # 정상적인 갱신이다. 덮어쓸 내용이 이미 반대편에 있으므로 백업하지 않는다.
            Write-Host "fast-forward: $rel" -ForegroundColor DarkCyan
        }
        elseif ($baseHash -and $srcHash -eq $baseHash) {
            # 반대. 목적지가 앞서 있고 출발지는 옛날 그대로다. 그대로 덮으면 최신을 잃는다.
            $other = if ($Direction -eq 'Pull') { 'Push' } else { 'Pull' }
            Write-Warning "Destination is ahead, source unchanged: $rel"
            if (-not $Force) {
                Write-Warning "  Sync the other direction first ($other). Skipped without -Force."
                return
            }
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
            $backup = "$destination.bak-$stamp"
            if (-not $DryRun) {
                New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
                Copy-Item -LiteralPath $destination -Destination $backup -Force
                Write-Warning "Backup created: $backup"
            }
            else {
                Write-Warning "Would create backup: $backup"
            }
        }
        else {
            # 양쪽 다 기준점에서 벗어났거나(진짜 충돌) 기준점 자체가 없다(첫 동기화).
            # 기준점이 없을 때만 방향별 기본값을 쓴다. Push 는 "내 작업을 올린다"는 뜻이라
            # 출발지를 우선하고, Pull 은 받는 쪽이므로 로컬을 지키고 멈춘다. 기준점이 생긴
            # 뒤에는 이 추정을 쓰지 않는다.
            $assumeSourceWins = (-not $baseHash) -and ($Direction -eq 'Push')
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
            $backup = "$destination.bak-$stamp"
            if ($assumeSourceWins) {
                Write-Warning "No baseline recorded, assuming the source copy is newer: $rel"
            }
            else {
                Write-Warning "Divergent file: $rel"
            }
            if (-not $DryRun) {
                New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
                Copy-Item -LiteralPath $destination -Destination $backup -Force
                Write-Warning "Backup created: $backup"
            }
            else {
                Write-Warning "Would create backup: $backup"
            }
            if (-not $Force -and -not $assumeSourceWins) {
                Write-Warning "Skipped without -Force: $rel"
                return
            }
        }
    }

    if ($DryRun) {
        Write-Host "copy: $rel" -ForegroundColor Cyan
        return
    }

    New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
    Copy-Item -LiteralPath $SourceFile.FullName -Destination $destination -Force
    $script:Baseline[$rel] = $srcHash
    Write-Host "copied: $rel" -ForegroundColor Green
}

if ($Direction -eq 'Pull') {
    $sourceRoot = $VaultRoot
    $destinationRoot = $WorktreeRoot
}
else {
    $sourceRoot = $WorktreeRoot
    $destinationRoot = $VaultRoot
}

if (-not (Test-Path -LiteralPath $sourceRoot)) {
    if ($Direction -eq 'Push') {
        if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $sourceRoot | Out-Null }
    }
    else {
        throw "Source root does not exist: $sourceRoot"
    }
}
if (-not (Test-Path -LiteralPath $destinationRoot) -and -not $DryRun) {
    New-Item -ItemType Directory -Force -Path $destinationRoot | Out-Null
}

$files = @(Get-WorkbenchStateFiles $sourceRoot)
if ($Direction -eq 'Push') { Assert-NoSecrets $files }

if (-not $files) {
    Write-Host "No workbench state files found under $sourceRoot" -ForegroundColor Yellow
    return
}

$BaselinePath = Get-BaselinePath $VaultRoot $WorktreeRoot
$Baseline = Import-Baseline $BaselinePath

Write-Host "WorkbenchStateSync $Direction" -ForegroundColor Cyan
Write-Host "  source:      $sourceRoot"
Write-Host "  destination: $destinationRoot"

foreach ($file in $files) {
    Copy-StateFile $sourceRoot $destinationRoot $file
}

# DryRun 은 아무것도 옮기지 않았으므로 기준점도 옮기지 않는다.
if (-not $DryRun) { Export-Baseline $BaselinePath $Baseline }

$global:LASTEXITCODE = 0

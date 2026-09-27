#Requires -Version 7.0
<#
.SYNOPSIS
  Copy selected live configuration files into my-config-backup, then commit and push changes.
.EXAMPLE
  pwsh -NoProfile -File .\sync-dotfiles.ps1 -DryRun
.EXAMPLE
  pwsh -NoProfile -File .\sync-dotfiles.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoPath,
    [string]$AutoHotkeyDirectory = 'D:\Scripts\AutoHotkey',
    [switch]$DryRun,
    [switch]$SkipPush
)

$ErrorActionPreference = 'Stop'
if (-not $RepoPath) {
    if (-not $env:OneDrive) { throw 'Pass -RepoPath (the OneDrive environment variable is unavailable).' }
    $RepoPath = Join-Path $env:OneDrive 'Desktop\my-config-backup'
}
$repo = (Resolve-Path -LiteralPath $RepoPath).Path
if (-not (Test-Path -LiteralPath (Join-Path $repo '.git'))) { throw "Not a Git checkout: $repo" }

function Git([string[]]$Arguments) {
    $result = & git.exe -C $repo @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed (exit $LASTEXITCODE): $($result -join ' ')"
    }
    return $result
}

if (-not $DryRun) {
    $alreadyStaged = @(Git -Arguments @('diff', '--cached', '--name-only'))
    if ($alreadyStaged.Count) { throw "The Git index already has staged changes: $($alreadyStaged -join ', '). Commit or unstage them first." }
}

$profileRoot = $env:USERPROFILE
$roaming = $env:APPDATA
$local = $env:LOCALAPPDATA
$oneDriveDocuments = Join-Path $env:OneDrive 'Documents'
$wsl = '\\wsl.localhost\Ubuntu'
$terminal = Join-Path $local 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'
$nvim = Join-Path $local 'nvim'
$mappings = [System.Collections.Generic.List[object]]::new()

function Map([string]$Source, [string]$Destination) {
    $mappings.Add([pscustomobject]@{ Source = $Source; Destination = $Destination })
}

Map (Join-Path $roaming 'alacritty\alacritty.toml') 'Windows/Alacritty/alacritty.toml'
Map (Join-Path $roaming 'Zellij\config\config.kdl') 'Windows/Zellij/config.kdl'
Map (Join-Path $roaming 'Zellij\config\powershell-no-logo.cmd') 'Windows/Zellij/powershell-no-logo.cmd'
Map (Join-Path $nvim 'init.lua') 'Windows/Neovim/init.lua'
Map (Join-Path $nvim 'lazy-lock.json') 'Windows/Neovim/lazy-lock.json'
Map (Join-Path $nvim 'colors\vscode_black.lua') 'Windows/Neovim/colors/vscode_black.lua'
Map (Join-Path $nvim 'bin\zig-cc.cmd') 'Windows/Neovim/bin/zig-cc.cmd'
Map (Join-Path $nvim 'templates\template.java') 'Windows/Neovim/templates/template.java'
Map (Join-Path $oneDriveDocuments 'PowerShell\Microsoft.PowerShell_profile.ps1') 'Windows/PowerShell/Microsoft.PowerShell_profile.ps1'
Map (Join-Path $oneDriveDocuments 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1') 'Windows/PowerShell/WindowsPowerShell_profile.ps1'
Map (Join-Path $profileRoot '.config\starship.toml') 'Windows/Starship/starship.toml'
Map (Join-Path $profileRoot '.gitconfig') 'Windows/Git/.gitconfig'
Map (Join-Path $roaming 'yazi\config\keymap.toml') 'Windows/Yazi/keymap.toml'
Map (Join-Path $terminal 'settings.json') 'Windows/Windows Terminal/settings.json'

foreach ($name in @('cyberpunk-avatar.jpg', 'cyberpunk-back.png', 'cyberpunk-front.png', 'final-terminal-clean.png', 'gemini-neon-warrior.png', 'wallpaper-credits.txt')) {
    Map (Join-Path $terminal "wallpapers\$name") "Windows/Windows Terminal/wallpapers/$name"
}

# Only the named scripts and their companion DLL are copied. The source has its own .git folder.
foreach ($name in @('Combined_shortcuts.ahk', 'FindCopilot.ahk', 'VirtualDesktopAccessor.dll')) {
    Map (Join-Path $AutoHotkeyDirectory $name) "Windows/AutoHotkey/$name"
}

Map (Join-Path $wsl 'etc\wsl.conf') 'WSL/Ubuntu/etc/wsl.conf'
Map (Join-Path $wsl 'home\ubuntu\.bashrc') 'WSL/Ubuntu/home/ubuntu/.bashrc'
Map (Join-Path $wsl 'home\ubuntu\.zshrc') 'WSL/Ubuntu/home/ubuntu/.zshrc'
Map (Join-Path $wsl 'home\ubuntu\.config\starship.toml') 'WSL/Ubuntu/home/ubuntu/.config/starship.toml'
Map (Join-Path $wsl 'home\ubuntu\.oh-my-zsh\custom\themes\neon-cyberpunk.zsh-theme') 'WSL/Ubuntu/home/ubuntu/.oh-my-zsh/custom/themes/neon-cyberpunk.zsh-theme'

$stagePaths = [System.Collections.Generic.List[string]]::new()
$changed = 0
$missing = 0
foreach ($item in $mappings) {
    $source = $item.Source
    $relative = $item.Destination
    $target = Join-Path $repo ($relative.Replace('/', [IO.Path]::DirectorySeparatorChar))
    try {
        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    } catch {
        Write-Warning "Skipped unavailable source: $source"
        $missing++
        continue
    }
    $stagePaths.Add($relative)
    $targetHash = if (Test-Path -LiteralPath $target -PathType Leaf) { (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash } else { $null }
    if ($sourceHash -eq $targetHash) { continue }
    Write-Host "Update: $relative"
    $changed++
    if ($DryRun) { continue }
    $parent = Split-Path -Parent $target
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    $temporary = "$target.sync-$([guid]::NewGuid().ToString('N')).tmp"
    try {
        Copy-Item -LiteralPath $source -Destination $temporary -ErrorAction Stop
        [IO.File]::Move($temporary, $target, $true)
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

Write-Host "Compared $($mappings.Count) sources; $changed file(s) need copying; $missing source(s) unavailable."
if ($DryRun) {
    Write-Host 'Dry run: no files copied, staged, committed, or pushed.'
    exit 0
}

foreach ($relative in @('sync-dotfiles.ps1', 'SYNC.md', 'RESTORE PATHS.txt', 'Windows/PowerShell/winget-tool-directories.txt')) {
    if (Test-Path -LiteralPath (Join-Path $repo $relative) -PathType Leaf) { $stagePaths.Add($relative) }
}
foreach ($relative in ($stagePaths | Select-Object -Unique)) {
    Git -Arguments @('add', '-A', '--', $relative) | Out-Null
}
$stagedNames = @(Git -Arguments @('diff', '--cached', '--name-only'))
if (-not $stagedNames.Count) { Write-Host 'No changes to commit or push.'; exit 0 }

# Stop on common credential formats in added lines, before anything is committed or sent.
$patterns = @(
    '-----BEGIN (?:OPENSSH |RSA |EC |DSA )?PRIVATE KEY-----',
    'github_pat_[A-Za-z0-9_]{20,}',
    'gh[pousr]_[A-Za-z0-9]{30,}',
    'AKIA[0-9A-Z]{16}',
    'xox[baprs]-[A-Za-z0-9-]{20,}',
    'sk-[A-Za-z0-9_-]{32,}'
)
$patch = @(Git -Arguments (@('diff', '--cached', '--no-ext-diff', '--unified=0', '--') + $stagedNames))
foreach ($line in $patch) {
    if ($line.StartsWith('+') -and -not $line.StartsWith('+++')) {
        foreach ($pattern in $patterns) {
            if ($line -match $pattern) { throw 'Potential credential found in staged additions. Review the staged diff; no commit or push was made.' }
        }
    }
}

Write-Host "Staged: $($stagedNames -join ', ')"
$message = 'Config backup ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')
Git -Arguments @('commit', '-m', $message) | Out-Host
if ($SkipPush) { Write-Host 'Committed locally; push skipped.'; exit 0 }

$branch = @(Git -Arguments @('branch', '--show-current'))[0]
if ($branch -ne 'main') { throw "Committed locally, but push requires the main branch (current: $branch)." }
Git -Arguments @('fetch', '--quiet', 'origin', 'main') | Out-Null
& git.exe -C $repo merge-base --is-ancestor 'origin/main' 'HEAD'
if ($LASTEXITCODE -ne 0) { throw 'Committed locally, but origin/main has diverged. Resolve it before pushing.' }
Git -Arguments @('push', 'origin', 'HEAD:main') | Out-Host
Write-Host 'Backup committed and pushed.'

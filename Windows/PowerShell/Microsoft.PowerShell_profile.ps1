# Personal commands
Set-Alias lvim 'C:\Users\kaura\.local\bin\lvim.ps1'

# UTF-8 output for modern command-line tools.
$OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$env:COLORTERM = "truecolor"
Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
$env:STARSHIP_CONFIG = Join-Path $env:USERPROFILE '.config\starship.toml'

# Yazi uses Git for Windows' file.exe for reliable MIME-type detection.
$yaziFileOne = 'C:\Program Files\Git\usr\bin\file.exe'
if (Test-Path -LiteralPath $yaziFileOne) {
    $env:YAZI_FILE_ONE = $yaziFileOne
}

# bottom's MSI does not add its binary directory to PATH.
$bottomBin = 'C:\Program Files\bottom\bin'
if ((Test-Path -LiteralPath $bottomBin) -and $env:Path -notlike "*$bottomBin*") {
    $env:Path = "$bottomBin;$env:Path"
}

# Cache WinGet portable-package executable directories. The cache refreshes
# automatically when the package root changes or a cached directory vanishes.
$wingetPackageRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
$wingetPathCache = Join-Path $env:USERPROFILE '.config\powershell\winget-tool-directories.txt'

function Update-KauraWingetToolPathCache {
    if (-not (Test-Path -LiteralPath $wingetPackageRoot)) { return }

    New-Item -ItemType Directory -Path (Split-Path -Parent $wingetPathCache) -Force | Out-Null
    $directories = Get-ChildItem -LiteralPath $wingetPackageRoot -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty DirectoryName -Unique
    $directories | Set-Content -LiteralPath $wingetPathCache -Encoding utf8
}

if (Test-Path -LiteralPath $wingetPackageRoot) {
    $cacheNeedsRefresh = -not (Test-Path -LiteralPath $wingetPathCache)
    if (-not $cacheNeedsRefresh) {
        $cacheNeedsRefresh = (Get-Item -LiteralPath $wingetPathCache).LastWriteTimeUtc -lt (Get-Item -LiteralPath $wingetPackageRoot).LastWriteTimeUtc
    }

    $wingetToolDirectories = if ($cacheNeedsRefresh) {
        Update-KauraWingetToolPathCache
        Get-Content -LiteralPath $wingetPathCache -ErrorAction SilentlyContinue
    } else {
        Get-Content -LiteralPath $wingetPathCache -ErrorAction SilentlyContinue
    }

    foreach ($toolDirectory in $wingetToolDirectories | Where-Object { Test-Path -LiteralPath $_ -PathType Container }) {
        if (($env:Path -split ';') -notcontains $toolDirectory) {
            $env:Path = "$toolDirectory;$env:Path"
        }
    }
}

# Better interactive history and completion.
if (Get-Module -ListAvailable -Name PSReadLine) {
    Set-PSReadLineOption -EditMode Windows

    if ([Environment]::UserInteractive -and -not [Console]::IsOutputRedirected) {
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -PredictionViewStyle ListView
    }

    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Search command history with fzf.
    Set-PSReadLineKeyHandler -Chord Ctrl+r -ScriptBlock {
        $historyPath = (Get-PSReadLineOption).HistorySavePath
        $selection = Get-Content -LiteralPath $historyPath -ErrorAction SilentlyContinue |
            fzf --tac --no-sort --height 40% --layout reverse --border

        if ($selection) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selection)
        }
    }
}

# VS Code-inspired fuzzy finder colours.
$env:FZF_DEFAULT_OPTS = '--height=40% --layout=reverse --border=rounded --info=inline --prompt=❯  --pointer=◆ --marker=✓ --color=bg+:#202328,bg:#0f1113,spinner:#d4d4d4,hl:#ff6b6b,fg:#d4d4d4,header:#ff6b6b,info:#c792ea,pointer:#f0f0f0,marker:#ffd700,fg+:#f0f0f0,prompt:#c792ea,hl+:#e879d2'
$env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git'

# Smarter directory navigation: `z project-name`.
$env:Path += ";C:\Users\kaura\AppData\Local\Microsoft\WinGet\Packages\ajeetdsouza.zoxide_Microsoft.Winget.Source_8wekyb3d8bbwe"
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# Unix-style file listings powered by eza.
# WinGet's portable-package link can occasionally be absent, so find eza's
# installed executable directly before defining the friendly listing commands.
$ezaCommand = Get-Command eza -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($ezaCommand) {
    $global:KauraEzaPath = $ezaCommand.Source
} else {
    $ezaPackageRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    $ezaExecutable = Get-ChildItem -Path $ezaPackageRoot -Filter "eza.exe" -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "eza-community\.eza" } |
        Select-Object -First 1
    $global:KauraEzaPath = if ($ezaExecutable) { $ezaExecutable.FullName } else { $null }
}

if ($global:KauraEzaPath) {
    function eza { & $global:KauraEzaPath @args }
    Set-Alias -Name ls -Value eza -Option AllScope -Force
    function ll { eza --long --icons=always --group-directories-first @args }
    function la { eza --long --all --icons=always --group-directories-first @args }
    function lt { eza --tree --level=2 --icons=always --group-directories-first @args }
} else {
    Set-Alias -Name ls -Value Get-ChildItem -Option AllScope -Force
    function ll { Get-ChildItem @args }
    function la { Get-ChildItem -Force @args }
    function lt { Get-ChildItem @args }
    Write-Warning "eza is not installed; using PowerShell's standard file listing."
}

# Full-screen terminal applications.
Set-Alias -Name lg -Value lazygit
Set-Alias -Name top -Value btm
Set-Alias -Name fetch -Value fastfetch

# Start Yazi and switch PowerShell to its final directory when it exits.
function y {
    $cwdFile = Join-Path ([System.IO.Path]::GetTempPath()) ("yazi-cwd-{0}.txt" -f [guid]::NewGuid())

    try {
        yazi @args --cwd-file="$cwdFile"

        if (Test-Path -LiteralPath $cwdFile) {
            $newDirectory = Get-Content -LiteralPath $cwdFile -Raw
            if ($newDirectory -and $newDirectory -ne $PWD.Path) {
                Set-Location -LiteralPath $newDirectory
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $cwdFile -Force -ErrorAction SilentlyContinue
    }
}

# Pick a file and open it in Neovim.
function ff {
    $selection = fzf --preview 'bat --color=always --style=numbers --line-range=:500 {}'
    if ($selection) {
        nvim $selection
    }
}

Invoke-Expression (&starship init powershell)

function zellij { & "C:\Users\kaura\AppData\Local\Zellij\zellij.exe" options --default-shell powershell.exe $args }

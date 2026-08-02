# Personal commands
Set-Alias lvim 'C:\Users\kaura\.local\bin\lvim.ps1'

# UTF-8 output for modern command-line tools.
$OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

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
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# Unix-style file listings powered by eza.
Set-Alias -Name ls -Value eza -Option AllScope -Force
function ll { eza --long --icons=always --group-directories-first @args }
function la { eza --long --all --icons=always --group-directories-first @args }
function lt { eza --tree --level=2 --icons=always --group-directories-first @args }

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

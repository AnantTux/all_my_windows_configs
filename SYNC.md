# Config backup sync

Run this on Windows with PowerShell 7 from the `my-config-backup` directory:

```powershell
pwsh -NoProfile -File .\sync-dotfiles.ps1 -DryRun
pwsh -NoProfile -File .\sync-dotfiles.ps1
```

The script defaults to `%OneDrive%\Desktop\my-config-backup`. Use `-RepoPath` if the checkout is elsewhere, `-AutoHotkeyDirectory` if the scripts move, or `-SkipPush` to create only a local commit. Each run compares SHA-256 hashes, copies changed live files, stages only its named configuration paths, scans added lines for common credential formats, commits with a local timestamp, and pushes `main` to `origin`. It never deletes a backup file when a live source is unavailable.

Sources include PowerShell 7 and Windows PowerShell profiles, Git, Alacritty, Starship, Zellij, Neovim, Yazi, Windows Terminal and its wallpapers, selected AutoHotkey scripts from `D:\Scripts\AutoHotkey`, and Ubuntu WSL shell and theme files. WSL must be running for its `\\wsl.localhost\Ubuntu` paths to be readable. The script prints a warning for each unavailable source. It also stages edits to the backup's winget directory inventory and restore notes; it does not regenerate that inventory. Other backup-only reference files and the separate AutoHotkey utility package remain as they are.

For scheduled runs, create a Windows Task Scheduler task under your account that invokes `pwsh.exe` with `-NoProfile -File "C:\Users\kaura\OneDrive\Desktop\my-config-backup\sync-dotfiles.ps1"`. Allow it to run only when a network connection is available. Git credentials must already work for the `origin` remote.

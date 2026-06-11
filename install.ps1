param()

$ErrorActionPreference = "Stop"

$DotfilesDir = $PSScriptRoot
$ConfigDir = "$env:LOCALAPPDATA"
$BackupDir = "$env:USERPROFILE\.dotfiles_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Write-Host "==============================================="
Write-Host "🚀 Starting Dotfiles Interactive Installation (Windows)"
Write-Host "==============================================="
Write-Host ""

function Prompt-Install {
    param (
        [string]$Name,
        [string]$Src,
        [string]$Dest
    )

    Write-Host "-----------------------------------------------"
    Write-Host "📦 Configuration: $Name"
    Write-Host "⚠️  WARNING: This will replace your current configuration at $Dest."
    Write-Host "   (A backup will automatically be created at $BackupDir if it exists)"
    
    $Response = Read-Host "Do you want to install the $Name configuration? [y/N]"
    if ($Response -match "^[yY]([eE][sS])?$") {
        Link-File -Src $Src -Dest $Dest
    } else {
        Write-Host "⏭️  Skipping $Name."
    }
}

function Link-File {
    param (
        [string]$Src,
        [string]$Dest
    )

    if (Test-Path -Path $Dest -PathType Leaf) {
        $Item = Get-Item -Path $Dest -ErrorAction SilentlyContinue
        if ($Item.LinkType -eq "SymbolicLink" -and $Item.Target -eq $Src) {
            Write-Host "✅ Already linked: $Dest"
            return
        }
    }

    if (Test-Path -Path $Dest) {
        Write-Host "📦 Backing up $Dest to $BackupDir"
        if (-not (Test-Path -Path $BackupDir)) {
            New-Item -ItemType Directory -Path $BackupDir | Out-Null
        }
        Move-Item -Path $Dest -Destination $BackupDir -Force
    }

    Write-Host "🔗 Creating symlink: $Dest -> $Src"
    $DestDir = Split-Path -Path $Dest -Parent
    if (-not (Test-Path -Path $DestDir)) {
        New-Item -ItemType Directory -Path $DestDir | Out-Null
    }
    
    # Needs Administrator privileges for symlinks unless Developer Mode is on in Windows 10/11
    try {
        New-Item -ItemType SymbolicLink -Path $Dest -Target $Src | Out-Null
    } catch {
        Write-Host "❌ Failed to create symlink (You might need to run PowerShell as Administrator or enable Developer Mode)." -ForegroundColor Red
    }
}

$ConfigApps = @("nvim", "trunk", "lazygit", "lazydocker", "ghostty", "zed")

foreach ($App in $ConfigApps) {
    $SrcPath = Join-Path -Path $DotfilesDir -ChildPath "configs\$App"
    if (Test-Path -Path $SrcPath) {
        # Note: Some apps use different folders in Windows. 
        # Neovim uses ~/AppData/Local/nvim
        $DestPath = Join-Path -Path $ConfigDir -ChildPath $App
        Prompt-Install -Name $App -Src $SrcPath -Dest $DestPath
    }
}

Write-Host "==============================================="
Write-Host "🎉 Installation complete!"
Write-Host "If any existing directories were replaced, you can find their backups in:"
Write-Host "$BackupDir"

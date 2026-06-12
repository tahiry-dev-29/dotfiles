param()

$ErrorActionPreference = "Stop"

$DotfilesDir = $PSScriptRoot
$ConfigDir = "$env:LOCALAPPDATA"
$CurrentDate = Get-Date -Format "yyyyMMdd_HHmmss"

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
    Write-Host "   (An automatic backup will be created: ${Dest}.${CurrentDate}.bak)"
    
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
        $BackupName = "${Dest}.${CurrentDate}.bak"
        Write-Host "📦 Backing up $Dest to $BackupName"
        Move-Item -Path $Dest -Destination $BackupName -Force
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

$ConfigApps = @("nvim", "trunk", "lazygit", "lazydocker", "ghostty")

foreach ($App in $ConfigApps) {
    $SrcPath = Join-Path -Path $DotfilesDir -ChildPath "configs\$App"
    if (Test-Path -Path $SrcPath) {
        # Note: Some apps use different folders in Windows. 
        # Neovim uses ~/AppData/Local/nvim
        $DestPath = Join-Path -Path $ConfigDir -ChildPath $App
        Prompt-Install -Name $App -Src $SrcPath -Dest $DestPath
    }
}

Write-Host "-----------------------------------------------"
Write-Host "🧩 Optional Developer Modules"

$AngularSrc = Join-Path -Path $DotfilesDir -ChildPath "configs\optional\angular_aliases.zsh"
if (Test-Path -Path $AngularSrc) {
    $AngularDest = Join-Path -Path $env:USERPROFILE -ChildPath ".angular_aliases.zsh"
    Prompt-Install -Name "Angular & Nx Aliases" -Src $AngularSrc -Dest $AngularDest
}

$DockerSrc = Join-Path -Path $DotfilesDir -ChildPath "configs\optional\docker_aliases.zsh"
if (Test-Path -Path $DockerSrc) {
    $DockerDest = Join-Path -Path $env:USERPROFILE -ChildPath ".docker_aliases.zsh"
    Prompt-Install -Name "Docker Aliases" -Src $DockerSrc -Dest $DockerDest
}

$FlutterSrc = Join-Path -Path $DotfilesDir -ChildPath "configs\optional\flutter_aliases.zsh"
if (Test-Path -Path $FlutterSrc) {
    $FlutterDest = Join-Path -Path $env:USERPROFILE -ChildPath ".flutter_aliases.zsh"
    Prompt-Install -Name "Flutter Aliases" -Src $FlutterSrc -Dest $FlutterDest
}

$NestjsPrismaSrc = Join-Path -Path $DotfilesDir -ChildPath "configs\optional\nestjs_prisma_aliases.zsh"
if (Test-Path -Path $NestjsPrismaSrc) {
    $NestjsPrismaDest = Join-Path -Path $env:USERPROFILE -ChildPath ".nestjs_prisma_aliases.zsh"
    Prompt-Install -Name "NestJS & Prisma Aliases" -Src $NestjsPrismaSrc -Dest $NestjsPrismaDest
}

$GitSrc = Join-Path -Path $DotfilesDir -ChildPath "configs\optional\git_aliases.zsh"
if (Test-Path -Path $GitSrc) {
    $GitDest = Join-Path -Path $env:USERPROFILE -ChildPath ".git_aliases.zsh"
    Prompt-Install -Name "Git & GitHub CLI Aliases" -Src $GitSrc -Dest $GitDest
}

Write-Host "==============================================="
Write-Host "🎉 Installation complete!"
Write-Host "If any existing directories were replaced, they were safely backed up with the .bak extension."

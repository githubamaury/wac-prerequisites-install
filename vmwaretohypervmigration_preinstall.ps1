# VMware to Hyper-V Migration Prerequisites Installer
# Author: Amaury
# Requires: Admin privileges

$ErrorActionPreference = 'Stop'

function Assert-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        throw "❌ Script must be run as Administrator."
    }
}

function Assert-Internet {
    try { Invoke-WebRequest -Uri "https://www.microsoft.com" -UseBasicParsing -TimeoutSec 10 | Out-Null }
    catch { throw "❌ Internet connection required." }
}

function Install-VCRedist {
    param([string]$Url, [string]$Name)
    Write-Host "Installing $Name..."
    $temp = "$env:TEMP\$Name.exe"
    Invoke-WebRequest -Uri $Url -OutFile $temp
    Start-Process -FilePath $temp -ArgumentList "/quiet /norestart" -Wait
    Remove-Item $temp
}

function Is-VCRedistInstalled {
    param([string]$Pattern)
    Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |
        Where-Object { $_.DisplayName -like $Pattern } | ForEach-Object { return $true }
    return $false
}

function Install-WAC {
    $installPath = "C:\Program Files\Windows Admin Center"
    if (Test-Path $installPath) {
        Write-Host "✅ Windows Admin Center already installed at: $installPath. Skipping."
        return
    }

    $wacUrl = "https://download.microsoft.com/download/1/0/5/1059800B-F375-451C-B37E-758FFC7C8C8B/WindowsAdminCenter2410.exe"
    $userProfile = [Environment]::GetFolderPath("UserProfile")
    $downloads = Join-Path $userProfile "Downloads"
    $installerPath = Join-Path $downloads "WindowsAdminCenter2410.exe"

    if (-not (Test-Path $installerPath)) {
        Write-Host "📥 Downloading Windows Admin Center 2410 installer to: $installerPath"
        Invoke-WebRequest -Uri $wacUrl -OutFile $installerPath
    } else {
        Write-Host "📦 Installer already exists at: $installerPath"
    }

    Write-Host "🚀 Launching silent install..."
    $proc = Start-Process -FilePath $installerPath -ArgumentList "/quiet /norestart" -PassThru
    Wait-Process -Id $proc.Id

    Write-Host "✅ Windows Admin Center installer completed."
}

function Install-PowerCLI {
    Write-Host "Installing VMware PowerCLI..."
    Set-ExecutionPolicy RemoteSigned -Scope Process -Force
    Install-Module -Name VCF.PowerCLI -SkipPublisherCheck -AllowClobber
}

function Is-PowerCLIInstalled {
    Get-Module -ListAvailable -Name VCF.PowerCLI
}

function Install-VDDK {
    $targetPath = "C:\Program Files\WindowsAdminCenter\Services\VDDK"
    if (Test-Path "$targetPath\vixDiskLib.dll") {
        Write-Host "✅ VDDK already installed at target path. Skipping."
        return
    }

    $zipPath = Read-Host "📦 Enter full path to VDDK zipped folder (e.g., C:\Users\Amaury\Downloads\vddk.zip)"
    if (-not (Test-Path $zipPath)) {
        Write-Warning "❌ Zip file not found. Please check the path and try again."
        return
    }

    try {
        Write-Host "📂 Extracting VDDK to $targetPath..."
        Expand-Archive -Path $zipPath -DestinationPath $targetPath -Force
        Write-Host "✅ VDDK extracted successfully."
    } catch {
        Write-Error "❌ Failed to extract VDDK: $_"
    }
}

# --- Main Execution ---
try {
    Assert-Admin
    Assert-Internet

    # VC++ 2013
    if (-not (Is-VCRedistInstalled "*Visual C++*2013*64*")) {
        Install-VCRedist -Url "https://download.microsoft.com/download/1/2/3/12345678-abcd-1234-abcd-1234567890ab/vcredist_x64_2013.exe" -Name "VC2013"
    } else {
        Write-Host "✅ VC++ 2013 x64 already installed. Skipping."
    }

    # VC++ 2022–2025
    if (-not (Is-VCRedistInstalled "*Visual C++*2022*64*")) {
        Install-VCRedist -Url "https://aka.ms/vs/17/release/vc_redist.x64.exe" -Name "VC2022-2025"
    } else {
        Write-Host "✅ VC++ 2022–2025 x64 already installed. Skipping."
    }

    # Windows Admin Center
    Install-WAC

    # PowerCLI
    if (-not (Is-PowerCLIInstalled)) {
        Install-PowerCLI
    } else {
        Write-Host "✅ PowerCLI already installed. Skipping."
    }

    # VDDK
    Install-VDDK
}
catch {
    Write-Error "❌ An error occurred during setup: $_"
}

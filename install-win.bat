<# :
@echo off
title Dynamic Proxy Installer for Windows
color 0b
echo ====================================================
echo   Dynamic Proxy Installer for Windows
echo ====================================================

:: Cek Hak Akses Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Meminta hak akses Administrator...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression $([System.IO.File]::ReadAllText('%~f0'))"
echo.
pause
goto :eof
#>

# ============================================================
#  Dynamic Proxy Installer for Windows
#  Nginx-based dynamic reverse proxy with wildcard subdomain
# ============================================================

$ErrorActionPreference = "Stop"

# ── Config ──────────────────────────────────────────────────
$InstallDir = "C:\nginx"
$NginxVersion = "1.26.0"
$NginxZipUrl = "http://nginx.org/download/nginx-$NginxVersion.zip"
$NginxZipPath = "$env:TEMP\nginx.zip"
$ConfPath = Join-Path $InstallDir "conf\nginx.conf"
$EnvFile = "C:\dynamic-proxy.env"

# ── Helper functions ────────────────────────────────────────
$Script:StepCurrent = 0
$Script:StepTotal = 0

function Print-Banner {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "       Dynamic Proxy Installer v1.0               " -ForegroundColor Cyan
    Write-Host "       Windows (PowerShell)                       " -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Step($msg) {
    $Script:StepCurrent++
    Write-Host ""
    Write-Host "-- [$($Script:StepCurrent)/$($Script:StepTotal)] $msg --" -ForegroundColor Cyan
}

function Info($msg)    { Write-Host "[INFO]    $msg" -ForegroundColor Blue }
function Success($msg) { Write-Host "[OK]      $msg" -ForegroundColor Green }
function Warn($msg)    { Write-Host "[WARN]    $msg" -ForegroundColor Yellow }
function Error-Msg($msg) { Write-Host "[ERROR]   $msg" -ForegroundColor Red }

# ── Parse arguments ─────────────────────────────────────────
$Action = "install"
$Domain = ""
$NginxPort = ""

$i = 0
while ($i -lt $args.Count) {
    switch ($args[$i]) {
        { $_ -in "--domain", "-d" } {
            $Domain = $args[$i + 1]
            $i += 2
        }
        { $_ -in "--port", "-p" } {
            $NginxPort = $args[$i + 1]
            $i += 2
        }
        { $_ -in "--uninstall", "-u" } {
            $Action = "uninstall"
            $i++
        }
        { $_ -in "--update", "-c" } {
            $Action = "update"
            $i++
        }
        { $_ -in "--help", "-h" } {
            $Action = "help"
            $i++
        }
        default {
            Error-Msg "Opsi tidak dikenal: $($args[$i])"
            Write-Host "Gunakan --help untuk bantuan."
            exit 1
        }
    }
}

# ── Get user input ──────────────────────────────────────────
function Get-UserInput {
    Write-Host ""
    Write-Host "-- Konfigurasi Dynamic Proxy --" -ForegroundColor White

    # Domain
    if ([string]::IsNullOrWhiteSpace($Script:Domain)) {
        while ($true) {
            $Script:Domain = Read-Host "Masukkan domain (contoh: proxy.example.com)"
            if ([string]::IsNullOrWhiteSpace($Script:Domain)) {
                Warn "Domain tidak boleh kosong!"
            } elseif ($Script:Domain -notmatch '^[a-zA-Z0-9]([a-zA-Z0-9.\-]*[a-zA-Z0-9])?$') {
                Warn "Format domain tidak valid!"
            } else {
                break
            }
        }
    } else {
        Info "Domain: $($Script:Domain)"
    }

    # Port
    if ([string]::IsNullOrWhiteSpace($Script:NginxPort)) {
        while ($true) {
            $portInput = Read-Host "Masukkan port Nginx (default: 8080)"
            if ([string]::IsNullOrWhiteSpace($portInput)) {
                $Script:NginxPort = "8080"
                break
            } elseif ($portInput -match '^\d+$' -and [int]$portInput -ge 1 -and [int]$portInput -le 65535) {
                $Script:NginxPort = $portInput
                break
            } else {
                Warn "Port harus berupa angka antara 1-65535!"
            }
        }
    } else {
        Info "Port: $($Script:NginxPort)"
    }

    # Validasi domain
    if ($Script:Domain -notmatch '^[a-zA-Z0-9]([a-zA-Z0-9.\-]*[a-zA-Z0-9])?$') {
        Error-Msg "Format domain tidak valid: $($Script:Domain)"
        exit 1
    }

    # Validasi port
    if ($Script:NginxPort -notmatch '^\d+$' -or [int]$Script:NginxPort -lt 1 -or [int]$Script:NginxPort -gt 65535) {
        Error-Msg "Port tidak valid: $($Script:NginxPort)"
        exit 1
    }

    Write-Host ""
    Write-Host "-- Ringkasan Konfigurasi --" -ForegroundColor White
    Write-Host "  Domain : $($Script:Domain)" -ForegroundColor Green
    Write-Host "  Port   : $($Script:NginxPort)" -ForegroundColor Green
    Write-Host "  Pola   : <ip1>-<ip2>-<ip3>-<ip4>.$($Script:Domain)" -ForegroundColor Yellow
    Write-Host "  Pola   : <ip1>-<ip2>-<ip3>-<ip4>-<port>.$($Script:Domain)" -ForegroundColor Yellow
    Write-Host ""
}

# ── Install Nginx ───────────────────────────────────────────
function Install-Nginx {
    Step "Menginstal Nginx"

    if (Test-Path (Join-Path $InstallDir "nginx.exe")) {
        Success "Nginx sudah terinstal di $InstallDir"
        return
    }

    if (Test-Path $InstallDir) {
        Warn "Folder $InstallDir ada tapi nginx.exe tidak ditemukan."
    }

    Info "Mengunduh Nginx $NginxVersion..."
    Invoke-WebRequest -Uri $NginxZipUrl -OutFile $NginxZipPath -UseBasicParsing

    Info "Mengekstrak Nginx..."
    Expand-Archive -Path $NginxZipPath -DestinationPath "C:\" -Force

    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force
    }
    Rename-Item -Path "C:\nginx-$NginxVersion" -NewName "nginx"
    Remove-Item -Path $NginxZipPath -Force

    if (Test-Path (Join-Path $InstallDir "nginx.exe")) {
        Success "Nginx berhasil diinstal ke $InstallDir"
    } else {
        Error-Msg "Gagal menginstal Nginx."
        exit 1
    }
}

# ── Generate Nginx config ──────────────────────────────────
function Generate-NginxConfig {
    Step "Membuat Konfigurasi Nginx"
    Info "Menulis file konfigurasi..."

    $EscapedDomain = $Script:Domain -replace '\.', '\.'
    $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $ConfigContent = @"
# ============================================================
#  Dynamic Proxy - Auto-generated configuration
#  Domain : $($Script:Domain)
#  Port   : $($Script:NginxPort)
#  Generated: $Date
# ============================================================

worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    # BLOK 1: Menangkap IP + Port Custom (Contoh: 192-168-18-2-8080.$($Script:Domain))
    server {
        listen $($Script:NginxPort);
        server_name ~^(?<ip1>\d+)-(?<ip2>\d+)-(?<ip3>\d+)-(?<ip4>\d+)-(?<port>\d+)\.$($EscapedDomain)$;

        resolver 8.8.8.8 1.1.1.1 valid=300s;

        location / {
            proxy_pass http://`$ip1.`$ip2.`$ip3.`$ip4:`$port;

            proxy_set_header Host `$host;
            proxy_set_header X-Real-IP `$remote_addr;
            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto `$scheme;

            proxy_read_timeout 300;
            proxy_connect_timeout 300;
            proxy_send_timeout 300;
        }
    }

    # BLOK 2: Menangkap IP Standar (Contoh: 192-168-18-2.$($Script:Domain))
    server {
        listen $($Script:NginxPort);
        server_name ~^(?<ip1>\d+)-(?<ip2>\d+)-(?<ip3>\d+)-(?<ip4>\d+)\.$($EscapedDomain)$;

        resolver 8.8.8.8 1.1.1.1 valid=300s;

        location / {
            proxy_pass http://`$ip1.`$ip2.`$ip3.`$ip4;

            proxy_set_header Host `$host;
            proxy_set_header X-Real-IP `$remote_addr;
            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto `$scheme;

            proxy_read_timeout 300;
            proxy_connect_timeout 300;
            proxy_send_timeout 300;
        }
    }
}
"@

    [System.IO.File]::WriteAllText($ConfPath, $ConfigContent)
    Success "Konfigurasi Nginx dibuat: $ConfPath"
}

# ── Save env ────────────────────────────────────────────────
function Save-Env {
    Step "Menyimpan Konfigurasi Environment"
    $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $EnvContent = @"
# Dynamic Proxy Environment
DOMAIN=$($Script:Domain)
NGINX_PORT=$($Script:NginxPort)
INSTALLED_AT="$Date"
"@
    [System.IO.File]::WriteAllText($EnvFile, $EnvContent)
    Success "Konfigurasi disimpan: $EnvFile"
}

# ── Test & reload Nginx ─────────────────────────────────────
function Test-AndReload {
    Step "Menguji & Memuat Ulang Nginx"
    Info "Menguji konfigurasi Nginx..."

    $nginxExe = Join-Path $InstallDir "nginx.exe"

    $testResult = & $nginxExe -t 2>&1
    if ($LASTEXITCODE -eq 0) {
        Success "Konfigurasi Nginx valid!"
    } else {
        Error-Msg "Konfigurasi Nginx tidak valid! Periksa file: $ConfPath"
        Write-Host $testResult
        exit 1
    }

    Info "Menghentikan Nginx yang mungkin sedang berjalan..."
    Stop-Process -Name nginx -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    Info "Menjalankan Nginx..."
    Start-Process -FilePath $nginxExe -WorkingDirectory $InstallDir

    Start-Sleep -Seconds 1
    $nginxProc = Get-Process -Name nginx -ErrorAction SilentlyContinue
    if ($nginxProc) {
        Success "Nginx berjalan dengan baik!"
    } else {
        Error-Msg "Nginx gagal berjalan. Periksa log di: $InstallDir\logs\error.log"
        exit 1
    }
}

# ── Create helper scripts ──────────────────────────────────
function Create-HelperScripts {
    Step "Membuat Script Helper"

    $DesktopPath = [Environment]::GetFolderPath("Desktop")

    $BatStartContent = "@echo off`r`ncd /d C:\nginx`r`nstart nginx.exe`r`necho Nginx Started`r`npause"
    $BatStopContent = "@echo off`r`ncd /d C:\nginx`r`nnginx.exe -s quit`r`necho Nginx Stopped`r`npause"
    $BatReloadContent = "@echo off`r`ncd /d C:\nginx`r`nnginx.exe -s reload`r`necho Nginx Reloaded`r`npause"

    # Script di folder saat ini
    $StartBat = Join-Path (Get-Location).Path "start-nginx.bat"
    $StopBat = Join-Path (Get-Location).Path "stop-nginx.bat"
    $ReloadBat = Join-Path (Get-Location).Path "reload-nginx.bat"

    Set-Content -Path $StartBat -Value $BatStartContent
    Set-Content -Path $StopBat -Value $BatStopContent
    Set-Content -Path $ReloadBat -Value $BatReloadContent
    Success "Script helper dibuat: start-nginx.bat, stop-nginx.bat, reload-nginx.bat"

    # Script di Desktop
    Set-Content -Path (Join-Path $DesktopPath "Start Dynamic Proxy.bat") -Value $BatStartContent
    Set-Content -Path (Join-Path $DesktopPath "Stop Dynamic Proxy.bat") -Value $BatStopContent
    Success "Shortcut Desktop dibuat."
}

# ── Setup PM2 Auto-Start ────────────────────────────────────
function Setup-PM2 {
    Step "Mengatur PM2 Auto-Start"

    # Cek apakah Node.js terinstal
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeCmd) {
        Error-Msg "Node.js belum terinstal!"
        Warn "Install Node.js terlebih dahulu dari: https://nodejs.org"
        Warn "Setelah install Node.js, jalankan ulang installer ini."
        Warn "Melewati setup PM2... Nginx tetap berjalan tapi TIDAK auto-start saat boot."
        return
    }
    Info "Node.js terdeteksi: $(node -v)"

    # Cek apakah npm tersedia
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if (-not $npmCmd) {
        Error-Msg "npm tidak ditemukan!"
        Warn "Melewati setup PM2..."
        return
    }

    # Install PM2 global
    $pm2Cmd = Get-Command pm2 -ErrorAction SilentlyContinue
    if (-not $pm2Cmd) {
        Info "Menginstal PM2 secara global..."
        & npm install -g pm2 2>&1 | Out-Null
        $pm2Cmd = Get-Command pm2 -ErrorAction SilentlyContinue
        if (-not $pm2Cmd) {
            Error-Msg "Gagal menginstal PM2."
            Warn "Melewati setup PM2..."
            return
        }
        Success "PM2 berhasil diinstal."
    } else {
        Success "PM2 sudah terinstal."
    }

    # Hapus proses PM2 lama jika ada
    & pm2 delete dynamic-proxy 2>&1 | Out-Null

    # Buat ecosystem file untuk PM2
    $ecosystemPath = Join-Path $InstallDir "ecosystem.config.js"
    $ecosystemContent = @"
module.exports = {
  apps: [{
    name: 'dynamic-proxy',
    script: 'nginx.exe',
    cwd: 'C:\\nginx',
    interpreter: 'none',
    watch: false,
    autorestart: true,
    restart_delay: 3000,
    max_restarts: 10
  }]
};
"@
    [System.IO.File]::WriteAllText($ecosystemPath, $ecosystemContent)
    Info "Ecosystem file dibuat: $ecosystemPath"

    # Hentikan nginx yang berjalan manual (PM2 akan mengelolanya)
    Stop-Process -Name nginx -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    # Start nginx via PM2
    Info "Menjalankan Nginx via PM2..."
    & pm2 start $ecosystemPath 2>&1 | Out-Null
    Start-Sleep -Seconds 2

    # Verifikasi
    $pm2Status = & pm2 jlist 2>&1
    if ($pm2Status -match 'dynamic-proxy') {
        Success "Nginx berjalan via PM2."
    } else {
        Warn "PM2 mungkin belum memulai Nginx dengan benar. Cek: pm2 status"
    }

    # Save PM2 process list
    & pm2 save 2>&1 | Out-Null
    Success "PM2 process list disimpan."

    # Setup PM2 startup (Windows service)
    Info "Mengatur PM2 auto-start saat boot..."
    $pm2Home = $env:PM2_HOME
    if ([string]::IsNullOrWhiteSpace($pm2Home)) {
        $pm2Home = Join-Path $env:USERPROFILE ".pm2"
    }

    # Install pm2-windows-startup
    $pm2Startup = Get-Command pm2-startup -ErrorAction SilentlyContinue
    if (-not $pm2Startup) {
        Info "Menginstal pm2-windows-startup..."
        & npm install -g pm2-windows-startup 2>&1 | Out-Null
    }

    # Jalankan pm2-startup install
    $pm2StartupCmd = Get-Command pm2-startup -ErrorAction SilentlyContinue
    if ($pm2StartupCmd) {
        & pm2-startup install 2>&1 | Out-Null
        Success "PM2 auto-start saat boot diaktifkan."
    } else {
        Warn "pm2-windows-startup gagal diinstal."
        Warn "Jalankan manual: npm install -g pm2-windows-startup && pm2-startup install"
    }
}

# ── Print usage ─────────────────────────────────────────────
function Print-Usage {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "         Instalasi Berhasil!                      " -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Cara Penggunaan:" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. Akses IP tanpa port custom:" -ForegroundColor Cyan
    Write-Host "     http://192-168-1-100.$($Script:Domain):$($Script:NginxPort)"
    Write-Host "     -> Proxy ke http://192.168.1.100"
    Write-Host ""
    Write-Host "  2. Akses IP dengan port custom:" -ForegroundColor Cyan
    Write-Host "     http://192-168-1-100-8080.$($Script:Domain):$($Script:NginxPort)"
    Write-Host "     -> Proxy ke http://192.168.1.100:8080"
    Write-Host ""
    Write-Host "DNS Setup:" -ForegroundColor White
    Write-Host "  Tambahkan wildcard DNS record:"
    Write-Host "  *.$($Script:Domain)  ->  <IP server ini>" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Manajemen:" -ForegroundColor White
    Write-Host "  Konfigurasi : $ConfPath" -ForegroundColor Cyan
    Write-Host "  Environment : $EnvFile" -ForegroundColor Cyan
    Write-Host "  PM2 Status  : pm2 status" -ForegroundColor Cyan
    Write-Host "  PM2 Restart : pm2 restart dynamic-proxy" -ForegroundColor Cyan
    Write-Host "  PM2 Logs    : pm2 logs dynamic-proxy" -ForegroundColor Cyan
    Write-Host "  Start       : start-nginx.bat" -ForegroundColor Cyan
    Write-Host "  Stop        : stop-nginx.bat" -ForegroundColor Cyan
    Write-Host "  Reload      : reload-nginx.bat" -ForegroundColor Cyan
    Write-Host "  Uninstall   : jalankan install-win.bat --uninstall" -ForegroundColor Cyan
    Write-Host ""
}

# ── Uninstall ───────────────────────────────────────────────
function Invoke-Uninstall {
    $Script:StepCurrent = 0
    $Script:StepTotal = 5

    Print-Banner
    Write-Host "-- Uninstall Dynamic Proxy --" -ForegroundColor Red
    Write-Host ""

    $confirm = Read-Host "Hapus konfigurasi Dynamic Proxy? (y/n)"
    if ($confirm -notmatch '^[Yy]$') {
        Info "Uninstall dibatalkan."
        exit 0
    }

    Step "Menghentikan Nginx & PM2"
    # Hapus dari PM2
    $pm2Cmd = Get-Command pm2 -ErrorAction SilentlyContinue
    if ($pm2Cmd) {
        & pm2 delete dynamic-proxy 2>&1 | Out-Null
        & pm2 save 2>&1 | Out-Null
        Success "Proses PM2 dynamic-proxy dihapus."
    }
    Stop-Process -Name nginx -ErrorAction SilentlyContinue
    Success "Nginx dihentikan."

    Step "Menghapus Konfigurasi"
    if (Test-Path $ConfPath) {
        # Restore default config if backup exists
        $backupConf = Join-Path $InstallDir "conf\nginx.conf.bak"
        if (Test-Path $backupConf) {
            Copy-Item -Path $backupConf -Destination $ConfPath -Force
            Success "Konfigurasi default dikembalikan."
        } else {
            Info "Tidak ada backup konfigurasi default."
        }
    }

    Step "Menghapus Environment File"
    if (Test-Path $EnvFile) {
        Remove-Item -Path $EnvFile -Force
        Success "Environment file dihapus: $EnvFile"
    } else {
        Info "Environment file tidak ditemukan."
    }

    Step "Menghapus Script Helper & PM2 Startup"
    $DesktopPath = [Environment]::GetFolderPath("Desktop")

    # Hapus PM2 startup service
    $pm2StartupCmd = Get-Command pm2-startup -ErrorAction SilentlyContinue
    if ($pm2StartupCmd) {
        & pm2-startup uninstall 2>&1 | Out-Null
        Success "PM2 auto-start dihapus."
    }

    # Hapus ecosystem file
    $ecosystemPath = Join-Path $InstallDir "ecosystem.config.js"
    if (Test-Path $ecosystemPath) {
        Remove-Item -Path $ecosystemPath -Force
        Success "Ecosystem file dihapus."
    }

    $filesToRemove = @(
        (Join-Path (Get-Location).Path "start-nginx.bat"),
        (Join-Path (Get-Location).Path "stop-nginx.bat"),
        (Join-Path (Get-Location).Path "reload-nginx.bat"),
        (Join-Path $DesktopPath "Start Dynamic Proxy.bat"),
        (Join-Path $DesktopPath "Stop Dynamic Proxy.bat")
    )

    foreach ($f in $filesToRemove) {
        if (Test-Path $f) {
            Remove-Item -Path $f -Force
            Success "Dihapus: $f"
        }
    }

    Step "Hapus Nginx (Opsional)"
    $removeNginx = Read-Host "Hapus juga folder Nginx ($InstallDir)? (y/n)"
    if ($removeNginx -match '^[Yy]$') {
        Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
        Success "Nginx dihapus: $InstallDir"
    }

    Write-Host ""
    Success "Dynamic Proxy berhasil di-uninstall!"
    Write-Host ""
}

# ── Update ──────────────────────────────────────────────────
function Invoke-Update {
    $Script:StepCurrent = 0
    $Script:StepTotal = 5

    Print-Banner
    Write-Host "-- Update Konfigurasi --" -ForegroundColor Yellow
    Write-Host ""

    Step "Membaca Konfigurasi Saat Ini"
    if (Test-Path $EnvFile) {
        $envContent = Get-Content $EnvFile
        foreach ($line in $envContent) {
            if ($line -match '^DOMAIN=(.+)$') {
                $currentDomain = $Matches[1]
            }
            if ($line -match '^NGINX_PORT=(.+)$') {
                $currentPort = $Matches[1]
            }
        }
        Info "Konfigurasi saat ini:"
        Write-Host "  Domain : $currentDomain" -ForegroundColor Green
        Write-Host "  Port   : $currentPort" -ForegroundColor Green
        Write-Host ""
    } else {
        Warn "File environment tidak ditemukan: $EnvFile"
    }

    # Reset untuk input baru
    $Script:Domain = ""
    $Script:NginxPort = ""
    Get-UserInput
    Generate-NginxConfig
    Save-Env
    Test-AndReload
    Print-Usage
}

# ── Main ────────────────────────────────────────────────────
Print-Banner

switch ($Action) {
    "help" {
        Write-Host "Penggunaan: install-win.bat [OPSI]"
        Write-Host ""
        Write-Host "Opsi:"
        Write-Host "  --domain, -d <domain>   Set domain (contoh: proxy.example.com)"
        Write-Host "  --port, -p <port>       Set port Nginx (default: 8080)"
        Write-Host "  --update, -c            Update domain/port"
        Write-Host "  --uninstall, -u         Hapus Dynamic Proxy"
        Write-Host "  --help, -h              Tampilkan bantuan ini"
        Write-Host ""
        Write-Host "Contoh:"
        Write-Host "  install-win.bat --domain proxy.example.com --port 8080"
        Write-Host ""
        exit 0
    }
    "uninstall" {
        Invoke-Uninstall
        exit 0
    }
    "update" {
        Invoke-Update
        exit 0
    }
}

# ── Install flow ────────────────────────────────────────────
Get-UserInput

$Script:StepTotal = 7
Install-Nginx
Generate-NginxConfig
Save-Env
Test-AndReload
Create-HelperScripts
Setup-PM2
Print-Usage

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

$ErrorActionPreference = "Stop"

$InstallDir = "C:\nginx"
$NginxVersion = "1.26.0"
$NginxZipUrl = "http://nginx.org/download/nginx-$NginxVersion.zip"
$NginxZipPath = "$env:TEMP\nginx.zip"

Write-Host "Memulai instalasi Dynamic Proxy untuk Windows..." -ForegroundColor Cyan

# Ambil input Domain
$Domain = Read-Host "Masukkan domain (contoh: proxy.example.com)"
if ([string]::IsNullOrWhiteSpace($Domain)) {
    Write-Host "Domain tidak boleh kosong!" -ForegroundColor Red
    exit
}

# Ambil input Port
$PortStr = Read-Host "Masukkan port Nginx (default: 8080)"
$Port = 8080
if (![string]::IsNullOrWhiteSpace($PortStr)) {
    $Port = [int]$PortStr
}

# Download Nginx jika belum ada
if (!(Test-Path $InstallDir)) {
    Write-Host "Mengunduh Nginx $NginxVersion..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $NginxZipUrl -OutFile $NginxZipPath
    
    Write-Host "Mengekstrak Nginx..." -ForegroundColor Yellow
    Expand-Archive -Path $NginxZipPath -DestinationPath "C:\" -Force
    Rename-Item -Path "C:\nginx-$NginxVersion" -NewName "nginx"
    Remove-Item -Path $NginxZipPath -Force
    Write-Host "Nginx berhasil diunduh dan diekstrak ke C:\nginx." -ForegroundColor Green
} else {
    Write-Host "Folder C:\nginx sudah ada, melewati proses unduh." -ForegroundColor Green
}

# Generate Config
$ConfPath = Join-Path $InstallDir "conf\nginx.conf"
Write-Host "Membuat konfigurasi Nginx..." -ForegroundColor Yellow

$EscapedDomain = $Domain -replace '\.', '\.'

$ConfigContent = @'
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    # ============================================================
    #  Dynamic Proxy - Auto-generated configuration
    #  Domain : {{DOMAIN}}
    #  Port   : {{PORT}}
    # ============================================================

    # BLOK 1: Menangkap IP + Port Custom (Contoh: 192-168-18-2-8080.{{DOMAIN}})
    server {
        listen {{PORT}};
        server_name ~^(?<ip1>\d+)-(?<ip2>\d+)-(?<ip3>\d+)-(?<ip4>\d+)-(?<port>\d+)\.{{ESCAPED_DOMAIN}}$;

        resolver 8.8.8.8 1.1.1.1 valid=300s;

        location / {
            proxy_pass http://$ip1.$ip2.$ip3.$ip4:$port;
            proxy_intercept_errors on;
            error_page 400 497 502 504 = @https_fallback;
            
            # Rewrite Redirect Headers
            proxy_redirect http://$ip1.$ip2.$ip3.$ip4:$port http://$http_host;
            proxy_redirect https://$ip1.$ip2.$ip3.$ip4:$port $scheme://s-$ip1-$ip2-$ip3-$ip4-$port.{{DOMAIN}};
            proxy_redirect http://$ip1.$ip2.$ip3.$ip4:80 http://$http_host;
            proxy_redirect https://$ip1.$ip2.$ip3.$ip4:443 $scheme://s-$ip1-$ip2-$ip3-$ip4-$port.{{DOMAIN}};
            proxy_redirect http://$ip1.$ip2.$ip3.$ip4 http://$http_host;
            proxy_redirect https://$ip1.$ip2.$ip3.$ip4 $scheme://s-$ip1-$ip2-$ip3-$ip4-$port.{{DOMAIN}};

            # Rewrite Hardcoded IPs in HTML/JS
            proxy_set_header Accept-Encoding "";
            sub_filter "http://$ip1.$ip2.$ip3.$ip4:$port" "http://$http_host";
            sub_filter "https://$ip1.$ip2.$ip3.$ip4:$port" "$scheme://s-$ip1-$ip2-$ip3-$ip4-$port.{{DOMAIN}}";
            sub_filter "http://$ip1.$ip2.$ip3.$ip4:80" "http://$http_host";
            sub_filter "https://$ip1.$ip2.$ip3.$ip4:443" "$scheme://s-$ip1-$ip2-$ip3-$ip4-$port.{{DOMAIN}}";
            sub_filter "http://$ip1.$ip2.$ip3.$ip4" "http://$http_host";
            sub_filter "https://$ip1.$ip2.$ip3.$ip4" "$scheme://s-$ip1-$ip2-$ip3-$ip4-$port.{{DOMAIN}}";
            sub_filter_once off;
            sub_filter_types *;

            proxy_set_header Host $ip1.$ip2.$ip3.$ip4;
            chunked_transfer_encoding off;
            proxy_buffering off;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_read_timeout 300;
            proxy_connect_timeout 300;
            proxy_send_timeout 300;
        }

        location @https_fallback {
            proxy_pass https://$ip1.$ip2.$ip3.$ip4:$port;
            
            # Rewrite Redirect Headers
            proxy_redirect http://$ip1.$ip2.$ip3.$ip4:$port http://$http_host;
            proxy_redirect https://$ip1.$ip2.$ip3.$ip4:$port https://$http_host;
            proxy_redirect http://$ip1.$ip2.$ip3.$ip4:80 http://$http_host;
            proxy_redirect https://$ip1.$ip2.$ip3.$ip4:443 https://$http_host;
            proxy_redirect http://$ip1.$ip2.$ip3.$ip4 http://$http_host;
            proxy_redirect https://$ip1.$ip2.$ip3.$ip4 https://$http_host;

            # Rewrite Hardcoded IPs in HTML/JS
            proxy_set_header Accept-Encoding "";
            sub_filter "http://$ip1.$ip2.$ip3.$ip4:$port" "http://$http_host";
            sub_filter "https://$ip1.$ip2.$ip3.$ip4:$port" "https://$http_host";
            sub_filter "http://$ip1.$ip2.$ip3.$ip4:80" "http://$http_host";
            sub_filter "https://$ip1.$ip2.$ip3.$ip4:443" "https://$http_host";
            sub_filter "http://$ip1.$ip2.$ip3.$ip4" "http://$http_host";
            sub_filter "https://$ip1.$ip2.$ip3.$ip4" "https://$http_host";
            sub_filter_once off;
            sub_filter_types *;

            proxy_ssl_verify off;
            proxy_set_header Host $ip1.$ip2.$ip3.$ip4;
            chunked_transfer_encoding off;
            proxy_buffering off;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_read_timeout 300;
            proxy_connect_timeout 300;
            proxy_send_timeout 300;
        }
    }

    # BLOK 2: Menangkap IP Standar (Contoh: 192-168-18-2.{{DOMAIN}})
    server {
        listen {{PORT}};
        server_name ~^(?<ip1>\d+)-(?<ip2>\d+)-(?<ip3>\d+)-(?<ip4>\d+)\.{{ESCAPED_DOMAIN}}$;

        resolver 8.8.8.8 1.1.1.1 valid=300s;

        location / {
            proxy_pass http://$ip1.$ip2.$ip3.$ip4;
            proxy_intercept_errors on;
            error_page 400 497 502 504 = @https_fallback;
            
            # Rewrite Redirect Headers
            proxy_redirect http://$ip1.$ip2.$ip3.$ip4:80 http://$http_host;
            proxy_redirect https://$ip1.$ip2.$ip3.$ip4:443 $scheme://s-$ip1-$ip2-$ip3-$ip4.{{DOMAIN}};
            proxy_redirect http://$ip1.$ip2.$ip3.$ip4 http://$http_host;
            proxy_redirect https://$ip1.$ip2.$ip3.$ip4 $scheme://s-$ip1-$ip2-$ip3-$ip4.{{DOMAIN}};

            # Rewrite Hardcoded IPs in HTML/JS
            proxy_set_header Accept-Encoding "";
            sub_filter "http://$ip1.$ip2.$ip3.$ip4:80" "http://$http_host";
            sub_filter "https://$ip1.$ip2.$ip3.$ip4:443" "$scheme://s-$ip1-$ip2-$ip3-$ip4.{{DOMAIN}}";
            sub_filter "http://$ip1.$ip2.$ip3.$ip4" "http://$http_host";
            sub_filter "https://$ip1.$ip2.$ip3.$ip4" "$scheme://s-$ip1-$ip2-$ip3-$ip4.{{DOMAIN}}";
            sub_filter_once off;
            sub_filter_types *;

            proxy_set_header Host $ip1.$ip2.$ip3.$ip4;
            chunked_transfer_encoding off;
            proxy_buffering off;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_read_timeout 300;
            proxy_connect_timeout 300;
            proxy_send_timeout 300;
        }

        location @https_fallback {
            proxy_pass https://$ip1.$ip2.$ip3.$ip4;
            
            # Rewrite Redirect Headers
            proxy_redirect http://$ip1.$ip2.$ip3.$ip4:80 http://$http_host;
            proxy_redirect https://$ip1.$ip2.$ip3.$ip4:443 https://$http_host;
            proxy_redirect http://$ip1.$ip2.$ip3.$ip4 http://$http_host;
            proxy_redirect https://$ip1.$ip2.$ip3.$ip4 https://$http_host;

            # Rewrite Hardcoded IPs in HTML/JS
            proxy_set_header Accept-Encoding "";
            sub_filter "http://$ip1.$ip2.$ip3.$ip4:80" "http://$http_host";
            sub_filter "https://$ip1.$ip2.$ip3.$ip4:443" "https://$http_host";
            sub_filter "http://$ip1.$ip2.$ip3.$ip4" "http://$http_host";
            sub_filter "https://$ip1.$ip2.$ip3.$ip4" "https://$http_host";
            sub_filter_once off;
            sub_filter_types *;

            proxy_ssl_verify off;
            proxy_set_header Host $ip1.$ip2.$ip3.$ip4;
            chunked_transfer_encoding off;
            proxy_buffering off;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_read_timeout 300;
            proxy_connect_timeout 300;
            proxy_send_timeout 300;
        }
    }

    # BLOK 3: Menangkap IP + Port Custom HTTPS (Contoh: s-192-168-18-2-8443.{{DOMAIN}})
    server {
        listen {{PORT}};
        server_name ~^s-(?<ip1>\d+)-(?<ip2>\d+)-(?<ip3>\d+)-(?<ip4>\d+)-(?<port>\d+)\.{{ESCAPED_DOMAIN}}$;

        resolver 8.8.8.8 1.1.1.1 valid=300s;

        location / {
            proxy_pass https://$ip1.$ip2.$ip3.$ip4:$port;
            
            # Rewrite Redirect Headers
            proxy_redirect http://$ip1.$ip2.$ip3.$ip4:$port http://$http_host;
            proxy_redirect https://$ip1.$ip2.$ip3.$ip4:$port https://$http_host;
            proxy_redirect http://$ip1.$ip2.$ip3.$ip4:80 http://$http_host;
            proxy_redirect https://$ip1.$ip2.$ip3.$ip4:443 https://$http_host;
            proxy_redirect http://$ip1.$ip2.$ip3.$ip4 http://$http_host;
            proxy_redirect https://$ip1.$ip2.$ip3.$ip4 https://$http_host;

            # Rewrite Hardcoded IPs in HTML/JS
            proxy_set_header Accept-Encoding "";
            sub_filter "http://$ip1.$ip2.$ip3.$ip4:$port" "http://$http_host";
            sub_filter "https://$ip1.$ip2.$ip3.$ip4:$port" "https://$http_host";
            sub_filter "http://$ip1.$ip2.$ip3.$ip4:80" "http://$http_host";
            sub_filter "https://$ip1.$ip2.$ip3.$ip4:443" "https://$http_host";
            sub_filter "http://$ip1.$ip2.$ip3.$ip4" "http://$http_host";
            sub_filter "https://$ip1.$ip2.$ip3.$ip4" "https://$http_host";
            sub_filter_once off;
            sub_filter_types *;

            proxy_ssl_verify off;
            proxy_set_header Host $ip1.$ip2.$ip3.$ip4;
            chunked_transfer_encoding off;
            proxy_buffering off;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_read_timeout 300;
            proxy_connect_timeout 300;
            proxy_send_timeout 300;
        }
    }

    # BLOK 4: Menangkap IP Standar HTTPS (Contoh: s-192-168-18-2.{{DOMAIN}})
    server {
        listen {{PORT}};
        server_name ~^s-(?<ip1>\d+)-(?<ip2>\d+)-(?<ip3>\d+)-(?<ip4>\d+)\.{{ESCAPED_DOMAIN}}$;

        resolver 8.8.8.8 1.1.1.1 valid=300s;

        location / {
            proxy_pass https://$ip1.$ip2.$ip3.$ip4;
            
            # Rewrite Redirect Headers
            proxy_redirect http://$ip1.$ip2.$ip3.$ip4:80 http://$http_host;
            proxy_redirect https://$ip1.$ip2.$ip3.$ip4:443 https://$http_host;
            proxy_redirect http://$ip1.$ip2.$ip3.$ip4 http://$http_host;
            proxy_redirect https://$ip1.$ip2.$ip3.$ip4 https://$http_host;

            # Rewrite Hardcoded IPs in HTML/JS
            proxy_set_header Accept-Encoding "";
            sub_filter "http://$ip1.$ip2.$ip3.$ip4:80" "http://$http_host";
            sub_filter "https://$ip1.$ip2.$ip3.$ip4:443" "https://$http_host";
            sub_filter "http://$ip1.$ip2.$ip3.$ip4" "http://$http_host";
            sub_filter "https://$ip1.$ip2.$ip3.$ip4" "https://$http_host";
            sub_filter_once off;
            sub_filter_types *;

            proxy_ssl_verify off;
            proxy_set_header Host $ip1.$ip2.$ip3.$ip4;
            chunked_transfer_encoding off;
            proxy_buffering off;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_read_timeout 300;
            proxy_connect_timeout 300;
            proxy_send_timeout 300;
        }
    }
}
'@

$ConfigContent = $ConfigContent -replace '\{\{DOMAIN\}\}', $Domain -replace '\{\{PORT\}\}', $Port -replace '\{\{ESCAPED_DOMAIN\}\}', $EscapedDomain

[System.IO.File]::WriteAllText($ConfPath, $ConfigContent)

# Restart Nginx
Write-Host "Menghentikan Nginx yang mungkin sedang berjalan..." -ForegroundColor Yellow
Stop-Process -Name nginx -ErrorAction SilentlyContinue

Write-Host "Menjalankan Nginx..." -ForegroundColor Yellow
Start-Process -FilePath (Join-Path $InstallDir "nginx.exe") -WorkingDirectory $InstallDir

# Bikin Shortcut Bat di Desktop dan Folder saat ini
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$StartBat = Join-Path (Get-Location).Path "start-nginx.bat"
$StopBat = Join-Path (Get-Location).Path "stop-nginx.bat"
$ReloadBat = Join-Path (Get-Location).Path "reload-nginx.bat"

$BatStartContent = "@echo off`r`ncd /d C:\nginx`r`nstart nginx.exe`r`necho Nginx Started`r`npause"
$BatStopContent = "@echo off`r`ncd /d C:\nginx`r`nnginx.exe -s quit`r`necho Nginx Stopped`r`npause"
$BatReloadContent = "@echo off`r`ncd /d C:\nginx`r`nnginx.exe -s reload`r`necho Nginx Reloaded`r`npause"

Set-Content -Path $StartBat -Value $BatStartContent
Set-Content -Path $StopBat -Value $BatStopContent
Set-Content -Path $ReloadBat -Value $BatReloadContent

# Salin juga ke Desktop agar lebih mudah
Set-Content -Path (Join-Path $DesktopPath "Start Dynamic Proxy.bat") -Value $BatStartContent
Set-Content -Path (Join-Path $DesktopPath "Stop Dynamic Proxy.bat") -Value $BatStopContent

# Buat Auto-start saat Windows Booting (di folder Startup)
$StartupPath = [Environment]::GetFolderPath("Startup")
$VbsStartupFile = Join-Path $StartupPath "StartDynamicProxy.vbs"
$VbsContent = "Set WshShell = CreateObject(`"WScript.Shell`")`r`nWshShell.CurrentDirectory = `"C:\nginx`"`r`nWshShell.Run `"nginx.exe`", 0, False"
Set-Content -Path $VbsStartupFile -Value $VbsContent

Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  Instalasi Berhasil!" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host "Domain: $Domain"
Write-Host "Port  : $Port"
Write-Host ""
Write-Host "Cara Penggunaan (Sama seperti Linux):"
Write-Host "http://192-168-1-100.${Domain}:${Port}"
Write-Host "http://192-168-1-100-8080.${Domain}:${Port}"
Write-Host "http://s-192-168-1-100.${Domain}:${Port}"
Write-Host ""
Write-Host "Shortcut tambahan telah dibuat di Desktop dan folder ini:"
Write-Host "- Start Dynamic Proxy.bat : Menjalankan Nginx"
Write-Host "- Stop Dynamic Proxy.bat  : Mematikan Nginx"
Write-Host "- reload-nginx.bat        : Memuat ulang konfigurasi"
Write-Host "- Auto-Start (Booting)    : AKTIF (via Startup folder)"
Write-Host "================================================="
Write-Host "Selesai!" -ForegroundColor Green

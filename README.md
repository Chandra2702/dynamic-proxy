# 🔀 Dynamic Proxy Domain

Nginx-based dynamic reverse proxy dengan wildcard subdomain. Akses perangkat di jaringan lokal melalui subdomain tanpa konfigurasi manual per-device.

## Cara Kerja

Ubah IP address menjadi subdomain dengan mengganti titik (`.`) menjadi dash (`-`):

| Subdomain | Proxy ke |
|---|---|
| `192-168-1-100.domain.com` | `http://192.168.1.100` *(Otomatis fallback ke `https://` jika ditolak)*|
| `192-168-1-100-8080.domain.com` | `http://192.168.1.100:8080` |
| `10-0-0-1-3000.domain.com` | `http://10.0.0.1:3000` |
| `s-192-168-1-100.domain.com` | `https://192.168.1.100` *(Memaksa HTTPS)* |
| `s-10-0-0-1-8443.domain.com` | `https://10.0.0.1:8443` |

## Prasyarat

- **Node.js** (untuk PM2 auto-start saat boot)
- **npm** (biasanya sudah termasuk bersama Node.js)

> **Note:** Jika Node.js tidak terinstal, Nginx tetap akan berjalan tapi **tidak akan auto-start** saat reboot.

## Instalasi Linux

### Quick Install (curl)

```bash
curl -fsSL https://raw.githubusercontent.com/Chandra2702/dynamic-proxy/main/install.sh | sudo bash
```

### Quick Install (wget)

```bash
wget -qO- https://raw.githubusercontent.com/Chandra2702/dynamic-proxy/main/install.sh | sudo bash
```

### Manual Install (Interaktif)

```bash
git clone https://github.com/Chandra2702/dynamic-proxy.git
cd dynamic-proxy
sudo bash install.sh
```

### Manual Install (Dengan Argumen)

```bash
sudo bash install.sh --domain proxy.example.com --port 8080
```

> **Tip (Non-Interaktif):** Untuk install otomatis tanpa dialog (misal untuk CI/CD atau Docker):
> `curl -fsSL https://.../install.sh | sudo bash -s -- --domain proxy.example.com --port 8080`

## Instalasi Windows

### Quick Install (PowerShell)

Buka **PowerShell sebagai Administrator**, lalu jalankan:

```powershell
irm https://raw.githubusercontent.com/Chandra2702/dynamic-proxy/main/install-win.bat -OutFile "$env:TEMP\install-win.bat"; Start-Process "$env:TEMP\install-win.bat" -Verb RunAs
```

### Manual Install (Interaktif)

1. Download atau clone repository ini
2. Double-click `install-win.bat` (otomatis minta hak Administrator)
3. Ikuti dialog interaktif untuk memasukkan domain dan port

### Manual Install (Dengan Argumen)

```cmd
install-win.bat --domain domain.example.com --port 8080
```

> **Note:** Installer akan otomatis mengunduh Nginx ke `C:\nginx`, menginstal PM2 global, dan mengatur auto-start saat boot.

## OS yang Didukung

### Linux

| Base | Distro |
|---|---|
| **Debian** | Debian, Ubuntu, Armbian, Linux Mint, Pop!_OS, Zorin, Raspbian |
| **RPM** | CentOS, RHEL, Fedora, Rocky Linux, AlmaLinux |
| **Arch** | Arch Linux, Manjaro, EndeavourOS, Garuda, Artix, CachyOS |

### Windows

| OS | Versi |
|---|---|
| **Windows** | Windows 10, Windows 11, Windows Server 2016+ |

## Manajemen

### Linux

```bash
# Update domain / port
sudo bash install.sh --update

# Uninstall
sudo bash install.sh --uninstall

# Bantuan
sudo bash install.sh --help
```

### Windows

```cmd
:: Update domain / port
install-win.bat --update

:: Uninstall
install-win.bat --uninstall

:: Bantuan
install-win.bat --help
```

### PM2 (Linux & Windows)

```bash
# Cek status Nginx
pm2 status

# Restart Nginx
pm2 restart dynamic-proxy

# Lihat log Nginx
pm2 logs dynamic-proxy

# Stop Nginx
pm2 stop dynamic-proxy

# Start Nginx
pm2 start dynamic-proxy
```

## DNS Setup

Tambahkan **wildcard DNS record** yang mengarah ke IP server:

```
*.proxy.example.com  →  IP_SERVER
```

Bisa menggunakan:
- **Cloudflare** — Tambah A record `*.proxy` ke IP server
- **Local DNS** — Konfigurasi di dnsmasq, Pi-hole, atau AdGuard Home

## Contoh Penggunaan

Misalkan domain: `domain.com`, port Nginx: `80`

```bash
# Akses router di 192.168.1.1
curl http://192-168-1-1.domain.com

# Akses aplikasi di 192.168.1.100 port 3000
curl http://192-168-1-100-3000.domain.com

# Akses kamera di 10.0.0.50 port 8080
curl http://10-0-0-50-8080.domain.com
```

## Struktur File

```
dynamic-proxy/
├── install.sh          # Installer untuk Linux
├── install-win.bat     # Installer untuk Windows
└── README.md
```

### File yang dibuat saat instalasi

| File | Platform | Keterangan |
|---|---|---|
| `/etc/nginx/sites-available/dynamic-proxy` | Linux | Konfigurasi Nginx |
| `/etc/dynamic-proxy.env` | Linux | Environment (domain, port) |
| `/etc/dynamic-proxy-ecosystem.config.js` | Linux | PM2 ecosystem config |
| `C:\nginx\conf\nginx.conf` | Windows | Konfigurasi Nginx |
| `C:\dynamic-proxy.env` | Windows | Environment (domain, port) |
| `C:\nginx\ecosystem.config.js` | Windows | PM2 ecosystem config |

## Lisensi

Mikrofast TEAM License 2026

# 🔀 Dynamic Proxy

Nginx-based dynamic reverse proxy dengan wildcard subdomain. Akses perangkat di jaringan lokal melalui subdomain tanpa konfigurasi manual per-device.

## Cara Kerja

Ubah IP address menjadi subdomain dengan mengganti titik (`.`) menjadi dash (`-`):

| Subdomain | Proxy ke |
|---|---|
| `192-168-1-100.proxy.example.com` | `http://192.168.1.100` |
| `192-168-1-100-8080.proxy.example.com` | `http://192.168.1.100:8080` |
| `10-0-0-1-3000.proxy.example.com` | `http://10.0.0.1:3000` |

## Instalasi

### Quick Install (curl)

```bash
curl -fsSL https://raw.githubusercontent.com/Chandra2702/dynamic-proxy/main/install.sh | sudo bash -s -- --domain proxy.example.com --port 80
```

### Quick Install (wget)

```bash
wget -qO- https://raw.githubusercontent.com/Chandra2702/dynamic-proxy/main/install.sh | sudo bash -s -- --domain proxy.example.com --port 80
```

### Manual Install (Interaktif)

```bash
git clone https://github.com/Chandra2702/dynamic-proxy.git
cd dynamic-proxy
sudo bash install.sh
```

### Manual Install (Dengan Argumen)

```bash
sudo bash install.sh --domain proxy.example.com --port 80
```

> **Note:** Sesuaikan `proxy.example.com` dengan domain milikmu.

> **Tip:** Install online tanpa `--domain` dan `--port` akan menampilkan dialog interaktif, tapi tidak dijamin bekerja di semua environment (Docker, CI/CD, SSH tanpa TTY). Untuk hasil terbaik, selalu gunakan `--domain` dan `--port` saat install via curl/wget.

## OS yang Didukung

| Base | Distro |
|---|---|
| **Debian** | Debian, Ubuntu, Armbian, Linux Mint, Pop!_OS, Zorin, Raspbian |
| **RPM** | CentOS, RHEL, Fedora, Rocky Linux, AlmaLinux |
| **Arch** | Arch Linux, Manjaro, EndeavourOS, Garuda, Artix, CachyOS |

## Manajemen

```bash
# Update domain / port
sudo bash install.sh --update

# Uninstall
sudo bash install.sh --uninstall

# Bantuan
sudo bash install.sh --help
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

Misalkan domain: `proxy.example.com`, port Nginx: `80`

```bash
# Akses router di 192.168.1.1
curl http://192-168-1-1.proxy.example.com

# Akses aplikasi di 192.168.1.100 port 3000
curl http://192-168-1-100-3000.proxy.example.com

# Akses kamera di 10.0.0.50 port 8080
curl http://10-0-0-50-8080.proxy.example.com
```

## Lisensi

MIT License

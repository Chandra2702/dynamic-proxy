# 🔀 Dynamic Proxy

Nginx-based dynamic reverse proxy dengan wildcard subdomain. Akses perangkat di jaringan lokal melalui subdomain tanpa konfigurasi manual per-device. Sangat cocok digunakan bersama Cloudflare, VPN, atau Tunneling.

## Fitur Utama Baru ✨
- **Auto-HTTPS Fallback**: Punya router (seperti TP-Link) yang menolak koneksi HTTP dan memaksa HTTPS? Nginx sekarang akan secara otomatis mendeteksi hal tersebut dan beralih mengakses via HTTPS di belakang layar! Aplikasi Anda tidak perlu diubah.
- **Intelligent Redirect Loop Breaker**: Mencegah *error* `ERR_TOO_MANY_REDIRECTS` saat mengakses perangkat yang sering me-redirect HTTP secara paksa.
- **Manual Secure Prefix (`s-`)**: Opsi untuk *memaksa* Nginx terhubung ke perangkat lokal menggunakan jalur aman HTTPS dengan hanya menambahkan awalan `s-`.
- **Proteksi Host/Blank Page**: Otomatis menangani *Chunked Encoding* dan *Host Header* agar halaman login router selalu tampil sempurna tanpa blank page.

## Cara Kerja

Ubah IP address lokal menjadi subdomain dengan mengganti titik (`.`) menjadi dash (`-`):

| Subdomain | Proxy ke (Backend) |
|---|---|
| `192-168-1-100.proxy.example.com` | `http://192.168.1.100` *(Otomatis fallback ke `https://` jika ditolak)* |
| `192-168-1-100-8080.proxy.example.com` | `http://192.168.1.100:8080` |
| `s-192-168-1-100.proxy.example.com` | `https://192.168.1.100` *(Memaksa HTTPS)* |
| `s-10-0-0-1-8443.proxy.example.com` | `https://10.0.0.1:8443` |

## Instalasi

### Quick Install (curl)

```bash
curl -fsSL https://raw.githubusercontent.com/Chandra2702/dynamic-proxy/main/install.sh | sudo bash
```

### Quick Update (curl)

Jika sudah pernah install dan ingin melakukan update dari GitHub:
```bash
curl -fsSL https://raw.githubusercontent.com/Chandra2702/dynamic-proxy/main/install.sh | sudo bash -s -- --update
```

### Quick Uninstall (curl)

Untuk menghapus Dynamic Proxy secara penuh dari server:
```bash
curl -fsSL https://raw.githubusercontent.com/Chandra2702/dynamic-proxy/main/install.sh | sudo bash -s -- --uninstall
```

### Quick Install (wget)

```bash
wget -qO- https://raw.githubusercontent.com/Chandra2702/dynamic-proxy/main/install.sh | sudo bash
```

### Quick Update (wget)

Jika sudah pernah install dan ingin melakukan update menggunakan wget:
```bash
wget -qO- https://raw.githubusercontent.com/Chandra2702/dynamic-proxy/main/install.sh | sudo bash -s -- --update
```

### Quick Uninstall (wget)

Untuk menghapus menggunakan wget:
```bash
wget -qO- https://raw.githubusercontent.com/Chandra2702/dynamic-proxy/main/install.sh | sudo bash -s -- --uninstall
```

### Manual Install (Dengan Argumen / Non-Interaktif)

Jika kamu ingin install otomatis tanpa dialog (misal untuk CI/CD atau Docker), tambahkan flag di akhir perintah seperti ini:  
```bash
curl -fsSL https://raw.githubusercontent.com/Chandra2702/dynamic-proxy/main/install.sh | sudo bash -s -- --domain proxy.example.com --port 8080
```

> **Note:** Sesuaikan `proxy.example.com` dengan domain milikmu.

## OS yang Didukung

| Base | Distro |
|---|---|
| **Debian** | Debian, Ubuntu, Armbian, Linux Mint, Pop!_OS, Zorin, Raspbian |
| **RPM** | CentOS, RHEL, Fedora, Rocky Linux, AlmaLinux |
| **Arch** | Arch Linux, Manjaro, EndeavourOS, Garuda, Artix, CachyOS |

## Manajemen

```bash
# Update konfigurasi dari file lokal
sudo bash install.sh --update

# Update LANGSUNG dari GitHub (jika ada update/rilis fitur baru di repository)
curl -fsSL https://raw.githubusercontent.com/Chandra2702/dynamic-proxy/main/install.sh | sudo bash -s -- --update

# Uninstall
sudo bash install.sh --uninstall

# Bantuan
sudo bash install.sh --help
```

## DNS Setup

Tambahkan **wildcard DNS record** yang mengarah ke IP server/proxy:

```
*.proxy.example.com  →  IP_SERVER
```

Bisa menggunakan:
- **Cloudflare** — Tambah A record `*.proxy` ke IP server
- **Local DNS** — Konfigurasi di dnsmasq, Pi-hole, atau AdGuard Home

## Contoh Penggunaan

Misalkan domain: `proxy.example.com`, port Nginx: `8081`

```bash
# 1. Akses router di 192.168.1.1 (Otomatis handle HTTP/HTTPS)
curl http://192-168-1-1.proxy.example.com:8081

# 2. Akses aplikasi di 192.168.1.100 port 3000
curl http://192-168-1-100-3000.proxy.example.com:8081

# 3. Paksa akses ke antarmuka HTTPS router
curl http://s-192-168-33-2.proxy.example.com:8081
```

## Lisensi

MIT License

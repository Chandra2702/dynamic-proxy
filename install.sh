#!/bin/bash

# ============================================================
#  Dynamic Proxy Installer for Armbian & Linux
#  Nginx-based dynamic reverse proxy with wildcard subdomain
# ============================================================

set -e

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Config paths ───────────────────────────────────────────
NGINX_CONF_DIR="/etc/nginx"
PROXY_CONF="${NGINX_CONF_DIR}/sites-available/dynamic-proxy"
PROXY_LINK="${NGINX_CONF_DIR}/sites-enabled/dynamic-proxy"
ENV_FILE="/etc/dynamic-proxy.env"

# ── Helper functions ───────────────────────────────────────
STEP_CURRENT=0
STEP_TOTAL=0

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║       Dynamic Proxy Installer v1.0              ║"
    echo "║       Armbian & Linux (Debian/Ubuntu)           ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

step() {
    STEP_CURRENT=$((STEP_CURRENT + 1))
    echo ""
    echo -e "${BOLD}${CYAN}── [${STEP_CURRENT}/${STEP_TOTAL}] $1 ──${NC}"
}

info()    { echo -e "${BLUE}[INFO]${NC}    $1"; }
success() { echo -e "${GREEN}[OK]${NC}      $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}    $1"; }
error()   { echo -e "${RED}[ERROR]${NC}   $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Script ini harus dijalankan sebagai root!"
        echo -e "  Gunakan: ${BOLD}sudo bash $0${NC}"
        exit 1
    fi
}

# ── Detect OS ──────────────────────────────────────────────
detect_os() {
    step "Mendeteksi Sistem Operasi"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_ID="$ID"
        OS_VERSION="$VERSION_ID"
    else
        error "Tidak dapat mendeteksi OS. /etc/os-release tidak ditemukan."
        exit 1
    fi

    # Check if it's a supported distro
    case "$OS_ID" in
        debian|ubuntu|armbian|linuxmint|pop|elementary|zorin|raspbian)
            info "OS terdeteksi: ${BOLD}${OS_NAME} ${OS_VERSION}${NC}"
            ;;
        centos|rhel|fedora|rocky|alma)
            info "OS terdeteksi: ${BOLD}${OS_NAME} ${OS_VERSION}${NC} (RPM-based)"
            ;;
        arch|manjaro|endeavouros|garuda|artix|cachyos)
            info "OS terdeteksi: ${BOLD}${OS_NAME} ${OS_VERSION}${NC} (Arch-based)"
            ;;
        *)
            warn "OS ${OS_NAME} belum diuji. Melanjutkan dengan asumsi Debian-based..."
            ;;
    esac
}

# ── Install Nginx ──────────────────────────────────────────
install_nginx() {
    step "Menginstal Nginx"

    if command -v nginx &>/dev/null; then
        success "Nginx sudah terinstal: $(nginx -v 2>&1)"
        return 0
    fi

    info "Menginstal Nginx..."

    case "$OS_ID" in
        debian|ubuntu|armbian|linuxmint|pop|elementary|zorin|raspbian)
            apt-get update -qq
            apt-get install -y -qq nginx
            ;;
        centos|rhel|rocky|alma)
            yum install -y epel-release
            yum install -y nginx
            ;;
        fedora)
            dnf install -y nginx
            ;;
        arch|manjaro|endeavouros|garuda|artix|cachyos)
            pacman -Sy --noconfirm nginx
            ;;
        *)
            apt-get update -qq
            apt-get install -y -qq nginx
            ;;
    esac

    if command -v nginx &>/dev/null; then
        success "Nginx berhasil diinstal!"
    else
        error "Gagal menginstal Nginx."
        exit 1
    fi
}

# ── Get user input ─────────────────────────────────────────
get_user_input() {
    echo ""
    echo -e "${BOLD}── Konfigurasi Dynamic Proxy ──${NC}"

    # Domain (skip jika sudah diset via argumen)
    if [[ -z "${DOMAIN:-}" ]]; then
        while true; do
            read -rp "$(echo -e "${CYAN}Masukkan domain (contoh: proxy.example.com): ${NC}")" DOMAIN < /dev/tty
            if [[ -z "$DOMAIN" ]]; then
                warn "Domain tidak boleh kosong!"
            elif [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
                warn "Format domain tidak valid!"
            else
                break
            fi
        done
    else
        info "Domain: ${GREEN}${DOMAIN}${NC}"
    fi

    # Port (skip jika sudah diset via argumen)
    if [[ -z "${NGINX_PORT:-}" ]]; then
        while true; do
            read -rp "$(echo -e "${CYAN}Masukkan port Nginx (default: 8080): ${NC}")" NGINX_PORT < /dev/tty
            NGINX_PORT=${NGINX_PORT:-8080}
            if [[ "$NGINX_PORT" =~ ^[0-9]+$ ]] && [ "$NGINX_PORT" -ge 1 ] && [ "$NGINX_PORT" -le 65535 ]; then
                break
            else
                warn "Port harus berupa angka antara 1-65535!"
            fi
        done
    else
        info "Port: ${GREEN}${NGINX_PORT}${NC}"
    fi

    # Validasi domain
    if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
        error "Format domain tidak valid: ${DOMAIN}"
        exit 1
    fi

    # Validasi port
    if ! [[ "$NGINX_PORT" =~ ^[0-9]+$ ]] || [ "$NGINX_PORT" -lt 1 ] || [ "$NGINX_PORT" -gt 65535 ]; then
        error "Port tidak valid: ${NGINX_PORT}"
        exit 1
    fi

    echo ""
    echo -e "${BOLD}── Ringkasan Konfigurasi ──${NC}"
    echo -e "  Domain : ${GREEN}${DOMAIN}${NC}"
    echo -e "  Port   : ${GREEN}${NGINX_PORT}${NC}"
    echo -e "  Pola   : ${YELLOW}<ip1>-<ip2>-<ip3>-<ip4>.${DOMAIN}${NC}"
    echo -e "  Pola   : ${YELLOW}<ip1>-<ip2>-<ip3>-<ip4>-<port>.${DOMAIN}${NC}"
    echo ""
}

# ── Generate Nginx config ─────────────────────────────────
generate_nginx_config() {
    step "Membuat Konfigurasi Nginx"
    info "Menulis file konfigurasi..."

    # Escape dots in domain for regex
    ESCAPED_DOMAIN=$(echo "$DOMAIN" | sed 's/\./\\./g')

    cat > "$PROXY_CONF" <<NGINX_EOF
# ============================================================
#  Dynamic Proxy - Auto-generated configuration
#  Domain : ${DOMAIN}
#  Port   : ${NGINX_PORT}
#  Generated: $(date '+%Y-%m-%d %H:%M:%S')
# ============================================================

# Map client scheme to backend scheme
map \$http_x_forwarded_proto \$backend_scheme {
    default \$scheme;
    "https" https;
    "http" http;
}

# BLOK 1: Menangkap IP + Port Custom (Contoh: 192-168-18-2-8080.${DOMAIN})
server {
    listen ${NGINX_PORT};
    server_name ~^(?<ip1>\d+)-(?<ip2>\d+)-(?<ip3>\d+)-(?<ip4>\d+)-(?<port>\d+)\.${ESCAPED_DOMAIN}\$;

    resolver 8.8.8.8 1.1.1.1 valid=300s;

    location / {
        proxy_pass \$backend_scheme://\$ip1.\$ip2.\$ip3.\$ip4:\$port;
        proxy_intercept_errors on;
        error_page 400 497 502 504 = @https_fallback;
        
        # Rewrite Redirect Headers
        proxy_redirect "~^(https?)://[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(:\d+)?(/?.*)$" "\$1://\$http_host\$3";
        proxy_redirect http://\$ip1.\$ip2.\$ip3.\$ip4:\$port/ http://\$http_host/;
        proxy_redirect https://\$ip1.\$ip2.\$ip3.\$ip4:\$port/ https://\$http_host/;

        # Rewrite Hardcoded IPs in HTML/JS
        proxy_set_header Accept-Encoding "";
        sub_filter "http://\$ip1.\$ip2.\$ip3.\$ip4:\$port" "http://\$http_host";
        sub_filter "https://\$ip1.\$ip2.\$ip3.\$ip4:\$port" "https://\$http_host";
        sub_filter "http://\$ip1.\$ip2.\$ip3.\$ip4" "http://\$http_host";
        sub_filter "https://\$ip1.\$ip2.\$ip3.\$ip4" "https://\$http_host";
        sub_filter_once off;
        sub_filter_types *;

        proxy_set_header Host \$ip1.\$ip2.\$ip3.\$ip4;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }

    location @https_fallback {
        proxy_pass https://\$ip1.\$ip2.\$ip3.\$ip4:\$port;
        
        # Rewrite Redirect Headers
        proxy_redirect "~^(https?)://[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(:\d+)?(/?.*)$" "\$1://\$http_host\$3";
        proxy_redirect http://\$ip1.\$ip2.\$ip3.\$ip4:\$port/ http://\$http_host/;
        proxy_redirect https://\$ip1.\$ip2.\$ip3.\$ip4:\$port/ https://\$http_host/;

        # Rewrite Hardcoded IPs in HTML/JS
        proxy_set_header Accept-Encoding "";
        sub_filter "http://\$ip1.\$ip2.\$ip3.\$ip4:\$port" "http://\$http_host";
        sub_filter "https://\$ip1.\$ip2.\$ip3.\$ip4:\$port" "https://\$http_host";
        sub_filter "http://\$ip1.\$ip2.\$ip3.\$ip4" "http://\$http_host";
        sub_filter "https://\$ip1.\$ip2.\$ip3.\$ip4" "https://\$http_host";
        sub_filter_once off;
        sub_filter_types *;

        proxy_ssl_verify off;
        proxy_set_header Host \$ip1.\$ip2.\$ip3.\$ip4;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
}

# BLOK 2: Menangkap IP Standar (Contoh: 192-168-18-2.${DOMAIN})
server {
    listen ${NGINX_PORT};
    server_name ~^(?<ip1>\d+)-(?<ip2>\d+)-(?<ip3>\d+)-(?<ip4>\d+)\.${ESCAPED_DOMAIN}\$;

    resolver 8.8.8.8 1.1.1.1 valid=300s;

    location / {
        proxy_pass \$backend_scheme://\$ip1.\$ip2.\$ip3.\$ip4;
        proxy_intercept_errors on;
        error_page 400 497 502 504 = @https_fallback;
        
        # Rewrite Redirect Headers
        proxy_redirect "~^(https?)://[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(:\d+)?(/?.*)$" "\$1://\$http_host\$3";
        proxy_redirect http://\$ip1.\$ip2.\$ip3.\$ip4/ http://\$http_host/;
        proxy_redirect https://\$ip1.\$ip2.\$ip3.\$ip4/ https://\$http_host/;

        # Rewrite Hardcoded IPs in HTML/JS
        proxy_set_header Accept-Encoding "";
        sub_filter "http://\$ip1.\$ip2.\$ip3.\$ip4" "http://\$http_host";
        sub_filter "https://\$ip1.\$ip2.\$ip3.\$ip4" "https://\$http_host";
        sub_filter_once off;
        sub_filter_types *;

        proxy_set_header Host \$ip1.\$ip2.\$ip3.\$ip4;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }

    location @https_fallback {
        proxy_pass https://\$ip1.\$ip2.\$ip3.\$ip4;
        
        # Rewrite Redirect Headers
        proxy_redirect "~^(https?)://[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(:\d+)?(/?.*)$" "\$1://\$http_host\$3";
        proxy_redirect http://\$ip1.\$ip2.\$ip3.\$ip4/ http://\$http_host/;
        proxy_redirect https://\$ip1.\$ip2.\$ip3.\$ip4/ https://\$http_host/;

        # Rewrite Hardcoded IPs in HTML/JS
        proxy_set_header Accept-Encoding "";
        sub_filter "http://\$ip1.\$ip2.\$ip3.\$ip4" "http://\$http_host";
        sub_filter "https://\$ip1.\$ip2.\$ip3.\$ip4" "https://\$http_host";
        sub_filter_once off;
        sub_filter_types *;

        proxy_ssl_verify off;
        proxy_set_header Host \$ip1.\$ip2.\$ip3.\$ip4;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
}

# BLOK 3: Menangkap IP + Port Custom HTTPS (Contoh: s-192-168-18-2-8443.${DOMAIN})
server {
    listen ${NGINX_PORT};
    server_name ~^s-(?<ip1>\d+)-(?<ip2>\d+)-(?<ip3>\d+)-(?<ip4>\d+)-(?<port>\d+)\.${ESCAPED_DOMAIN}\$;

    resolver 8.8.8.8 1.1.1.1 valid=300s;

    location / {
        proxy_pass https://\$ip1.\$ip2.\$ip3.\$ip4:\$port;
        
        # Rewrite Redirect Headers
        proxy_redirect "~^(https?)://[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(:\d+)?(/?.*)$" "\$1://\$http_host\$3";
        proxy_redirect http://\$ip1.\$ip2.\$ip3.\$ip4:\$port/ http://\$http_host/;
        proxy_redirect https://\$ip1.\$ip2.\$ip3.\$ip4:\$port/ https://\$http_host/;

        # Rewrite Hardcoded IPs in HTML/JS
        proxy_set_header Accept-Encoding "";
        sub_filter "http://\$ip1.\$ip2.\$ip3.\$ip4:\$port" "http://\$http_host";
        sub_filter "https://\$ip1.\$ip2.\$ip3.\$ip4:\$port" "https://\$http_host";
        sub_filter "http://\$ip1.\$ip2.\$ip3.\$ip4" "http://\$http_host";
        sub_filter "https://\$ip1.\$ip2.\$ip3.\$ip4" "https://\$http_host";
        sub_filter_once off;
        sub_filter_types *;

        proxy_ssl_verify off;
        proxy_set_header Host \$ip1.\$ip2.\$ip3.\$ip4;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
}

# BLOK 4: Menangkap IP Standar HTTPS (Contoh: s-192-168-18-2.${DOMAIN})
server {
    listen ${NGINX_PORT};
    server_name ~^s-(?<ip1>\d+)-(?<ip2>\d+)-(?<ip3>\d+)-(?<ip4>\d+)\.${ESCAPED_DOMAIN}\$;

    resolver 8.8.8.8 1.1.1.1 valid=300s;

    location / {
        proxy_pass https://\$ip1.\$ip2.\$ip3.\$ip4;
        
        # Rewrite Redirect Headers
        proxy_redirect "~^(https?)://[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(:\d+)?(/?.*)$" "\$1://\$http_host\$3";
        proxy_redirect http://\$ip1.\$ip2.\$ip3.\$ip4/ http://\$http_host/;
        proxy_redirect https://\$ip1.\$ip2.\$ip3.\$ip4/ https://\$http_host/;

        # Rewrite Hardcoded IPs in HTML/JS
        proxy_set_header Accept-Encoding "";
        sub_filter "http://\$ip1.\$ip2.\$ip3.\$ip4" "http://\$http_host";
        sub_filter "https://\$ip1.\$ip2.\$ip3.\$ip4" "https://\$http_host";
        sub_filter_once off;
        sub_filter_types *;

        proxy_ssl_verify off;
        proxy_set_header Host \$ip1.\$ip2.\$ip3.\$ip4;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
}
NGINX_EOF

    success "Konfigurasi Nginx dibuat: ${PROXY_CONF}"
}

# ── Save env for future reference / updates ────────────────
save_env() {
    step "Menyimpan Konfigurasi Environment"
    cat > "$ENV_FILE" <<EOF
# Dynamic Proxy Environment
DOMAIN=${DOMAIN}
NGINX_PORT=${NGINX_PORT}
INSTALLED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
EOF
    success "Konfigurasi disimpan: ${ENV_FILE}"
}

# ── Enable site ────────────────────────────────────────────
enable_site() {
    step "Mengaktifkan Site Nginx"
    info "Mengaktifkan konfigurasi..."

    # Remove default site to prevent conflict with other services
    if [ -f "${NGINX_CONF_DIR}/sites-enabled/default" ] || [ -L "${NGINX_CONF_DIR}/sites-enabled/default" ]; then
        warn "Menonaktifkan konfigurasi default Nginx untuk mencegah konflik port..."
        rm -f "${NGINX_CONF_DIR}/sites-enabled/default"
    fi

    # Create symlink
    ln -sf "$PROXY_CONF" "$PROXY_LINK"
    success "Site dynamic-proxy diaktifkan."
}

# ── Test & reload ──────────────────────────────────────────
test_and_reload() {
    step "Menguji & Memuat Ulang Nginx"
    info "Menguji konfigurasi Nginx..."

    if nginx -t 2>&1; then
        success "Konfigurasi Nginx valid!"
    else
        error "Konfigurasi Nginx tidak valid! Periksa file: ${PROXY_CONF}"
        exit 1
    fi

    info "Memuat ulang Nginx..."
    systemctl enable nginx 2>/dev/null || true
    systemctl restart nginx

    if systemctl is-active --quiet nginx; then
        success "Nginx berjalan dengan baik!"
    else
        error "Nginx gagal berjalan. Periksa log: journalctl -u nginx"
        exit 1
    fi
}

# ── Print usage info ───────────────────────────────────────
print_usage() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Instalasi Berhasil! ✓                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Cara Penggunaan:${NC}"
    echo ""
    echo -e "  ${CYAN}1. Akses IP tanpa port custom (HTTP):${NC}"
    echo -e "     http://${YELLOW}192-168-1-100${NC}.${DOMAIN}:${NGINX_PORT}"
    echo -e "     → Proxy ke http://192.168.1.100"
    echo ""
    echo -e "  ${CYAN}2. Akses IP dengan port custom (HTTP):${NC}"
    echo -e "     http://${YELLOW}192-168-1-100-8080${NC}.${DOMAIN}:${NGINX_PORT}"
    echo -e "     → Proxy ke http://192.168.1.100:8080"
    echo ""
    echo -e "  ${CYAN}3. Akses HTTPS Router (Tambahkan 's-'):${NC}"
    echo -e "     http://${YELLOW}s-192-168-1-100${NC}.${DOMAIN}:${NGINX_PORT}"
    echo -e "     → Proxy ke https://192.168.1.100"
    echo ""
    echo -e "${BOLD}DNS Setup:${NC}"
    echo -e "  Tambahkan wildcard DNS record:"
    echo -e "  ${YELLOW}*.${DOMAIN}${NC}  →  ${YELLOW}<IP server ini>${NC}"
    echo ""
    echo -e "${BOLD}Manajemen:${NC}"
    echo -e "  Konfigurasi : ${CYAN}${PROXY_CONF}${NC}"
    echo -e "  Environment : ${CYAN}${ENV_FILE}${NC}"
    echo -e "  Restart     : ${CYAN}sudo systemctl restart nginx${NC}"
    echo -e "  Status      : ${CYAN}sudo systemctl status nginx${NC}"
    echo -e "  Uninstall   : ${CYAN}sudo bash $0 --uninstall${NC}"
    echo ""
}

# ── Uninstall ──────────────────────────────────────────────
uninstall() {
    STEP_CURRENT=0
    STEP_TOTAL=4

    print_banner
    echo -e "${RED}${BOLD}── Uninstall Dynamic Proxy ──${NC}"
    echo ""

    read -rp "$(echo -e "${RED}Hapus konfigurasi Dynamic Proxy? (y/n): ${NC}")" CONFIRM < /dev/tty
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        info "Uninstall dibatalkan."
        exit 0
    fi

    step "Menghapus Konfigurasi Nginx"
    # Remove nginx config
    if [ -f "$PROXY_LINK" ]; then
        rm -f "$PROXY_LINK"
        success "Symlink dihapus: ${PROXY_LINK}"
    fi

    if [ -f "$PROXY_CONF" ]; then
        rm -f "$PROXY_CONF"
        success "Konfigurasi dihapus: ${PROXY_CONF}"
    fi

    step "Menghapus Environment File"
    # Remove env file
    if [ -f "$ENV_FILE" ]; then
        rm -f "$ENV_FILE"
        success "Environment file dihapus: ${ENV_FILE}"
    fi

    step "Memuat Ulang Nginx"
    # Reload nginx
    if command -v nginx &>/dev/null; then
        nginx -t 2>/dev/null && systemctl reload nginx
        success "Nginx dimuat ulang."
    fi

    step "Hapus Nginx (Opsional)"
    read -rp "$(echo -e "${YELLOW}Hapus juga Nginx? (y/n): ${NC}")" REMOVE_NGINX < /dev/tty
    if [[ "$REMOVE_NGINX" =~ ^[Yy]$ ]]; then
        case "$OS_ID" in
            debian|ubuntu|armbian|linuxmint|pop|elementary|zorin|raspbian)
                apt-get remove -y nginx
                apt-get autoremove -y
                ;;
            arch|manjaro|endeavouros|garuda|artix|cachyos)
                pacman -Rns --noconfirm nginx
                ;;
            centos|rhel|rocky|alma)
                yum remove -y nginx
                ;;
            fedora)
                dnf remove -y nginx
                ;;
        esac
        success "Nginx dihapus."
    fi

    echo ""
    success "Dynamic Proxy berhasil di-uninstall!"
    echo ""
}

# ── Update (change domain/port) ────────────────────────────
update_config() {
    STEP_CURRENT=0
    STEP_TOTAL=5

    print_banner
    echo -e "${YELLOW}${BOLD}── Update Konfigurasi ──${NC}"
    echo ""

    step "Membaca Konfigurasi Saat Ini"
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
        info "Konfigurasi saat ini:"
        echo -e "  Domain : ${GREEN}${DOMAIN}${NC}"
        echo -e "  Port   : ${GREEN}${NGINX_PORT}${NC}"
        echo ""
    fi

    # Reset for new input
    unset DOMAIN NGINX_PORT
    get_user_input
    generate_nginx_config
    save_env
    test_and_reload
    print_usage
}

# ── Main ───────────────────────────────────────────────────
main() {
    # Parse argumen
    ACTION="install"
    DOMAIN=""
    NGINX_PORT=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain|-d)
                DOMAIN="$2"
                shift 2
                ;;
            --port|-p)
                NGINX_PORT="$2"
                shift 2
                ;;
            --uninstall|-u)
                ACTION="uninstall"
                shift
                ;;
            --update|-c)
                ACTION="update"
                shift
                ;;
            --help|-h)
                ACTION="help"
                shift
                ;;
            *)
                error "Opsi tidak dikenal: $1"
                echo "Gunakan --help untuk bantuan."
                exit 1
                ;;
        esac
    done

    print_banner
    check_root

    case "$ACTION" in
        uninstall)
            detect_os
            uninstall
            exit 0
            ;;
        update)
            detect_os
            update_config
            exit 0
            ;;
        help)
            echo "Penggunaan: sudo bash $0 [OPSI]"
            echo ""
            echo "Opsi:"
            echo "  --domain, -d <domain>   Set domain (wajib untuk install online)"
            echo "  --port, -p <port>       Set port Nginx (default: 8080)"
            echo "  --update, -c            Update domain/port"
            echo "  --uninstall, -u         Hapus Dynamic Proxy"
            echo "  --help, -h              Tampilkan bantuan ini"
            echo ""
            echo "Contoh:"
            echo "  sudo bash $0 --domain proxy.example.com --port 8080"
            echo "  curl -fsSL https://...install.sh | sudo bash -s -- --domain proxy.example.com"
            echo ""
            exit 0
            ;;
    esac

    get_user_input

    STEP_TOTAL=6
    detect_os
    install_nginx
    generate_nginx_config
    save_env
    enable_site
    test_and_reload
    print_usage
}

main "$@"

#!/bin/bash

#==============================================================================
# Linux Saat Dilimi Ayarlama Scripti
# Versiyon: 1.0
# Açıklama: Sunucu saat dilimini güvenli ve etkileşimli şekilde ayarlar
# Gereksinimler: Root yetkisi, systemd tabanlı sistem
#==============================================================================

# Renk kodları ve formatlar
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Global değişkenler
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/timezone-setup"
LOG_FILE="${LOG_DIR}/timezone-setup.log"
BACKUP_DIR="/var/backups/timezone-setup"
TEMP_DIR="/tmp/timezone-setup-$$"
CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
ORIGINAL_TZ=""
NEW_TZ=""
CLEANUP_REQUIRED=0

#==============================================================================
# Yardımcı Fonksiyonlar
#==============================================================================

# Log fonksiyonu
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Konsola yazma
    case "$level" in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[UYARI]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[HATA]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[BAŞARILI]${NC} $message"
            ;;
        "DEBUG")
            echo -e "${CYAN}[DEBUG]${NC} $message"
            ;;
        *)
            echo -e "${WHITE}[LOG]${NC} $message"
            ;;
    esac
    
    # Log dosyasına yazma
    if [[ -w "$LOG_DIR" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

# İlerleme çubuğu
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local percent=$((current * 100 / total))
    local bar_length=50
    local filled_length=$((percent * bar_length / 100))
    
    printf "\r${BLUE}[%s] %3d%% ${CYAN}%s${NC}" \
        "$(printf "%*s" $filled_length | tr ' ' '█')$(printf "%*s" $((bar_length - filled_length)))" \
        $percent "$message"
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Hata yakalama ve temizlik
error_exit() {
    local error_message="$1"
    local exit_code="${2:-1}"
    
    log_message "ERROR" "$error_message"
    cleanup
    exit $exit_code
}

# Temizlik fonksiyonu
cleanup() {
    if [[ $CLEANUP_REQUIRED -eq 1 ]]; then
        log_message "INFO" "Temizlik işlemi başlatılıyor..."
        
        # Geçici dizin temizliği
        if [[ -d "$TEMP_DIR" ]]; then
            rm -rf "$TEMP_DIR" 2>/dev/null
            log_message "DEBUG" "Geçici dizin temizlendi: $TEMP_DIR"
        fi
        
        # Geçici dosyalar temizliği
        find /tmp -name "timezone-setup-*" -type f -mmin +60 -delete 2>/dev/null
        
        log_message "INFO" "Temizlik işlemi tamamlandı"
    fi
}

# Sinyal yakalama
trap 'error_exit "Script kesintiye uğradı" 130' INT TERM

#==============================================================================
# Sistem Kontrol Fonksiyonları
#==============================================================================

# Root yetki kontrolü
check_root_privileges() {
    log_message "INFO" "Root yetki kontrolü yapılıyor..."
    
    if [[ $EUID -ne 0 ]]; then
        log_message "ERROR" "Bu script root yetkisi ile çalıştırılmalıdır!"
        echo -e "${RED}Kullanım:${NC} sudo $0"
        exit 1
    fi
    
    log_message "SUCCESS" "Root yetki kontrolü başarılı"
}

# Sistem uyumluluğu kontrolü
check_system_compatibility() {
    log_message "INFO" "Sistem uyumluluğu kontrol ediliyor..."
    
    # Systemd varlığı kontrolü
    if ! command -v timedatectl >/dev/null 2>&1; then
        error_exit "Bu sistem systemd tabanlı değil. timedatectl komutu bulunamadı."
    fi
    
    # Temel komutlar kontrolü
    local required_commands=("date" "ln" "cp" "mv" "mkdir" "rm" "find")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error_exit "Gerekli komut bulunamadı: $cmd"
        fi
    done
    
    log_message "SUCCESS" "Sistem uyumluluğu kontrolü başarılı"
}

# Dizin yapısı kontrolü ve oluşturma
setup_directories() {
    log_message "INFO" "Dizin yapısı kontrol ediliyor ve oluşturuluyor..."
    
    # Log dizini
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" || error_exit "Log dizini oluşturulamadı: $LOG_DIR"
        chmod 755 "$LOG_DIR"
        log_message "DEBUG" "Log dizini oluşturuldu: $LOG_DIR"
    fi
    
    # Backup dizini
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR" || error_exit "Backup dizini oluşturulamadı: $BACKUP_DIR"
        chmod 755 "$BACKUP_DIR"
        log_message "DEBUG" "Backup dizini oluşturuldu: $BACKUP_DIR"
    fi
    
    # Geçici dizin
    mkdir -p "$TEMP_DIR" || error_exit "Geçici dizin oluşturulamadı: $TEMP_DIR"
    chmod 700 "$TEMP_DIR"
    CLEANUP_REQUIRED=1
    
    log_message "SUCCESS" "Dizin yapısı hazırlandı"
}

#==============================================================================
# Saat Dilimi Fonksiyonları
#==============================================================================

# Mevcut saat dilimi bilgisini al
get_current_timezone() {
    log_message "INFO" "Mevcut saat dilimi bilgisi alınıyor..."
    
    ORIGINAL_TZ=$(timedatectl show --property=Timezone --value)
    if [[ -z "$ORIGINAL_TZ" ]]; then
        error_exit "Mevcut saat dilimi bilgisi alınamadı"
    fi
    
    log_message "DEBUG" "Mevcut saat dilimi: $ORIGINAL_TZ"
}

# Yedek alma
create_backup() {
    log_message "INFO" "Sistem ayarlarının yedeği alınıyor..."
    
    local backup_timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${BACKUP_DIR}/timezone_backup_${backup_timestamp}.tar.gz"
    
    # Yedeklenecek dosyalar ve dizinler
    local backup_items=(
        "/etc/localtime"
        "/etc/timezone"
        "/usr/share/zoneinfo"
    )
    
    # Var olan dosyaları yedekle
    local existing_items=()
    for item in "${backup_items[@]}"; do
        if [[ -e "$item" ]]; then
            existing_items+=("$item")
        fi
    done
    
    if [[ ${#existing_items[@]} -gt 0 ]]; then
        tar -czf "$backup_file" "${existing_items[@]}" 2>/dev/null || \
            log_message "WARN" "Yedek alma işleminde bazı sorunlar oluştu"
        
        if [[ -f "$backup_file" ]]; then
            log_message "SUCCESS" "Yedek dosyası oluşturuldu: $backup_file"
        else
            log_message "WARN" "Yedek dosyası oluşturulamadı"
        fi
    else
        log_message "WARN" "Yedeklenecek dosya bulunamadı"
    fi
}

# Kullanılabilir saat dilimlerini listele
list_available_timezones() {
    log_message "INFO" "Kullanılabilir saat dilimleri listeleniyor..."
    
    echo -e "\n${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║                    SAAT DİLİMLERİ LİSTESİ                    ║${NC}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    
    # Popüler saat dilimleri
    echo -e "${BOLD}${GREEN}Popüler Saat Dilimleri:${NC}"
    echo -e "${CYAN}1.${NC}  Europe/Istanbul     (Türkiye - GMT+3)"
    echo -e "${CYAN}2.${NC}  UTC                 (Koordineli Evrensel Zaman)"
    echo -e "${CYAN}3.${NC}  Europe/London       (İngiltere - GMT+0/+1)"
    echo -e "${CYAN}4.${NC}  Europe/Berlin       (Almanya - GMT+1/+2)"
    echo -e "${CYAN}5.${NC}  America/New_York    (Doğu ABD - GMT-5/-4)"
    echo -e "${CYAN}6.${NC}  America/Los_Angeles (Batı ABD - GMT-8/-7)"
    echo -e "${CYAN}7.${NC}  Asia/Tokyo          (Japonya - GMT+9)"
    echo -e "${CYAN}8.${NC}  Australia/Sydney    (Avustralya - GMT+10/+11)"
    echo -e "${CYAN}9.${NC}  Europe/Moscow       (Rusya - GMT+3)"
    echo -e "${CYAN}10.${NC} Asia/Dubai          (BAE - GMT+4)"
    echo -e "${CYAN}11.${NC} Manual Entry        (Manuel giriş)"
    echo -e "${CYAN}12.${NC} List All            (Tüm saat dilimlerini listele)"
    
    echo ""
}

# Tüm saat dilimlerini listele
show_all_timezones() {
    log_message "INFO" "Tüm saat dilimleri listeleniyor..."
    
    echo -e "\n${BOLD}${YELLOW}Tüm Kullanılabilir Saat Dilimleri:${NC}\n"
    
    timedatectl list-timezones | while IFS= read -r tz; do
        echo -e "${CYAN}• ${NC}$tz"
    done | column -c 80
    
    echo ""
}

# Saat dilimi seçimi
select_timezone() {
    local selected_tz=""
    
    while true; do
        list_available_timezones
        
        echo -e "${BOLD}${WHITE}Seçiminizi yapın (1-12):${NC} "
        read -r choice
        
        case "$choice" in
            1) selected_tz="Europe/Istanbul" ;;
            2) selected_tz="UTC" ;;
            3) selected_tz="Europe/London" ;;
            4) selected_tz="Europe/Berlin" ;;
            5) selected_tz="America/New_York" ;;
            6) selected_tz="America/Los_Angeles" ;;
            7) selected_tz="Asia/Tokyo" ;;
            8) selected_tz="Australia/Sydney" ;;
            9) selected_tz="Europe/Moscow" ;;
            10) selected_tz="Asia/Dubai" ;;
            11)
                echo -e "${BOLD}${WHITE}Saat dilimini manuel olarak girin:${NC} "
                read -r selected_tz
                ;;
            12)
                show_all_timezones
                echo -e "${BOLD}${WHITE}Saat dilimini girin:${NC} "
                read -r selected_tz
                ;;
            *)
                log_message "WARN" "Geçersiz seçim: $choice"
                continue
                ;;
        esac
        
        # Saat dilimi doğrulama
        if validate_timezone "$selected_tz"; then
            NEW_TZ="$selected_tz"
            break
        else
            log_message "ERROR" "Geçersiz saat dilimi: $selected_tz"
            echo -e "${RED}Lütfen geçerli bir saat dilimi girin.${NC}\n"
        fi
    done
}

# Saat dilimi doğrulama
validate_timezone() {
    local timezone="$1"
    
    if [[ -z "$timezone" ]]; then
        return 1
    fi
    
    # timedatectl ile kontrol
    if timedatectl list-timezones | grep -q "^${timezone}$"; then
        return 0
    else
        return 1
    fi
}

# Saat dilimi ayarlama
set_timezone() {
    log_message "INFO" "Saat dilimi ayarlama işlemi başlatılıyor..."
    
    echo -e "\n${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║                    SAAT DİLİMİ AYARLANIYOR                   ║${NC}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    
    # İşlem adımları
    local steps=(
        "Mevcut ayarlar kontrol ediliyor"
        "Saat dilimi değiştiriliyor"
        "Sistem saati güncelleniyor"
        "Doğrulama yapılıyor"
        "İşlem tamamlanıyor"
    )
    
    local step_count=${#steps[@]}
    
    for i in "${!steps[@]}"; do
        local current_step=$((i + 1))
        show_progress $current_step $step_count "${steps[$i]}"
        
        case $current_step in
            1)
                sleep 1
                log_message "DEBUG" "Mevcut saat dilimi: $ORIGINAL_TZ"
                log_message "DEBUG" "Yeni saat dilimi: $NEW_TZ"
                ;;
            2)
                if ! timedatectl set-timezone "$NEW_TZ" 2>/dev/null; then
                    error_exit "Saat dilimi ayarlanamadı: $NEW_TZ"
                fi
                sleep 1
                ;;
            3)
                # NTP senkronizasyonu varsa güncelle
                if timedatectl show | grep -q "NTP=yes"; then
                    systemctl restart systemd-timesyncd 2>/dev/null || true
                fi
                sleep 1
                ;;
            4)
                if ! verify_timezone_change; then
                    error_exit "Saat dilimi değişikliği doğrulanamadı"
                fi
                sleep 1
                ;;
            5)
                sleep 1
                ;;
        esac
    done
    
    echo ""
    log_message "SUCCESS" "Saat dilimi başarıyla ayarlandı: $NEW_TZ"
}

# Saat dilimi değişikliğini doğrula
verify_timezone_change() {
    log_message "INFO" "Saat dilimi değişikliği doğrulanıyor..."
    
    local current_tz=$(timedatectl show --property=Timezone --value)
    
    if [[ "$current_tz" == "$NEW_TZ" ]]; then
        log_message "SUCCESS" "Saat dilimi doğrulaması başarılı"
        return 0
    else
        log_message "ERROR" "Saat dilimi doğrulaması başarısız. Beklenen: $NEW_TZ, Mevcut: $current_tz"
        return 1
    fi
}

# Sistem durumu gösterimi
show_system_status() {
    echo -e "\n${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║                    SİSTEM DURUMU                             ║${NC}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    
    # Saat dilimi bilgileri
    echo -e "${BOLD}${CYAN}Saat Dilimi Bilgileri:${NC}"
    echo -e "${WHITE}├─ Önceki Saat Dilimi:${NC} $ORIGINAL_TZ"
    echo -e "${WHITE}├─ Yeni Saat Dilimi:${NC}   $NEW_TZ"
    echo -e "${WHITE}└─ Değişiklik Zamanı:${NC}  $(date '+%Y-%m-%d %H:%M:%S')"
    
    echo -e "\n${BOLD}${CYAN}Sistem Saati:${NC}"
    timedatectl status | while IFS= read -r line; do
        echo -e "${WHITE}  $line${NC}"
    done
    
    echo -e "\n${BOLD}${CYAN}Log Dosyası:${NC} $LOG_FILE"
    echo -e "${BOLD}${CYAN}Backup Dizini:${NC} $BACKUP_DIR"
    
    echo ""
}

#==============================================================================
# Ana Menü Fonksiyonları
#==============================================================================

# Başlangıç banner'ı
show_banner() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║                    LİNUX SAAT DİLİMİ AYARLAMA ARACI                   ║"
    echo "║                                                                        ║"
    echo "║  Bu araç sisteminizin saat dilimini güvenli şekilde değiştirir.       ║"
    echo "║  İşlem öncesi otomatik yedekleme yapılır ve detaylı log tutulur.      ║"
    echo "║                                                                        ║"
    echo "║  Versiyon: 1.0                                                         ║"
    echo "║  Geliştirici: System Administrator                                     ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
}

# Onay alma
get_confirmation() {
    local message="$1"
    local response
    
    while true; do
        echo -e "${BOLD}${YELLOW}$message (e/h):${NC} "
        read -r response
        
        case "${response,,}" in
            e|evet|yes|y)
                return 0
                ;;
            h|hayır|no|n)
                return 1
                ;;
            *)
                echo -e "${RED}Lütfen 'e' (evet) veya 'h' (hayır) girin.${NC}"
                ;;
        esac
    done
}

# Son onay
final_confirmation() {
    echo -e "\n${BOLD}${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${YELLOW}║                        SON ONAY                              ║${NC}"
    echo -e "${BOLD}${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${BOLD}${WHITE}İşlem Özeti:${NC}"
    echo -e "${WHITE}├─ Mevcut Saat Dilimi:${NC} $ORIGINAL_TZ"
    echo -e "${WHITE}├─ Yeni Saat Dilimi:${NC}   $NEW_TZ"
    echo -e "${WHITE}├─ Yedekleme:${NC}          Otomatik yapılacak"
    echo -e "${WHITE}└─ Log Tutma:${NC}          Aktif"
    
    echo ""
    if get_confirmation "Bu değişiklikleri yapmak istediğinizden emin misiniz?"; then
        return 0
    else
        log_message "INFO" "İşlem kullanıcı tarafından iptal edildi"
        echo -e "${YELLOW}İşlem iptal edildi.${NC}"
        exit 0
    fi
}

#==============================================================================
# Ana Program
#==============================================================================

main() {
    # Başlangıç
    show_banner
    log_message "INFO" "Script başlatıldı: $SCRIPT_NAME"
    log_message "DEBUG" "Script dizini: $SCRIPT_DIR"
    log_message "DEBUG" "PID: $$"
    
    # Sistem kontrolleri
    check_root_privileges
    check_system_compatibility
    setup_directories
    
    # Mevcut durumu al
    get_current_timezone
    
    # Bilgilendirme
    echo -e "${BOLD}${CYAN}Mevcut sistem saat dilimi:${NC} $ORIGINAL_TZ"
    echo -e "${BOLD}${CYAN}Sistem zamanı:${NC} $(date)"
    echo ""
    
    if get_confirmation "Saat dilimini değiştirmek istiyor musunuz?"; then
        # Yedek al
        create_backup
        
        # Saat dilimi seçimi
        select_timezone
        
        # Son onay
        final_confirmation
        
        # Saat dilimini ayarla
        set_timezone
        
        # Durumu göster
        show_system_status
        
        log_message "SUCCESS" "İşlem başarıyla tamamlandı"
    else
        log_message "INFO" "İşlem kullanıcı tarafından iptal edildi"
        echo -e "${YELLOW}İşlem iptal edildi.${NC}"
    fi
    
    # Temizlik
    cleanup
    
    echo -e "${BOLD}${GREEN}İşlem tamamlandı!${NC}"
    log_message "INFO" "Script sonlandırıldı"
}

# Script'i çalıştır
main "$@"

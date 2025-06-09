#!/bin/bash

#############################################################################
# Debian 10/11/12 Sunucu Güncelleme Scripti
# Bu script Debian sunucularını güvenli bir şekilde güncelleştirir
# Yazar: Sistem Yöneticisi
# Sürüm: 1.0
# Tarih: $(date +%Y-%m-%d)
#############################################################################

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Global değişkenler
SCRIPT_NAME="Debian Güncelleme Scripti"
LOG_DIR="/var/log/debian-update"
LOG_FILE="$LOG_DIR/update-$(date +%Y%m%d-%H%M%S).log"
BACKUP_DIR="/tmp/debian-update-backup"
SOURCES_LIST="/etc/apt/sources.list"
SOURCES_BACKUP="$BACKUP_DIR/sources.list.backup"
RESOLV_BACKUP="$BACKUP_DIR/resolv.conf.backup"
ORIGINAL_DNS=""
DEBIAN_VERSION=""
START_TIME=$(date +%s)

#############################################################################
# Fonksiyonlar
#############################################################################

# Log fonksiyonu
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
    case $level in
        "ERROR")
            echo -e "${RED}[HATA]${NC} $message" >&2
            ;;
        "WARNING")
            echo -e "${YELLOW}[UYARI]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[BAŞARILI]${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}[BİLGİ]${NC} $message"
            ;;
        "PROGRESS")
            echo -e "${CYAN}[İLERLEME]${NC} $message"
            ;;
    esac
}

# İlerleme çubuğu
show_progress() {
    local current=$1
    local total=$2
    local description=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${CYAN}[İLERLEME]${NC} $description: ["
    printf "%*s" $filled | tr ' ' '='
    printf "%*s" $empty | tr ' ' '-'
    printf "] %d%%" $percent
    
    if [ $current -eq $total ]; then
        echo ""
    fi
}

# Banner gösterimi
show_banner() {
    clear
    echo -e "${PURPLE}"
    echo "############################################################################"
    echo "#                                                                          #"
    echo "#                    DEBIAN SUNUCU GÜNCELLEME SCRİPTİ                     #"
    echo "#                                                                          #"
    echo "#              Debian 10 (Buster) / 11 (Bullseye) / 12 (Bookworm)       #"
    echo "#                            Güvenli Güncelleme                           #"
    echo "#                                                                          #"
    echo "############################################################################"
    echo -e "${NC}"
    echo
}

# Root kontrol fonksiyonu
check_root() {
    log_message "INFO" "Root yetki kontrolü yapılıyor..."
    
    if [[ $EUID -ne 0 ]]; then
        log_message "ERROR" "Bu script root yetkileri ile çalıştırılmalıdır!"
        echo -e "${RED}Lütfen scripti 'sudo $0' komutu ile çalıştırın.${NC}"
        exit 1
    fi
    
    log_message "SUCCESS" "Root yetki kontrolü başarılı"
}

# Sistem bilgilerini al
get_system_info() {
    log_message "INFO" "Sistem bilgileri toplanıyor..."
    
    # Debian sürümünü tespit et
    if [ -f /etc/debian_version ]; then
        local version_info=$(cat /etc/debian_version)
        if grep -q "10\." /etc/debian_version || grep -qi "buster" /etc/os-release; then
            DEBIAN_VERSION="10"
        elif grep -q "11\." /etc/debian_version || grep -qi "bullseye" /etc/os-release; then
            DEBIAN_VERSION="11"
        elif grep -q "12\." /etc/debian_version || grep -qi "bookworm" /etc/os-release; then
            DEBIAN_VERSION="12"
        else
            log_message "ERROR" "Desteklenmeyen Debian sürümü: $version_info"
            exit 1
        fi
        
        log_message "SUCCESS" "Debian $DEBIAN_VERSION tespit edildi"
        log_message "INFO" "Sistem: $(uname -a)"
        log_message "INFO" "Uptime: $(uptime)"
        log_message "INFO" "Disk kullanımı: $(df -h / | tail -1)"
        log_message "INFO" "Bellek kullanımı: $(free -h | grep ^Mem)"
    else
        log_message "ERROR" "Bu sistem Debian değil!"
        exit 1
    fi
}

# Backup dizinini oluştur
create_backup_dir() {
    log_message "INFO" "Backup dizini oluşturuluyor..."
    
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        if [ $? -eq 0 ]; then
            log_message "SUCCESS" "Backup dizini oluşturuldu: $BACKUP_DIR"
        else
            log_message "ERROR" "Backup dizini oluşturulamadı!"
            exit 1
        fi
    else
        log_message "INFO" "Backup dizini zaten mevcut"
    fi
}

# Log dizinini oluştur
create_log_dir() {
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
        log_message "SUCCESS" "Log dizini oluşturuldu: $LOG_DIR"
    fi
}

# Mevcut sources.list'i yedekle
backup_sources_list() {
    log_message "INFO" "Mevcut sources.list yedekleniyor..."
    
    if [ -f "$SOURCES_LIST" ]; then
        cp "$SOURCES_LIST" "$SOURCES_BACKUP"
        if [ $? -eq 0 ]; then
            log_message "SUCCESS" "sources.list yedeklendi"
            log_message "INFO" "Yedek konumu: $SOURCES_BACKUP"
        else
            log_message "ERROR" "sources.list yedeklenemedi!"
            exit 1
        fi
    else
        log_message "WARNING" "sources.list dosyası bulunamadı!"
    fi
}

# DNS ayarlarını yedekle ve Cloudflare DNS'e geç
setup_dns() {
    log_message "INFO" "DNS ayarları yapılandırılıyor..."
    
    # Mevcut DNS ayarlarını yedekle
    if [ -f /etc/resolv.conf ]; then
        cp /etc/resolv.conf "$RESOLV_BACKUP"
        ORIGINAL_DNS=$(grep "nameserver" /etc/resolv.conf | head -1 | awk '{print $2}')
        log_message "INFO" "Mevcut DNS yedeklendi. Orijinal DNS: $ORIGINAL_DNS"
    fi
    
    # Cloudflare DNS'e geç
    echo "# Geçici Cloudflare DNS ayarı" > /etc/resolv.conf
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    echo "nameserver 1.0.0.1" >> /etc/resolv.conf
    
    if [ $? -eq 0 ]; then
        log_message "SUCCESS" "Cloudflare DNS (1.1.1.1) ayarlandı"
        
        # DNS testini yap
        if ping -c 1 1.1.1.1 >/dev/null 2>&1; then
            log_message "SUCCESS" "DNS bağlantı testi başarılı"
        else
            log_message "WARNING" "DNS bağlantı testi başarısız"
        fi
    else
        log_message "ERROR" "DNS ayarları yapılandırılamadı!"
        exit 1
    fi
}

# Yeni sources.list oluştur
create_sources_list() {
    log_message "INFO" "Debian $DEBIAN_VERSION için yeni sources.list oluşturuluyor..."
    
    case $DEBIAN_VERSION in
        "10")
            cat > "$SOURCES_LIST" << 'EOF'
# Debian 10 (Buster) - Ana depolar
deb http://deb.debian.org/debian buster main contrib non-free
deb-src http://deb.debian.org/debian buster main contrib non-free

# Güncelleme depoları
deb http://deb.debian.org/debian buster-updates main contrib non-free
deb-src http://deb.debian.org/debian buster-updates main contrib non-free

# Güvenlik güncellemeleri
deb http://security.debian.org/debian-security/ buster/updates main contrib non-free
deb-src http://security.debian.org/debian-security/ buster/updates main contrib non-free
EOF
            ;;
        "11")
            cat > "$SOURCES_LIST" << 'EOF'
# Debian 11 (Bullseye) - Ana depolar
deb http://deb.debian.org/debian bullseye main contrib non-free
deb-src http://deb.debian.org/debian bullseye main contrib non-free

# Güncelleme depoları
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb-src http://deb.debian.org/debian bullseye-updates main contrib non-free

# Backports depoları
deb http://deb.debian.org/debian bullseye-backports main contrib non-free
deb-src http://deb.debian.org/debian bullseye-backports main contrib non-free

# Güvenlik güncellemeleri
deb http://security.debian.org/debian-security/ bullseye-security main contrib non-free
deb-src http://security.debian.org/debian-security/ bullseye-security main contrib non-free
EOF
            ;;
        "12")
            cat > "$SOURCES_LIST" << 'EOF'
# Debian 12 (Bookworm) - Ana depolar
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware

# Güncelleme depoları
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware

# Backports depoları
deb http://deb.debian.org/debian/ bookworm-backports main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm-backports main contrib non-free non-free-firmware

# Güvenlik güncellemeleri
deb http://security.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware
EOF
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        log_message "SUCCESS" "Yeni sources.list oluşturuldu"
        log_message "INFO" "sources.list içeriği:"
        cat "$SOURCES_LIST" | while read line; do
            if [[ ! "$line" =~ ^#.* ]] && [[ -n "$line" ]]; then
                log_message "INFO" "  $line"
            fi
        done
    else
        log_message "ERROR" "sources.list oluşturulamadı!"
        exit 1
    fi
}

# Paket listesini güncelle
update_package_list() {
    log_message "PROGRESS" "Paket listesi güncelleniyor..."
    
    show_progress 1 4 "APT cache temizleniyor"
    apt-get clean >> "$LOG_FILE" 2>&1
    
    show_progress 2 4 "Paket listesi güncelleniyor"
    if apt-get update >> "$LOG_FILE" 2>&1; then
        show_progress 3 4 "Paket listesi başarıyla güncellendi"
        log_message "SUCCESS" "Paket listesi güncellendi"
    else
        show_progress 3 4 "Paket listesi güncellenemedi"
        log_message "ERROR" "Paket listesi güncellenemedi!"
        restore_sources_list
        exit 1
    fi
    
    show_progress 4 4 "İşlem tamamlandı"
    echo
}

# Sistemi güncelle
upgrade_system() {
    log_message "PROGRESS" "Sistem güncellemeleri yapılıyor..."
    
    # Güncellenebilir paket sayısını al
    local upgradable=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    log_message "INFO" "Güncellenecek paket sayısı: $upgradable"
    
    if [ $upgradable -eq 0 ]; then
        log_message "INFO" "Güncelleme gerektiren paket bulunamadı"
        return 0
    fi
    
    # Güncelleme işlemini başlat
    echo -e "${YELLOW}Sistem güncellemeleri yapılıyor, lütfen bekleyin...${NC}"
    
    if apt-get upgrade -y >> "$LOG_FILE" 2>&1; then
        log_message "SUCCESS" "Sistem güncellemeleri tamamlandı"
    else
        log_message "ERROR" "Sistem güncellemeleri başarısız!"
        return 1
    fi
    
    # Dist-upgrade işlemi
    log_message "INFO" "Dağıtım güncellemeleri kontrol ediliyor..."
    if apt-get dist-upgrade -y >> "$LOG_FILE" 2>&1; then
        log_message "SUCCESS" "Dağıtım güncellemeleri tamamlandı"
    else
        log_message "WARNING" "Dağıtım güncellemeleri başarısız"
    fi
}

# Gereksiz paketleri temizle
cleanup_packages() {
    log_message "PROGRESS" "Sistem temizliği yapılıyor..."
    
    show_progress 1 5 "Otomatik yüklenen gereksiz paketler kaldırılıyor"
    apt-get autoremove -y >> "$LOG_FILE" 2>&1
    
    show_progress 2 5 "Paket cache temizleniyor"
    apt-get autoclean >> "$LOG_FILE" 2>&1
    
    show_progress 3 5 "Eski kernel sürümleri kontrol ediliyor"
    # Eski kernel'ları temizle (güvenlik için en az 2 kernel bırak)
    local old_kernels=$(dpkg -l | grep '^ii' | grep 'linux-image-[0-9]' | wc -l)
    if [ $old_kernels -gt 2 ]; then
        apt-get autoremove --purge -y >> "$LOG_FILE" 2>&1
        log_message "INFO" "Eski kernel sürümleri temizlendi"
    fi
    
    show_progress 4 5 "Log dosyaları kontrol ediliyor"
    # Eski log dosyalarını temizle (30 günden eski)
    find /var/log -type f -name "*.log" -mtime +30 -delete 2>/dev/null
    
    show_progress 5 5 "Temizlik işlemi tamamlandı"
    echo
    
    log_message "SUCCESS" "Sistem temizliği tamamlandı"
}

# sources.list'i geri yükle
restore_sources_list() {
    log_message "INFO" "Orijinal sources.list geri yükleniyor..."
    
    if [ -f "$SOURCES_BACKUP" ]; then
        cp "$SOURCES_BACKUP" "$SOURCES_LIST"
        if [ $? -eq 0 ]; then
            log_message "SUCCESS" "Orijinal sources.list geri yüklendi"
        else
            log_message "ERROR" "sources.list geri yüklenemedi!"
        fi
    else
        log_message "WARNING" "sources.list yedeği bulunamadı!"
    fi
}

# DNS ayarlarını geri yükle
restore_dns() {
    log_message "INFO" "Orijinal DNS ayarları geri yükleniyor..."
    
    if [ -f "$RESOLV_BACKUP" ]; then
        cp "$RESOLV_BACKUP" /etc/resolv.conf
        if [ $? -eq 0 ]; then
            log_message "SUCCESS" "Orijinal DNS ayarları geri yüklendi"
        else
            log_message "ERROR" "DNS ayarları geri yüklenemedi!"
        fi
    else
        log_message "WARNING" "DNS yedeği bulunamadı!"
        
        # Manuel DNS geri yükleme
        if [ -n "$ORIGINAL_DNS" ]; then
            echo "nameserver $ORIGINAL_DNS" > /etc/resolv.conf
            log_message "INFO" "DNS manuel olarak geri yüklendi: $ORIGINAL_DNS"
        fi
    fi
}

# Temizlik işlemleri
final_cleanup() {
    log_message "INFO" "Final temizlik işlemleri yapılıyor..."
    
    # Geçici dosyaları temizle
    if [ -d "$BACKUP_DIR" ]; then
        # Yedek dosyalarını log dizinine taşı
        if [ -f "$SOURCES_BACKUP" ]; then
            cp "$SOURCES_BACKUP" "$LOG_DIR/"
        fi
        if [ -f "$RESOLV_BACKUP" ]; then
            cp "$RESOLV_BACKUP" "$LOG_DIR/"
        fi
        
        rm -rf "$BACKUP_DIR"
        log_message "SUCCESS" "Geçici dosyalar temizlendi"
    fi
    
    # Sistem durumunu kontrol et
    log_message "INFO" "Final sistem kontrolü yapılıyor..."
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    
    log_message "INFO" "Disk kullanımı: %$disk_usage"
    log_message "INFO" "Bellek kullanımı: %$memory_usage"
    
    # Sistem servislerinin durumunu kontrol et
    if systemctl is-active --quiet ssh; then
        log_message "SUCCESS" "SSH servisi aktif"
    else
        log_message "WARNING" "SSH servisi kontrol edilmeli"
    fi
}

# Sistem durumunu rapor et
show_final_report() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    echo
    echo -e "${GREEN}############################################################################${NC}"
    echo -e "${GREEN}#                        GÜNCELLEME RAPORU                                #${NC}"
    echo -e "${GREEN}############################################################################${NC}"
    echo
    echo -e "${WHITE}Sistem Bilgileri:${NC}"
    echo -e "  • Debian Sürümü: $DEBIAN_VERSION"
    echo -e "  • Güncelleme Tarihi: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "  • İşlem Süresi: ${hours}s ${minutes}d ${seconds}s"
    echo
    echo -e "${WHITE}İşlem Detayları:${NC}"
    echo -e "  • sources.list güncellendi ve geri yüklendi"
    echo -e "  • DNS geçici olarak Cloudflare kullanıldı"
    echo -e "  • Tüm güncellemeler uygulandı"
    echo -e "  • Sistem temizliği yapıldı"
    echo
    echo -e "${WHITE}Log Dosyası:${NC} $LOG_FILE"
    echo
    
    # Yeniden başlatma gerekip gerekmediğini kontrol et
    if [ -f /var/run/reboot-required ]; then
        echo -e "${YELLOW}⚠️  DİKKAT: Sistem güncellemeleri nedeniyle yeniden başlatma gerekiyor!${NC}"
        echo -e "${YELLOW}   Lütfen uygun bir zamanda sistemi yeniden başlatın.${NC}"
        echo
    fi
    
    echo -e "${GREEN}✅ Güncelleme işlemi başarıyla tamamlandı!${NC}"
    echo
}

# Onay al
get_confirmation() {
    echo -e "${YELLOW}Bu script aşağıdaki işlemleri gerçekleştirecek:${NC}"
    echo -e "  • Mevcut sources.list dosyasını yedekleyecek"
    echo -e "  • DNS ayarlarını geçici olarak Cloudflare (1.1.1.1) olarak değiştirecek"
    echo -e "  • Debian $DEBIAN_VERSION için optimize edilmiş sources.list oluşturacak"
    echo -e "  • Tüm sistem güncellemelerini yapacak"
    echo -e "  • Sistem temizliği gerçekleştirecek"
    echo -e "  • Orijinal ayarları geri yükleyecek"
    echo
    echo -e "${RED}⚠️  DİKKAT: Bu işlem sistem ayarlarınızı geçici olarak değiştirecektir!${NC}"
    echo
    
    while true; do
        read -p "Devam etmek istiyor musunuz? (e/h): " yn
        case $yn in
            [Ee]* | [Yy]* | "evet" | "EVET" ) 
                log_message "INFO" "Kullanıcı işleme devam etmeyi onayladı"
                break
                ;;
            [Hh]* | [Nn]* | "hayır" | "HAYIR" ) 
                log_message "INFO" "Kullanıcı işlemi iptal etti"
                echo -e "${YELLOW}İşlem iptal edildi.${NC}"
                exit 0
                ;;
            * ) 
                echo -e "${RED}Lütfen 'e' (evet) veya 'h' (hayır) girin.${NC}"
                ;;
        esac
    done
}

# Hata yakalama fonksiyonu
error_handler() {
    local line_no=$1
    local error_code=$2
    
    log_message "ERROR" "Script hata ile sonlandı. Satır: $line_no, Hata kodu: $error_code"
    
    # Temizlik işlemlerini yap
    if [ -f "$SOURCES_BACKUP" ]; then
        restore_sources_list
    fi
    
    if [ -f "$RESOLV_BACKUP" ]; then
        restore_dns
    fi
    
    echo -e "${RED}❌ Script hata ile sonlandı. Detaylar için log dosyasını kontrol edin: $LOG_FILE${NC}"
    exit $error_code
}

# Signal yakalama
cleanup_on_exit() {
    log_message "WARNING" "Script kesintiye uğradı"
    
    # Yedeklemeleri geri yükle
    if [ -f "$SOURCES_BACKUP" ]; then
        restore_sources_list
    fi
    
    if [ -f "$RESOLV_BACKUP" ]; then
        restore_dns
    fi
    
    echo -e "${YELLOW}⚠️  Script kesintiye uğradı. Ayarlar geri yüklendi.${NC}"
    exit 130
}

#############################################################################
# Ana Program
#############################################################################

# Signal ve hata yakalayıcıları ayarla
trap 'error_handler ${LINENO} $?' ERR
trap cleanup_on_exit INT TERM

# Script başlangıcı
main() {
    # Banner göster
    show_banner
    
    # Log dizinini oluştur
    create_log_dir
    
    # Script başlangıç logu
    log_message "INFO" "=== $SCRIPT_NAME BAŞLATILDI ==="
    log_message "INFO" "Script PID: $$"
    log_message "INFO" "Başlangıç zamanı: $(date)"
    log_message "INFO" "Log dosyası: $LOG_FILE"
    
    # Root kontrolü
    check_root
    
    # Sistem bilgilerini al
    get_system_info
    
    # Kullanıcı onayı al
    get_confirmation
    
    # Backup dizini oluştur
    create_backup_dir
    
    echo -e "${BLUE}🚀 Güncelleme işlemi başlatılıyor...${NC}"
    echo
    
    # Ana işlemler
    backup_sources_list
    setup_dns
    create_sources_list
    update_package_list
    upgrade_system
    cleanup_packages
    
    # Geri yükleme işlemleri
    restore_sources_list
    restore_dns
    
    # Final temizlik
    final_cleanup
    
    # Rapor göster
    show_final_report
    
    # Script bitiş logu
    log_message "INFO" "=== $SCRIPT_NAME TAMAMLANDI ==="
    log_message "SUCCESS" "Tüm işlemler başarıyla tamamlandı"
}

# Ana fonksiyonu çalıştır
main "$@"

# Script başarıyla tamamlandı
exit 0

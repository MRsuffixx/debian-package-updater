# 🚀 NACSS Debian 11/12 Updater Script

![Debian](https://img.shields.io/badge/Debian-11%20|%2012-red)
![License](https://img.shields.io/badge/License-MIT-blue)
![Version](https://img.shields.io/badge/Version-1.0-green)

## 🌟 Overview / Genel Bakış

### 🇬🇧 English
This script automates the process of updating the `sources.list` file for Debian 11 and Debian 12 systems. It ensures your system has access to the correct repositories, temporarily configures DNS settings for reliable connectivity, and performs a system update.

### 🇹🇷 Türkçe
Bu script, Debian 11 ve Debian 12 sistemleri için `sources.list` dosyasını güncelleme işlemini otomatikleştirir. Sisteminizin doğru depolara erişimini sağlar, güvenilir bağlantı için DNS ayarlarını geçici olarak yapılandırır ve sistem güncellemesi gerçekleştirir.

## ✨ Features / Özellikler

### 🇬🇧 English
- ✅ Automatically detects Debian version (works only on Debian 11 or 12)
- ✅ Checks and requests root privileges if needed
- ✅ Temporarily configures DNS to use Cloudflare (1.1.1.1) for reliable connectivity
- ✅ Updates the sources.list with optimized repository configurations
- ✅ Runs system update and upgrade
- ✅ Restores original DNS configuration after completion
- ✅ Creates backups of modified files

### 🇹🇷 Türkçe
- ✅ Debian sürümünü otomatik algılar (yalnızca Debian 11 veya 12'de çalışır)
- ✅ Root yetkilerini kontrol eder ve gerekirse talep eder
- ✅ Güvenilir bağlantı için DNS'i geçici olarak Cloudflare (1.1.1.1) kullanacak şekilde yapılandırır
- ✅ Sources.list dosyasını optimize edilmiş depo yapılandırmalarıyla günceller
- ✅ Sistem güncellemesi ve yükseltmesi çalıştırır
- ✅ İşlem tamamlandıktan sonra orijinal DNS yapılandırmasını geri yükler
- ✅ Değiştirilen dosyaların yedeklerini oluşturur

## ⚙️ Installation & Usage / Kurulum ve Kullanım

### 🇬🇧 English

#### Option 1: One-line execution (Recommended)
Run the script directly with a single command:
```bash
curl -s https://raw.githubusercontent.com/MRsuffixx/nacss-debian-updater/main/nacss-debian-11-12-updater.sh | sudo bash
```

#### Option 2: Download and execute
1. Download the script:
   ```bash
   wget -O nacss-debian-11-12-updater.sh https://raw.githubusercontent.com/MRsuffixx/nacss-debian-updater/main/nacss-debian-11-12-updater.sh
   ```

2. Make the script executable:
   ```bash
   chmod +x nacss-debian-11-12-updater.sh
   ```

3. Run the script:
   ```bash
   sudo ./nacss-debian-11-12-updater.sh
   ```

### 🇹🇷 Türkçe

#### Seçenek 1: Tek komutla çalıştırma (Önerilen)
Script'i doğrudan tek bir komutla çalıştırın:
```bash
curl -s https://raw.githubusercontent.com/MRsuffixx/nacss-debian-updater/main/nacss-debian-11-12-updater.sh | sudo bash
```

#### Seçenek 2: İndirip çalıştırma
1. Script'i indirin:
   ```bash
   wget -O nacss-debian-11-12-updater.sh https://raw.githubusercontent.com/MRsuffixx/nacss-debian-updater/main/nacss-debian-11-12-updater.sh
   ```

2. Script'i çalıştırılabilir yapın:
   ```bash
   chmod +x nacss-debian-11-12-updater.sh
   ```

3. Script'i çalıştırın:
   ```bash
   sudo ./nacss-debian-11-12-updater.sh
   ```

## 🔍 What Does This Script Do? / Bu Script Ne Yapar?

### 🇬🇧 English
1. **Privilege Check**: Ensures the script runs with necessary permissions
2. **OS Compatibility Check**: Verifies it's running on Debian 11 or 12
3. **DNS Configuration**: Temporarily sets DNS to 1.1.1.1 for reliable connectivity
4. **Repository Update**:
   - For Debian 12: Uses optimized sources from [this configuration](https://gist.githubusercontent.com/ishad0w/e1ba0843edc9eb3084a1a0750861d073/raw/8148f9eac76d380f4340242e5a835dc1b9e4d2e7/sources_full.list)
   - For Debian 11: Uses optimized sources from [this configuration](https://gist.githubusercontent.com/ishad0w/7665cde882aa7dc3eec99613802e61e4/raw/1b250a3fea94f8337b73f70be6694daa9f0ac8d3/sources.list)
5. **System Update**: Runs `apt update && apt upgrade -y`
6. **Cleanup**: Restores original DNS configuration

### 🇹🇷 Türkçe
1. **Yetki Kontrolü**: Script'in gerekli izinlerle çalıştığından emin olur
2. **İşletim Sistemi Uyumluluk Kontrolü**: Debian 11 veya 12'de çalıştığını doğrular
3. **DNS Yapılandırması**: Güvenilir bağlantı için DNS'i geçici olarak 1.1.1.1 olarak ayarlar
4. **Depo Güncellemesi**:
   - Debian 12 için: [Bu yapılandırmadan](https://gist.githubusercontent.com/ishad0w/e1ba0843edc9eb3084a1a0750861d073/raw/8148f9eac76d380f4340242e5a835dc1b9e4d2e7/sources_full.list) optimize edilmiş kaynakları kullanır
   - Debian 11 için: [Bu yapılandırmadan](https://gist.githubusercontent.com/ishad0w/7665cde882aa7dc3eec99613802e61e4/raw/1b250a3fea94f8337b73f70be6694daa9f0ac8d3/sources.list) optimize edilmiş kaynakları kullanır
5. **Sistem Güncellemesi**: `apt update && apt upgrade -y` komutlarını çalıştırır
6. **Temizlik**: Orijinal DNS yapılandırmasını geri yükler

## ⚠️ Warning / Uyarı

### 🇬🇧 English
This script modifies system files. Although it creates backups, please ensure you understand what the script does before running it. It is recommended to run this on a fresh Debian installation or a system where you have recent backups.

### 🇹🇷 Türkçe
Bu script sistem dosyalarını değiştirir. Yedekler oluşturmasına rağmen, çalıştırmadan önce script'in ne yaptığını anladığınızdan emin olun. Bunu yeni bir Debian kurulumunda veya yakın zamanda yedeklerinizin olduğu bir sistemde çalıştırmanız önerilir.

## 🤝 Contributing / Katkıda Bulunma

### 🇬🇧 English
Contributions are welcome! Please feel free to submit a Pull Request.

### 🇹🇷 Türkçe
Katkılarınızı bekliyoruz! Lütfen bir Pull Request göndermekten çekinmeyin.

## 📄 License / Lisans

### 🇬🇧 English
This project is licensed under the MIT License - see the LICENSE file for details.

### 🇹🇷 Türkçe
Bu proje MIT Lisansı altında lisanslanmıştır - detaylar için LICENSE dosyasına bakın.

---

⭐ **If you find this script useful, please consider giving it a star on GitHub!** ⭐

⭐ **Bu script'i faydalı bulursanız, lütfen GitHub'da yıldız vermeyi düşünün!** ⭐

<div align="center">

# 🎵 MozeMusic

**Modern, Akıcı ve Reklamsız Müzik Deneyimi**  
*Next-generation music streaming experience for Windows & Android*

[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android-blue.svg?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/mozelabsprojects/mozemusic)
[![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B.svg?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Powered by Mozelabs](https://img.shields.io/badge/Powered%20by-Mozelabs-E63946.svg?style=for-the-badge)](https://mozelabs.com)
[![License](https://img.shields.io/badge/License-Proprietary-green.svg?style=for-the-badge)](https://mozelabs.com)

---

</div>

## 📥 İndirme & Kurulum (Downloads)

Tüm platformlar için en güncel MozeMusic sürümlerini aşağıdan indirebilirsiniz:

| Platform | Dil / Tür | İndirme Bağlantısı | Açıklama |
| :--- | :--- | :--- | :--- |
| **Windows 10/11** | 🇹🇷 **Türkçe Kurulum Sihirbazı** | [📥 MozeMusic_Kurulum_Sihirbazi.exe](https://github.com/mozelabsprojects/mozemusic/releases/latest/download/MozeMusic_Kurulum_Sihirbazi.exe) | 7 adımlı, Türkçe izin ve politika onaylı masaüstü kurulum sihirbazı. |
| **Windows 10/11** | 🇬🇧 **English Setup Wizard** | [📥 MozeMusic_Setup.exe](https://github.com/mozelabsprojects/mozemusic/releases/latest/download/MozeMusic_Setup.exe) | 7-step desktop setup wizard with English policies & terms. |
| **Android** | 📱 **Doğrudan APK İndir** | [📥 MozeMusic-Android.apk](https://github.com/mozelabsprojects/mozemusic/releases/latest/download/MozeMusic-Android.apk) | Android telefon ve tabletler için doğrudan yüklenebilir APK. |
| **Android** | ⚡ **Otomatik APK İndirici (Downloader)** | [tools/download_apk.ps1](file:///tools/download_apk.ps1) | En son sürüm APK'yı tek komutla otomatik çeken yardımcı script. |

> 💡 **Not:** Kurulum dosyaları derlendikten sonra doğrudan bilgisayarınızın **Masaüstü (Desktop)** klasöründe de hazır olarak bulunmaktadır (`MozeMusic_Kurulum_Sihirbazi.exe` ve `MozeMusic_Setup.exe`).

---

## ⚡ Hızlı APK İndirici (APK Downloader)

Android APK'sını bilgisayarınıza veya sunucunuza tek tıkla indirmek için hazır downloader araçlarımız:

### Windows (PowerShell)
```powershell
# tools klasöründeki scripti çalıştırmak için:
powershell -ExecutionPolicy Bypass -File .\tools\download_apk.ps1
```
*Veya doğrudan tek satır PowerShell komutu:*
```powershell
Invoke-WebRequest -Uri "https://github.com/mozelabsprojects/mozemusic/releases/latest/download/MozeMusic-Android.apk" -OutFile "MozeMusic.apk"
```

### Linux / macOS / Bash
```bash
bash ./tools/download_apk.sh
```
*Veya tek satır curl:*
```bash
curl -L -o MozeMusic.apk https://github.com/mozelabsprojects/mozemusic/releases/latest/download/MozeMusic-Android.apk
```

---

## 🚀 Canlı Güncelleme Sistemi (Over-The-Air Update)

MozeMusic, çift kanallı otomatik güncelleme altyapısına sahiptir:

1. **GitHub Releases Otomasyonu (CI/CD):**
   * GitHub'a yeni bir versiyon etiketi pushlandığında (örn: `git tag v1.0.1` ve `git push origin v1.0.1`):
   * GitHub Actions arka planda devreye girer, Android APK ve Windows sürümlerini derleyip Releases sayfasına yükler.
   * MozeMusic uygulaması otomatik olarak yeni sürümü algılar ve kullanıcıların telefonuna/bilgisayarına güncelleme pop-up'ı gönderir.
2. **Yönetici Paneli (Admin Only):**
   * Yalnızca yetkili yönetici hesapları (`mox17012000@gmail.com`) Ayarlar menüsünden **"Yeni Güncelleme Yayınla"** butonunu görebilir.
   * Buradan yayınlanan acil güncellemeler Firestore üzerinden tüm aktif kullanıcılara canlı olarak iletilir.

---

## ✨ Temel Özellikler

- 🎧 **Reklamsız ve Kesintisiz Akış:** Yüksek kaliteli ses motoru ile sıfır reklam kesintisi.
- 📋 **Doğru Sıralı & Mix Oynatma:** Beğenilen şarkılar ve çalma listelerinde sıradaki şarkıya doğru sıra ile geçiş veya akıllı shuffle.
- 🎨 **Neon Cyberpunk / Glassmorphism UI:** Modern koyu tema, akıcı geçiş animasyonları ve responsive arayüz.
- 🔍 **Canlı Arama & Trendler:** YouTube Music entegrasyonu ile anlık şarkı, sanatçı ve kategori keşfi.
- 💻 **Platform Bağımsız:** Windows masaüstü ve Android mobil ortamlarında optimize performans.

---

## 🏢 Hakkında

MozeMusic, **[Mozelabs](https://mozelabs.com)** tarafından geliştirilmiştir.

- 🌐 **Web Sitesi (TR):** [https://mozelabs.com/tr](https://mozelabs.com/tr)
- 🌐 **Web Sitesi (EN):** [https://mozelabs.com/en](https://mozelabs.com/en)
- 📦 **GitHub Repository:** [https://github.com/mozelabsprojects/mozemusic](https://github.com/mozelabsprojects/mozemusic)

---
<div align="center">
<sub>© 2026 Mozelabs. Tüm hakları saklıdır.</sub>
</div>

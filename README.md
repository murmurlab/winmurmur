# Windows Node.js, npm & Git Otomatik Kurulum Scripti

Windows 10, Windows 11 ve Windows Server sistemlerinde **Node.js** (varsayılan LTS sürümü), **npm** ve **Git** araçlarını tek tıklamayla veya tek satırlık komutla otomatik kuran PowerShell ve Batch scriptidir.

---

## 🚀 Özellikler

- 🛡️ **Otomatik Yönetici Yükseltme (UAC):** Script yönetici hakları olmadan çalıştırılırsa otomatik olarak izin onay penceresini (UAC) açar.
- ⚡ **Akıllı Kurulum Motoru (Node.js & Git):**
  - Sistemde `winget` (Windows Package Manager) varsa hızlı ve sessiz kurulumu (`OpenJS.NodeJS.LTS` ve `Git.Git`) winget üzerinden yapar.
  - `winget` yoksa veya hata verirse, resmi `nodejs.org` ve `github.com/git-for-windows/git` sunucularından en güncel kurulum paketlerini otomatik indirip sessizce kurar (`msiexec /qn` ve `/VERYSILENT`).
- 🧠 **Mimari Tespiti:** Sistemin 64-bit (x64), ARM64 veya 32-bit (x86) olduğunu otomatik tespit eder ve doğru kurulum paketini çeker.
- 🔄 **Anında PATH Güncellemesi:** Kurulum biter bitmez mevcut terminal oturumundaki ortam değişkenlerini yeniler; bilgisayarı veya terminali yeniden başlatmadan `node`, `npm` ve `git` kullanılabilir.
- 🔍 **Kurulum Doğrulaması:** `node -v`, `npm -v` ve `git --version` çalıştırarak kurulumun sağlamlığını test eder.
- 📦 **Ek Paket Yöneticisi Desteği:** İsteğe bağlı olarak `yarn` ve `pnpm` kurulumlarını da tek komutla tamamlar.

---

## ⚡ Hızlı Kurulum (Tek Satır)

Repoyu indirmeden doğrudan PowerShell (Yönetici olarak açılmış) üzerinden tek satırla kurmak için:

```powershell
irm https://raw.githubusercontent.com/murmurlab/winmurmur/main/install-node.ps1 | iex
```

> **Not:** Özel parametrelerle çalıştırmak isterseniz (örneğin ek olarak `pnpm` kurmak veya belirli bir sürüm belirtmek için):
> ```powershell
> & ([scriptblock]::Create((irm https://raw.githubusercontent.com/murmurlab/winmurmur/main/install-node.ps1))) -InstallPnpm
> ```

---

## 🛠️ Nasıl Çalıştırılır?

### Yöntem 1: Tek Satır Uzaktan Kurulum (Önerilen)
PowerShell'i açıp yukarıdaki tek satırlık `irm ... | iex` komutunu yapıştırmanız yeterlidir.

### Yöntem 2: Çift Tıklayarak
1. `install-node.bat` dosyasına çift tıklayın (veya sağ tıklayıp **Yönetici olarak çalıştır** deyin).
2. Çıkan Windows UAC onayına "Evet" deyin.
3. Kurulum otomatik tamamlanacak ve sürümler ekrana yazdırılacaktır.

### Yöntem 3: İndirip PowerShell ile Çalıştırma
PowerShell konsolunu açın ve aşağıdaki komutlardan birini çalıştırın:

```powershell
# Standart LTS Kurulumu:
powershell -ExecutionPolicy Bypass -File .\install-node.ps1

# Zaten kuruluysa bile yeniden kurmaya zorlama:
powershell -ExecutionPolicy Bypass -File .\install-node.ps1 -Force

# En son güncel sürümü (Current) kurma:
powershell -ExecutionPolicy Bypass -File .\install-node.ps1 -Channel current

# Belirli bir sürüm kurma:
powershell -ExecutionPolicy Bypass -File .\install-node.ps1 -CustomVersion "22.14.0"

# Node.js + npm + pnpm ve Yarn birlikte kurma:
powershell -ExecutionPolicy Bypass -File .\install-node.ps1 -InstallPnpm -InstallYarn
```

---

## ⚙️ Parametreler

| Parametre | Tip | Varsayılan | Açıklama |
|---|---|---|---|
| `-Channel` | String (`lts` / `current`) | `lts` | Kurulacak Node.js dağıtım kanalı. |
| `-CustomVersion` | String | Boş | Özel bir Node.js sürüm numarası (ör. `22.14.0` veya `20.18.0`). |
| `-Force` | Switch | Kapalı | Sistemde Node.js veya Git kurulu olsa bile sormadan üzerine kurar. |
| `-SkipGit` | Switch | Kapalı | Sadece Node.js ve npm kurar, Git kurulumunu atlar. |
| `-InstallYarn` | Switch | Kapalı | Kurulum sonrası global olarak Yarn paketini kurar (`npm install -g yarn`). |
| `-InstallPnpm` | Switch | Kapalı | Kurulum sonrası global olarak pnpm paketini kurar (`npm install -g pnpm`). |
| `-NoWinget` | Switch | Kapalı | winget'i atlayıp doğrudan resmi kurulum paketlerini indirir. |

---

## ❓ Sık Karşılaşılan Sorunlar ve Çözümleri

### 1. "Script çalıştırma bu sistemde devre dışı bırakılmış" Hatası
Windows varsayılan olarak PowerShell scriptlerinin doğrudan çalıştırılmasını engeller (`ExecutionPolicy`).
- Çözüm: Scripti `powershell -ExecutionPolicy Bypass -File .\install-node.ps1` komutu ile veya doğrudan `install-node.bat` üzerinden çalıştırın.

### 2. Kurulumdan Sonra `node` Komutu Bulunamıyor
- Script geçerli oturumun PATH değerini otomatik yeniler. Ancak önceden açık olan diğer CMD veya PowerShell pencerelerini kapatıp yeni bir pencere açmanız gereklidir.

---

## 📄 Dosya Yapısı

- [install-node.ps1](file:///home/murmur/sources/repos/winmurmur/install-node.ps1) - Ana PowerShell kurulum betiği.
- [install-node.bat](file:///home/murmur/sources/repos/winmurmur/install-node.bat) - Çift tıklanabilir Windows Batch wrapper.
- [README.md](file:///home/murmur/sources/repos/winmurmur/README.md) - Kullanım kılavuzu.


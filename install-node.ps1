<#
.SYNOPSIS
    Windows icin otomatik Node.js, npm ve Git Kurulum Scripti.

.DESCRIPTION
    Bu script Windows uzerinde Node.js (varsayilan olarak LTS surumu), npm ve Git kurulumunu otomatiklestirir.
    - Yonetici yetkisi denetimi ve otomatik yukseltme (UAC).
    - Windows Paket Yoneticisi (winget) destegi ve otomatik fallback.
    - Resmi kaynaklardan (nodejs.org ve git-scm.com / GitHub) guvenli indirme ve sessiz (silent) kurulum.
    - Kurulum sonrasinda mevcut terminal oturumundaki PATH degiskenini guncelleme.
    - Kurulum dogrulamasi (node -v, npm -v, git --version).
    - Opsiyonel Yarn ve pnpm kurulum destegi.

.PARAMETER Channel
    Kurulacak Node.js kanali. Secenekler: "lts" (varsayilan) veya "current".

.PARAMETER CustomVersion
    Belirli bir Node.js surumu kurmak istenirse (ornegin: "22.14.0" veya "v22.14.0").

.PARAMETER Force
    Sistemde Node.js veya Git zaten kurulu olsa bile yeniden kurulumu/guncellemeyi zorlar.

.PARAMETER SkipGit
    Git kurulumunu atlamak istenirse kullanilir (varsayilan olarak Git de kurulur).

.PARAMETER InstallYarn
    Kurulum sonrasinda global olarak Yarn paket yoneticisini kurar.

.PARAMETER InstallPnpm
    Kurulum sonrasinda global olarak pnpm paket yoneticisini kurar.

.PARAMETER NoWinget
    winget kontrolunu atlayip dogrudan resmi kurulum paketlerini indirir.

.EXAMPLE
    .\install-node.ps1

.EXAMPLE
    .\install-node.ps1 -Channel current -InstallPnpm

.EXAMPLE
    .\install-node.ps1 -CustomVersion "22.14.0" -Force
#>

[CmdletBinding()]
param(
    [ValidateSet("lts", "current", "latest")]
    [string]$Channel = "lts",

    [string]$CustomVersion = "",

    [switch]$Force,

    [switch]$SkipGit,

    [switch]$InstallYarn,

    [switch]$InstallPnpm,

    [switch]$NoWinget
)

# Konsol ciktisi icin UTF-8 ve guvenli iletisim protokolleri
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

function Write-Info {
    param([string]$Message)
    Write-Host "[BILGI] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[BASARILI] $Message" -ForegroundColor Green
}

function Write-WarnMsg {
    param([string]$Message)
    Write-Host "[UYARI] $Message" -ForegroundColor Yellow
}

function Write-ErrMsg {
    param([string]$Message)
    Write-Host "[HATA] $Message" -ForegroundColor Red
}

# 1. Yonetici (Administrator) Yetkisi Kontrolu
function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-WarnMsg "Yonetici (Administrator) yetkisi gerekiyor. UAC yetkilendirmesi baslatiliyor..."

    if (-not [string]::IsNullOrEmpty($PSCommandPath)) {
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
        foreach ($boundParam in $PSBoundParameters.GetEnumerator()) {
            if ($boundParam.Value -is [System.Management.Automation.SwitchParameter]) {
                if ($boundParam.Value.IsPresent) {
                    $argList += "-$($boundParam.Key)"
                }
            } else {
                $argList += "-$($boundParam.Key)"
                $argList += "`"$($boundParam.Value)`""
            }
        }
    } else {
        # irm ... | iex ile uzaktan calistirildiysa
        $remoteUrl = "https://raw.githubusercontent.com/murmurlab/winmurmur/main/install-node.ps1"
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "`"irm $remoteUrl | iex`"")
    }

    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ($argList -join " ")
        exit 0
    } catch {
        Write-ErrMsg "Yonetici yetkisi alinamadi veya kullanici UAC istegini reddetti: $_"
        exit 1
    }
}

Clear-Host
Write-Host "==========================================================" -ForegroundColor Magenta
Write-Host "    Windows Node.js, npm ve Git Otomatik Kurulum Araci    " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Magenta
Write-Host ""

# 2. PATH Yenileme Fonksiyonu
function Update-SessionEnvironment {
    Write-Info "Ortam degiskenleri ve PATH yenileniyor..."
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
    $combinedPath = "$machinePath;$userPath"
    
    # Standart nodejs ve Git dizinlerini kontrol et ve PATH'e ekle
    $standardDirs = @(
        "$env:ProgramFiles\nodejs",
        "${env:ProgramFiles(x86)}\nodejs",
        "$env:APPDATA\npm",
        "$env:ProgramFiles\Git\cmd",
        "$env:ProgramFiles\Git\bin",
        "${env:ProgramFiles(x86)}\Git\cmd",
        "$env:LOCALAPPDATA\Programs\Git\cmd"
    )
    foreach ($dir in $standardDirs) {
        if ((Test-Path $dir) -and ($combinedPath -notlike "*$dir*")) {
            $combinedPath = "$dir;$combinedPath"
        }
    }

    $env:Path = $combinedPath
}

Update-SessionEnvironment

# 3. Sistem Mimarisi Tespiti
$osArch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
$osArch64 = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITEW6432")

$targetArch = "x64"
if ($osArch -eq "ARM64" -or $osArch64 -eq "ARM64") {
    $targetArch = "arm64"
} elseif ($osArch -eq "x86" -and [string]::IsNullOrEmpty($osArch64)) {
    $targetArch = "x86"
}
Write-Info "Tespit edilen sistem mimarisi: $targetArch"

# ==========================================================
# BOLUM A: NODE.JS VE NPM KURULUMU
# ==========================================================
Write-Host ""
Write-Host "----------------------------------------------------------" -ForegroundColor DarkCyan
Write-Host " [1/2] Node.js ve npm Kurulum Kontrolu" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------" -ForegroundColor DarkCyan

$shouldInstallNode = $true
$existingNode = Get-Command "node.exe" -ErrorAction SilentlyContinue
if ($existingNode) {
    try {
        $currentVersion = & node -v 2>$null
        $currentNpmVersion = & npm -v 2>$null
        Write-Info "Sistemde zaten Node.js kurulu: $currentVersion (npm: v$currentNpmVersion)"
        Write-Info "Dosya yolu: $($existingNode.Source)"

        if (-not $Force) {
            Write-Host ""
            $choice = Read-Host "Node.js'i yeniden kurmak / guncellemek istiyor musunuz? (E/H) [Varsayilan: H]"
            if ($choice -ne "E" -and $choice -ne "e") {
                Write-Info "Node.js kurulumu atlandi. Mevcut surum korundu."
                $shouldInstallNode = $false
            }
        } else {
            Write-Info "-Force parametresi algilandi. Node.js guncelleme/yeniden kuruluma devam ediliyor..."
        }
    } catch {
        Write-WarnMsg "Node.js yolu bulundu fakat surum sorgulanamadi. Kuruluma devam ediliyor..."
    }
}

if ($shouldInstallNode) {
    $installedViaWinget = $false
    if (-not $NoWinget -and [string]::IsNullOrEmpty($CustomVersion)) {
        $wingetCmd = Get-Command "winget.exe" -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            Write-Info "Windows Paket Yoneticisi (winget) ile Node.js kuruluyor..."
            $packageId = if ($Channel -eq "current" -or $Channel -eq "latest") { "OpenJS.NodeJS" } else { "OpenJS.NodeJS.LTS" }

            try {
                Write-Info "Paket indiriliyor ve kuruluyor: $packageId ..."
                $wingetArgs = "install --id $packageId --exact --silent --accept-source-agreements --accept-package-agreements --force"
                $wingetProc = Start-Process -FilePath "winget.exe" -ArgumentList $wingetArgs -NoNewWindow -Wait -PassThru
                
                if ($wingetProc.ExitCode -eq 0 -or $wingetProc.ExitCode -eq 2316632065) {
                    Write-Success "winget ile Node.js kurulumu tamamlandi."
                    $installedViaWinget = $true
                } else {
                    Write-WarnMsg "winget kurulumu hata kodu verdi ($($wingetProc.ExitCode)). Resmi MSI yontemine geciliyor..."
                }
            } catch {
                Write-WarnMsg "winget calistirilirken hata olustu: $_. Resmi MSI yontemine geciliyor..."
            }
        } else {
            Write-Info "winget bulunamadi. Resmi nodejs.org MSI indiricisi kullanilacak."
        }
    }

    if (-not $installedViaWinget) {
        Write-Info "Resmi nodejs.org sunucularindan en uygun surum tespit ediliyor..."
        
        $selectedVersion = ""
        if (-not [string]::IsNullOrEmpty($CustomVersion)) {
            $selectedVersion = $CustomVersion.TrimStart('v')
        } else {
            try {
                $distIndexUrl = "https://nodejs.org/dist/index.json"
                $distJson = Invoke-RestMethod -Uri $distIndexUrl -UseBasicParsing -TimeoutSec 15
                
                if ($Channel -eq "current" -or $Channel -eq "latest") {
                    $selectedEntry = $distJson[0]
                } else {
                    $selectedEntry = $distJson | Where-Object { $_.lts -ne $false } | Select-Object -First 1
                }

                if ($selectedEntry) {
                    $selectedVersion = $selectedEntry.version.TrimStart('v')
                    Write-Info "Secilen Node.js surumu: v$selectedVersion (LTS: $($selectedEntry.lts))"
                }
            } catch {
                Write-WarnMsg "Surum listesi API'den alinamadi: $_"
            }

            if ([string]::IsNullOrEmpty($selectedVersion)) {
                $selectedVersion = "22.14.0"
                Write-WarnMsg "Varsayilan guvenli LTS surumune basvuruluyor: v$selectedVersion"
            }
        }

        $msiFileName = "node-v$selectedVersion-$targetArch.msi"
        $downloadUrl = "https://nodejs.org/dist/v$selectedVersion/$msiFileName"
        $tempMsiPath = Join-Path $env:TEMP $msiFileName

        Write-Info "Node.js MSI paketi indiriliyor: $downloadUrl"
        try {
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) NodeJS-Installer")
            $webClient.DownloadFile($downloadUrl, $tempMsiPath)
            Write-Success "MSI basariyla indirildi: $tempMsiPath"
        } catch {
            Write-ErrMsg "Node.js MSI paketi indirilemedi: $_"
            exit 1
        }

        Write-Info "Node.js sessiz (silent) kurulum baslatiliyor (msiexec)..."
        $msiArgs = @("/i", "`"$tempMsiPath`"", "/qn", "/norestart", "ADDLOCAL=ALL")
        $msiProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru

        if (Test-Path $tempMsiPath) {
            Remove-Item $tempMsiPath -Force -ErrorAction SilentlyContinue
        }

        if ($msiProcess.ExitCode -eq 0) {
            Write-Success "Node.js MSI kurulumu basariyla tamamlandi."
        } elseif ($msiProcess.ExitCode -eq 3010) {
            Write-Success "Node.js kurulumu tamamlandi (Sistemin yeniden baslatilmasi onerilir - Kod 3010)."
        } else {
            Write-ErrMsg "Node.js kurulumu basarisiz oldu. msiexec cikis kodu: $($msiProcess.ExitCode)"
            exit $msiProcess.ExitCode
        }
    }
}

# ==========================================================
# BOLUM B: GIT KURULUMU
# ==========================================================
if (-not $SkipGit) {
    Write-Host ""
    Write-Host "----------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " [2/2] Git Kurulum Kontrolu" -ForegroundColor Cyan
    Write-Host "----------------------------------------------------------" -ForegroundColor DarkCyan

    Update-SessionEnvironment
    $shouldInstallGit = $true
    $existingGit = Get-Command "git.exe" -ErrorAction SilentlyContinue

    if ($existingGit) {
        try {
            $currentGitVer = & git --version 2>$null
            Write-Info "Sistemde zaten Git kurulu: $currentGitVer"
            Write-Info "Dosya yolu: $($existingGit.Source)"

            if (-not $Force) {
                Write-Host ""
                $gitChoice = Read-Host "Git'i yeniden kurmak / guncellemek istiyor musunuz? (E/H) [Varsayilan: H]"
                if ($gitChoice -ne "E" -and $gitChoice -ne "e") {
                    Write-Info "Git kurulumu atlandi. Mevcut surum korundu."
                    $shouldInstallGit = $false
                }
            } else {
                Write-Info "-Force parametresi algilandi. Git guncelleme/yeniden kuruluma devam ediliyor..."
            }
        } catch {
            Write-WarnMsg "Git yolu bulundu fakat surum sorgulanamadi. Kuruluma devam ediliyor..."
        }
    }

    if ($shouldInstallGit) {
        $gitInstalledViaWinget = $false
        if (-not $NoWinget) {
            $wingetCmd = Get-Command "winget.exe" -ErrorAction SilentlyContinue
            if ($wingetCmd) {
                Write-Info "Windows Paket Yoneticisi (winget) ile Git kuruluyor..."
                try {
                    $wingetGitArgs = "install --id Git.Git --exact --silent --accept-source-agreements --accept-package-agreements --force"
                    $wingetGitProc = Start-Process -FilePath "winget.exe" -ArgumentList $wingetGitArgs -NoNewWindow -Wait -PassThru

                    if ($wingetGitProc.ExitCode -eq 0 -or $wingetGitProc.ExitCode -eq 2316632065) {
                        Write-Success "winget ile Git kurulumu tamamlandi."
                        $gitInstalledViaWinget = $true
                    } else {
                        Write-WarnMsg "winget Git kurulumu hata kodu verdi ($($wingetGitProc.ExitCode)). Dogrudan indirme yontemine geciliyor..."
                    }
                } catch {
                    Write-WarnMsg "winget ile Git kurulurken hata olustu: $_. Dogrudan indirme yontemine geciliyor..."
                }
            }
        }

        if (-not $gitInstalledViaWinget) {
            Write-Info "GitHub resmi deposundan en guncel Git for Windows surumu tespit ediliyor..."
            $gitDownloadUrl = ""
            $gitFileName = "Git-Setup.exe"

            try {
                $gitApiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"
                $gitRelease = Invoke-RestMethod -Uri $gitApiUrl -Headers @{ "User-Agent" = "PowerShell-Installer" } -UseBasicParsing -TimeoutSec 15

                $archPattern = if ($targetArch -eq "arm64") { "*-arm64.exe" } elseif ($targetArch -eq "x86") { "*-32-bit.exe" } else { "*-64-bit.exe" }
                $asset = $gitRelease.assets | Where-Object { $_.name -like "Git-*" -and $_.name -like $archPattern -and $_.name -notlike "*rc*" } | Select-Object -First 1

                if ($asset) {
                    $gitDownloadUrl = $asset.browser_download_url
                    $gitFileName = $asset.name
                    Write-Info "Bulunan Git surumu: $($gitRelease.tag_name) ($gitFileName)"
                }
            } catch {
                Write-WarnMsg "GitHub API uzerinden surum alinamadi: $_"
            }

            if ([string]::IsNullOrEmpty($gitDownloadUrl)) {
                $gitVersionFallback = "2.48.1"
                $bitSuffix = if ($targetArch -eq "arm64") { "arm64" } elseif ($targetArch -eq "x86") { "32-bit" } else { "64-bit" }
                $gitFileName = "Git-$gitVersionFallback-$bitSuffix.exe"
                $gitDownloadUrl = "https://github.com/git-for-windows/git/releases/download/v$gitVersionFallback.windows.1/$gitFileName"
                Write-WarnMsg "Varsayilan Git indirme baglantisi kullaniliyor: $gitDownloadUrl"
            }

            $tempGitPath = Join-Path $env:TEMP $gitFileName
            Write-Info "Git kurulum paketi indiriliyor: $gitDownloadUrl"
            try {
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Git-Installer")
                $webClient.DownloadFile($gitDownloadUrl, $tempGitPath)
                Write-Success "Git kurulum paketi indirildi: $tempGitPath"
            } catch {
                Write-ErrMsg "Git paketi indirilemedi: $_"
            }

            if (Test-Path $tempGitPath) {
                Write-Info "Git sessiz (silent) kurulum baslatiliyor..."
                $gitInstallerArgs = @("/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-", "/CLOSEAPPLICATIONS", "/RESTARTAPPLICATIONS")
                $gitProc = Start-Process -FilePath $tempGitPath -ArgumentList $gitInstallerArgs -Wait -PassThru

                Remove-Item $tempGitPath -Force -ErrorAction SilentlyContinue

                if ($gitProc.ExitCode -eq 0) {
                    Write-Success "Git kurulumu basariyla tamamlandi."
                } else {
                    Write-ErrMsg "Git kurulumu hata kodu dondurdu: $($gitProc.ExitCode)"
                }
            }
        }
    }
}

# 7. PATH ve Ortam Degiskenlerini Guncelle
Update-SessionEnvironment
Start-Sleep -Seconds 2

# 8. Kurulum Dogrulamasi
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Magenta
Write-Host "                  Kurulum Dogrulamasi                     " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Magenta

$nodeCmd = Get-Command "node.exe" -ErrorAction SilentlyContinue
$npmCmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
$gitCmd = Get-Command "git.exe" -ErrorAction SilentlyContinue

if ($nodeCmd) {
    try {
        $finalNodeVer = & node -v 2>$null
        Write-Success "Node.js Calisiyor: $finalNodeVer ($($nodeCmd.Source))"
    } catch {
        Write-ErrMsg "Node.js calistirilamadi: $_"
    }
} else {
    Write-ErrMsg "node.exe PATH icinde bulunamadi! Terminali yeniden baslatmaniz gerekebilir."
}

if ($npmCmd) {
    try {
        $finalNpmVer = & npm -v 2>$null
        Write-Success "npm Calisiyor    : v$finalNpmVer ($($npmCmd.Source))"
    } catch {
        Write-ErrMsg "npm calistirilamadi: $_"
    }
} else {
    Write-ErrMsg "npm PATH icinde bulunamadi! Terminali yeniden baslatmaniz gerekebilir."
}

if (-not $SkipGit) {
    if ($gitCmd) {
        try {
            $finalGitVer = & git --version 2>$null
            Write-Success "Git Calisiyor    : $finalGitVer ($($gitCmd.Source))"
        } catch {
            Write-ErrMsg "Git calistirilamadi: $_"
        }
    } else {
        Write-ErrMsg "git.exe PATH icinde bulunamadi! Terminali yeniden baslatmaniz gerekebilir."
    }
}

# 9. Opsiyonel Paket Yoneticileri (Yarn & pnpm)
if ($InstallYarn) {
    Write-Info "Yarn global paketi kuruluyor..."
    try {
        & npm install -g yarn
        $yarnVer = & yarn -v 2>$null
        Write-Success "Yarn basariyla kuruldu: v$yarnVer"
    } catch {
        Write-WarnMsg "Yarn kurulumu tamamlanamadi: $_"
    }
}

if ($InstallPnpm) {
    Write-Info "pnpm global paketi kuruluyor..."
    try {
        & npm install -g pnpm
        $pnpmVer = & pnpm -v 2>$null
        Write-Success "pnpm basariyla kuruldu: v$pnpmVer"
    } catch {
        Write-WarnMsg "pnpm kurulumu tamamlanamadi: $_"
    }
}

Write-Host ""
Write-Success "Tum kurulum sureci basariyla tamamlandi!"
Write-Info "Yeni bir PowerShell, Windows Terminal veya Komut Istemi (CMD) penceresi acarak 'node -v', 'npm -v' ve 'git --version' komutlarini hemen kullanabilirsiniz."
Write-Host ""

if ($Host.Name -notmatch "ConsoleHost" -or $env:TERM_PROGRAM -eq $null) {
    # Dogrudan cift tiklama ile acilmissa pencerenin aninda kapanmamasi icin bekle
    Write-Host "Kapatmak icin herhangi bir tusa basin..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

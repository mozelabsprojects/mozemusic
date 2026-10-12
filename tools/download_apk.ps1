# MozeMusic Android APK Downloader
# Mozelabs (https://mozelabs.com)

$repo = "mozelabsprojects/mozemusic"
$apiUrl = "https://api.github.com/repos/$repo/releases/latest"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   MozeMusic Android APK Downloader    " -ForegroundColor Magenta
Write-Host "         Powered by Mozelabs           " -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    Write-Host "[1/3] En son sürüm bilgisi alınıyor..." -ForegroundColor Gray
    $release = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "MozeMusic-Downloader" }
    $version = $release.tag_name
    Write-Host "[+] En güncel sürüm bulundu: $version" -ForegroundColor Green

    $apkAsset = $release.assets | Where-Object { $_.name -like "*.apk" } | Select-Object -First 1

    if ($null -eq $apkAsset) {
        $downloadUrl = "https://github.com/$repo/releases/download/$version/MozeMusic-Android.apk"
    } else {
        $downloadUrl = $apkAsset.browser_download_url
    }

    $outputPath = Join-Path (Get-Location) "MozeMusic-$version.apk"
    Write-Host "[2/3] İndiriliyor: $downloadUrl" -ForegroundColor Gray
    Write-Host "Hedef dosya: $outputPath" -ForegroundColor Gray

    Invoke-WebRequest -Uri $downloadUrl -OutFile $outputPath

    Write-Host ""
    Write-Host "[3/3] Başarıyla indirildi! -> $outputPath" -ForegroundColor Green
    Write-Host "Şimdi bu APK dosyasını telefonunuza yükleyebilirsiniz." -ForegroundColor Cyan
}
catch {
    Write-Host "[-] Hata oluştu: $_" -ForegroundColor Red
    Write-Host "Alternatif indirme linki:" -ForegroundColor Yellow
    Write-Host "https://github.com/$repo/releases/latest" -ForegroundColor Cyan
}

Write-Host ""
pause

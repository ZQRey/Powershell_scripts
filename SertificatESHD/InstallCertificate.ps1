param (
    [string]$CertPath = ".\Unified_State_Internet_Access_Gateway.cer"
)

# Проверяем существование файла сертификата
if (-Not (Test-Path -Path $CertPath)) {
    Write-Host "Ошибка: Файл сертификата не найден: $CertPath" -ForegroundColor Red
    exit 1
}

# Отображаем полный путь для проверки
$fullPath = (Resolve-Path $CertPath).Path
Write-Host "Путь к сертификату: $fullPath"

# Импорт сертификата
try {
    $certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $certificate.Import($fullPath)

    # Устанавливаем в хранилище "Root"
    $storeRoot = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "CurrentUser")
    $storeRoot.Open("ReadWrite")
    $storeRoot.Add($certificate)
    $storeRoot.Close()
    Write-Host "✅ Сертификат установлен в 'Доверенные корневые центры сертификации'."

    # Устанавливаем в хранилище "CA"
    $storeCA = New-Object System.Security.Cryptography.X509Certificates.X509Store("CA", "CurrentUser")
    $storeCA.Open("ReadWrite")
    $storeCA.Add($certificate)
    $storeCA.Close()
    Write-Host "✅ Сертификат установлен в 'Промежуточные центры сертификации'."

} catch {
    Write-Host "❌ Ошибка при установке сертификата: $_" -ForegroundColor Red
    exit 1
}

Write-Host "🔹 Установка сертификата завершена успешно." -ForegroundColor Cyan

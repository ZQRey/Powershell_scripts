param (
    [string]$CertPath = ".\Unified_State_Internet_Access_Gateway.cer"
)

# Проверяем существование файла сертификата
if (-Not (Test-Path -Path $CertPath)) {
    Write-Host "Ошибка: Файл сертификата не найден: $CertPath" -ForegroundColor Red
    exit 1
}

# Импортируем сертификат для получения отпечатка
try {
    $certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $certificate.Import((Resolve-Path $CertPath).Path)
    $thumbprint = $certificate.Thumbprint
    Write-Host "Отпечаток сертификата: $thumbprint"
}
catch {
    Write-Host "❌ Ошибка при чтении сертификата: $_" -ForegroundColor Red
    exit 1
}

# Функция удаления сертификата из указанного хранилища
function Remove-CertificateFromStore {
    param (
        [string]$storeName
    )

    try {
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($storeName, "CurrentUser")
        $store.Open("ReadWrite")

        $certToRemove = $store.Certificates | Where-Object { $_.Thumbprint -eq $thumbprint }

        if ($certToRemove) {
            $store.Remove($certToRemove)
            Write-Host "✅ Сертификат успешно удален из хранилища '$storeName'."
        } else {
            Write-Host "⚠️ Сертификат не найден в хранилище '$storeName'."
        }

        $store.Close()
    }
    catch {
        Write-Host "❌ Ошибка при удалении сертификата из хранилища '$storeName': $_" -ForegroundColor Red
    }
}

# Удаляем сертификат из "Root" и "CA"
Remove-CertificateFromStore -storeName "Root"
Remove-CertificateFromStore -storeName "CA"

Write-Host "🔹 Удаление сертификата завершено." -ForegroundColor Cyan
# Данный скрипт отключает смену пароля через интервал

# Проверка модуля ActiveDirectory
$checkAD = Get-Module -ListAvailable ActiveDirectory
if ($checkAD) {
    Write-Host "AD модуль установлен"
} else {
    try {
        # Если не установлен то запускаем установку
        Write-Host "AD модуль не установлен. Запускаю установку."
        $sourcefile = Join-Path -Path $PSScriptRoot -ChildPath "AD_Powershell.msi"
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$sourcefile`" /qn" -Wait
        Write-Host "AD модуль установлен"
    }
    catch {
        try{
            Write-Host "Ошибка установки модуля AD. $_" -ForegroundColor Red
            Write-Host "Пробуем установить из Windows Future"
            Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
        }
        catch {
            Write-Host "Ошибка установки модуля AD. $_" -ForegroundColor Red
        }
    }
}

# Основной процесс
Import-Module ActiveDirectory
try {
    $Identity = Read-Host "Введите имя домена (пример: gp1.loc): "
    $Server = Read-Host "Введите имя контроллера домена (например: dc1): "
    # Устанавливаем максимальный возраст пароля в 0 дней
    Set-ADDefaultDomainPasswordPolicy -Identity $Identity -MaxPasswordAge ([TimeSpan]::FromDays(0)) -Server $Server"."$Identity
    Write-Host "Групповая политика домена успешно обновлена. Пароли больше не требуют смены."
}
catch {
    Write-Error "Произошла ошибка при обновлении политики: $_" -ForegroundColor Red
}

Write-Host "Обновление политики на сервере"
Invoke-Command -ComputerName $Server -ScriptBlock {GPUpdate /force} -ErrorAction Stop

Write-Host "Обновление политики на компьютере"
GPUpdate /force

Write-Host "Операция успешно выполнена"
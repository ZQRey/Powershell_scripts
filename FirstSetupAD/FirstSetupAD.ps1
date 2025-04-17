# Скрипт первоначальной настройки домен контроллера с DNS

# Проверка наличия прав администратора
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "Скрипт необходимо запускать от имени администратора." -ForegroundColor Red
    exit
}

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
            Write-Host "Ошибка установки модуля AD с помощью файла"
            Write-Host "Пробуем установить из Windows Future"
            Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
        }
        catch {
            Write-Host "Ошибка установки модуля AD по сети"
            Write-Host "AD модуль не установлен. Если вы хотите управлять домен контролером через powershell необходимо установить этот модуль вручную."
        }
    }
}



# Переименование компьютера
Rename-Computer -NewName "dc01" -Force -Restart:$false
Write-Host "Компьютер переименован в dc01."

# Настройка статического IP и шлюза
# Необходимо изменить имя сетевого интерфейса (например, "Ethernet") если требуется.
$InterfaceAlias = "Ethernet"
$ipAddress      = "192.168.1.5"
$prefixLength   = 24
$defaultGateway = "192.168.1.1"
$dnsServers     = @("192.168.1.5", "8.8.8.8")

try {
    # Устанавливаем статический IP и шлюз
    New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $ipAddress `
                     -PrefixLength $prefixLength -DefaultGateway $defaultGateway `
                     -AddressFamily IPv4 -ErrorAction Stop
    Write-Host "Статический IP $ipAddress и шлюз $defaultGateway установлены для интерфейса $InterfaceAlias."
} catch {
    Write-Host "Ошибка установки IP-адреса: $_" -ForegroundColor Red
    exit
}

try {
    # Устанавливаем DNS-серверы
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $dnsServers -ErrorAction Stop
    Write-Host "DNS-серверы для интерфейса $InterfaceAlias установлены: $($dnsServers -join ', ')."
} catch {
    Write-Host "Ошибка установки DNS-серверов: $_" -ForegroundColor Red
}

# Установка роли AD Domain Services
try {
    Write-Host "Устанавливаю роль Active Directory Domain Services..."
    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools -Verbose -ErrorAction Stop
    Write-Host "Роль AD Domain Services успешно установлена."
} catch {
    Write-Host "Ошибка установки роли AD DS: $_" -ForegroundColor Red
    exit
}

# Установка доменного контроллера с созданием нового леса
# Пароль для режима восстановления каталога (DSRM). Заменить значение на требуемый безопасный пароль.
$dsrmPasswordPlain = "P@ssw0rd!"  
$dsrmPassword = ConvertTo-SecureString $dsrmPasswordPlain -AsPlainText -Force

try {
    Write-Host "Запускаю установку нового леса с доменом gp1.loc..."
    Install-ADDSForest `
        -DomainName "gp1.loc" `
        -SafeModeAdministratorPassword $dsrmPassword `
        -InstallDns `
        -Force:$true `
        -NoRebootOnCompletion:$false `
        -Verbose
} catch {
    Write-Host "Ошибка установки доменного контроллера: $_" -ForegroundColor Red
    exit
}

Write-Host "Необходимо перезапустить сервер! И проверить всё ли работает!"

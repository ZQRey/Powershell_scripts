# ============================
# Настраиваем переменные
# ============================
$FileServerName    = "fileserver"         # Имя файлового сервера
$DomainController  = "dc01"               # Имя доменного контроллера (SYSVOL находится на dc01)
$DomainName        = "gp1.loc"            # Имя домена
$targetOU          = "DC=gp1,DC=loc"       # Применяем GPO ко всему домену

# ============================
# 1. Установка роли файлового сервера
# ============================
Write-Host "Устанавливаю роль файлового сервера..."
Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools -Verbose
Add-WindowsFeature GPMC

# ============================
# 2. Создание необходимых папок на диске F:
# ============================
$folders = @("ALL_ACCSES", "SOFTWARE", "USER_DATA")
foreach ($folder in $folders) {
    $folderPath = "F:\$folder"
    if (-not (Test-Path $folderPath)) {
        Write-Host "Создаю папку: $folderPath"
        New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
    }
    else {
        Write-Host "Папка $folderPath уже существует."
    }
}

# ============================
# 3. Создание SMB-расшариваний
# ============================
Write-Host "Создаю SMB-расшаривания..."

# ALL_ACCSES – общий доступ с полными правами для всех
New-SmbShare -Name "ALL_ACCSES" -Path "F:\ALL_ACCSES" -FullAccess "Все" -ErrorAction Stop

# SOFTWARE – доступ на чтение для всех
New-SmbShare -Name "SOFTWARE" -Path "F:\SOFTWARE" -ReadAccess "Все" -ErrorAction Stop

# USER_DATA – расшаривание для пользовательских данных с Access Based Enumeration
New-SmbShare -Name "USER_DATA" -Path "F:\USER_DATA" -FolderEnumerationMode AccessBased -FullAccess "Администраторы домена" -ErrorAction Stop

# ============================
# 4. Установка FS-Resource-Manager и настройка квот
# ============================
Write-Host "Устанавливаю FS-Resource-Manager..."
Install-WindowsFeature -Name FS-Resource-Manager -IncludeManagementTools -Verbose

# Попытка загрузить модуль FSrm. Если не найден, пробуем добавить PSSnapin FSrm.
if (-not (Get-Module -ListAvailable -Name FSrm)) {
    Write-Host "Модуль FSrm не найден. Пытаюсь добавить PSSnapin FSrm..."
    try {
        Add-PSSnapin FSrm -ErrorAction Stop
        Write-Host "PSSnapin FSrm успешно добавлен."
    } catch {
        Write-Host "Не удалось добавить PSSnapin FSrm. Убедитесь, что FS-Resource-Manager установлен." -ForegroundColor Red
    }
} else {
    Import-Module FSrm
}

# Создание шаблона квоты для пользовательских папок (20GB), если его ещё нет
$templateName = "UserFolderQuota"
$template = Get-FsrmQuotaTemplate -Name $templateName -ErrorAction SilentlyContinue
if (-not $template) {
    Write-Host "Создаю шаблон квоты '$templateName' с лимитом 20GB..."
    New-FsrmQuotaTemplate -Name $templateName -Size 20GB -Description "Квота для пользовательских папок (20GB)"
} else {
    Write-Host "Шаблон квоты '$templateName' уже существует."
}

# Применение шаблона квоты к папке USER_DATA для автоматического применения к новым подпапкам
$quotaPath = "F:\USER_DATA"
$existingQuota = Get-FsrmQuota -Path $quotaPath -ErrorAction SilentlyContinue
if (-not $existingQuota) {
    Write-Host "Применяю шаблон квоты к папке $quotaPath..."
    New-FsrmQuota -Path $quotaPath -Template $templateName -Description "Автоквота для пользовательских папок" -ErrorAction SilentlyContinue
} else {
    Write-Host "Квота для папки $quotaPath уже настроена."
}

# ============================
# 5. Создание логон-скрипта для маппинга диска и создания ярлыка
# ============================
$logonScriptPath = "C:\Scripts\MapUserFolder.ps1"
$logonScriptFolder = Split-Path $logonScriptPath
if (-not (Test-Path $logonScriptFolder)) {
    New-Item -ItemType Directory -Path $logonScriptFolder -Force | Out-Null
}

$logonScriptContent = @'
# Логон-скрипт для подключения сетевого диска и создания ярлыка на рабочем столе
$UserFolder = "\\fileserver\USER_DATA\" + $env:USERNAME

# Мапим диск U:
New-PSDrive -Name U -PSProvider FileSystem -Root $UserFolder -Persist

# Создаем ярлык на рабочем столе
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopPath "Моя папка пользователя.lnk"

$wshShell = New-Object -ComObject WScript.Shell
$shortcut = $wshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $UserFolder
$shortcut.WindowStyle = 1
$shortcut.IconLocation = "shell32.dll, 1"
$shortcut.Description = "Папка пользователя на файловом сервере"
$shortcut.Save()
'@

Set-Content -Path $logonScriptPath -Value $logonScriptContent -Encoding UTF8
Write-Host "Логон-скрипт создан по пути: $logonScriptPath"
Write-Host "Для автоматического подключения диска и создания ярлыка данный скрипт будет назначен через GPO."
# ============================
# 6. Создание и настройка GPO для назначения логон-скрипта
# ============================
if (-not (Get-Module -ListAvailable -Name GroupPolicy)) {
    Write-Host "Модуль GroupPolicy не найден. Убедитесь, что установлены RSAT Group Policy Management Tools." -ForegroundColor Yellow
} else {
    Import-Module GroupPolicy
    $gpoName = "User Logon Script"
    $gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
    if (-not $gpo) {
        Write-Host "Создаю GPO '$gpoName' для назначения логон-скрипта..."
        $gpo = New-GPO -Name $gpoName -Comment "GPO для назначения логон-скрипта (мапинг диска и ярлык на рабочем столе)"
    } else {
        Write-Host "GPO '$gpoName' уже существует."
    }

    Write-Host "Линкую GPO '$gpoName' ко всему домену: $targetOU"
    New-GPLink -Name $gpoName -Target $targetOU -Enforced No

    Write-Host "Настраиваю фильтрацию безопасности: применять политику только к группе 'Domain Users'"
    Set-GPPermissions -Name $gpoName -TargetName "Пользователи домена" -TargetType Group -PermissionLevel GpoApply -ErrorAction SilentlyContinue

    $gpoGuid = $gpo.Id.ToString()
    $sysvolPath = "\\$DomainController\SYSVOL\$DomainName\Policies\{$gpoGuid}\User\Scripts\Logon"
    if (-not (Test-Path $sysvolPath)) {
        New-Item -Path $sysvolPath -ItemType Directory -Force | Out-Null
    }

    try {
        Copy-Item -Path $logonScriptPath -Destination $sysvolPath -Force
    } catch {
        Write-Host "Ошибка копирования логон-скрипта в SYSVOL: $_" -ForegroundColor Red
    }

    $scriptIniPath = Join-Path $sysvolPath "script.ini"
    $iniContent = @"
[Logon]
0CmdLine=MapUserFolder.ps1
0Parameters=
"@
    try {
        Set-Content -Path $scriptIniPath -Value $iniContent -Encoding UTF8
        Write-Host "Логон-скрипт назначен в GPO '$gpoName'."
    } catch {
        Write-Host "Ошибка записи файла script.ini: $_" -ForegroundColor Red
    }
}

Write-Host "Настройка файлового сервера завершена."

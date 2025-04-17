# Путь к .msi-файлу
$msiPath = "\\fileserver\SOFTWARE\commfort_client.msi"

# Путь установки по умолчанию
$installDir = "C:\Program Files (x86)\CommFort"

$securePass = ConvertTo-SecureString "Password" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential("pol4\name", $securePass)

Start-Process msiexec.exe -Credential $cred -ArgumentList "/i `"$msiPath`" /passive /norestart" -Wait

# Установка в тихом режиме
#Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /passive /norestart" -Wait

# Ждём немного (если нужно)
Start-Sleep -Seconds 3

# Создание ярлыка на рабочем столе
$WshShell = New-Object -ComObject WScript.Shell
$desktopPath = [Environment]::GetFolderPath('Desktop')
$shortcut = $WshShell.CreateShortcut("$desktopPath\CommFort.lnk")
$shortcut.TargetPath = "$installDir\CommFort.exe"
$shortcut.WorkingDirectory = "$installDir"
$shortcut.WindowStyle = 1
$shortcut.Save()

# Путь к пользовательскому профилю
$userProfile = [Environment]::GetFolderPath("ApplicationData")
$configPath = Join-Path $userProfile "CommFort\Default\Config"

# Создание структуры папок
New-Item -ItemType Directory -Path $configPath -Force | Out-Null

# Создание файла Network.ini
$networkIni = @"
[Main]
Server_address=commfort
Client_TCP_port=30700
Client_UDP_port=31700

[Proxy]
Enabled=0
Address=
Port=1080
Authentication=0
Login=
Password=
"@
$networkIni | Set-Content -Path (Join-Path $configPath "Network.ini") -Encoding UTF8

# Создание файла ServerList.txt
"commfort" | Set-Content -Path (Join-Path $configPath "ServerList.txt") -Encoding UTF8

Write-Host "Установка и настройка завершены успешно."

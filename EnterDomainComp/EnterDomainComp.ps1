# Задайте имя домена и (опционально) путь к организационной единице (OU)
$domainName = "gp1.loc"
# Если требуется указать конкретный OU, раскомментируйте и задайте корректный путь
#$ouPath = "OU=Servers,DC=gp1,DC=loc"

# Запрашиваем учетные данные домена
$credential = Get-Credential -Message "Введите учетные данные домена $domainName"

# Присоединение компьютера к домену
try {
    # Если не используется OU, используйте следующую команду:
    Add-Computer -DomainName $domainName -Credential $credential -ErrorAction Stop
    
    # Если требуется присоединение с указанием OU, используйте:
    # Add-Computer -DomainName $domainName -OUPath $ouPath -Credential $credential -ErrorAction Stop

    Write-Host "Компьютер успешно добавлен в домен $domainName. Перезагрузка..."
    Restart-Computer -Force
}
catch {
    Write-Error "Не удалось добавить компьютер в домен: $_"
}
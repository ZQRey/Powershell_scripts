Write-Host "Проверка доступности доменного контроллера..."
Get-ADDomainController -Discover

Write-Host "Проверка служб Active Directory (статус должен быть Running)..."
Get-Service adws,kdc,netlogon,dns

Write-Host "Проверка, что ключевые папки расшарены (SYSVOL и Netlogon)..."
Get-SmbShare

Write-Host "Проверка последних событий в Event Viewer от служб ADDS..."
Get-EventLog "Directory Service" -Newest 10 | Select-Object EntryType, Source, EventID, Message
Get-EventLog "Active Directory Web Services" -Newest 10 | Select-Object EntryType, Source, EventID, Message

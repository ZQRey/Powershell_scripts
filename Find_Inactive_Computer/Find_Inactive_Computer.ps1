# Находим неактивные компьютеры
$ComputerCollection = Get-ADComputer -Filter * -Properties lastlogondate

$Date = New-Object System.DateTime 
$Date = Get-Date
#Количество дней. (Будут показаны компьютеры последний вход которых был выполнен более указанных дней)
$DayExpire = 15 
$Date = $Date.AddDays($DayExpire - $DayExpire * 2) #Перевод в отрицательное значение
$NumberComputerFound = 0

FOREACH ($Computer in $ComputerCollection)
{
IF ($Computer.lastlogondate -lt $date) 
{
Write-Host '-----'
Write-Host $Computer.Name  ' последний вход '  $Computer.LastLogonDate.DateTime
$NumberComputerFound++
}
}
Write-Host 'Всего компьютеров: '  $NumberComputerFound
pause
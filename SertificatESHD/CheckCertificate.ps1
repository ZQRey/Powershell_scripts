# Проверка хранилища "Root"
Get-ChildItem -Path Cert:\CurrentUser\Root | Where-Object { $_.Thumbprint -eq "25D54593985C423F63C23733DDEA8A16705CC8A4" }

# Проверка хранилища "CA"
Get-ChildItem -Path Cert:\CurrentUser\CA | Where-Object { $_.Thumbprint -eq "25D54593985C423F63C23733DDEA8A16705CC8A4" }

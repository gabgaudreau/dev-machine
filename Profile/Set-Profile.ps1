# from this file's directory
# run as admin

$defaultProfilePath = "C:\Windows\System32\WindowsPowerShell\v1.0\Profile.ps1"
Copy-Item .\Profile.ps1 $defaultProfilePath -Force
Write-Host $defaultProfilePath "is set."

$vsCodeProfilePath = "C:\Users\gabri\OneDrive\Documents\PowerShell\Microsoft.VSCode_profile.ps1"
Copy-Item .\Profile.ps1 $vsCodeProfilePath -Force
Write-Host $vsCodeProfilePath "is set."

$ohMyPoshThemePath = "C:\Users\gabri\AppData\Local\Programs\oh-my-posh\themes\ggaudreau.omp.json"
Copy-Item .\ggaudreau.omp.json C:\Users\gabri\AppData\Local\Programs\oh-my-posh\themes\ggaudreau.omp.json -Force
Write-Host $ohMyPoshThemePath "is set."

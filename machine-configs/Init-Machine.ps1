# run script as admin

Install-Module posh-git
Install-Module Terminal-Icons

if (!$PSScriptRoot) {
    Write-Error "Please run the file, not its content."
    return;
}

# WSL
# Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

# numlock to on
Set-ItemProperty -Path 'Registry::HKU\.DEFAULT\Control Panel\Keyboard' -Name "InitialKeyboardIndicators" -Value "2"

# installs
winget install Microsoft.AzureCLI
winget install --id=GoLang.Go  -e
winget install Git.Git
winget install JanDeDobbeleer.OhMyPosh
winget install Microsoft.VisualStudioCode
winget install pwsh
winget install --id=Hashicorp.Terraform  -e
winget install --id=Kubernetes.kubectl  -e
winget install Docker.DockerDesktop

# git configs
git config --global core.editor "code --wait"
git config --global user.name "Gabriel Gaudreau"
git config --global user.email "gabriel.gaudreau23@hotmail.com"

# chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# nuget
if(-not (Test-Path 'C:\Tools')){ New-Item 'C:\Tools' -ItemType Directory;[System.Environment]::SetEnvironmentVariable("Path", "$([System.Environment]::GetEnvironmentVariable("Path", "User"));C:\Tools", "User") }
Invoke-WebRequest -Uri https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile 'C:\Tools\Nuget.exe'; 

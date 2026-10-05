#requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Distro,

    [Parameter()]
    [string]$DesktopFolderName = 'BloodHound-CE',

    [Parameter()]
    [switch]$InstallWslIfMissing,

    [Parameter()]
    [switch]$NoDesktopControls,

    [Parameter()]
    [switch]$NoStart,

    [Parameter()]
    [switch]$OpenBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:BhConfigDirectory = $null
$script:BhUrl = 'http://127.0.0.1:8080/ui/login'

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WslDistributions {
    $raw = & wsl.exe --list --quiet 2>$null
    if ($LASTEXITCODE -ne 0) {
        return @()
    }

    return @(
        $raw |
            ForEach-Object { ($_ -replace "`0", '').Trim() } |
            Where-Object { $_ -and $_ -notmatch '^docker-desktop(-data)?$' }
    )
}

function Select-WslDistribution {
    param(
        [string]$Requested,
        [string[]]$Available
    )

    if ($Requested) {
        $match = $Available | Where-Object { $_ -ieq $Requested } | Select-Object -First 1
        if (-not $match) {
            throw "La distribución WSL '$Requested' no existe. Disponibles: $($Available -join ', ')"
        }
        return $match
    }

    foreach ($preferred in @('kali-linux', 'Ubuntu-24.04', 'Ubuntu-22.04', 'Ubuntu', 'Debian')) {
        $match = $Available | Where-Object { $_ -ieq $preferred } | Select-Object -First 1
        if ($match) {
            return $match
        }
    }

    return $Available[0]
}

function ConvertTo-Base64Utf8 {
    param([Parameter(Mandatory)][string]$Text)
    return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Text))
}

function Invoke-WslBash {
    param(
        [Parameter(Mandatory)][string]$Script,
        [switch]$AsInstallUser,
        [switch]$Capture
    )

    $encoded = ConvertTo-Base64Utf8 -Text $Script
    $bootstrap = "echo '$encoded' | base64 -d | bash"
    $runAsUser = if ($AsInstallUser) { $script:LinuxUser } else { 'root' }

    if ($Capture) {
        $output = & wsl.exe -d $script:SelectedDistro -u $runAsUser -- bash -lc $bootstrap 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            throw "Falló una operación dentro de WSL (código $exitCode): $($output -join [Environment]::NewLine)"
        }
        return ($output -join "`n").Trim()
    }

    & wsl.exe -d $script:SelectedDistro -u $runAsUser -- bash -lc $bootstrap
    if ($LASTEXITCODE -ne 0) {
        throw "Falló una operación dentro de WSL (código $LASTEXITCODE)."
    }
}

function Wait-BloodHound {
    param([int]$TimeoutSeconds = 120)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        try {
            $response = Invoke-WebRequest -Uri $script:BhUrl -UseBasicParsing -TimeoutSec 4
            if ($response.StatusCode -eq 200) {
                return $true
            }
        }
        catch {
            Start-Sleep -Seconds 2
        }
    } while ((Get-Date) -lt $deadline)

    return $false
}

function Install-DesktopControls {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $folder = Join-Path $desktop $DesktopFolderName
    New-Item -ItemType Directory -Path $folder -Force | Out-Null

    $escapedDistro = $script:SelectedDistro.Replace('"', '""')
    $escapedLinuxUser = $script:LinuxUser.Replace('"', '""')
    $escapedConfigDirectory = $script:BhConfigDirectory.Replace('"', '\"')

    $start = @'
@echo off
chcp 65001 >nul
title HoundForge - Start
echo [*] Iniciando Docker y BloodHound CE...
wsl.exe -d "__DISTRO__" -u root -- bash -lc "systemctl start docker 2>/dev/null || service docker start"
if errorlevel 1 goto error
wsl.exe -d "__DISTRO__" -u "__LINUX_USER__" -- bloodhound-cli up
if errorlevel 1 goto error
timeout /t 5 /nobreak >nul
start "" http://127.0.0.1:8080/ui/login
echo [+] BloodHound disponible en http://127.0.0.1:8080/ui/login
exit /b 0
:error
echo [-] BloodHound could not be started. Run 02-Status.cmd for details.
pause
exit /b 1
'@.Replace('__DISTRO__', $escapedDistro).Replace('__LINUX_USER__', $escapedLinuxUser)

    $status = @'
@echo off
chcp 65001 >nul
title HoundForge - Status
echo === SERVICIOS ===
wsl.exe -d "__DISTRO__" -u "__LINUX_USER__" -- bloodhound-cli running
echo.
echo === INTERFAZ LOCAL ===
curl.exe -sS -o NUL -w "HTTP %%{http_code} - %%{size_download} bytes" http://127.0.0.1:8080/ui/login
echo.
echo URL: http://127.0.0.1:8080/ui/login
pause
'@.Replace('__DISTRO__', $escapedDistro).Replace('__LINUX_USER__', $escapedLinuxUser)

    $credentials = @'
@echo off
chcp 65001 >nul
title HoundForge - Local credentials
echo These credentials are displayed only on this computer.
powershell.exe -NoProfile -Command "$j = ((wsl.exe -d '__DISTRO__' -u '__LINUX_USER__' -- cat '__CONFIG_DIRECTORY__/bloodhound.config.json') -join [Environment]::NewLine) | ConvertFrom-Json; Write-Host ('Usuario: ' + $j.default_admin.principal_name); Write-Host ('Password: ' + $j.default_admin.password)"
pause
'@.Replace('__DISTRO__', $escapedDistro).Replace('__LINUX_USER__', $escapedLinuxUser).Replace('__CONFIG_DIRECTORY__', $escapedConfigDirectory)

    $stop = @'
@echo off
chcp 65001 >nul
title HoundForge - Stop
echo [*] Stopping BloodHound CE...
wsl.exe -d "__DISTRO__" -u "__LINUX_USER__" -- bloodhound-cli down
if errorlevel 1 goto error
echo [+] BloodHound stopped. Data has been preserved.
pause
exit /b 0
:error
echo [-] The containers could not be stopped.
pause
exit /b 1
'@.Replace('__DISTRO__', $escapedDistro).Replace('__LINUX_USER__', $escapedLinuxUser)

    $readme = @"
HoundForge
==========

Interface: $($script:BhUrl)
WSL distribution: $($script:SelectedDistro)
Linux user: $($script:LinuxUser)

01-Start.cmd       Starts Docker and BloodHound, then opens the browser.
02-Status.cmd      Shows container status and checks the local interface.
03-Credentials.cmd Displays credentials only on this computer.
04-Stop.cmd        Stops the services without deleting data.

The interface and Neo4j ports are bound only to 127.0.0.1.
PostgreSQL is not published to the host. Data persists in Docker volumes.
Linux configuration: $($script:BhConfigDirectory)
"@

    Set-Content -LiteralPath (Join-Path $folder '01-Start.cmd') -Value $start -Encoding Ascii
    Set-Content -LiteralPath (Join-Path $folder '02-Status.cmd') -Value $status -Encoding Ascii
    Set-Content -LiteralPath (Join-Path $folder '03-Credentials.cmd') -Value $credentials -Encoding Ascii
    Set-Content -LiteralPath (Join-Path $folder '04-Stop.cmd') -Value $stop -Encoding Ascii
    Set-Content -LiteralPath (Join-Path $folder 'README.txt') -Value $readme -Encoding UTF8

    Write-Success "Controles creados en: $folder"
}

Write-Step 'Comprobando Windows y WSL'
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    if (-not $InstallWslIfMissing) {
        throw 'WSL no está disponible. Ejecute nuevamente con -InstallWslIfMissing desde PowerShell como administrador.'
    }
    if (-not (Test-IsAdministrator)) {
        throw 'La instalación de WSL requiere PowerShell como administrador.'
    }

    Write-Step 'Instalando WSL y Ubuntu'
    & wsl.exe --install -d Ubuntu
    if ($LASTEXITCODE -ne 0) {
        throw "No fue posible instalar WSL (código $LASTEXITCODE)."
    }
    Write-Warning 'Windows puede requerir reinicio o completar la inicialización de Ubuntu. Después, ejecute este script nuevamente.'
    exit 0
}

[string[]]$availableDistros = @(Get-WslDistributions)
if ($availableDistros.Count -eq 0) {
    if (-not $InstallWslIfMissing) {
        throw 'No hay distribuciones WSL instaladas. Use -InstallWslIfMissing o instale Kali/Ubuntu/Debian y vuelva a ejecutar el script.'
    }
    if (-not (Test-IsAdministrator)) {
        throw 'La instalación de una distribución WSL requiere PowerShell como administrador.'
    }

    Write-Step 'Instalando Ubuntu en WSL'
    & wsl.exe --install -d Ubuntu
    if ($LASTEXITCODE -ne 0) {
        throw "No fue posible instalar Ubuntu (código $LASTEXITCODE)."
    }
    Write-Warning 'Complete la inicialización de Ubuntu y ejecute este script nuevamente.'
    exit 0
}

$script:SelectedDistro = Select-WslDistribution -Requested $Distro -Available $availableDistros
Write-Success "Distribución seleccionada: $($script:SelectedDistro)"

$kernel = (& wsl.exe -d $script:SelectedDistro -- uname -r 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo iniciar la distribución '$($script:SelectedDistro)'."
}
if ($kernel -notmatch '(?i)microsoft-standard.*wsl2|wsl2') {
    throw "La distribución '$($script:SelectedDistro)' no parece usar WSL2. Ejecute: wsl --set-version `"$($script:SelectedDistro)`" 2"
}

$script:LinuxUser = (& wsl.exe -d $script:SelectedDistro -- id -un 2>$null | Out-String).Trim()
$script:LinuxHome = (& wsl.exe -d $script:SelectedDistro -- sh -lc 'printf %s "$HOME"' 2>$null | Out-String).Trim()
if (-not $script:LinuxUser -or -not $script:LinuxHome -or $script:LinuxHome[0] -ne '/') {
    throw 'No fue posible determinar el usuario y directorio personal predeterminados de WSL.'
}
$script:BhConfigDirectory = "$($script:LinuxHome)/.config/bloodhound"
Write-Success "Usuario de instalación: $($script:LinuxUser) ($($script:LinuxHome))"

$memoryGb = [math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1MB, 1)
if ($memoryGb -lt 8) {
    Write-Warning "El equipo tiene $memoryGb GB de RAM; BloodHound CE recomienda al menos 8 GB."
}

$systemInfo = Invoke-WslBash -Capture -Script @'
set -e
command -v apt-get >/dev/null 2>&1 || { echo UNSUPPORTED_PACKAGE_MANAGER; exit 40; }
. /etc/os-release
printf '%s|%s|%s\n' "$ID" "${VERSION_ID:-unknown}" "$(uname -m)"
'@
if ($systemInfo -match 'UNSUPPORTED_PACKAGE_MANAGER') {
    throw 'Esta versión admite Kali, Debian y Ubuntu (distribuciones con apt-get).'
}
Write-Success "Linux detectado: $systemInfo"

Write-Step 'Instalando o actualizando Docker dentro de WSL'
Invoke-WslBash -Script @'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y docker.io curl ca-certificates tar
if ! docker compose version >/dev/null 2>&1; then
    apt-get install -y docker-compose-v2 2>/dev/null || \
    apt-get install -y docker-compose-plugin 2>/dev/null || \
    apt-get install -y docker-compose
fi
if command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
    systemctl enable --now docker
else
    service docker start
fi
docker version >/dev/null
docker compose version
'@

if ($script:LinuxUser -ne 'root') {
    & wsl.exe -d $script:SelectedDistro -u root -- usermod -aG docker $script:LinuxUser
    if ($LASTEXITCODE -ne 0) {
        throw "No fue posible agregar '$($script:LinuxUser)' al grupo docker."
    }
}

Write-Step 'Instalando BloodHound CLI oficial'
Invoke-WslBash -Script @'
set -euo pipefail
case "$(uname -m)" in
    x86_64) cli_arch=amd64 ;;
    aarch64|arm64) cli_arch=arm64 ;;
    *) echo "Arquitectura no soportada: $(uname -m)" >&2; exit 41 ;;
esac
archive="/tmp/bloodhound-cli-linux-${cli_arch}.tar.gz"
curl -fL "https://github.com/SpecterOps/bloodhound-cli/releases/latest/download/bloodhound-cli-linux-${cli_arch}.tar.gz" -o "$archive"
tar -tzf "$archive" | grep -qx bloodhound-cli
tar -xzf "$archive" -C /usr/local/bin bloodhound-cli
chmod 0755 /usr/local/bin/bloodhound-cli
'@

Invoke-WslBash -AsInstallUser -Script 'bloodhound-cli version'

Write-Step 'Configurando y desplegando BloodHound CE'
Invoke-WslBash -AsInstallUser -Script @'
set -euo pipefail
umask 077
config_directory="$HOME/.config/bloodhound"
mkdir -p "$config_directory"
bloodhound-cli config set bind_addr 0.0.0.0:8080 >/dev/null
if test -f "$config_directory/docker-compose.yml"; then
    bloodhound-cli up
else
    bloodhound-cli install > "$config_directory/install.log" 2>&1
fi
chmod 0600 "$config_directory/bloodhound.config.json"
test ! -f "$config_directory/install.log" || chmod 0600 "$config_directory/install.log"
ports="$(docker ps --filter label=name=bhce_bloodhound --format '{{.Ports}}')"
printf '%s\n' "$ports" | grep -q '127.0.0.1:8080->8080'
all_ports="$(docker ps --format '{{.Ports}}')"
if printf '%s\n' "$all_ports" | grep -Eq '(^|, )(0\.0\.0\.0|\[::\]):'; then
    echo 'Se detectó un puerto Docker publicado en todas las interfaces.' >&2
    exit 42
fi
'@

if (-not $NoDesktopControls) {
    Write-Step 'Creando controles en el escritorio'
    Install-DesktopControls
}

if ($NoStart) {
    Write-Step 'Deteniendo los contenedores por solicitud'
    Invoke-WslBash -AsInstallUser -Script 'bloodhound-cli down'
}
else {
    Write-Step 'Esperando a que la interfaz responda'
    if (-not (Wait-BloodHound -TimeoutSeconds 120)) {
        throw "Los contenedores arrancaron, pero la interfaz no respondió en $($script:BhUrl). Revise 02-Status.cmd o ejecute 'bloodhound-cli logs' dentro de WSL."
    }
    Write-Success "BloodHound CE responde en $($script:BhUrl)"
}

if ($OpenBrowser -and -not $NoStart) {
    Start-Process $script:BhUrl
}

Write-Host ''
Write-Success 'Instalación completada.'
Write-Host "URL: $($script:BhUrl)"
if (-not $NoDesktopControls) {
    Write-Host "Credenciales: abra '$DesktopFolderName\03-Credentials.cmd' en el escritorio."
}

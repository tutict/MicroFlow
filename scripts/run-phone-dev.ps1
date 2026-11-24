<#
.SYNOPSIS
  Runs a debug Android build through the real pairing and login flows.
.DESCRIPTION
  A new backend uses a seeded development DB and random persisted JWT/AES keys
  under the gitignored .codex-tmp directory. An existing backend is reused
  without changing its seed, keys or database. Backend startup stays hidden.
.PARAMETER ServerHost
  IPv4 address or DNS hostname reachable from the phone. Required when multiple
  active physical interfaces with default gateways have usable IPv4 addresses.
.EXAMPLE
  .\scripts\run-phone-dev.ps1 -ServerHost 192.168.1.20 -ServerPort 8081
#>
param(
    [string]$Device = '',
    [ValidateRange(1, 65535)][int]$ServerPort = 8080,
    [string]$ServerHost = '',
    [string]$Email = 'demo@microflow.local',
    [string]$Password = 'demo12345'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BackendDir = Join-Path $ProjectRoot 'backend'
$FrontendDir = Join-Path $ProjectRoot 'frontend'

function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }

Write-Step 'Selecting the host address reachable from the phone'
if ([string]::IsNullOrWhiteSpace($ServerHost)) {
    $physicalIndexes = @(Get-NetAdapter -Physical -ErrorAction Stop |
        Where-Object { $_.Status -eq 'Up' -and $_.HardwareInterface } |
        Select-Object -ExpandProperty InterfaceIndex)
    $gatewayIndexes = @(Get-NetIPConfiguration -ErrorAction Stop |
        Where-Object { $_.InterfaceIndex -in $physicalIndexes -and $_.IPv4DefaultGateway.NextHop } |
        Select-Object -ExpandProperty InterfaceIndex)
    $candidates = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
        Where-Object {
            $_.InterfaceIndex -in $gatewayIndexes -and $_.AddressState -eq 'Preferred' -and
            -not $_.SkipAsSource -and $_.IPAddress -notmatch '^(127\.|169\.254\.|0\.)'
        } | Select-Object -ExpandProperty IPAddress -Unique)
    if ($candidates.Count -ne 1) {
        throw 'Cannot choose a unique physical LAN address with a default gateway. Pass -ServerHost <phone-reachable-host-ip> (and -ServerPort <port> if needed).'
    }
    $ServerHost = $candidates[0]
}
$ServerHost = $ServerHost.Trim()
if ($ServerHost -notmatch '^[a-zA-Z0-9][a-zA-Z0-9.-]*$' -or
    $ServerHost -match '^(localhost$|127\.|0\.|169\.254\.)') {
    throw '-ServerHost must be a phone-reachable IPv4 address or DNS hostname, without a scheme, path or port.'
}
$serverUrl = "http://${ServerHost}:${ServerPort}"
$apiUrl = "$serverUrl/api/v1"
$wsUrl = "ws://${ServerHost}:${ServerPort}/ws"
Write-Host "    phone backend: $serverUrl"

$existing = Get-NetTCPConnection -LocalPort $ServerPort -State Listen -ErrorAction SilentlyContinue
if ($existing) {
    Write-Step "Reusing the backend at port $ServerPort without changing its data or configuration"
    Write-Host '    Use -Email/-Password for an existing account if the demo seed is absent.'
} else {
    $MavenWrapper = Join-Path $ProjectRoot 'mvnw.cmd'
    if (-not (Test-Path -LiteralPath $MavenWrapper -PathType Leaf)) {
        $MavenWrapper = Join-Path $BackendDir 'mvnw.cmd'
    }
    if (-not (Test-Path -LiteralPath $MavenWrapper -PathType Leaf)) {
        throw 'The project Maven wrapper was not found at the project root or backend directory.'
    }
    $LogDir = Join-Path $ProjectRoot ".codex-tmp/phone-dev-$ServerPort"
    $BackendLog = Join-Path $LogDir 'backend.log'
    $SettingsPath = Join-Path $LogDir 'settings.json'
    $HelperPath = Join-Path $PSScriptRoot 'run-phone-dev-backend.ps1'
    $PowerShellPath = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $PowerShellPath)) { $PowerShellPath = Join-Path $PSHOME 'pwsh.exe' }
    Write-Step 'Starting the backend with isolated development data and persisted random keys'
    # Windows paths cannot contain double quotes. Quote individual -File argument
    # values so spaces and apostrophes remain literal; no command string is built.
    $processArguments = @(
        '-NoProfile', '-File', ('"{0}"' -f $HelperPath),
        '-MavenWrapper', ('"{0}"' -f $MavenWrapper),
        '-BackendDir', ('"{0}"' -f $BackendDir),
        '-SettingsPath', ('"{0}"' -f $SettingsPath),
        '-BackendLog', ('"{0}"' -f $BackendLog),
        '-ServerHost', $ServerHost, '-ServerPort', $ServerPort.ToString()
    )
    Start-Process -FilePath $PowerShellPath -ArgumentList $processArguments -WindowStyle Hidden | Out-Null
    Write-Host "    backend log: $BackendLog"
}

Write-Step 'Waiting for the local pairing challenge'
$challenge = $null
$deadline = (Get-Date).AddSeconds(120)
while ((Get-Date) -lt $deadline -and -not $challenge) {
    try {
        $response = Invoke-RestMethod -Uri "http://127.0.0.1:${ServerPort}/api/v1/bootstrap/challenge" -TimeoutSec 5
        if ($response.pairingCode) { $challenge = $response }
    } catch {
        # Readiness polling is local and only reads the current challenge.
    }
    if (-not $challenge) { Start-Sleep -Seconds 3 }
}
if (-not $challenge) {
    throw "Backend did not answer on port $ServerPort within 120s. Check .codex-tmp/phone-dev-$ServerPort/backend.log or the existing backend's log."
}
if ($challenge.serverOrigin.TrimEnd('/') -ne $serverUrl -or
    $challenge.apiBaseUrl.TrimEnd('/') -ne $apiUrl -or
    $challenge.wsBaseUrl.TrimEnd('/') -ne $wsUrl) {
    throw "Backend advertised endpoints do not match $serverUrl. Configure MICROFLOW_BOOTSTRAP_SERVER_ORIGIN=$serverUrl, MICROFLOW_BOOTSTRAP_API_BASE_URL=$apiUrl and MICROFLOW_BOOTSTRAP_WS_BASE_URL=$wsUrl on that backend, or pass its reachable -ServerHost/-ServerPort. Existing data and settings were left unchanged."
}

Write-Step 'Choosing an Android device'
if ($Device) { $deviceId = $Device } else {
    $devicesJson = & flutter devices --machine 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Flutter device discovery failed with exit code $LASTEXITCODE." }
    $devices = $devicesJson | ConvertFrom-Json
    $android = $devices | Where-Object { $_.targetPlatform -match '^android(?:-|$)' } | Select-Object -First 1
    if (-not $android) { throw 'No Android device found. Enable USB debugging, or pass -Device <id> from flutter devices.' }
    $deviceId = $android.id
}
Write-Host "    device: $deviceId"

Write-Step 'Launching the debug app through real pairing and login'
Push-Location -LiteralPath $FrontendDir
try {
    & flutter run -d $deviceId `
        --dart-define=DEV_BYPASS=true `
        --dart-define=DEV_SERVER_URL=$serverUrl `
        --dart-define=DEV_PAIRING_CODE=$($challenge.pairingCode) `
        --dart-define=DEV_EMAIL=$Email `
        --dart-define=DEV_PASSWORD=$Password
    if ($LASTEXITCODE -ne 0) { throw "Flutter run failed with exit code $LASTEXITCODE." }
} finally {
    Pop-Location
}

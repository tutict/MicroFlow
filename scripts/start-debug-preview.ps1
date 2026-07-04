param(
    [int]$BackendPort = 8080,
    [int]$FrontendPort = 3000,
    [string]$HostName = "127.0.0.1",
    [switch]$SkipPubGet,
    [switch]$NoBrowser,
    [switch]$Hidden,
    [switch]$SeedDemo,
    [switch]$StrictSecrets
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$BackendDir = Join-Path $ProjectRoot "backend"
$FrontendDir = Join-Path $ProjectRoot "frontend"
$LogDir = Join-Path $ProjectRoot ".codex-tmp\debug-preview"
$ApiBaseUrl = "http://$HostName`:$BackendPort/api/v1"
$WsBaseUrl = "ws://$HostName`:$BackendPort/ws"
$FrontendUrl = "http://$HostName`:$FrontendPort"

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "OK  $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "WARN $Message" -ForegroundColor Yellow
}

function Assert-Path {
    param(
        [string]$Path,
        [string]$Name
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Name not found: $Path"
    }
}

function Resolve-Tool {
    param(
        [string[]]$Names,
        [string]$Fallback
    )

    foreach ($name in $Names) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    if ($Fallback -and (Test-Path -LiteralPath $Fallback)) {
        return $Fallback
    }

    return $null
}

function Start-DebugProcess {
    param(
        [string]$Title,
        [string]$WorkingDirectory,
        [string]$Command,
        [string]$LogPath
    )

    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes(@"
Set-Location -LiteralPath '$WorkingDirectory'
`$Host.UI.RawUI.WindowTitle = '$Title'
Write-Host '$Title' -ForegroundColor Cyan
Write-Host 'Working directory: $WorkingDirectory'
Write-Host 'Log file: $LogPath'
Write-Host ''
$Command 2>&1 | Tee-Object -FilePath '$LogPath' -Append
if (`$LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host '$Title exited with code' `$LASTEXITCODE -ForegroundColor Red
    exit `$LASTEXITCODE
}
"@))

    $arguments = @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", $encoded)
    $windowStyle = if ($Hidden) { "Hidden" } else { "Normal" }
    return Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -WindowStyle $windowStyle -PassThru
}

Assert-Path -Path $BackendDir -Name "Backend directory"
Assert-Path -Path $FrontendDir -Name "Frontend directory"

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$maven = Resolve-Tool -Names @("mvnw.cmd", "mvn.cmd", "mvn") -Fallback (Join-Path $ProjectRoot "mvnw.cmd")
$flutter = Resolve-Tool -Names @("flutter.bat", "flutter") -Fallback $env:FLUTTER_BIN

if (-not $maven) {
    throw "Maven was not found. Install Maven or keep mvnw.cmd in the project root."
}

if (-not $flutter) {
    throw "Flutter was not found. Install Flutter or set FLUTTER_BIN to flutter.bat."
}

Write-Step "Starting MicroFlow debug preview"
Write-Host "Backend:  http://$HostName`:$BackendPort"
Write-Host "Health:   http://$HostName`:$BackendPort/api/v1/system/health"
Write-Host "Frontend: $FrontendUrl"
Write-Host "API:      $ApiBaseUrl"
Write-Host "WS:       $WsBaseUrl"
Write-Host "Logs:     $LogDir"
Write-Host ""

$backendLog = Join-Path $LogDir "backend.log"
$frontendLog = Join-Path $LogDir "frontend.log"
$allowInsecureDefaultSecrets = if ($StrictSecrets) { "false" } else { "true" }
$seedDemoEnabled = if ($SeedDemo) { "true" } else { "false" }
$databasePath = Join-Path $ProjectRoot "microflow.db"

$backendCommand = @"
`$env:MICROFLOW_ALLOW_INSECURE_DEFAULT_SECRETS = '$allowInsecureDefaultSecrets'
`$env:MICROFLOW_SEED_DEMO_ENABLED = '$seedDemoEnabled'
`$env:MICROFLOW_DB_PATH = '$databasePath'
& '$maven' -f '$BackendDir\pom.xml' quarkus:dev -Dquarkus.http.port=$BackendPort
"@
$backendProcess = Start-DebugProcess -Title "MicroFlow Backend (Quarkus dev)" -WorkingDirectory $ProjectRoot -Command $backendCommand -LogPath $backendLog
Write-Ok "Backend launch requested (PID $($backendProcess.Id))"

Write-Step "Waiting a few seconds before starting Flutter"
Start-Sleep -Seconds 6

$pubGetCommand = if ($SkipPubGet) { "" } else { "& '$flutter' pub get`n" }
$frontendCommand = @"
$pubGetCommand& '$flutter' run -d chrome --web-port $FrontendPort --dart-define=MICROFLOW_API_BASE_URL=$ApiBaseUrl --dart-define=MICROFLOW_WS_BASE_URL=$WsBaseUrl
"@

$frontendProcess = Start-DebugProcess -Title "MicroFlow Frontend (Flutter Chrome)" -WorkingDirectory $FrontendDir -Command $frontendCommand -LogPath $frontendLog
Write-Ok "Frontend launch requested (PID $($frontendProcess.Id))"

if (-not $NoBrowser) {
    Write-Step "Opening preview URL"
    Start-Process $FrontendUrl | Out-Null
}

Write-Host ""
Write-Ok "Debug preview is starting."
Write-Host "Close the launched PowerShell windows, or run:" -ForegroundColor Yellow
Write-Host "  Stop-Process -Id $($backendProcess.Id),$($frontendProcess.Id)"
Write-Host ""
Write-Warn "If Flutter needs a different Chrome device, run flutter devices and adjust the script command."

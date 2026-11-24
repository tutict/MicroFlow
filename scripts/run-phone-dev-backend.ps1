# Hidden child process for run-phone-dev.ps1. Secrets never enter its command line.
param(
    [Parameter(Mandatory)][string]$MavenWrapper,
    [Parameter(Mandatory)][string]$BackendDir,
    [Parameter(Mandatory)][string]$SettingsPath,
    [Parameter(Mandatory)][string]$BackendLog,
    [Parameter(Mandatory)][string]$ServerHost,
    [Parameter(Mandatory)][ValidateRange(1, 65535)][int]$ServerPort
)
$ErrorActionPreference = 'Stop'
$LocalDir = Split-Path -Parent $SettingsPath
New-Item -ItemType Directory -Force -Path $LocalDir | Out-Null
if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
    if (Test-Path -LiteralPath (Join-Path $LocalDir 'microflow.db')) {
        throw "Phone development DB already exists but its keys are missing at $SettingsPath. Restore the original keys before starting it."
    }
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $jwtBytes = New-Object byte[] 64
        $cryptoBytes = New-Object byte[] 32
        $rng.GetBytes($jwtBytes)
        $rng.GetBytes($cryptoBytes)
        $newSettings = @{
            jwtSecret = [Convert]::ToBase64String($jwtBytes)
            cryptoSecret = [Convert]::ToBase64String($cryptoBytes)
        } | ConvertTo-Json
        # CreateNew cannot silently replace keys protecting an existing dev DB.
        $stream = [IO.File]::Open($SettingsPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $bytes = [Text.Encoding]::UTF8.GetBytes($newSettings)
            $stream.Write($bytes, 0, $bytes.Length)
        } finally { $stream.Dispose() }
    } finally { $rng.Dispose() }
}
try {
    $settings = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
    $jwtLength = [Convert]::FromBase64String($settings.jwtSecret).Length
    $cryptoLength = [Convert]::FromBase64String($settings.cryptoSecret).Length
    if ($jwtLength -ne 64 -or $cryptoLength -ne 32 -or
        $settings.cryptoSecret -eq 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=') { throw 'Invalid persisted key lengths or insecure default' }
} catch {
    throw "Invalid phone development key configuration at $SettingsPath. Restore its original strong keys; do not replace keys for an existing encrypted DB."
}

$serverOrigin = "http://${ServerHost}:${ServerPort}"
$environment = @{
    QUARKUS_HTTP_PORT = $ServerPort.ToString()
    QUARKUS_HTTP_HOST = '0.0.0.0'
    MICROFLOW_DB_PATH = Join-Path $LocalDir 'microflow.db'
    MICROFLOW_AGENT_CONFIG_PATH = Join-Path $LocalDir 'agents.json'
    MICROFLOW_SEED_DEMO_ENABLED = 'true'
    MICROFLOW_JWT_SECRET = $settings.jwtSecret
    MICROFLOW_CRYPTO_SECRET = $settings.cryptoSecret
    MICROFLOW_ALLOW_INSECURE_DEFAULT_SECRETS = 'false'
    MICROFLOW_BOOTSTRAP_SERVER_ORIGIN = $serverOrigin
    MICROFLOW_BOOTSTRAP_API_BASE_URL = "$serverOrigin/api/v1"
    MICROFLOW_BOOTSTRAP_WS_BASE_URL = "ws://${ServerHost}:${ServerPort}/ws"
}
$previousEnvironment = @{}
foreach ($name in $environment.Keys) { $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
Push-Location -LiteralPath $BackendDir
try {
    foreach ($name in $environment.Keys) { [Environment]::SetEnvironmentVariable($name, $environment[$name], 'Process') }
    & $MavenWrapper '-f' (Join-Path $BackendDir 'pom.xml') 'quarkus:dev' *>&1 |
        Tee-Object -FilePath $BackendLog | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Backend Maven wrapper failed with exit code $LASTEXITCODE. Check $BackendLog." }
} finally {
    foreach ($name in $previousEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process') }
    Pop-Location
}

param([string]$LogPath = '')
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$testResults = [System.Collections.Generic.List[string]]::new()
$failures = 0

function Assert-Phone([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

# Boundary doubles prevent Maven/Flutter execution and any network requests.
# The launcher and, when present, its helper run unchanged inside a fresh fixture.
function Invoke-PhoneFixture {
    param([hashtable]$Parameters = @{}, [bool]$Existing = $false,
        [string]$Platform = 'android-arm64', [bool]$Ambiguous = $false,
        [bool]$FlutterFailure = $false, [bool]$LaunchFailure = $false,
        [bool]$EndpointMismatch = $false, [bool]$Restart = $false,
        [bool]$MissingPersistedKeys = $false, [bool]$NativeFailure = $false)
    $fixtureBase = Join-Path $sourceRoot '.codex-tmp/phone-script-fixtures'
    $fixture = Join-Path $fixtureBase ([guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path (Join-Path $fixture 'scripts'), (Join-Path $fixture 'backend'), (Join-Path $fixture 'frontend') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'scripts/run-phone-dev.ps1') -Destination (Join-Path $fixture 'scripts/run-phone-dev.ps1')
    $helper = Join-Path $sourceRoot 'scripts/run-phone-dev-backend.ps1'
    if (Test-Path -LiteralPath $helper) { Copy-Item -LiteralPath $helper -Destination (Join-Path $fixture 'scripts/run-phone-dev-backend.ps1') }
    $wrapper = Join-Path $fixture 'backend/mvnw.cmd'
    Set-Content -LiteralPath $wrapper -Value '@echo Fake fixture wrapper must be intercepted' -Encoding Ascii
    Set-Content -LiteralPath (Join-Path $fixture 'backend/pom.xml') -Value '<project />'
    $sentinelDb = Join-Path $fixture 'backend/microflow.db'
    Set-Content -LiteralPath $sentinelDb -Value 'EXISTING DATA MUST SURVIVE'
    $environmentBefore = @{}
    Get-ChildItem Env: | ForEach-Object { $environmentBefore[$_.Name] = $_.Value }
    $locationBefore = (Get-Location).Path
    $global:phoneFake = @{
        Existing = $Existing; Platform = $Platform; Ambiguous = $Ambiguous
        FlutterFailure = $FlutterFailure; LaunchFailure = $LaunchFailure
        EndpointMismatch = $EndpointMismatch; Fixture = $fixture; NativeFailure = $NativeFailure
        Wrapper = $wrapper; Port = 8080; HostAddress = '192.168.50.20'
        Starts = @(); Native = @(); Flutter = @(); Requests = @(); Tick = 0
        Output = ''; Error = ''; EnvironmentRestored = $false
    }
    if ($Parameters.ContainsKey('ServerPort')) { $global:phoneFake.Port = $Parameters.ServerPort }
    if ($Parameters.ContainsKey('ServerHost')) { $global:phoneFake.HostAddress = $Parameters.ServerHost }
    if ($MissingPersistedKeys) {
        $devDirectory = Join-Path $fixture ('.codex-tmp/phone-dev-' + $global:phoneFake.Port)
        New-Item -ItemType Directory -Path $devDirectory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $devDirectory 'microflow.db') -Value 'ENCRYPTED DB SENTINEL'
    }
    function global:Get-NetIPAddress {
        param($AddressFamily, $ErrorAction)
        @(
            [pscustomobject]@{ IPAddress = '172.28.0.1'; InterfaceIndex = 1; PrefixOrigin = 'Manual'; AddressState = 'Preferred'; SkipAsSource = $false }
            [pscustomobject]@{ IPAddress = '10.8.0.2'; InterfaceIndex = 2; PrefixOrigin = 'Dhcp'; AddressState = 'Preferred'; SkipAsSource = $false }
            [pscustomobject]@{ IPAddress = '192.168.50.20'; InterfaceIndex = 3; PrefixOrigin = 'Dhcp'; AddressState = 'Preferred'; SkipAsSource = $false }
            if ($global:phoneFake.Ambiguous) { [pscustomobject]@{ IPAddress = '192.168.60.20'; InterfaceIndex = 4; PrefixOrigin = 'Dhcp'; AddressState = 'Preferred'; SkipAsSource = $false } }
        )
    }
    function global:Get-NetAdapter {
        param([switch]$Physical, $ErrorAction)
        @(
            [pscustomobject]@{ InterfaceIndex = 1; Status = 'Up'; HardwareInterface = $false; Name = 'vEthernet' }
            [pscustomobject]@{ InterfaceIndex = 2; Status = 'Up'; HardwareInterface = $false; Name = 'VPN' }
            [pscustomobject]@{ InterfaceIndex = 3; Status = 'Up'; HardwareInterface = $true; Name = 'Wi-Fi' }
            if ($global:phoneFake.Ambiguous) { [pscustomobject]@{ InterfaceIndex = 4; Status = 'Up'; HardwareInterface = $true; Name = 'Ethernet' } }
        ) | Where-Object { -not $Physical -or $_.HardwareInterface }
    }
    function global:Get-NetIPConfiguration {
        param($InterfaceIndex, $ErrorAction)
        @(
            [pscustomobject]@{ InterfaceIndex = 1; IPv4DefaultGateway = $null }
            [pscustomobject]@{ InterfaceIndex = 2; IPv4DefaultGateway = [pscustomobject]@{ NextHop = '10.8.0.1' } }
            [pscustomobject]@{ InterfaceIndex = 3; IPv4DefaultGateway = [pscustomobject]@{ NextHop = '192.168.50.1' } }
            if ($global:phoneFake.Ambiguous) { [pscustomobject]@{ InterfaceIndex = 4; IPv4DefaultGateway = [pscustomobject]@{ NextHop = '192.168.60.1' } } }
        ) | Where-Object { $null -eq $InterfaceIndex -or $_.InterfaceIndex -eq $InterfaceIndex }
    }
    function global:Get-NetTCPConnection {
        param($LocalPort, $State, $ErrorAction)
        if ($global:phoneFake.Existing) { [pscustomobject]@{ LocalPort = $LocalPort; State = 'Listen'; LocalAddress = '0.0.0.0'; OwningProcess = 777 } }
    }
    function global:Start-Sleep { param($Seconds, $Milliseconds) }
    function global:Get-Date {
        param($Format)
        $global:phoneFake.Tick += 30
        [datetime]'2026-11-24T00:00:00Z' + [timespan]::FromSeconds($global:phoneFake.Tick)
    }
    function global:Start-Process {
        param($FilePath, $ArgumentList, $WindowStyle, $WorkingDirectory, [switch]$PassThru)
        $global:phoneFake.Starts += [pscustomobject]@{ FilePath = $FilePath; Arguments = $ArgumentList; WindowStyle = $WindowStyle }
        if ($global:phoneFake.LaunchFailure) { throw 'FAKE background launch failed' }
        $fileIndex = [array]::IndexOf([object[]]$ArgumentList, '-File')
        if ($fileIndex -ge 0) {
            $helperPath = $ArgumentList[$fileIndex + 1].Trim('"')
            $helperArguments = @{}
            for ($i = $fileIndex + 2; $i -lt $ArgumentList.Count; $i += 2) { $helperArguments[$ArgumentList[$i].TrimStart('-')] = $ArgumentList[$i + 1].ToString().Trim('"') }
            & $helperPath @helperArguments
        } else {
            # Original -Command cannot safely be evaluated. Record the effective
            # startup defaults at this boundary, without invoking its string.
            $global:phoneFake.Native += [pscustomobject]@{ Wrapper = '.\mvnw.cmd'; Arguments = @('quarkus:dev'); Port = ''; Host = ''; Seed = $env:MICROFLOW_SEED_DEMO_ENABLED; Db = ''; Jwt = ''; Crypto = ''; AllowInsecure = ''; Origin = ''; Api = ''; Ws = '' }
        }
    }
    Set-Item -LiteralPath ('Function:global:' + $wrapper) -Value {
        $global:phoneFake.Native += [pscustomobject]@{
            Wrapper = $global:phoneFake.Wrapper; Arguments = @($args)
            Port = $env:QUARKUS_HTTP_PORT; Host = $env:QUARKUS_HTTP_HOST
            Seed = $env:MICROFLOW_SEED_DEMO_ENABLED; Db = $env:MICROFLOW_DB_PATH
            Jwt = $env:MICROFLOW_JWT_SECRET; Crypto = $env:MICROFLOW_CRYPTO_SECRET
            AllowInsecure = $env:MICROFLOW_ALLOW_INSECURE_DEFAULT_SECRETS
            Origin = $env:MICROFLOW_BOOTSTRAP_SERVER_ORIGIN
            Api = $env:MICROFLOW_BOOTSTRAP_API_BASE_URL; Ws = $env:MICROFLOW_BOOTSTRAP_WS_BASE_URL
        }
        if ($global:phoneFake.NativeFailure) { throw 'FAKE native backend failure' }
        $global:LASTEXITCODE = 0
    }
    function global:Invoke-RestMethod {
        param($Uri, $TimeoutSec, $ErrorAction)
        $global:phoneFake.Requests += $Uri
        $origin = 'http://' + $global:phoneFake.HostAddress + ':' + $global:phoneFake.Port
        if ($global:phoneFake.EndpointMismatch) { $origin = 'http://127.0.0.1:8080' }
        [pscustomobject]@{ pairingCode = 'FAKE-0000-0000'; instanceName = 'fixture'; expiresAt = '2026-11-24T00:10:00Z'; serverOrigin = $origin; apiBaseUrl = $origin + '/api/v1'; wsBaseUrl = $origin.Replace('http://', 'ws://') + '/ws'; qrPayload = '{}' }
    }
    function global:flutter {
        $global:phoneFake.Flutter += ,@($args)
        if ($args[0] -eq 'devices') { '[{"id":"fake-phone","name":"Fixture Android","targetPlatform":"' + $global:phoneFake.Platform + '","emulator":false,"isSupported":true}]'; $global:LASTEXITCODE = 0 }
        elseif ($global:phoneFake.FlutterFailure) { $global:LASTEXITCODE = 9 }
        else { $global:LASTEXITCODE = 0 }
    }
    try {
        $scriptPath = Join-Path $fixture 'scripts/run-phone-dev.ps1'
        try { $global:phoneFake.Output = (& $scriptPath @Parameters *>&1 | Out-String) } catch { $global:phoneFake.Error = $_.Exception.Message }
        if ($Restart -and -not $global:phoneFake.Error) { try { $global:phoneFake.Output += (& $scriptPath @Parameters *>&1 | Out-String) } catch { $global:phoneFake.Error = $_.Exception.Message } }
        $environmentAfter = @{}
        Get-ChildItem Env: | ForEach-Object { $environmentAfter[$_.Name] = $_.Value }
        $changed = @($environmentBefore.Keys + $environmentAfter.Keys | Select-Object -Unique | Where-Object { $environmentBefore[$_] -cne $environmentAfter[$_] })
        $global:phoneFake.EnvironmentRestored = $changed.Count -eq 0
        $global:phoneFake.LocationRestored = (Get-Location).Path -eq $locationBefore
        $global:phoneFake.SentinelUnchanged = (Get-Content -LiteralPath $sentinelDb -Raw).Trim() -eq 'EXISTING DATA MUST SURVIVE'
        $global:phoneFake.Settings = @(Get-ChildItem -LiteralPath (Join-Path $fixture '.codex-tmp') -Filter '*.json' -Recurse -ErrorAction SilentlyContinue)
        if ($MissingPersistedKeys) { $global:phoneFake.DevSentinelUnchanged = (Get-Content -LiteralPath (Join-Path $devDirectory 'microflow.db') -Raw).Trim() -eq 'ENCRYPTED DB SENTINEL' }
        return $global:phoneFake
    } finally {
        foreach ($name in @((Get-ChildItem Env:).Name)) { if (-not $environmentBefore.ContainsKey($name)) { [Environment]::SetEnvironmentVariable($name, $null, 'Process') } }
        foreach ($name in $environmentBefore.Keys) { [Environment]::SetEnvironmentVariable($name, $environmentBefore[$name], 'Process') }
        Set-Location -LiteralPath $locationBefore
        foreach ($name in @('Get-NetIPAddress', 'Get-NetAdapter', 'Get-NetIPConfiguration', 'Get-NetTCPConnection', 'Start-Sleep', 'Get-Date', 'Start-Process', 'Invoke-RestMethod', 'flutter', $wrapper)) { Remove-Item -LiteralPath ('Function:global:' + $name) -ErrorAction SilentlyContinue }
        $absoluteFixture = [IO.Path]::GetFullPath($fixture)
        $absoluteBase = [IO.Path]::GetFullPath($fixtureBase) + [IO.Path]::DirectorySeparatorChar
        if (-not $absoluteFixture.StartsWith($absoluteBase, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture cleanup path' }
        Remove-Item -LiteralPath $absoluteFixture -Recurse -Force
    }
}

function Test-Phone([string]$Name, [scriptblock]$Body) {
    try { & $Body; $line = 'PASS ' + $Name } catch { $script:failures++; $line = 'FAIL ' + $Name + ': ' + $_.Exception.Message }
    $testResults.Add($line); Write-Output $line
}

Test-Phone 'default startup passes strong-secret contract and isolates seed DB' {
    $r = Invoke-PhoneFixture -Parameters @{ Device = 'fake-phone' }
    Assert-Phone ($r.Native.Count -eq 1) 'Expected one controlled backend invocation'
    $n = $r.Native[0]
    Assert-Phone (-not $r.Error) 'Default launch must reach Flutter'
    Assert-Phone ($n.Jwt.Length -ge 64 -and $n.Jwt -ne 'change-this-dev-jwt-secret-before-production') 'Default JWT must be strong, random and non-default'
    Assert-Phone ([Convert]::FromBase64String($n.Crypto).Length -eq 32 -and $n.Crypto -ne 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=') 'AES key must decode to 32 random bytes'
    Assert-Phone ($n.AllowInsecure -eq 'false') 'Security validator must remain enabled'
    Assert-Phone ($n.Seed -eq 'true' -and $n.Db.StartsWith((Join-Path $r.Fixture '.codex-tmp')) -and $r.SentinelUnchanged) 'Demo seed must target only ignored development DB'
    Assert-Phone ($r.Settings.Count -eq 1) 'Secret configuration must be persisted only inside ignored local fixture'
    Assert-Phone (-not $r.Output.Contains($n.Jwt) -and -not $r.Output.Contains($n.Crypto)) 'Generated secrets must not be printed'
}
Test-Phone 'wrapper invocation uses actual absolute wrapper and backend pom' {
    $r = Invoke-PhoneFixture -Parameters @{ Device = 'fake-phone' }
    Assert-Phone ($r.Native[0].Wrapper -eq $r.Wrapper -and $r.Native[0].Arguments -contains (Join-Path $r.Fixture 'backend/pom.xml')) 'Wrapper must resolve absolute existing backend wrapper and pom'
}
Test-Phone 'custom port binds LAN and aligns challenge with Flutter URLs' {
    $r = Invoke-PhoneFixture -Parameters @{ Device = 'fake-phone'; ServerPort = 8081 }
    Assert-Phone ($r.Native[0].Port -eq '8081' -and $r.Native[0].Host -eq '0.0.0.0') 'Backend must listen on configured 8081 at LAN-accessible bind'
    Assert-Phone ($r.Requests -contains 'http://127.0.0.1:8081/api/v1/bootstrap/challenge') 'Local challenge must use selected port'
    Assert-Phone ($r.Native[0].Origin -eq 'http://192.168.50.20:8081' -and $r.Native[0].Api -eq 'http://192.168.50.20:8081/api/v1' -and $r.Native[0].Ws -eq 'ws://192.168.50.20:8081/ws') 'Advertised endpoints must agree'
    Assert-Phone ($r.Flutter[-1] -contains '--dart-define=DEV_SERVER_URL=http://192.168.50.20:8081') 'Flutter origin must agree'
}
foreach ($platform in @('android-arm64', 'android-x64', 'android')) {
    Test-Phone ('Android discovery accepts ' + $platform) {
        $r = Invoke-PhoneFixture -Platform $platform
        Assert-Phone (-not $r.Error -and $r.Flutter[-1][0] -eq 'run' -and $r.Flutter[-1] -contains 'fake-phone') 'Connected Android architecture must be runnable'
    }
}
Test-Phone 'LAN selection excludes HyperV and VPN despite enumeration order' {
    $r = Invoke-PhoneFixture -Parameters @{ Device = 'fake-phone' }
    Assert-Phone ($r.Flutter[-1] -contains '--dart-define=DEV_SERVER_URL=http://192.168.50.20:8080') 'Choose physical active interface with default gateway'
}
Test-Phone 'explicit host override works when physical LAN is ambiguous' {
    $r = Invoke-PhoneFixture -Parameters @{ Device = 'fake-phone'; ServerHost = '192.168.60.20'; ServerPort = 8090 } -Ambiguous $true
    Assert-Phone (-not $r.Error -and $r.Flutter[-1] -contains '--dart-define=DEV_SERVER_URL=http://192.168.60.20:8090') 'Explicit host must determine both backend and Flutter origin'
}
Test-Phone 'ambiguous physical LAN fails with recoverable host parameter' {
    $r = Invoke-PhoneFixture -Ambiguous $true -Parameters @{ Device = 'fake-phone' }
    Assert-Phone ($r.Error -like '*-ServerHost*' -and $r.Starts.Count -eq 0 -and $r.Requests.Count -eq 0) 'Ambiguity must stop before startup and explain -ServerHost'
}
Test-Phone 'background startup stays Hidden and avoids command-string process' {
    $r = Invoke-PhoneFixture -Parameters @{ Device = 'fake-phone' }
    Assert-Phone ($r.Starts[0].WindowStyle -eq 'Hidden' -and $r.Starts[0].Arguments -contains '-File' -and $r.Starts[0].Arguments -notcontains '-NoExit' -and $r.Starts[0].Arguments -notcontains '-Command') 'Backend helper must be Hidden with -File, without persistent visible shell'
}
Test-Phone 'shell environment and working directory survive success' {
    $seedBefore = [Environment]::GetEnvironmentVariable('MICROFLOW_SEED_DEMO_ENABLED', 'Process')
    $portBefore = [Environment]::GetEnvironmentVariable('QUARKUS_HTTP_PORT', 'Process')
    try {
        $env:MICROFLOW_SEED_DEMO_ENABLED = 'original-false'
        $env:QUARKUS_HTTP_PORT = 'original-port'
        $r = Invoke-PhoneFixture -Parameters @{ Device = 'fake-phone' }
        Assert-Phone ($r.EnvironmentRestored -and $r.LocationRestored) 'Launcher/helper must restore all caller environment and working directory'
    } finally {
        [Environment]::SetEnvironmentVariable('MICROFLOW_SEED_DEMO_ENABLED', $seedBefore, 'Process')
        [Environment]::SetEnvironmentVariable('QUARKUS_HTTP_PORT', $portBefore, 'Process')
    }
}
Test-Phone 'shell environment survives background startup exception' {
    $r = Invoke-PhoneFixture -LaunchFailure $true -Parameters @{ Device = 'fake-phone' }
    Assert-Phone ($r.Error -like '*FAKE background*' -and $r.EnvironmentRestored -and $r.LocationRestored) 'Startup failure must restore caller environment'
}
Test-Phone 'Flutter nonzero exit becomes visible failure and restores shell' {
    $r = Invoke-PhoneFixture -FlutterFailure $true -Parameters @{ Device = 'fake-phone' }
    Assert-Phone ($r.Error -like '*Flutter*9*' -and $r.EnvironmentRestored -and $r.LocationRestored) 'Native Flutter failure must propagate with preserved shell'
}
Test-Phone 'existing backend is reused without DB seed or configuration changes' {
    $r = Invoke-PhoneFixture -Existing $true -Parameters @{ Device = 'fake-phone' }
    Assert-Phone ($r.Starts.Count -eq 0 -and $r.Native.Count -eq 0 -and $r.Settings.Count -eq 0 -and $r.SentinelUnchanged -and $r.EnvironmentRestored) 'Reusing backend must not enable seed or create/change DB and keys'
}
Test-Phone 'existing backend endpoint mismatch stops before spending pairing code' {
    $r = Invoke-PhoneFixture -Existing $true -EndpointMismatch $true -Parameters @{ Device = 'fake-phone' }
    Assert-Phone ($r.Error -like '*advertis*' -and $r.Flutter.Count -eq 0 -and $r.Starts.Count -eq 0) 'Existing server with loopback advertised endpoints must get actionable error before Flutter'
}
Test-Phone 'restart reuses persisted strong keys and isolated DB' {
    $r = Invoke-PhoneFixture -Restart $true -Parameters @{ Device = 'fake-phone' }
    Assert-Phone ($r.Native.Count -eq 2 -and $r.Native[0].Jwt.Length -ge 64 -and $r.Native[0].Jwt -ceq $r.Native[1].Jwt -and $r.Native[0].Crypto -ceq $r.Native[1].Crypto -and $r.Native[0].Db -eq $r.Native[1].Db) 'Restart must preserve dev identity and encrypted DB keys'
}
Test-Phone 'existing encrypted dev DB without keys refuses regeneration' {
    $r = Invoke-PhoneFixture -MissingPersistedKeys $true -Parameters @{ Device = 'fake-phone' }
    Assert-Phone ($r.Error -like '*key*' -and $r.Settings.Count -eq 0 -and $r.Native.Count -eq 0 -and $r.DevSentinelUnchanged) 'Missing dev keys must stop without generating replacement identity or touching encrypted DB'
}
Test-Phone 'helper restores environment after native backend exception' {
    $r = Invoke-PhoneFixture -NativeFailure $true -Parameters @{ Device = 'fake-phone' }
    Assert-Phone ($r.Error -like '*FAKE native*' -and $r.EnvironmentRestored -and $r.LocationRestored) 'Helper native failure must restore every temporarily overridden variable and directory'
}

$summary = 'RESULT tests=' + $testResults.Count + ' failed=' + $failures
$testResults.Add($summary); Write-Output $summary
if ($LogPath) { $testResults | Set-Content -LiteralPath $LogPath -Encoding UTF8 }
if ($failures -gt 0) { exit 1 }

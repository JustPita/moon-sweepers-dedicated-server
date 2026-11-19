param(
    [string]$GamePath=$PSScriptRoot,
    [switch]$ShowErrors
)
$ErrorActionPreference='Stop'
try {
    $gameDirectory=(Resolve-Path -LiteralPath $GamePath).Path
    $gameExe=Join-Path $gameDirectory 'MoonSweepers.exe'
    $recordPath=Join-Path $gameDirectory 'moon-client-install.json'
    $proxy=Join-Path $gameDirectory 'version.dll'
    if (-not (Test-Path -LiteralPath $gameExe -PathType Leaf)) { throw 'MoonSweepers.exe was not found. Recreate the shortcut using the client installer.' }
    if (-not (Test-Path -LiteralPath $recordPath -PathType Leaf)) { throw 'Install the Moon Sweepers client module first.' }
    $record=Get-Content -LiteralPath $recordPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not (Test-Path -LiteralPath $proxy -PathType Leaf) -or (Get-FileHash -LiteralPath $proxy -Algorithm SHA256).Hash -ne $record.sha256) { throw 'The installed client module changed. Update it using the client installer.' }
    # GameAssembly.dll SHA-256 of supported builds; keep in sync with container/server/server-import.
    $supported=@{'14F711A6A3B1B7CD803A03F85CC6C6201C5B546AB9B90329533F5CB8AE2E7F13'='1.0.5 (Steam build 26317497)';'106B28AA7DEEF1054639A5F48C2C3AE9623A309E0E49631D8B5DFA29A6D5B88F'='1.0.6 (Steam build 26682829)'}
    if (-not $supported.ContainsKey((Get-FileHash -LiteralPath (Join-Path $gameDirectory 'GameAssembly.dll') -Algorithm SHA256).Hash)) { throw ('This module supports Moon Sweepers '+(($supported.Values | Sort-Object) -join ', ')+'. The installed game differs.') }
    $serverId=[string]$record.server_id
    if ($serverId -notmatch '^\d{17}$' -or (([UInt64]::Parse($serverId) -shr 52) -band 15) -ne 4) { throw 'Set the current server SteamID with the client installer before joining.' }
    if (Get-CimInstance Win32_Process -Filter "Name='MoonSweepers.exe'" | Where-Object { $_.ExecutablePath -eq $gameExe }) { throw 'Moon Sweepers is already running. Close it before joining again.' }
    $steam=(Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamExe
    if (-not $steam) { $steam=Join-Path ${env:ProgramFiles(x86)} 'Steam\steam.exe' }
    if (-not (Test-Path -LiteralPath $steam -PathType Leaf)) { throw 'Steam was not found. Open Steam, then try the shortcut again.' }
    Start-Process -FilePath $steam -ArgumentList ('-applaunch 5335510 -moon-connect '+$serverId)
    Write-Output ('Requested Steam launch connecting to server '+$serverId+'.')
} catch {
    if ($ShowErrors) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Moon Sweepers - Join server',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning) > $null
        exit 1
    }
    throw
}

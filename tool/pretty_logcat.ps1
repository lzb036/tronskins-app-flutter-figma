param(
  [string]$DeviceId = "127.0.0.1:5555",
  [switch]$ClearBuffer
)

$adb = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adb) {
  Write-Error "adb was not found. Make sure Android SDK platform-tools is in PATH."
  exit 1
}

if ($ClearBuffer) {
  & adb -s $DeviceId logcat -c
}

Write-Host "Watching Flutter logs from $DeviceId" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray

& adb -s $DeviceId logcat -v brief flutter:I *:S |
  ForEach-Object {
    $line = $_

    if ($line -match '\|\s*ERROR\s*\|') {
      Write-Host $line -ForegroundColor Red
      return
    }

    if ($line -match '\|\s*WARN\s*\|') {
      Write-Host $line -ForegroundColor Yellow
      return
    }

    if ($line -match '\|\s*SUCCESS\s*\|') {
      Write-Host $line -ForegroundColor Green
      return
    }

    if ($line -match '\|\s*INFO\s*\|') {
      Write-Host $line -ForegroundColor Cyan
      return
    }

    Write-Host $line -ForegroundColor DarkGray
  }

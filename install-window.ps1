$ErrorActionPreference = "Continue"
$Base = "C:\Users\ZBookMW\Desktop\MacBook_eGPU"
$Log = Join-Path $Base "window-log.txt"
function Log($m) { Add-Content $Log ("{0} {1}" -f (Get-Date -Format o), $m); Write-Output $m }
Set-Content $Log ("window {0}" -f (Get-Date -Format o))

$src = Join-Path $Base "acpitabl.dat"
if (-not (Test-Path $src) -or (Get-Item $src).Length -ne 34352) { Log "acpitabl.dat size wrong"; exit 1 }
$bytes = [IO.File]::ReadAllBytes($src)
$oem = [BitConverter]::ToUInt32($bytes, 24)
if ($oem -ne 0x00130006) { Log ("oem=0x{0:X8}" -f $oem); exit 1 }
Copy-Item $src "C:\Windows\System32\acpitabl.dat" -Force
$placed = [IO.File]::ReadAllBytes("C:\Windows\System32\acpitabl.dat")
$placedOem = [BitConverter]::ToUInt32($placed, 24)
Log ("system32 len={0} oem=0x{1:X8}" -f $placed.Length, $placedOem)
if ($placed.Length -ne 34352 -or $placedOem -ne 0x00130006) { Log "system32 table wrong; not rebooting"; exit 2 }

$enum = bcdedit /enum "{current}" 2>&1 | Out-String
Log ("bcd={0}" -f ($enum -replace '\s+', ' ').Trim())
if ($enum -notmatch "testsigning\s+Yes") {
    $ts = bcdedit /set testsigning on 2>&1 | Out-String
    Log ("testsigning set: {0}" -f $ts.Trim())
    if ($ts -notmatch "successfully") { Log "test signing off; not rebooting"; exit 3 }
} else {
    Log "testsigning already on"
}

Log "normal Windows reboot, EFI not touched"
shutdown.exe /r /t 20 /c "Normal Windows restart to move the 3080 memory window above RAM. The startup file was not replaced."
Log "shutdown issued"

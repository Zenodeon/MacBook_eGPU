$ErrorActionPreference = "Continue"
$Base = "C:\Users\ZBookMW\Desktop\MacBook_eGPU"
$Log = Join-Path $Base "apple-set-os-log.txt"
function Log($m) { Add-Content $Log ("{0} {1}" -f (Get-Date -Format o), $m); Write-Output $m }
Set-Content $Log ("apple-set-os {0}" -f (Get-Date -Format o))

$src = Join-Path $Base "acpitabl.dat"
if (-not (Test-Path $src) -or (Get-Item $src).Length -ne 34352) { Log "project acpitabl.dat is not 34352"; exit 1 }
$bytes = [IO.File]::ReadAllBytes($src)
$oem = [BitConverter]::ToUInt32($bytes, 24)
if ($oem -ne 0x00130004) { Log ("project oemRev=0x{0:X8}" -f $oem); exit 1 }
Copy-Item $src "C:\Windows\System32\acpitabl.dat" -Force
$placed = Get-Item "C:\Windows\System32\acpitabl.dat"
$placedBytes = [IO.File]::ReadAllBytes($placed.FullName)
$placedOem = [BitConverter]::ToUInt32($placedBytes, 24)
Log ("system32 acpitabl len={0} oem=0x{1:X8}" -f $placed.Length, $placedOem)
if ($placed.Length -ne 34352 -or $placedOem -ne 0x00130004) { Log "system32 table wrong; not rebooting"; exit 2 }

mountvol Z: /S | Out-Null
$mgfw = "Z:\EFI\Microsoft\Boot\bootmgfw.efi"
$bootx64 = "Z:\EFI\Boot\bootx64.efi"
$orig = "Z:\EFI\Boot\bootx64_original.efi"
$silent = Join-Path $Base "tools\bootx64_silent.efi"
if (-not (Test-Path $mgfw) -or -not (Test-Path $bootx64)) { Log "ESP mount failed"; exit 3 }
if (-not (Test-Path $silent) -or (Get-Item $silent).Length -ne 246784) { Log "silent efi missing"; exit 3 }

Log ("bootmgfw={0}" -f (Get-Item $mgfw).Length)
Log ("bootx64={0}" -f (Get-Item $bootx64).Length)
if ((Get-Item $mgfw).Length -ne 1604016 -or (Get-Item $bootx64).Length -ne 1604016) {
    Log "boot files are not the Windows boot manager; not rebooting"
    exit 4
}
if (-not (Test-Path $orig) -or (Get-Item $orig).Length -ne 1604016) {
    Copy-Item $bootx64 $orig -Force
    Log ("saved bootx64_original={0}" -f (Get-Item $orig).Length)
}
if ((Get-Item $orig).Length -ne 1604016) { Log "backup is not the Windows boot manager; not rebooting"; exit 5 }

Copy-Item $silent $bootx64 -Force
Log ("bootx64 now={0}" -f (Get-Item $bootx64).Length)
Log ("bootmgfw still={0}" -f (Get-Item $mgfw).Length)
Log ("backup still={0}" -f (Get-Item $orig).Length)
if ((Get-Item $bootx64).Length -ne 246784 -or (Get-Item $mgfw).Length -ne 1604016 -or (Get-Item $orig).Length -ne 1604016) {
    Copy-Item $orig $bootx64 -Force
    Log ("restored bootx64 to {0}; not rebooting" -f (Get-Item $bootx64).Length)
    exit 6
}

$ts = bcdedit /set testsigning on 2>&1 | Out-String
Log ("testsigning: {0}" -f $ts.Trim())
if ($ts -notmatch "successfully") {
    Copy-Item $orig $bootx64 -Force
    Log ("test signing failed; restored bootx64 to {0}; not rebooting" -f (Get-Item $bootx64).Length)
    exit 7
}

Log "normal Windows reboot"
shutdown.exe /r /t 20 /c "Normal Windows restart. Firmware is told this boot is macOS, then the real Windows boot manager starts."
Log "shutdown issued"

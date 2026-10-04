$ErrorActionPreference = "Continue"
$Base = "C:\Users\ZBookMW\Desktop\MacBook_eGPU"
$Log = Join-Path $Base "dsm-log.txt"
function Log($m) { Add-Content $Log ("{0} {1}" -f (Get-Date -Format o), $m); Write-Output $m }
Set-Content $Log ("dsm {0}" -f (Get-Date -Format o))

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Log "ABORT not admin"; exit 9 }

function Check($path, $len, $oem) {
    $b = [IO.File]::ReadAllBytes($path)
    $s = 0
    foreach ($x in $b) { $s = ($s + $x) % 256 }
    $o = [BitConverter]::ToUInt32($b, 24)
    Log ("{0} len={1} oem=0x{2:X8} sum={3}" -f $path, $b.Length, $o, $s)
    return ($b.Length -eq $len -and $o -eq $oem -and $s -eq 0)
}

$rollback = Join-Path $Base "acpitabl-00130006.dat"
if (-not (Check $rollback 34352 0x00130006)) { Log "ABORT rollback table missing or wrong"; exit 1 }

$src = Join-Path $Base "acpi\dsdt.aml"
if (-not (Check $src 34406 0x00130007)) { Log "ABORT new table wrong"; exit 1 }

$re = & reagentc.exe /info 2>&1 | Out-String
Log ($re.Trim())
if ($re -notmatch "Windows RE status:\s*Enabled") { Log "ABORT WinRE not enabled"; exit 3 }

$enum = bcdedit /enum "{current}" 2>&1 | Out-String
if ($enum -notmatch "testsigning\s+Yes") { Log "ABORT test signing is off"; exit 3 }
Log "testsigning on"

Copy-Item $src (Join-Path $Base "acpitabl.dat") -Force
Copy-Item $src "C:\Windows\System32\acpitabl.dat" -Force
if (-not (Check "C:\Windows\System32\acpitabl.dat" 34406 0x00130007)) {
    Log "system32 table wrong; restoring 0x00130006 and not rebooting"
    Copy-Item $rollback "C:\Windows\System32\acpitabl.dat" -Force
    exit 2
}

Log "EFI, pci.sys, HackFlags, and root ports not touched"
shutdown.exe /r /t 30 /c "Restart to load DSDT 0x00130007 (PCI _DSM function 5). If Windows does not start: WinRE command prompt, copy acpitabl-00130006.dat over C:\Windows\System32\acpitabl.dat."
Log "shutdown issued t=30"

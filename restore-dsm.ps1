$ErrorActionPreference = "Continue"
$Base = "C:\Users\ZBookMW\Desktop\MacBook_eGPU"
$Log = Join-Path $Base "restore-dsm-log.txt"
function Log($m) { Add-Content $Log ("{0} {1}" -f (Get-Date -Format o), $m); Write-Output $m }
Set-Content $Log ("restore-dsm {0}" -f (Get-Date -Format o))

$src = Join-Path $Base "acpitabl-00130006.dat"
$b = [IO.File]::ReadAllBytes($src)
if ($b.Length -ne 34352 -or [BitConverter]::ToUInt32($b, 24) -ne 0x00130006) { Log "ABORT rollback table wrong"; exit 1 }
Copy-Item $src "C:\Windows\System32\acpitabl.dat" -Force
Copy-Item $src (Join-Path $Base "acpitabl.dat") -Force
$p = [IO.File]::ReadAllBytes("C:\Windows\System32\acpitabl.dat")
$s = 0; foreach ($x in $p) { $s = ($s + $x) % 256 }
Log ("system32 len={0} oem=0x{1:X8} sum={2}" -f $p.Length, [BitConverter]::ToUInt32($p, 24), $s)
if ($p.Length -ne 34352 -or [BitConverter]::ToUInt32($p, 24) -ne 0x00130006 -or $s -ne 0) { Log "readback wrong; not rebooting"; exit 2 }
shutdown.exe /r /t 30 /c "Restoring DSDT 0x00130006. The _DSM function 5 table left the Thunderbolt window at 224 MB."
Log "shutdown issued t=30"

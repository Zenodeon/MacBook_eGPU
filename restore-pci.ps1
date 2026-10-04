$ErrorActionPreference = "Stop"
$Base = "C:\Users\ZBookMW\Desktop\MacBook_eGPU"
$Log = Join-Path $Base "restore-log.txt"
$Bak = Join-Path $Base "pci-19041.sys"
$Dest = "C:\Windows\System32\drivers\pci.sys"
$Expected = "B41EBCCE9F68256E869CEE6C9A122D0C495D8B8F9095A5A4ED13D034D051515A"
function Log($m) { Add-Content $Log ("{0} {1}" -f (Get-Date -Format o), $m); Write-Output $m }
Set-Content $Log ("restore {0}" -f (Get-Date -Format o))

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Log "ABORT not admin"; exit 9 }

$b = Get-Item $Bak
$bv = $b.VersionInfo
$bh = (Get-FileHash $Bak -Algorithm SHA256).Hash
Log ("backup len={0} raw={1} hash={2}" -f $b.Length, $bv.FileVersionRaw, $bh)
if ($b.Length -ne 473488 -or $bv.FileVersionRaw.ToString() -ne "10.0.19041.6456" -or $bh -ne $Expected) {
    Log "ABORT backup is not the saved 19041 driver"
    exit 2
}

$take = & takeown.exe /f $Dest 2>&1 | Out-String
Log ($take.Trim())
$acl = & icacls.exe $Dest /grant "Administrators:F" 2>&1 | Out-String
Log ($acl.Trim())
Copy-Item $Bak $Dest -Force
$d = Get-Item $Dest
$dv = $d.VersionInfo
$dh = (Get-FileHash $Dest -Algorithm SHA256).Hash
Log ("dest len={0} raw={1} hash={2}" -f $d.Length, $dv.FileVersionRaw, $dh)
if ($d.Length -ne 473488 -or $dv.FileVersionRaw.ToString() -ne "10.0.19041.6456" -or $dh -ne $Expected) {
    Log "READBACK FAILED"
    exit 5
}
Log "restored; EFI, acpitabl.dat, HackFlags, and root ports not touched"
shutdown.exe /r /t 60 /c "Restoring the original PCI driver. The 1903 driver left the Thunderbolt window at 224 MB."
Log "shutdown issued t=60"

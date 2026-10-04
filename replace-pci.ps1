$ErrorActionPreference = "Stop"
$Base = "C:\Users\ZBookMW\Desktop\MacBook_eGPU"
$Log = Join-Path $Base "replace-log.txt"
$New = Join-Path $Base "pci-18362.sys"
$Bak = Join-Path $Base "pci-19041.sys"
$Dest = "C:\Windows\System32\drivers\pci.sys"
function Log($m) { Add-Content $Log ("{0} {1}" -f (Get-Date -Format o), $m); Write-Output $m }
Set-Content $Log ("replace {0}" -f (Get-Date -Format o))

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Log "ABORT not admin"; exit 9 }

$nitem = Get-Item $New
$nvi = $nitem.VersionInfo
$nsig = Get-AuthenticodeSignature $New
$nsub = $nsig.SignerCertificate.Subject
Log ("new len={0} file={1} product={2} sig={3} signer={4}" -f $nitem.Length, $nvi.FileVersion, $nvi.ProductVersion, $nsig.Status, $nsub)
$newOk = ($nitem.Length -eq 433976) -and ($nvi.ProductVersion -eq "10.0.18362.1") -and ($nvi.FileVersion -like "10.0.18362.1*") -and ($nsig.Status -eq "Valid") -and ($nsub -match "CN=Microsoft Windows")
if (-not $newOk) { Log "ABORT new file failed recheck"; exit 1 }

$liveHash = (Get-FileHash $Dest -Algorithm SHA256).Hash
Copy-Item $Dest $Bak -Force
$b = Get-Item $Bak
$bv = $b.VersionInfo
$bakHash = (Get-FileHash $Bak -Algorithm SHA256).Hash
Log ("backup len={0} file={1} product={2} raw={3} hash={4}" -f $b.Length, $bv.FileVersion, $bv.ProductVersion, $bv.FileVersionRaw, $bakHash)
if ($b.Length -ne 473488 -or $bakHash -ne $liveHash -or ($bv.FileVersionRaw.ToString() -notlike "10.0.19041.*")) {
    Log "ABORT backup is not the running 19041 driver"
    exit 2
}

$re = & reagentc.exe /info 2>&1 | Out-String
Log ($re.Trim())
if ($re -notmatch "Windows RE status:\s*Enabled") { Log "ABORT WinRE not enabled"; exit 3 }

$take = & takeown.exe /f $Dest 2>&1 | Out-String
Log ($take.Trim())
$acl = & icacls.exe $Dest /grant "Administrators:F" 2>&1 | Out-String
Log ($acl.Trim())

try {
    Copy-Item $New $Dest -Force
} catch {
    Log ("COPY FAILED {0}" -f $_.Exception.Message)
    exit 4
}

$d = Get-Item $Dest
$dv = $d.VersionInfo
$dsig = Get-AuthenticodeSignature $Dest
$dsub = ""
if ($dsig.SignerCertificate) { $dsub = $dsig.SignerCertificate.Subject }
Log ("dest len={0} file={1} product={2} raw={3} sig={4} signer={5}" -f $d.Length, $dv.FileVersion, $dv.ProductVersion, $dv.FileVersionRaw, $dsig.Status, $dsub)
$destOk = ($d.Length -eq 433976) -and ($dv.FileVersionRaw.ToString() -eq "10.0.18362.1") -and ($dsig.Status -eq "Valid") -and ($dsub -match "CN=Microsoft Windows")
if (-not $destOk) {
    Log "READBACK FAILED restoring backup"
    Copy-Item $Bak $Dest -Force
    $back = Get-Item $Dest
    Log ("restored len={0} product={1}" -f $back.Length, $back.VersionInfo.ProductVersion)
    exit 5
}

Log "readback ok; EFI, acpitabl.dat, HackFlags, and root ports not touched"
try { Dismount-DiskImage -ImagePath (Join-Path $Base "iso\Win10_1903_18362.1_x64.iso") -ErrorAction SilentlyContinue | Out-Null; Log "iso dismounted" } catch { Log "iso dismount skipped" }
shutdown.exe /r /t 90 /c "Restarting to load the Windows 10 1903 PCI driver. If the desktop does not return, recovery command prompt: copy pci-19041.sys back to pci.sys."
Log "shutdown issued t=90"

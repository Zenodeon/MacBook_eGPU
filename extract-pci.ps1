$ErrorActionPreference = "Stop"
$Base = "C:\Users\ZBookMW\Desktop\MacBook_eGPU"
$Log = Join-Path $Base "extract-log.txt"
$Mount = Join-Path $Base "iso\wimmount"
$Out = Join-Path $Base "pci-18362.sys"
function Log($m) { Add-Content $Log ("{0} {1}" -f (Get-Date -Format o), $m); Write-Output $m }
Set-Content $Log ("extract {0}" -f (Get-Date -Format o))

$wim = $null
Get-Volume | ForEach-Object {
    $root = "$($_.DriveLetter):\sources\install.wim"
    if ($_.DriveLetter -and (Test-Path $root)) {
        $label = (Get-Volume -DriveLetter $_.DriveLetter).FileSystemLabel
        if ($label -eq "CCSA_X64FRE_EN-US_DV5") { $wim = $root }
    }
}
if (-not $wim) { Log "install.wim not mounted"; exit 1 }
Log "wim=$wim"

$dism = & dism.exe /English /Get-WimInfo /WimFile:$wim /Index:1
$dism | ForEach-Object { Log $_ }
$imageVersion = @($dism | Where-Object { $_ -match "^\s*Version\s+:\s+10\.0\.18362\s*$" })
$spBuild = @($dism | Where-Object { $_ -match "^\s*ServicePack Build\s+:\s+1\s*$" })
if ($imageVersion.Count -ne 1 -or $spBuild.Count -ne 1) { Log "ABORT wim is not 10.0.18362 service pack build 1"; exit 2 }
Log "parsed=10.0.18362 sp=1"
$index = 1
Log "using index=1"

if (Test-Path $Mount) { Remove-Item $Mount -Recurse -Force }
New-Item -ItemType Directory -Path $Mount | Out-Null
try {
    Mount-WindowsImage -ImagePath $wim -Index $index -Path $Mount -ReadOnly | Out-Null
    $src = Join-Path $Mount "Windows\System32\drivers\pci.sys"
    if (-not (Test-Path $src)) { Log "ABORT pci.sys missing in image"; exit 3 }
    Copy-Item $src $Out -Force
    $item = Get-Item $Out
    $vi = $item.VersionInfo
    $sig = Get-AuthenticodeSignature $Out
    $signer = ""
    if ($sig.SignerCertificate) { $signer = $sig.SignerCertificate.Subject }
    Log ("len={0} file={1} product={2} raw={3}" -f $item.Length, $vi.FileVersion, $vi.ProductVersion, $vi.FileVersionRaw)
    Log ("sig={0} signer={1}" -f $sig.Status, $signer)
    $verOk = ($vi.ProductVersion -eq "10.0.18362.1") -and ($vi.FileVersion -like "10.0.18362.1*")
    $sigOk = ($sig.Status -eq "Valid") -and ($signer -match "CN=Microsoft Windows")
    if (-not $verOk -or -not $sigOk) { Log "FAIL checks"; exit 4 }
    Log "PASS"
} finally {
    if (Test-Path (Join-Path $Mount "Windows")) {
        Dismount-WindowsImage -Path $Mount -Discard | Out-Null
        Log "dismounted"
    }
}

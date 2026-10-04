$ErrorActionPreference = "Continue"
$Base = "C:\Users\ZBookMW\Desktop\MacBook_eGPU"
$Out = Join-Path $Base "oc-logs"
New-Item -ItemType Directory -Force -Path $Out | Out-Null
Get-ChildItem $Out -File -ErrorAction SilentlyContinue | Remove-Item -Force
$log = Join-Path $Base "oc-log-copy.txt"
function Log($m) { Add-Content $log $m }
Set-Content $log ("copy {0}" -f (Get-Date -Format o))
mountvol Z: /S | Out-Null
Log "efi=$(Test-Path Z:\EFI)"
Get-ChildItem "Z:\EFI\OC","Z:\EFI","Z:\" -File -ErrorAction SilentlyContinue | ForEach-Object {
    Log ("root {0} {1} {2}" -f $_.LastWriteTime.ToString("HH:mm:ss"), $_.Length, $_.Name)
}
Get-ChildItem "Z:\" -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "opencore|OpenCore|\.txt$|BOOT" } | ForEach-Object {
    Log ("hit {0} {1} {2}" -f $_.LastWriteTime.ToString("MM-dd HH:mm:ss"), $_.Length, $_.FullName.Replace("Z:",""))
    if ($_.Extension -match "txt|log|LOG") { Copy-Item $_.FullName (Join-Path $Out $_.Name) -Force }
}
if (Test-Path "Z:\EFI\APPLE\LOG\BOOT-1.LOG") {
    Copy-Item "Z:\EFI\APPLE\LOG\BOOT-1.LOG" (Join-Path $Base "BOOT-1.LOG") -Force
    $b = Get-Item "Z:\EFI\APPLE\LOG\BOOT-1.LOG"
    Log ("bootlog {0} {1}" -f $b.LastWriteTime.ToString("MM-dd HH:mm:ss"), $b.Length)
}
Log "---- firmware ----"
bcdedit /enum "{fwbootmgr}" | Out-String | Add-Content $log

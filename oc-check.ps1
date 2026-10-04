$log = "C:\Users\ZBookMW\Desktop\eGPU\oc-check.txt"
function Log($m){ Add-Content $log $m }
Set-Content $log "check $(Get-Date -Format o)"
mountvol Z: /S
Log "esp=$(Test-Path Z:\EFI\OC\OpenCore.efi)"
Get-ChildItem Z:\EFI\OC -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { Log ("{0} {1}" -f $_.FullName.Replace('Z:',''), $_.Length) }
Log "---- firmware ----"
bcdedit /enum firmware | Out-String | Add-Content $log

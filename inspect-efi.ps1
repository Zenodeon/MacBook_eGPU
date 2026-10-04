$ErrorActionPreference = "Stop"
$log = "C:\Users\ZBookMW\Desktop\eGPU\inspect-log.txt"
function Log($m){ Add-Content $log $m; Write-Output $m }
Set-Content $log "inspect $(Get-Date -Format o)"
New-Item -ItemType Directory -Force -Path "C:\Users\ZBookMW\Desktop\eGPU\acpi" | Out-Null
Set-Location "C:\Users\ZBookMW\Desktop\eGPU\acpi"
& "C:\Users\ZBookMW\Desktop\eGPU\tools\acpidump.exe" -b
Get-ChildItem "C:\Users\ZBookMW\Desktop\eGPU\acpi" | ForEach-Object { Log ("ACPI {0} {1}" -f $_.Name, $_.Length) }
$scriptDisk = "Z:"
if (Test-Path "Z:\") { Log "Z: already in use" } 
mountvol Z: /S
Log "mountvol exit $LASTEXITCODE"
if (Test-Path "Z:\EFI") {
  Get-ChildItem -Path "Z:\EFI" -Recurse -File | ForEach-Object { Log ("EFI {0} {1}" -f $_.FullName.Replace("Z:",""), $_.Length) }
} else {
  Log "No Z:\EFI"
}
cmd /c "bcdedit /enum firmware > C:\Users\ZBookMW\Desktop\eGPU\firmware-bcd.txt"
cmd /c "bcdedit /enum {current} > C:\Users\ZBookMW\Desktop\eGPU\current-bcd.txt"
Log "bcdedit saved"

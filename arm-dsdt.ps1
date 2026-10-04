$ErrorActionPreference = "Stop"
$log = "C:\Users\ZBookMW\Desktop\eGPU\dsdt-arm-log.txt"
function Log($m){ Add-Content $log "$(Get-Date -Format o) $m"; Write-Output $m }
Set-Content $log "arm $(Get-Date -Format o)"
$stage = "C:\Users\ZBookMW\Desktop\eGPU\efi-stage\EFI\OC"
mountvol Z: /S
if (-not (Test-Path "Z:\EFI")) { Log "ESP missing"; exit 1 }
New-Item -ItemType Directory -Force -Path "Z:\EFI\OC\Drivers","Z:\EFI\OC\ACPI" | Out-Null
Copy-Item "$stage\OpenCore.efi" "Z:\EFI\OC\OpenCore.efi" -Force
Copy-Item "$stage\config.plist" "Z:\EFI\OC\config.plist" -Force
Copy-Item "$stage\Drivers\OpenRuntime.efi" "Z:\EFI\OC\Drivers\OpenRuntime.efi" -Force
Copy-Item "$stage\ACPI\DSDT.aml" "Z:\EFI\OC\ACPI\DSDT.aml" -Force
foreach ($f in @("Z:\EFI\OC\OpenCore.efi","Z:\EFI\OC\config.plist","Z:\EFI\OC\Drivers\OpenRuntime.efi","Z:\EFI\OC\ACPI\DSDT.aml")) {
  Log ("file {0} {1}" -f $f, (Get-Item $f).Length)
}
$oc = "{4c8e84a2-29fd-11ec-b08f-bf0eb956520c}"
Log (bcdedit /set $oc device partition=Z: 2>&1 | Out-String).Trim()
Log (bcdedit /set $oc path "\EFI\OC\OpenCore.efi" 2>&1 | Out-String).Trim()
$seq = (bcdedit /set "{fwbootmgr}" bootsequence $oc 2>&1 | Out-String).Trim()
Log $seq
if ($seq -notmatch "successfully") { Log "bootsequence failed"; exit 1 }
Set-Content "C:\Users\ZBookMW\Desktop\eGPU\stage.txt" "need-dsdt" -Encoding ascii
Remove-Item "C:\Users\ZBookMW\Desktop\eGPU\last-boot-id.txt" -ErrorAction SilentlyContinue
Log "stage need-dsdt, rebooting once"
shutdown.exe /r /t 20 /c "One-time boot to give the RTX 3080 a Large Memory window. The Core X stays in the port next to Tab."
Log "shutdown issued"

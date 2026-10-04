$log = "C:\Users\ZBookMW\Desktop\eGPU\rescan-log.txt"
function Log($m){ $line = "$(Get-Date -Format o) $m"; Add-Content $log $line; Write-Output $line }
Set-Content $log "rescan $(Get-Date -Format o)"
pnputil.exe /scan-devices | Out-Null
Start-Sleep -Seconds 5
$tb = "PCI\VEN_8086&DEV_15D2&SUBSYS_00008086&REV_02\6&2E3CAE8B&0&000000E4"
Log "cycling thunderbolt $tb"
try {
  Disable-PnpDevice -InstanceId $tb -Confirm:$false -ErrorAction Stop
  Start-Sleep -Seconds 4
  Enable-PnpDevice -InstanceId $tb -Confirm:$false -ErrorAction Stop
  Start-Sleep -Seconds 12
  Log "thunderbolt cycled"
} catch {
  Log "cycle error $($_.Exception.Message)"
}
pnputil.exe /scan-devices | Out-Null
Start-Sleep -Seconds 8
Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match "VEN_10DE&DEV_2206|VEN_8086&DEV_15DA|VEN_8086&DEV_1927" -and $_.Status -ne "Unknown" } | ForEach-Object {
  $c = (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName "DEVPKEY_Device_ProblemCode" -ErrorAction SilentlyContinue).Data
  Log ("LIVE {0} code={1} {2}" -f $_.Status, $c, $_.FriendlyName)
}
Log "done"

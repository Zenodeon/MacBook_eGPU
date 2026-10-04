$ErrorActionPreference = "Continue"
$log = "C:\Users\ZBookMW\Desktop\eGPU\bridge-log.txt"
function Log($m){ $line = "$(Get-Date -Format o) $m"; Add-Content $log $line }
Set-Content $log "bridge $(Get-Date -Format o)"
$gpuId = "PCI\VEN_10DE&DEV_2206&SUBSYS_161219DA&REV_A1\8&36C1BE61&0&0008000800E4"
function Code($id) {
  $p = Get-PnpDeviceProperty -InstanceId $id -KeyName "DEVPKEY_Device_ProblemCode" -ErrorAction SilentlyContinue
  if ($null -eq $p) { return -1 }
  return [int]$p.Data
}
$before = Code $gpuId
Log "before=$before"
$parent = (Get-PnpDeviceProperty -InstanceId $gpuId -KeyName "DEVPKEY_Device_Parent").Data
Log "parent=$parent"
try {
  Disable-PnpDevice -InstanceId $parent -Confirm:$false -ErrorAction Stop
  Start-Sleep -Seconds 4
  Enable-PnpDevice -InstanceId $parent -Confirm:$false -ErrorAction Stop
  Start-Sleep -Seconds 8
  Log "bridge cycled"
} catch {
  Log "bridge error $($_.Exception.Message)"
}
$gpu = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match "VEN_10DE&DEV_2206" } | Select-Object -First 1
$mid = if ($gpu) { Code $gpu.InstanceId } else { -1 }
Log "after-bridge=$mid id=$($gpu.InstanceId)"
if ($mid -eq 12) {
  $port = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match "VEN_8086&DEV_9D18" } | Select-Object -First 1
  if ($port) {
    try {
      Disable-PnpDevice -InstanceId $port.InstanceId -Confirm:$false -ErrorAction Stop
      Log "disabled 9D18 $($port.InstanceId)"
      Start-Sleep -Seconds 2
      pnputil.exe /scan-devices | Out-Null
      Start-Sleep -Seconds 8
    } catch {
      Log "9D18 error $($_.Exception.Message)"
    }
  } else { Log "9D18 not found" }
  $gpu = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match "VEN_10DE&DEV_2206" } | Select-Object -First 1
  $after = if ($gpu) { Code $gpu.InstanceId } else { -1 }
  Log "after-9D18=$after id=$($gpu.InstanceId) status=$($gpu.Status)"
}
Log "done"

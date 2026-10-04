$log = "C:\Users\ZBookMW\Desktop\eGPU\fix-log.txt"
New-Item -ItemType Directory -Force -Path "C:\Users\ZBookMW\Desktop\eGPU" | Out-Null
function Log($m){ $line = "$(Get-Date -Format o) $m"; Add-Content -Path $log -Value $line }
$pci = "HKLM:\SYSTEM\CurrentControlSet\Control\PnP\Pci"
if (-not (Test-Path $pci)) { New-Item -Path $pci -Force | Out-Null }
New-ItemProperty -Path $pci -Name HackFlags -PropertyType DWord -Value 0x600 -Force | Out-Null
$v = (Get-ItemProperty -Path $pci).HackFlags
Log ("HackFlags set to 0x{0:X}" -f $v)
exit 0

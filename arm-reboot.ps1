$ErrorActionPreference = "Stop"
$base = "C:\Users\ZBookMW\Desktop\MacBook_eGPU"
Set-Content -Path "$base\stage.txt" -Value "hackflags" -Encoding ascii
Remove-Item "$base\last-boot-id.txt" -ErrorAction SilentlyContinue
Remove-Item "$base\reboot-count.txt" -ErrorAction SilentlyContinue
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Users\ZBookMW\Desktop\MacBook_eGPU\postboot.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = "PT45S"
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
Register-ScheduledTask -TaskName "eGPU-Code12" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
"TASK_OK" | Set-Content "$base\task-registered.txt"
Get-ScheduledTask -TaskName "eGPU-Code12" | Select-Object TaskName, State | Format-List | Out-String | Set-Content "$base\task-registered.txt"
shutdown.exe /r /t 25 /c "Restarting to apply the eGPU HackFlags fix. Leave the enclosure on the lower-left Thunderbolt port."
"SHUTDOWN_ISSUED" | Add-Content "$base\task-registered.txt"

$ErrorActionPreference = "Continue"
$Base = "C:\Users\ZBookMW\Desktop\MacBook_eGPU"
$Log = Join-Path $Base "safe-arm-log.txt"
function Log($m) { Add-Content $Log ("{0} {1}" -f (Get-Date -Format o), $m) }
Set-Content $Log ("safe-arm {0}" -f (Get-Date -Format o))

$task = Get-ScheduledTask -TaskName "eGPU-Code12" -ErrorAction SilentlyContinue
if ($task) {
    $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$Base\postboot.ps1`""
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arg
    Set-ScheduledTask -TaskName "eGPU-Code12" -Action $action | Out-Null
    Disable-ScheduledTask -TaskName "eGPU-Code12" | Out-Null
    $now = Get-ScheduledTask -TaskName "eGPU-Code12"
    Log ("task state={0} arg={1}" -f $now.State, $now.Actions[0].Arguments)
} else {
    Log "task eGPU-Code12 not found"
}

mountvol Z: /S | Out-Null
if (-not (Test-Path "Z:\EFI\Microsoft\Boot\bootmgfw.efi")) { Log "ESP mount failed"; exit 1 }

$mgfw = "Z:\EFI\Microsoft\Boot\bootmgfw.efi"
$mgfwBackup = "Z:\EFI\Microsoft\Boot\bootmgfw.original.efi"
$bootx64 = "Z:\EFI\Boot\bootx64.efi"
$orig = "Z:\EFI\Boot\bootx64_original.efi"
$launcher = Join-Path $Base "tools\OpenCore\X64\EFI\BOOT\BOOTx64.efi"
$stage = Join-Path $Base "efi-stage\EFI\OC"

foreach ($p in @($mgfw, $bootx64, $launcher, (Join-Path $stage "config.plist"), (Join-Path $stage "ACPI\DSDT.aml"), (Join-Path $stage "OpenCore.efi"))) {
    if (-not (Test-Path $p)) { Log "missing $p"; exit 2 }
}

if ((Get-Item $mgfw).Length -ne 1604016) {
    if ((Test-Path $mgfwBackup) -and (Get-Item $mgfwBackup).Length -eq 1604016) {
        Copy-Item $mgfwBackup $mgfw -Force
        Log "restored bootmgfw from original"
    }
}
Log ("bootmgfw={0}" -f (Get-Item $mgfw).Length)
Log ("bootx64={0}" -f (Get-Item $bootx64).Length)
if (Test-Path $orig) { Log ("bootx64_original={0}" -f (Get-Item $orig).Length) } else { Log "bootx64_original missing" }

if ((Get-Item $mgfw).Length -ne 1604016) { Log "bootmgfw is not the Windows boot manager; not rebooting"; exit 3 }

if (-not (Test-Path $orig) -or (Get-Item $orig).Length -ne 1604016) {
    if ((Get-Item $bootx64).Length -eq 1604016) {
        Copy-Item $bootx64 $orig -Force
        Log "saved bootx64 as bootx64_original"
    } else {
        Copy-Item $mgfw $orig -Force
        Log "saved bootmgfw as bootx64_original"
    }
}
if ((Get-Item $orig).Length -ne 1604016) { Log "backup is not 1604016; not rebooting"; exit 4 }

Copy-Item (Join-Path $stage "OpenCore.efi") "Z:\EFI\OC\OpenCore.efi" -Force
Copy-Item (Join-Path $stage "config.plist") "Z:\EFI\OC\config.plist" -Force
Copy-Item (Join-Path $stage "Drivers\OpenRuntime.efi") "Z:\EFI\OC\Drivers\OpenRuntime.efi" -Force
Copy-Item (Join-Path $stage "ACPI\DSDT.aml") "Z:\EFI\OC\ACPI\DSDT.aml" -Force
Log ("config={0} dsdt={1}" -f (Get-Item "Z:\EFI\OC\config.plist").Length, (Get-Item "Z:\EFI\OC\ACPI\DSDT.aml").Length)

Copy-Item $launcher $bootx64 -Force
Log ("bootx64 now={0} bootmgfw still={1} backup={2}" -f (Get-Item $bootx64).Length, (Get-Item $mgfw).Length, (Get-Item $orig).Length)
if ((Get-Item $bootx64).Length -gt 100000 -or (Get-Item $mgfw).Length -ne 1604016 -or (Get-Item $orig).Length -ne 1604016) {
    if ((Get-Item $orig).Length -eq 1604016) { Copy-Item $orig $bootx64 -Force }
    Log "size check failed; bootx64 restored if possible; not rebooting"
    exit 5
}

@"
Normal startup runs OpenCore for 5 seconds, then EFI\Microsoft\Boot\bootmgfw.efi.
bootmgfw.efi is the original Windows boot manager.
If the Windows logo does not appear, hold the power button, then hold Option and choose macOS.
From macOS, copy EFI\Boot\bootx64_original.efi over EFI\Boot\bootx64.efi.
"@ | Set-Content "Z:\EFI\RESTORE-WINDOWS-BOOT.txt" -Encoding ascii

Set-Content (Join-Path $Base "stage.txt") "default-dsdt" -Encoding ascii
Log "sizes ok, rebooting"
shutdown.exe /r /t 25 /c "Stay at the Mac. A menu runs for 5 seconds, then the Windows logo. If the logo is still missing after 15 seconds, hold power, then hold Option and choose macOS."
Log "shutdown issued"

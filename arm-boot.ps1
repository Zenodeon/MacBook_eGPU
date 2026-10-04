$ErrorActionPreference = "Continue"
$Base = "C:\Users\ZBookMW\Desktop\MacBook_eGPU"
$Log = Join-Path $Base "boot-arm-log.txt"
function Log($m) { Add-Content $Log ("{0} {1}" -f (Get-Date -Format o), $m) }
Set-Content $Log ("arm-boot {0}" -f (Get-Date -Format o))

mountvol Z: /S | Out-Null
if (-not (Test-Path "Z:\EFI")) { Log "ESP mount failed"; exit 1 }

$uuid = "8C9DAF09-7121-48FF-B7DE-86774A4970A8"
$bootEfi = "Z:\$uuid\System\Library\CoreServices\boot.efi"
$backupEsp = "Z:\$uuid\System\Library\CoreServices\boot.efi.apple"
$backupNt = Join-Path $Base "boot.efi.apple"
$launcher = Join-Path $Base "tools\OpenCore\X64\EFI\BOOT\BOOTx64.efi"
$stage = Join-Path $Base "efi-stage\EFI\OC"

Log "boot.efi exists=$(Test-Path $bootEfi)"
Get-ChildItem Z:\ -Force -ErrorAction SilentlyContinue | ForEach-Object { Log ("root {0}" -f $_.Name) }
Get-ChildItem Z:\ -Recurse -Filter boot.efi -ErrorAction SilentlyContinue | ForEach-Object {
    Log ("found {0} {1}" -f $_.FullName.Replace("Z:",""), $_.Length)
}

if (-not (Test-Path $bootEfi)) { Log "Boot Camp boot.efi missing; not rebooting"; exit 2 }
if (-not (Test-Path $launcher)) { Log "OpenCore launcher missing"; exit 3 }

$size = (Get-Item $bootEfi).Length
Log "Boot Camp boot.efi size=$size"
if ($size -lt 100000) {
    Log "boot.efi is already small; leaving it in place"
} else {
    Copy-Item $bootEfi $backupEsp -Force
    Copy-Item $bootEfi $backupNt -Force
    Copy-Item $launcher $bootEfi -Force
    Log "replaced boot.efi with OpenCore launcher $((Get-Item $bootEfi).Length) bytes; apple backup $((Get-Item $backupNt).Length)"
}

@"
Boot Camp startup now loads OpenCore, which loads the Large Memory table, then Windows.
The original Apple boot.efi is saved as:
  $uuid\System\Library\CoreServices\boot.efi.apple
and as C:\Users\ZBookMW\Desktop\MacBook_eGPU\boot.efi.apple
Windows Boot Manager (EFI\Microsoft\Boot\bootmgfw.efi) was not replaced.
If the Mac stops reaching Windows, hold Option at power-on and choose the other macOS disk.
From macOS, the EFI partition can be mounted and boot.efi.apple copied back over boot.efi.
"@ | Set-Content "Z:\EFI\RESTORE-BOOTCAMP.txt" -Encoding ascii

New-Item -ItemType Directory -Force -Path "Z:\EFI\OC\Drivers","Z:\EFI\OC\ACPI" | Out-Null
Copy-Item (Join-Path $stage "OpenCore.efi") "Z:\EFI\OC\OpenCore.efi" -Force
Copy-Item (Join-Path $stage "config.plist") "Z:\EFI\OC\config.plist" -Force
Copy-Item (Join-Path $stage "Drivers\OpenRuntime.efi") "Z:\EFI\OC\Drivers\OpenRuntime.efi" -Force
Copy-Item (Join-Path $stage "ACPI\DSDT.aml") "Z:\EFI\OC\ACPI\DSDT.aml" -Force
Get-ChildItem "Z:\EFI\OC" -Recurse -File | ForEach-Object { Log ("staged {0} {1}" -f $_.FullName.Replace("Z:",""), $_.Length) }

$oc = "{4c8e84a2-29fd-11ec-b08f-bf0eb956520c}"
Log (bcdedit /set $oc device partition=Z: 2>&1 | Out-String).Trim()
Log (bcdedit /set $oc path "\EFI\OC\OpenCore.efi" 2>&1 | Out-String).Trim()

Set-Content (Join-Path $Base "stage.txt") "need-dsdt" -Encoding ascii
Remove-Item (Join-Path $Base "last-boot-id.txt") -Force -ErrorAction SilentlyContinue
Log "stage need-dsdt, rebooting"
shutdown.exe /r /t 20 /c "Startup now loads the Large Memory table before Windows. The Core X stays in the port next to Tab."
Log "shutdown issued"

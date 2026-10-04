$ErrorActionPreference = "Continue"
$Base = "C:\Users\ZBookMW\Desktop\eGPU"
$Log = Join-Path $Base "boot-arm-log.txt"
function Log($m) { Add-Content $Log ("{0} {1}" -f (Get-Date -Format o), $m) }
Set-Content $Log ("arm-mgfw {0}" -f (Get-Date -Format o))

mountvol Z: /S | Out-Null
if (-not (Test-Path "Z:\EFI\Microsoft\Boot")) { Log "ESP mount failed"; exit 1 }

$mgfw = "Z:\EFI\Microsoft\Boot\bootmgfw.efi"
$backup = "Z:\EFI\Microsoft\Boot\bootmgfw.original.efi"
$chain = "Z:\EFI\Boot\bootx64_original.efi"
$silentDst = "Z:\EFI\Boot\bootx64_silent.efi"
$ntBackup = Join-Path $Base "bootmgfw.original.efi"
$launcher = Join-Path $Base "tools\OpenCore\X64\EFI\BOOT\BOOTx64.efi"
$silentSrc = Join-Path $Base "tools\bootx64_silent.efi"
$stage = Join-Path $Base "efi-stage\EFI\OC"

foreach ($p in @($mgfw, $launcher, $silentSrc, (Join-Path $stage "config.plist"), (Join-Path $stage "ACPI\DSDT.aml"))) {
    if (-not (Test-Path $p)) { Log "missing $p"; exit 2 }
}

$mgfwSize = (Get-Item $mgfw).Length
Log "bootmgfw size=$mgfwSize"
if ($mgfwSize -gt 500000) {
    Copy-Item $mgfw $backup -Force
    Copy-Item $mgfw $chain -Force
    Copy-Item $mgfw $ntBackup -Force
    Log "saved original bootmgfw $((Get-Item $backup).Length)"
} elseif (-not (Test-Path $backup) -or (Get-Item $backup).Length -lt 500000) {
    Log "bootmgfw is small and no original backup exists; not rebooting"
    exit 3
} else {
    Copy-Item $backup $chain -Force
    Log "bootmgfw already replaced; refreshed chain from backup"
}

Copy-Item $launcher $mgfw -Force
Copy-Item $silentSrc $silentDst -Force
Log "bootmgfw now $((Get-Item $mgfw).Length); silent $((Get-Item $silentDst).Length); chain $((Get-Item $chain).Length)"
if ((Get-Item $mgfw).Length -gt 100000 -or (Get-Item $chain).Length -lt 500000) {
    Log "size check failed; not rebooting"
    exit 4
}

@"
Windows startup now loads OpenCore, then apple_set_os, then the real Windows boot manager.
If Windows stops booting, start macOS, mount the EFI partition, and run:
copy /Y EFI\Microsoft\Boot\bootmgfw.original.efi EFI\Microsoft\Boot\bootmgfw.efi
The original Windows boot manager is also at EFI\Boot\bootx64_original.efi
and at C:\Users\ZBookMW\Desktop\eGPU\bootmgfw.original.efi
"@ | Set-Content "Z:\EFI\RESTORE-WINDOWS-BOOT.txt" -Encoding ascii

New-Item -ItemType Directory -Force -Path "Z:\EFI\OC\Drivers","Z:\EFI\OC\ACPI" | Out-Null
Copy-Item (Join-Path $stage "OpenCore.efi") "Z:\EFI\OC\OpenCore.efi" -Force
Copy-Item (Join-Path $stage "config.plist") "Z:\EFI\OC\config.plist" -Force
Copy-Item (Join-Path $stage "Drivers\OpenRuntime.efi") "Z:\EFI\OC\Drivers\OpenRuntime.efi" -Force
Copy-Item (Join-Path $stage "ACPI\DSDT.aml") "Z:\EFI\OC\ACPI\DSDT.aml" -Force
Get-ChildItem "Z:\EFI\OC" -Recurse -File | ForEach-Object { Log ("staged {0} {1}" -f $_.FullName.Replace("Z:",""), $_.Length) }
Log ("silent-dst {0}" -f (Get-Item $silentDst).Length)
Log ("chain-dst {0}" -f (Get-Item $chain).Length)

Set-Content (Join-Path $Base "stage.txt") "need-dsdt" -Encoding ascii
Remove-Item (Join-Path $Base "last-boot-id.txt") -Force -ErrorAction SilentlyContinue
Log "stage need-dsdt, rebooting"
shutdown.exe /r /t 20 /c "Startup now loads the Large Memory table, then Windows. The Core X stays in the port next to Tab."
Log "shutdown issued"

$ErrorActionPreference = "Continue"
$Base = "C:\Users\ZBookMW\Desktop\MacBook_eGPU"
$Log = Join-Path $Base "boot-arm-log.txt"
function Log($m) { Add-Content $Log ("{0} {1}" -f (Get-Date -Format o), $m) }
Set-Content $Log ("arm-bootx64 {0}" -f (Get-Date -Format o))

mountvol Z: /S | Out-Null
if (-not (Test-Path "Z:\EFI\Boot")) { Log "ESP mount failed"; exit 1 }

$bootx64 = "Z:\EFI\Boot\bootx64.efi"
$chain = "Z:\EFI\Boot\bootx64_original.efi"
$silent = "Z:\EFI\Boot\bootx64_silent.efi"
$launcher = Join-Path $Base "tools\OpenCore\X64\EFI\BOOT\BOOTx64.efi"
$stage = Join-Path $Base "efi-stage\EFI\OC"
$mgfw = "Z:\EFI\Microsoft\Boot\bootmgfw.efi"

foreach ($p in @($bootx64, $chain, $silent, $launcher, $mgfw, (Join-Path $stage "config.plist"))) {
    if (-not (Test-Path $p)) { Log "missing $p"; exit 2 }
}
if ((Get-Item $chain).Length -lt 500000) { Log "chain too small"; exit 3 }
if ((Get-Item $mgfw).Length -lt 500000) { Log "bootmgfw is not the Windows loader"; exit 4 }

$cur = (Get-Item $bootx64).Length
Log "bootx64 before=$cur"
if ($cur -gt 100000) {
    Copy-Item $launcher $bootx64 -Force
}
Log "bootx64 after=$((Get-Item $bootx64).Length) chain=$((Get-Item $chain).Length) mgfw=$((Get-Item $mgfw).Length)"
if ((Get-Item $bootx64).Length -gt 100000) { Log "replace failed"; exit 5 }

Copy-Item (Join-Path $stage "OpenCore.efi") "Z:\EFI\OC\OpenCore.efi" -Force
Copy-Item (Join-Path $stage "config.plist") "Z:\EFI\OC\config.plist" -Force
Copy-Item (Join-Path $stage "Drivers\OpenRuntime.efi") "Z:\EFI\OC\Drivers\OpenRuntime.efi" -Force
Copy-Item (Join-Path $stage "ACPI\DSDT.aml") "Z:\EFI\OC\ACPI\DSDT.aml" -Force

@"
The normal Windows startup file EFI\Boot\bootx64.efi now loads the Large Memory table, then Windows.
The real Windows boot file is EFI\Boot\bootx64_original.efi
and also EFI\Microsoft\Boot\bootmgfw.efi
If the Mac stops reaching Windows, start macOS, mount the EFI partition, and run:
copy /Y EFI\Boot\bootx64_original.efi EFI\Boot\bootx64.efi
"@ | Set-Content "Z:\EFI\RESTORE-WINDOWS-BOOT.txt" -Encoding ascii

Set-Content (Join-Path $Base "stage.txt") "need-dsdt" -Encoding ascii
Remove-Item (Join-Path $Base "last-boot-id.txt") -Force -ErrorAction SilentlyContinue
Log "stage need-dsdt, rebooting"
shutdown.exe /r /t 20 /c "Startup now goes through the Large Memory loader. The Core X stays in the port next to Tab."
Log "shutdown issued"

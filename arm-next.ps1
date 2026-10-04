$ErrorActionPreference = "Continue"
$Base = "C:\Users\ZBookMW\Desktop\MacBook_eGPU"
$Log = Join-Path $Base "boot-arm-log.txt"
function Log($m) { Add-Content $Log ("{0} {1}" -f (Get-Date -Format o), $m) }
Set-Content $Log ("arm-next {0}" -f (Get-Date -Format o))

mountvol Z: /S | Out-Null
if (-not (Test-Path "Z:\EFI\OC")) { Log "ESP mount failed"; exit 1 }

$mgfw = "Z:\EFI\Microsoft\Boot\bootmgfw.efi"
$backup = "Z:\EFI\Microsoft\Boot\bootmgfw.original.efi"
if ((Test-Path $backup) -and (Get-Item $backup).Length -gt 500000) {
    Copy-Item $backup $mgfw -Force
    Log "restored bootmgfw to $((Get-Item $mgfw).Length)"
} else {
    Log "no original bootmgfw to restore"
}

$stage = Join-Path $Base "efi-stage\EFI\OC"
Copy-Item (Join-Path $stage "OpenCore.efi") "Z:\EFI\OC\OpenCore.efi" -Force
Copy-Item (Join-Path $stage "config.plist") "Z:\EFI\OC\config.plist" -Force
Copy-Item (Join-Path $stage "Drivers\OpenRuntime.efi") "Z:\EFI\OC\Drivers\OpenRuntime.efi" -Force
Copy-Item (Join-Path $stage "ACPI\DSDT.aml") "Z:\EFI\OC\ACPI\DSDT.aml" -Force
Log ("config {0}" -f (Get-Item "Z:\EFI\OC\config.plist").Length)
Log ("bootx64 {0}" -f (Get-Item "Z:\EFI\Boot\bootx64.efi").Length)
Log ("silent {0}" -f (Get-Item "Z:\EFI\Boot\bootx64_silent.efi").Length)
Log ("chain {0}" -f (Get-Item "Z:\EFI\Boot\bootx64_original.efi").Length)

if ((Get-Item "Z:\EFI\Boot\bootx64_original.efi").Length -lt 500000) {
    Log "Windows chain file missing; not rebooting"
    exit 2
}

$oc = "{4c8e84a2-29fd-11ec-b08f-bf0eb956520c}"
Log (bcdedit /set $oc device partition=Z: 2>&1 | Out-String).Trim()
Log (bcdedit /set $oc path "\EFI\OC\OpenCore.efi" 2>&1 | Out-String).Trim()
Log (bcdedit /set "{fwbootmgr}" bootsequence $oc 2>&1 | Out-String).Trim()

Set-Content (Join-Path $Base "stage.txt") "need-dsdt" -Encoding ascii
Remove-Item (Join-Path $Base "last-boot-id.txt") -Force -ErrorAction SilentlyContinue
Log "stage need-dsdt, rebooting"
shutdown.exe /r /t 20 /c "One more startup through the Large Memory loader. The Core X stays in the port next to Tab."
Log "shutdown issued"

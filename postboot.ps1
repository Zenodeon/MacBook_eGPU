$ErrorActionPreference = "Continue"
$Base = "C:\Users\ZBookMW\Desktop\eGPU"
$Log = Join-Path $Base "postboot-status.txt"
$StageFile = Join-Path $Base "stage.txt"
$RebootFile = Join-Path $Base "reboot-count.txt"
$OcGuid = "{4c8e84a2-29fd-11ec-b08f-bf0eb956520c}"
$BootCampGuid = "{8e72434b-babd-11f1-b8ff-806e6f6e6963}"
$Silent = Join-Path $Base "tools\bootx64_silent.efi"
$StageDir = Join-Path $Base "efi-stage\EFI\OC"

function Log($m) {
    $line = "{0} {1}" -f (Get-Date -Format o), $m
    Add-Content -Path $Log -Value $line
}

function Get-Stage {
    if (Test-Path $StageFile) { return (Get-Content $StageFile -Raw).Trim() }
    return "hackflags"
}

function Set-Stage($name) {
    Set-Content -Path $StageFile -Value $name -Encoding ascii
    Log "stage -> $name"
}

function Get-Reboots {
    if (Test-Path $RebootFile) { return [int](Get-Content $RebootFile -Raw) }
    return 0
}

function Request-Reboot($reason) {
    $n = (Get-Reboots) + 1
    Set-Content -Path $RebootFile -Value $n -Encoding ascii
    Log "reboot $n requested: $reason"
    if ($n -gt 4) {
        Log "reboot limit reached; not rebooting"
        Set-Stage "stuck"
        return
    }
    shutdown.exe /r /t 20 /c "eGPU fix: $reason"
}

function Get-Rtx {
    Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object {
        $_.InstanceId -match "VEN_10DE&DEV_2206"
    } | Select-Object -First 1
}

function Get-ProblemCode($dev) {
    if (-not $dev) { return -1 }
    $p = Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName "DEVPKEY_Device_ProblemCode" -ErrorAction SilentlyContinue
    if ($null -eq $p) { return -1 }
    return [int]$p.Data
}

function Get-Iris {
    Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object {
        $_.InstanceId -match "VEN_8086&DEV_1927"
    } | Select-Object -First 1
}

function Test-LargeMemory {
    $dir = Join-Path $Base "acpi-live"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Get-ChildItem $dir -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Push-Location $dir
    & (Join-Path $Base "tools\acpidump.exe") -b | Out-Null
    Pop-Location
    $dsdt = Get-ChildItem $dir -File | Where-Object { $_.Name -like "dsdt*" } | Select-Object -First 1
    if (-not $dsdt) { return $false }
    $bytes = [IO.File]::ReadAllBytes($dsdt.FullName)
    $pat = [byte[]](0x00, 0x00, 0x00, 0x20, 0x0C, 0x00, 0x00, 0x00)
    for ($i = 0; $i -le $bytes.Length - 8; $i++) {
        $ok = $true
        for ($j = 0; $j -lt 8; $j++) {
            if ($bytes[$i + $j] -ne $pat[$j]) { $ok = $false; break }
        }
        if ($ok) { return $true }
    }
    return $false
}

function Mount-Esp {
    if (-not (Test-Path "Z:\EFI")) {
        mountvol Z: /S | Out-Null
    }
    return (Test-Path "Z:\EFI")
}

function Install-AppleSetOs {
    if (-not (Mount-Esp)) { Log "ESP mount failed"; return $false }
    if (-not (Test-Path $Silent)) { Log "silent loader missing"; return $false }
    $mgfw = "Z:\EFI\Microsoft\Boot\bootmgfw.efi"
    $backup = "Z:\EFI\Microsoft\Boot\bootmgfw.original.efi"
    $chain = "Z:\EFI\Boot\bootx64_original.efi"
    $ntBackup = Join-Path $Base "bootmgfw.original.efi"
    if (-not (Test-Path $mgfw)) { Log "bootmgfw missing"; return $false }
    $size = (Get-Item $mgfw).Length
    if ($size -gt 500000) {
        Copy-Item $mgfw $backup -Force
        Copy-Item $mgfw $chain -Force
        Copy-Item $mgfw $ntBackup -Force
        Copy-Item $Silent $mgfw -Force
        Log "replaced bootmgfw ($size bytes) with apple_set_os loader"
    } else {
        Log "bootmgfw already replaced ($size bytes)"
    }
    @"
If Windows stops booting, start macOS, mount the EFI partition, and run:
copy /Y EFI\Microsoft\Boot\bootmgfw.original.efi EFI\Microsoft\Boot\bootmgfw.efi
The original Windows boot manager is also at EFI\Boot\bootx64_original.efi
"@ | Set-Content "Z:\EFI\RESTORE-WINDOWS-BOOT.txt" -Encoding ascii
    return (Test-Path $chain)
}

function Enable-DsdtBoot {
    if (-not (Mount-Esp)) { Log "ESP mount failed for DSDT"; return $false }
    if (-not (Test-Path (Join-Path $StageDir "OpenCore.efi"))) { Log "OpenCore stage missing"; return $false }
    New-Item -ItemType Directory -Force -Path "Z:\EFI\OC\Drivers","Z:\EFI\OC\ACPI" | Out-Null
    Copy-Item (Join-Path $StageDir "OpenCore.efi") "Z:\EFI\OC\OpenCore.efi" -Force
    Copy-Item (Join-Path $StageDir "config.plist") "Z:\EFI\OC\config.plist" -Force
    Copy-Item (Join-Path $StageDir "Drivers\OpenRuntime.efi") "Z:\EFI\OC\Drivers\OpenRuntime.efi" -Force
    Copy-Item (Join-Path $StageDir "ACPI\DSDT.aml") "Z:\EFI\OC\ACPI\DSDT.aml" -Force
    $setDev = bcdedit /set $OcGuid device partition=Z: 2>&1 | Out-String
    $setPath = bcdedit /set $OcGuid path "\EFI\OC\OpenCore.efi" 2>&1 | Out-String
    $seq = bcdedit /set "{fwbootmgr}" bootsequence $OcGuid 2>&1 | Out-String
    Log "bcdedit device: $($setDev.Trim())"
    Log "bcdedit path: $($setPath.Trim())"
    Log "bcdedit bootsequence: $($seq.Trim())"
    return ($seq -match "successfully")
}

function Set-OpenCoreDefault {
    $out = bcdedit /set "{fwbootmgr}" displayorder $OcGuid /addfirst 2>&1 | Out-String
    Log "OpenCore set as default firmware boot: $($out.Trim())"
    return ($out -match "successfully")
}

function Invoke-BridgeCycle($gpu) {
    $parent = (Get-PnpDeviceProperty -InstanceId $gpu.InstanceId -KeyName "DEVPKEY_Device_Parent" -ErrorAction SilentlyContinue).Data
    Log "parent bridge $parent"
    if ($parent -notmatch "VEN_8086&DEV_15DA") {
        Log "parent is not the enclosure bridge; skip cycle"
        return
    }
    try {
        Disable-PnpDevice -InstanceId $parent -Confirm:$false -ErrorAction Stop
        Start-Sleep -Seconds 4
        Enable-PnpDevice -InstanceId $parent -Confirm:$false -ErrorAction Stop
        Start-Sleep -Seconds 8
        Log "bridge cycled"
    } catch {
        Log "bridge cycle error: $($_.Exception.Message)"
    }
}

function Disable-RightPort {
    $port = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object {
        $_.InstanceId -match "VEN_8086&DEV_9D18"
    } | Select-Object -First 1
    if (-not $port) { Log "root port 9D18 not found"; return }
    try {
        Disable-PnpDevice -InstanceId $port.InstanceId -Confirm:$false -ErrorAction Stop
        Log "disabled 9D18 $($port.InstanceId)"
        Start-Sleep -Seconds 2
        pnputil.exe /scan-devices | Out-Null
        Start-Sleep -Seconds 8
    } catch {
        Log "9D18 disable error: $($_.Exception.Message)"
    }
}

$bootId = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString("o")
$ranFile = Join-Path $Base "last-boot-id.txt"
if ((Test-Path $ranFile) -and ((Get-Content $ranFile -Raw).Trim() -eq $bootId)) {
    exit 0
}
Set-Content -Path $ranFile -Value $bootId -Encoding ascii

Log "===== boot $bootId ====="
$stage = Get-Stage
Log "enter stage $stage"
if ($stage -in @("done","stuck")) {
    Log "nothing to do"
    exit 0
}

$gpu = $null
for ($i = 0; $i -lt 30; $i++) {
    $gpu = Get-Rtx
    if ($gpu) { break }
    Start-Sleep -Seconds 3
}
$code = Get-ProblemCode $gpu
Log "gpu present=$([bool]$gpu) code=$code status=$($gpu.Status) id=$($gpu.InstanceId)"

if ($stage -eq "hackflags" -and $code -eq 12) {
    Log "skip bridge reset; it bugchecked 0x50"
    $gpu = Get-Rtx
    $code = Get-ProblemCode $gpu
}

$iris = Get-Iris
$large = Test-LargeMemory
Log "iris present=$([bool]$iris) status=$($iris.Status) largeMemory=$large finalCode=$code"

$ok = ($null -ne $gpu -and $code -eq 0)
if ($stage -eq "hackflags") {
    if ($ok -and -not $iris) {
        if (Install-AppleSetOs) {
            Set-Stage "apple"
            Request-Reboot "apple_set_os so Iris stays on"
        } else {
            Set-Stage "stuck"
        }
    } elseif ($ok -and $iris) {
        Set-Stage "done"
        Log "RESULT code 12 clear and Iris already present"
    } elseif ($code -eq 12) {
        if (Enable-DsdtBoot) {
            Set-Stage "need-dsdt"
            Request-Reboot "one-time OpenCore DSDT Large Memory"
        } else {
            Set-Stage "stuck"
            Log "RESULT could not arm DSDT boot"
        }
    } elseif ($code -eq -1) {
        Log "RTX 3080 not on the bus yet; rescanning"
        pnputil.exe /scan-devices | Out-Null
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep -Seconds 3
            $gpu = Get-Rtx
            if ($gpu) { break }
        }
        $code = Get-ProblemCode $gpu
        Log "after extra wait code=$code"
        if ($code -eq 12) {
            Log "skip late bridge reset; it bugchecked 0x50"
        }
        if ($code -eq 12) {
            if (Enable-DsdtBoot) {
                Set-Stage "need-dsdt"
                Request-Reboot "one-time OpenCore DSDT Large Memory"
            } else { Set-Stage "stuck" }
        } elseif ($code -eq 0) {
            if (-not (Get-Iris)) {
                if (Install-AppleSetOs) { Set-Stage "apple"; Request-Reboot "apple_set_os so Iris stays on" }
                else { Set-Stage "stuck" }
            } else { Set-Stage "done"; Log "RESULT code 12 clear and Iris present" }
        } else {
            Set-Stage "wait-gpu"
            Log "RESULT enclosure not enumerated; leaving stage wait-gpu"
        }
    } else {
        Set-Stage "stuck"
        Log "RESULT unexpected gpu code $code"
    }
} elseif ($stage -eq "need-dsdt") {
    if ($ok -and $large) {
        Log "DSDT boot cleared code 12 and Large Memory is present"
        if (-not $iris) {
            Log "RESULT Large Memory cleared code 12, but Iris is still off"
            Set-Stage "stuck"
        } else {
            Set-Stage "done"
            Log "RESULT code 12 clear with Large Memory and Iris"
        }
    } else {
        Set-Stage "stuck"
        Log "RESULT DSDT boot did not clear code 12 (code=$code large=$large)"
    }
} elseif ($stage -eq "apple") {
    if ($ok -and $iris) {
        Set-Stage "done"
        Log "RESULT Iris is active and RTX 3080 code is 0"
    } elseif ($code -eq 12 -and -not $large) {
        Log "Iris boot brought code 12 back; arming DSDT"
        if (Enable-DsdtBoot) {
            Set-Stage "need-dsdt"
            Request-Reboot "DSDT after Iris made code 12 return"
        } else {
            Set-Stage "stuck"
        }
    } else {
        Set-Stage "stuck"
        Log "RESULT apple_set_os boot iris=$([bool]$iris) code=$code large=$large"
    }
}

Log "leave stage $(Get-Stage)"
exit 0

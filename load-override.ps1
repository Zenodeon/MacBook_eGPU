$ErrorActionPreference = "Continue"
$Base = "C:\Users\ZBookMW\Desktop\MacBook_eGPU"
$Log = Join-Path $Base "override-log.txt"
function Log($m) { Add-Content $Log ("{0} {1}" -f (Get-Date -Format o), $m) }
Set-Content $Log ("override {0}" -f (Get-Date -Format o))

$task = Get-ScheduledTask -TaskName "eGPU-Code12" -ErrorAction SilentlyContinue
if ($task) {
    Disable-ScheduledTask -TaskName "eGPU-Code12" | Out-Null
    Log ("task={0}" -f (Get-ScheduledTask -TaskName "eGPU-Code12").State)
} else {
    Log "task not found"
}

mountvol Z: /S | Out-Null
$mgfw = "Z:\EFI\Microsoft\Boot\bootmgfw.efi"
$bootx64 = "Z:\EFI\Boot\bootx64.efi"
$orig = "Z:\EFI\Boot\bootx64_original.efi"
if (-not (Test-Path $mgfw)) { Log "ESP mount failed"; exit 1 }

Log ("bootmgfw={0}" -f (Get-Item $mgfw).Length)
Log ("bootx64={0}" -f (Get-Item $bootx64).Length)
if (Test-Path $orig) { Log ("backup={0}" -f (Get-Item $orig).Length) } else { Log "backup missing" }

if ((Get-Item $bootx64).Length -ne 1604016) {
    if ((Test-Path $orig) -and (Get-Item $orig).Length -eq 1604016) {
        Copy-Item $orig $bootx64 -Force
        Log ("restored bootx64 to {0}" -f (Get-Item $bootx64).Length)
    } else {
        Log "bootx64 is not the Windows boot manager and no backup; not rebooting"
        exit 2
    }
}
if ((Get-Item $mgfw).Length -ne 1604016) {
    $saved = "Z:\EFI\Microsoft\Boot\bootmgfw.original.efi"
    if ((Test-Path $saved) -and (Get-Item $saved).Length -eq 1604016) {
        Copy-Item $saved $mgfw -Force
        Log ("restored bootmgfw to {0}" -f (Get-Item $mgfw).Length)
    } else {
        Log "bootmgfw is not the Windows boot manager; not rebooting"
        exit 3
    }
}
if ((Get-Item $bootx64).Length -ne 1604016 -or (Get-Item $mgfw).Length -ne 1604016) {
    Log "boot files still wrong; not rebooting"
    exit 4
}

$src = Join-Path $Base "acpitabl.dat"
if (-not (Test-Path $src) -or (Get-Item $src).Length -ne 34352) { Log "acpitabl.dat missing"; exit 5 }
Copy-Item $src "C:\Windows\System32\acpitabl.dat" -Force
$placed = Get-Item "C:\Windows\System32\acpitabl.dat"
Log ("acpitabl.dat={0}" -f $placed.Length)

$ts = bcdedit /set testsigning on 2>&1 | Out-String
Log ("testsigning: {0}" -f $ts.Trim())
if ($ts -notmatch "successfully") { Log "test signing was not enabled; not rebooting"; exit 6 }

Log "normal Windows reboot"
shutdown.exe /r /t 20 /c "Normal Windows restart to load the memory table. The Windows startup file was not replaced."
Log "shutdown issued"

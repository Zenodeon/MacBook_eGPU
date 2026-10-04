$ErrorActionPreference = "Stop"
$Base = "C:\Users\ZBookMW\Desktop\MacBook_eGPU"
$Log = Join-Path $Base "egpuboot-log.txt"
function Log($m) { Add-Content $Log ("{0} {1}" -f (Get-Date -Format o), $m); Write-Output $m }
Set-Content $Log ("egpuboot {0}" -f (Get-Date -Format o))

function Snapshot {
    Get-Partition -DiskNumber 0 | ForEach-Object { "{0}|{1}|{2}|{3}" -f $_.PartitionNumber, $_.Offset, $_.Size, $_.GptType }
}

try {
    $before = @(Snapshot)
    $before | ForEach-Object { Log "before $_" }
    if ($before.Count -ne 4) { Log "ABORT expected 4 partitions"; exit 1 }
    $free = (Get-Disk -Number 0).LargestFreeExtent
    Log "free=$free"
    if ($free -lt 1000MB -or $free -gt 1100MB) { Log "ABORT free space is not about 1024 MB"; exit 1 }

    $letter = @('E','F','G','H','I','J','K','L','M','N') | Where-Object { -not (Test-Path "$($_):\") } | Select-Object -First 1
    $p = New-Partition -DiskNumber 0 -UseMaximumSize -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}" -DriveLetter $letter
    Log ("created partition={0} size={1} offset={2} letter={3}" -f $p.PartitionNumber, $p.Size, $p.Offset, $letter)
    Format-Volume -DriveLetter $letter -FileSystem FAT32 -NewFileSystemLabel EGPUBOOT -Confirm:$false -Force | Out-Null
    $v = Get-Volume -DriveLetter $letter
    Log ("volume fs={0} label={1} size={2}" -f $v.FileSystem, $v.FileSystemLabel, $v.Size)

    $after = @(Snapshot)
    $after | ForEach-Object { Log "after $_" }
    for ($i = 0; $i -lt 4; $i++) {
        if ($after[$i] -ne $before[$i]) { Log "WARNING partition $($i+1) changed" }
    }
    Log "done letter=$letter"
} catch {
    Log ("ERROR {0}" -f $_.Exception.Message)
    exit 2
}

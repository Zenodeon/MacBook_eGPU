$ErrorActionPreference = "Continue"
$Log = "C:\Users\ZBookMW\Desktop\eGPU\esp-now.txt"
function Log($m) { Add-Content $Log $m }
Set-Content $Log ("esp-now {0}" -f (Get-Date -Format o))
mountvol Z: /S | Out-Null
Log "efi=$(Test-Path Z:\EFI)"
Get-ChildItem "Z:\EFI" -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    Log ("{0} {1} {2}" -f $_.LastWriteTime.ToString("HH:mm:ss"), $_.Length, $_.FullName.Replace("Z:",""))
}
Log "---- firmware ----"
bcdedit /enum firmware | Out-String | Add-Content $Log

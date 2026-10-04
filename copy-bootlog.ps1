$dst = "C:\Users\ZBookMW\Desktop\MacBook_eGPU\BOOT-1.LOG"
mountvol Z: /S | Out-Null
Copy-Item "Z:\EFI\APPLE\LOG\BOOT-1.LOG" $dst -Force
Get-Item $dst | ForEach-Object { "copied {0} {1}" -f $_.Length, $_.LastWriteTime }

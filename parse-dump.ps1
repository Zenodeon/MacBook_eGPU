$ErrorActionPreference = "Stop"
$src = "C:\Windows\Minidump\100426-6234-01.dmp"
$dst = "C:\Users\ZBookMW\Desktop\eGPU\crash.dmp"
Copy-Item $src $dst -Force
$b = [IO.File]::ReadAllBytes($dst)
function U32($o){ [BitConverter]::ToUInt32($b, $o) }
function U64($o){ [BitConverter]::ToUInt64($b, $o) }
$sig = [Text.Encoding]::ASCII.GetString($b, 0, 4)
$streams = U32 8
$dir = U32 12
"sig=$sig streams=$streams dir=$dir size=$($b.Length)"
$modules = $null
$excAddr = $null
for ($i=0; $i -lt $streams; $i++) {
  $e = $dir + ($i*12)
  $type = U32 $e
  $size = U32 ($e+4)
  $rva = U32 ($e+8)
  if ($type -eq 4) { $modules = $rva }
  if ($type -eq 6) { $excAddr = U64 ($rva + 24) }
}
"exception=$($excAddr.ToString('X16'))"
$count = U32 $modules
"modules=$count"
$hit = $null
for ($i=0; $i -lt $count; $i++) {
  $m = $modules + 4 + ($i*108)
  $base = U64 $m
  $size = U32 ($m+8)
  $nameRva = U32 ($m+20)
  $nameLen = U32 $nameRva
  $name = [Text.Encoding]::Unicode.GetString($b, $nameRva+4, $nameLen)
  if ($excAddr -ge $base -and $excAddr -lt ($base + $size)) {
    $off = $excAddr - $base
    $hit = "{0} + 0x{1:X}" -f $name, $off
  }
}
if ($hit) { "FAULT $hit" } else { "FAULT module not found" }

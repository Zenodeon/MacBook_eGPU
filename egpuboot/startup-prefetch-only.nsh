@echo -off
echo "EGPUBOOT: move 9D14 prefetch window to 0x280000000-0x2FFFFFFFF, then start Windows."

for %i in 0 1 2 3 4 5 6 7 8 9
  if exist fs%i:\egpuboot.tag then
    fs%i:
    goto FOUND
  endif
endfor

echo "EGPUBOOT volume not found. Restarting without changes."
stall 5000000
reset

:FOUND
cd \
if not exist egpuboot.tag then
  echo "Wrong volume. Restarting without changes."
  stall 5000000
  reset
endif

echo "Saving before-dumps..."
pci 00 1C 04 -i >a w-before-rp05.txt
pci 03 00 00 -i >a w-before-b03.txt
pci 04 00 00 -i >a w-before-b04d0.txt
pci 04 01 00 -i >a w-before-b04d1.txt
pci 04 02 00 -i >a w-before-b04d2.txt
pci 04 04 00 -i >a w-before-b04d4.txt
pci 07 00 00 -i >a w-before-b07.txt
pci 08 01 00 -i >a w-before-b08.txt
pci 09 00 00 -i >a w-before-b09-gpu.txt

echo "Writing 9D14 prefetch window..."
mm 001C0424 FFF1 -w 2 -pci -n
mm 001C0428 00000002 -w 4 -pci -n
mm 001C042C 00000002 -w 4 -pci -n
mm 001C0426 FFF1 -w 2 -pci -n
mm 001C0424 8001 -w 2 -pci -n

pci 00 1C 04 -i >a w-after-rp05.txt
echo "written" >a w-done.txt

for %j in 0 1 2 3 4 5 6 7 8 9
  if exist fs%j:\EFI\Boot\bootx64_original.efi then
    if exist fs%j:\EFI\Boot\bootx64.efi then
      echo "Starting fs%j:\EFI\Boot\bootx64.efi"
      echo "fs%j" >a w-esp.txt
      fs%j:\EFI\Boot\bootx64.efi
    endif
  endif
endfor

echo "EFI partition not found or Windows did not start. Restarting."
stall 5000000
reset

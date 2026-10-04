@echo -off
echo "EGPUBOOT: slide the 32-bit window and the devices inside it, then start Windows."

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
pci 05 00 00 -i >a w-before-b05-nhi.txt
pci 06 00 00 -i >a w-before-b06-usb.txt
pci 07 00 00 -i >a w-before-b07.txt
pci 08 01 00 -i >a w-before-b08.txt
pci 09 00 00 -i >a w-before-b09-gpu.txt
pci 09 00 01 -i >a w-before-b09-audio.txt

echo "Writing 9D14 prefetch window..."
mm 001C0424 FFF1 -w 2 -pci -n
mm 001C0428 00000002 -w 4 -pci -n
mm 001C042C 00000002 -w 4 -pci -n
mm 001C0426 FFF1 -w 2 -pci -n
mm 001C0424 8001 -w 2 -pci -n

echo "Pausing devices that are using the old 32-bit window..."
mm 05000004 0004 -w 2 -pci -n
mm 06000004 0005 -w 2 -pci -n

echo "Sliding bridge windows by 0x4A000000..."
mm 03000020 CC70 -w 2 -pci -n
mm 03000022 DA80 -w 2 -pci -n
mm 04000020 CC80 -w 2 -pci -n
mm 04000022 CC80 -w 2 -pci -n
mm 04010020 CC90 -w 2 -pci -n
mm 04010022 D3F0 -w 2 -pci -n
mm 04020020 CC70 -w 2 -pci -n
mm 04020022 CC70 -w 2 -pci -n
mm 04040020 D390 -w 2 -pci -n
mm 04040022 DA80 -w 2 -pci -n
mm 07000020 CD00 -w 2 -pci -n
mm 07000022 CE00 -w 2 -pci -n
mm 08010020 CD00 -w 2 -pci -n
mm 08010022 CE00 -w 2 -pci -n

echo "Sliding device registers by 0x4A000000..."
mm 05000010 CC800000 -w 4 -pci -n
mm 05000014 CC840000 -w 4 -pci -n
mm 06000010 CC700000 -w 4 -pci -n
mm 09000010 CD000000 -w 4 -pci -n
mm 09000030 CE000000 -w 4 -pci -n
mm 09000110 CE080000 -w 4 -pci -n

echo "Opening the 9D14 32-bit window at 0xCC700000..."
mm 001C0420 FFF0 -w 2 -pci -n
mm 001C0422 DFF0 -w 2 -pci -n
mm 001C0420 CC70 -w 2 -pci -n

mm 05000004 0006 -w 2 -pci -n
mm 06000004 0007 -w 2 -pci -n

pci 00 1C 04 -i >a w-after-rp05.txt
pci 03 00 00 -i >a w-after-b03.txt
pci 05 00 00 -i >a w-after-b05-nhi.txt
pci 07 00 00 -i >a w-after-b07.txt
pci 09 00 00 -i >a w-after-b09-gpu.txt
pci 09 00 01 -i >a w-after-b09-audio.txt
echo "slid16" >a w-done.txt

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

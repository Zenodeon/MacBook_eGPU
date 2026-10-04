@echo -off
echo "EGPUBOOT read-only PCI dump. No PCI writes."

for %i in 0 1 2 3 4 5 6 7 8 9
  if exist fs%i:\egpuboot.tag then
    fs%i:
    goto FOUND
  endif
endfor

echo "EGPUBOOT volume not found. Restarting without dumping."
stall 5000000
reset

:FOUND
cd \
if not exist egpuboot.tag then
  echo "Wrong volume. Restarting without dumping."
  stall 5000000
  reset
endif

echo "Writing dumps to EGPUBOOT..."
map -r >a map.txt
pci >a pci-all.txt
pci 00 1C 04 -i >a rp05-9d14.txt
pci 00 1D 00 -i >a rp09-9d18.txt
pci 00 1C 00 -i >a rp01-9d10.txt
pci 00 1D 03 -i >a rp12-9d1b.txt
memmap >a memmap.txt
echo "done" >a done.txt

echo "Dump finished. Restarting in 5 seconds; let Windows start normally."
stall 5000000
reset

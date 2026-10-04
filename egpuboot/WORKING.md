# Working eGPU fix

Record of the boot at 12:44 AM on 5 October 2026, when the RTX 3080 reached problem code 0. Making this run on every normal Windows start, without holding Option, is not done yet.

## Machine

- MacBookPro13,2 (Late 2016 13-inch Touch Bar), Windows 10 Pro 22H2 build 19045.
- Razer Core X on the lower-left Thunderbolt port, the one next to Tab. That port is PCI Express Root Port #5, device 9D14 (`PCI\VEN_8086&DEV_9D14\...\E4`).
- GPU: NVIDIA GeForce RTX 3080, `VEN_10DE&DEV_2206`.

## What "working" means

On the 00:44 boot these devices were problem code 0:

- RTX 3080
- the 3080's HD Audio controller
- Thunderbolt USB
- Intel Iris Graphics 550
- Broadcom Wi-Fi
- the Apple SSD

The Thunderbolt controller itself (15D2) was code 43. That is the controller reporting a problem after it started. It is not a missing address, and it did not stop the GPU.

Windows gave the 3080 three memory blocks:

| Block | Address | Size |
|---|---|---|
| Control registers | `0x8E000000` | 16 MB |
| Graphics memory | `0x2E0000000` | 256 MB |
| Second prefetch block | `0x2F0000000` | 32 MB |

## The cause

Apple's firmware programs the lower-left port before Windows starts, and Windows keeps those windows:

- Prefetch window: `0xB0000000`–`0xBDFFFFFF`, 224 MB. The Core X bridge needs 288 MB (256 MB of graphics memory plus 32 MB).
- 32-bit window: `0x82700000`–`0x908FFFFF`, 226 MB. The 3080's 16 MB control block can only sit on a 16 MB boundary, so the first usable start inside that window is `0x83000000`. 224 MB from there ends at `0x91000000`, past the end of the window. The shortage is the alignment, not the raw size.

The 2 GB range `0x280000000`–`0x2FFFFFFFF` is free above RAM. A DSDT override already gives that range to the PCI root, but the current Windows PCI driver will not move the port's firmware windows into it.

## What the working boot does

1. The Core X is already plugged into the lower-left port.
2. Restart, hold Option, and choose **EFI Boot**. That is the 1 GB FAT32 partition labeled EGPUBOOT (disk 0, partition 5, drive E: in Windows).
3. OpenCore's UEFI Shell runs [startup-trim.nsh](startup-trim.nsh). It does not change any device register. It only changes bridge windows:
   - Prefetch window of 9D14 moves to `0x280000000`–`0x2FFFFFFFF` (2 GB).
   - The empty right-side Thunderbolt port window (15D3 device 4, `0x89900000`–`0x908FFFFF`) is closed. Nothing is plugged into it.
   - The 32-bit windows of 9D14 and of the Thunderbolt chip's top bridge (1578) are shortened so they end at `0x8FFFFFFF` (217 MB). The start stays `0x82700000`. The 3080's control registers stay at `0x83000000`, where the card's own startup display driver is already using them.
4. The script then starts the Mac's existing `\EFI\Boot\bootx64.efi`, so the silent startup that keeps Iris and Wi-Fi on still runs, and then Windows starts.

After that, Windows kept both windows and assigned:

- 9D14: 217 MB at `0x82700000`–`0x8FFFFFFF`, and 2 GB at `0x280000000`–`0x2FFFFFFFF`.
- Thunderbolt chip bridge 1578: 208 MB at `0x83000000`–`0x8FFFFFFF`.
- Core X downstream bridge: 17 MB below 4 GB, and 288 MB at `0x2E0000000`–`0x2F1FFFFFF`.

The shell writes are in [startup-trim.nsh](startup-trim.nsh):

```
mm 001C0424 FFF1 -w 2 -pci -n
mm 001C0428 00000002 -w 4 -pci -n
mm 001C042C 00000002 -w 4 -pci -n
mm 001C0426 FFF1 -w 2 -pci -n
mm 001C0424 8001 -w 2 -pci -n
mm 04040020 FFF0 -w 2 -pci -n
mm 04040022 0000 -w 2 -pci -n
mm 03000022 8FF0 -w 2 -pci -n
mm 001C0422 8FF0 -w 2 -pci -n
```

## What has to stay

- DSDT override in `C:\Windows\System32\acpitabl.dat`: OEM revision `0x00130006`, with the 2 GB prefetch producer at `0x280000000`. Test signing stays on, or Windows will not load that table.
- The Mac EFI partition is unchanged. `\EFI\Boot\bootx64.efi` is the silent startup file (246,784 bytes). `\EFI\Boot\bootx64_original.efi` is the Windows boot manager (1,604,016 bytes).
- `C:\Windows\System32\drivers\pci.sys` is the current driver, file version 10.0.19041.6456, 473,488 bytes. The copy from before any experiment is `pci-19041.sys` in the project folder.
- The cable stays in the lower-left port, and it has to be connected before power-on. The script runs before Windows and does not wait for a later plug-in.

A normal restart does not run the script. The firmware puts the 224 MB window back, and the 3080 returns to code 12 until the next Option → EFI Boot.

## What did not work

- HackFlags `0x600`. That only reopens a closed window or recovers from running out of bus numbers. This window was already open, and it was too small.
- Three DSDT placements of the large prefetch range, including the 2 GB window above RAM. Windows allocated that range on the PCI root and still left 9D14 at 224 MB.
- Replacing `pci.sys` with the Windows 10 1903 file, version 10.0.18362.1. The port stayed at 224 MB. The original driver was put back.
- A PCI `_DSM` function 5 that tells Windows it may ignore the firmware layout. The new table loaded. The port stayed at 224 MB. The previous table was put back.
- Disabling the right-hand root port (9D18). Wi-Fi dropped, because that disable made Windows rebalance the port the Wi-Fi card is on.
- Moving the 32-bit window to free space at `0xCC000000`, including a second attempt that also moved every device register by a 16 MB-aligned amount. The writes read back correctly, and Windows then stopped on its logo, before the kernel started. The 3080's startup display driver was still using `0x83000000`. The boot that reached the desktop never moved that address.

## How to do it again

1. Plug the Core X into the lower-left port.
2. Restart and hold Option until the boot menu appears.
3. Choose **EFI Boot**. Do not press anything during the shell countdown.
4. Windows starts on its own. The 3080 should be code 0.

`E:\startup.nsh` and `E:\EFI\BOOT\startup.nsh` are the trim script. `E:\startup-prefetch-only.nsh` is the earlier script that only moves the prefetch window. That one reaches the desktop, but the 3080 stays code 12.

If the machine stops on the Windows logo, hold the power button until it turns off, then start without holding Option. That boot does not run the script.

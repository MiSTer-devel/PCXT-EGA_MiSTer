# DOS configuration reference

The files in [`hdd/`](../hdd/) are a working reference for a DOS installation
that uses the PCXT-EGA core's current memory and audio layout. They are not
required by the RTL, but they keep the DOS drivers, the OSD and software
detection in agreement.

## Matching OSD settings

The supplied configuration expects these core options:

- **Hardware → UMB C400-CFFF: Enabled** exposes 48 KiB at
  `C4000h-CFFFFh`.
- **Hardware → 2MB EMS D000-DFFF: Enabled** exposes the four 16 KiB EMS
  page-frame banks at `D0000h-DFFFFh`. The backing store is up to 2 MiB and
  the Lo-tech-compatible page registers are at port `260h`.
- **Audio & Video → Audio 220h: Sound Blaster** selects the Sound Blaster
  instead of C/MS, since both devices overlap at `220h` and collide at
  `226h/227h`.
- **Hardware → Sound Blaster IRQ: 5** is the default. IRQ 7 is also supported,
  but DOS software and its `BLASTER` variable must select the same value.

The core also decodes SDRAM at `E0000h-EBFFFh`, but that region is deliberately
not registered as a DOS UMB. The EMS frame lies between the C400h and E000h
regions, so treating `C400h-EC00h` as one contiguous UMB would overlap EMS.

## CONFIG.SYS

The checked-in [`hdd/CONFIG.SYS`](../hdd/CONFIG.SYS) is:

```dos
FILES=40
BUFFERS = 30
DOS = HIGH, UMB
DEVICE=C:\UTIL\USE!UMBS.SYS C400-D000
DEVICE=C:\UTIL\DOSMAX\DOSMAX.EXE /R+ /N+ /P-
DEVICEHIGH=C:\UTIL\LTEMM.EXE /p:D000 /x /n
SHELL=C:\UTIL\DOSMAX\SHELLMAX.COM C:\COMMAND.COM C:\ /E:256 /P
```

`USE!UMBS.SYS` uses an end-exclusive upper segment: `C400-D000` therefore
registers exactly `C4000h-CFFFFh`, stopping before the EMS page frame. It is
the driver notation for the same window the OSD calls `C400-CFFF`.

`DOSMAX.EXE` and `SHELLMAX.COM` move DOS data and the command interpreter's
overhead into that UMB. `LTEMM.EXE /p:D000` registers the core's fixed EMS
page frame; no `/i:` argument is needed because `260h` is already LTEMM's
default I/O port.

If UMB or EMS is disabled in the OSD or temporarily with XTEGACTL, remove or
comment the matching driver line for that boot. A DOS driver cannot create a
memory device that the core has taken off the bus.

## AUTOEXEC.BAT and Sound Blaster variables

[`hdd/AUTOEXEC.BAT`](../hdd/AUTOEXEC.BAT) provides this starting point:

```bat
@ECHO OFF
SET PATH=C:\UTIL;%PATH%
SET BLASTER=A220 I5 D1 T4
SET SOUND=C:\SB
SET MIDI=SYNTH:1 MAP:E MODE:0
C:\UTIL\CTMOUSE\CTMOUSE.EXE
```

The `BLASTER` fields describe the actual hardware rather than configuring it:

| Field | Meaning in this core |
|---|---|
| `A220` | Sound Blaster base address `220h` |
| `I5` | IRQ 5, the default OSD choice |
| `D1` | 8-bit DMA channel 1 |
| `T4` | Sound Blaster Pro-compatible card type |

`SET SOUND=C:\SB` is the installation directory used by Creative utilities;
change it to the real directory or omit it when those utilities are not
installed. `SET MIDI=...` is another Creative software convention and does not
control the core's separate MPU-401 at `330h`.

When a game needs IRQ 7, change the hardware override and the environment
together:

```bat
@ECHO OFF
SET BLASTER=A220 I7 D1 T4
XTEGACTL sb sbirq=7
GAME.EXE
XTEGACTL reset
SET BLASTER=A220 I5 D1 T4
```

Omitting `sbirq=` or using `sbirq=auto` follows the OSD. `XTEGACTL status`
shows the effective IRQ and adds `(OSD)` when it matches the current menu
setting.

The final line in the supplied example starts CuteMouse. It probes PS/2 first
and then the serial ports, so the core's COM1 mouse normally needs no command
line switches. See [`hdd/CTMOUSE/CTMOUSE.TXT`](../hdd/CTMOUSE/CTMOUSE.TXT)
for explicit port, IRQ and protocol options.

## Per-program profiles

XTEGACTL rewrites its complete override register set on every invocation. A
batch file should therefore name every override that program needs, then use
`XTEGACTL reset` on exit:

```bat
@ECHO OFF
SET BLASTER=A220 I5 D1 T4
XTEGACTL 4.77 sb sbirq=5 joy1=digital
GAME.EXE
XTEGACTL reset
```

Anything not named remains under OSD control. These overrides apply
immediately and do not require a matching machine reset. CPU Type, the EGA
monitor profile and the second SD-card mapping remain OSD-only because the core
samples them during reset.

## MiSTer.ini example for a 31 kHz analogue display

For a VGA monitor that should receive scaler output rather than the core's
native 15 kHz EGA raster, add a core-specific section to `MiSTer.ini`:

```ini
[PCXT-EGA]
vga_scaler=1
video_mode=6
vsync_adjust=2
```

MiSTer matches `[PCXT-EGA]` against the name embedded in the core, so the
settings do not affect other cores. Mode 6 is the built-in 640×480,
25.175 MHz preset. `vsync_adjust=2` follows the core's approximately 59.917 Hz
refresh and avoids periodic repeated frames, but the result is non-standard;
use `vsync_adjust=1` if a flat panel rejects it. Do not enable `vga_scaler`
when the intention is to use the core's direct 15 kHz CRT output.

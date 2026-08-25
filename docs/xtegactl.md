# XTEGACTL

Per-program hardware control for the PCXT-EGA core. A DOS program writes a
small block of I/O ports to set the machine up the way it wants before it runs,
so a batch file can do what the user would otherwise do by hand in the OSD.

```
XTEGACTL 4.77 adlib joy1=digital
GAME.EXE
XTEGACTL reset
```

RTL: [`xtegactl.sv`](../rtl/KFPC-XT/HDL/xtegactl.sv) (port block) and
[`xtegactl_resolve.sv`](../rtl/KFPC-XT/HDL/xtegactl_resolve.sv) (what the
fields mean). Tool: [`SW/XTEGACTL`](../SW/XTEGACTL).

## The contract

**Everything XTEGACTL can change takes effect immediately.** No field needs a
machine reset, there is no apply-and-reboot command, and there is no state that
has to survive a reset. That single rule is what the whole design is arranged
around, and it is why several otherwise plausible settings are absent.

**Zero means "leave it to the OSD".** Every field encodes 0 as defer and 1..N
as the N choices, listed in the same order the menu lists them. Three
consequences follow: the power-on state of all zeroes is plain OSD behaviour;
a program overrides only what it names; and a setting left behind by an earlier
program cannot quietly capture an option nobody meant to touch.

## Register map

The block is at **8980h–898Fh**. All sixteen ports are decoded, so a read of a
reserved one returns a defined zero rather than whatever the bus was holding.

| Port | Access | Contents |
|---|---|---|
| `8980h` | R | Signature, `45h` (`'E'`) |
| `8981h` | R/W | CPU — `[2:0]` speed · `[4:3]` Fake 286 FLAGS |
| `8982h` | R/W | Expansion — `[1:0]` OPL2 · `[3:2]` CMS · `[5:4]` EMS · `[7:6]` UMB |
| `8983h` | R/W | Video — `[1:0]` VGA 13h+ |
| `8984h` | R/W | Input — `[1:0]` joy 1 · `[3:2]` joy 2 · `[5:4]` swap · `[7:6]` joy sync |
| `8985h` | R/W | MIDI — `[1:0]` MT32-pi mode |
| `8986h`–`898Fh` | — | Reserved, read as zero |

### Field values

| Field | Width | `0` | `1` | `2` | `3` | `4` |
|---|---|---|---|---|---|---|
| Speed | 3 | OSD | 4.77 MHz | 7.16 MHz | 9.54 MHz | Max |
| Fake 286 FLAGS | 2 | OSD | off | on | — | |
| OPL2 | 2 | OSD | Adlib 388h | SB FM 388h/228h | disabled | |
| CMS / EMS / UMB | 2 | OSD | enabled | disabled | — | |
| VGA 13h+ | 2 | OSD | off | on | — | |
| Joystick 1 / 2 | 2 | OSD | analog | digital | disabled | |
| Swap joysticks | 2 | OSD | normal | swapped | — | |
| Joy sync to CPU | 2 | OSD | off | on | — | |
| MT32-pi mode | 2 | OSD | MT-32 | General MIDI | — | |

Speed is the only field wider than two bits, because it picks between four
choices rather than three. Values above `4` are not choices, so they read as
defer rather than aliasing onto a speed.

VGA 13h+ controls only *whether* the extension is present, not *which* timing
profile it uses. The core already carries those as separate signals
(`vga_mode13_osd` and `vga_mode13_native`), so the program decides whether and
the user keeps deciding which — Native or 60 Hz — from the OSD.

## Why the block is at 8980h

The old XTCTL port was 8888h. That address was never a safe place to grow a
register block, and the reason is worth writing down.

The motherboard chip select decoder in
[`Peripherals.sv`](../rtl/KFPC-XT/HDL/Peripherals.sv) ignores `address[15:10]`
entirely. It qualifies on `~address[9] & ~address[8]` and then switches on
`address[7:5]`:

```systemverilog
if (iorq & ~address_enable_n & ~address[9] & ~address[8])
    casez (address[7:5])
```

This is what a real PC/XT does — only A0–A9 exist on the bus, so everything
above aliases down. The consequence here is that **every port whose bits 9 and
8 are both clear also lands on one of the on-board devices.** 8888h is such a
port: `address[7:5]` is `100`, which selects the DMA page registers.

A write there reaches [`Bus_Arbiter.sv`](../rtl/KFPC-XT/HDL/Bus_Arbiter.sv),
where `address[1:0]` picks which page register is written:

```systemverilog
else if ((~dma_page_chip_select_n) && (~io_write_n) && (DMA_PAGE_INDEX == address[1:0]))
    dma_page_register[dma_page_i] <= internal_data_bus[3:0];
```

8888h has `address[1:0] == 0`, and `dma_page_register[0]` is the one index
nothing ever reads back — channels 2, 3 and the rest use indices 1, 2 and 3.
**That is the only reason the old port was ever harmless.** The ports one, two
and three along from it are not: 888Ah would overwrite the page register for
DMA channel 3, and 888Dh the one for channel 2, which is the floppy.

Bit 8 of 8980h is set, so the on-board decoder never fires anywhere in the new
block and all sixteen ports are usable, every bit of them. The rest of the
8900h–89FFh page is free for the same reason if the block ever needs to grow.

## What is deliberately absent

**Anything the core only samples during reset.** Three OSD options are latched
while reset is asserted: CPU Type, the EGA monitor switches, and the 2nd SD
card mapping. A program cannot usefully set them — it would have to reboot to
make them take, and a program that reboots the machine from a batch file is
indistinguishable from a crash. They also describe the user's machine rather
than the program running on it. They stay in the OSD, which since
`742555a` says so when one of them is waiting on a reset.

CPU Type is additionally the one setting that could not be made live even in
principle without real surgery: `pfq_depth` is combinational in `IS8086`
([`mcl86_biu_max.sv`](../rtl/8088/mcl86_biu_max.sv)), so switching while the
prefetch queue holds more bytes than the narrower depth allows would leave
`pfq_used` above `pfq_depth` and desync the pointers.

**Display settings.** CRT H/V offset, sync widths, the 350-line mode, aspect
ratio, scandoubler and the monochrome tint all belong to whatever the user has
plugged in. A game that moves them decentres a picture the user has no reason
to connect back to the game.

**Audio volume, boost and stereo mix**, for the same reason: user preference,
not a property of the program.

**BIOS Writable, the storage mapping, and the boot splash.** The first would
let any program overwrite the BIOS; the second would remap storage under a
running DOS; the third is meaningless once a program is running.

**Floppy write protect** was considered and dropped: four values would need
three bits, breaking the uniform field width, and preserving a disk image is
the user's decision rather than the program's.

## Relation to XTCTL

XTEGACTL replaces XTCTL on this core, and the old 8888h port is retired. It is
not a new version of XTCTL: the address, the register layout and the option
names are all different. XTCTL remains the parent PCXT core's tool and is
untouched there.

On PCXT-EGA, XTCTL had decayed. Three of its options — `composite`, `border`
and `a000hoff` — controlled features that do not exist in this fork and had
become silent no-ops. Its speed options were worse than useless because the
names never matched what they selected:

| XTCTL option | Speed actually selected |
|---|---|
| `5Mhz` | 4.77 MHz |
| `8Mhz` | 7.16 MHz |
| `10Mhz` | 9.54 MHz |
| `AT4Mhz` | Max |

XTEGACTL names the actual speeds.

## Detection

The tool reads the signature at `8980h` and refuses to run if it is not `45h`.
This is not ceremony: the tool travels in the disk image while the RBF is
updated separately and often, so running a new XTEGACTL on an older core is a
normal thing to end up doing. An undecoded port leaves
`data_bus_out_from_chipset` low and the read returns whatever the bus was
holding, never the last value written, so the check is reliable — but without
it the failure would look exactly like the tool doing nothing at all.

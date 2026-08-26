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

The DOS utility is kept small enough for the core's low-memory environment.
Its diagnostics use direct DOS console output instead of `stdio`; this avoids
the Open Watcom startup allocation for unused stream structures before `main`.

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

The block is at **8980h–898Fh**. All sixteen ports are decoded. The last seven
ports are a read-only status extension: they report the effective values after
the OSD and XTEGACTL overrides have been resolved, plus which values currently
match the OSD.

| Port | Access | Contents |
|---|---|---|
| `8980h` | R | Signature, `45h` (`'E'`) |
| `8981h` | R/W | CPU — `[2:0]` speed · `[4:3]` Fake 286 FLAGS |
| `8982h` | R/W | Expansion — `[1:0]` OPL2 · `[3:2]` CMS · `[5:4]` EMS · `[7:6]` UMB |
| `8983h` | R/W | Video — `[1:0]` VGA 13h+ |
| `8984h` | R/W | Input — `[1:0]` joy 1 · `[3:2]` joy 2 · `[5:4]` swap · `[7:6]` joy sync |
| `8985h` | R/W | MIDI — `[1:0]` MT32-pi mode · `[3:2]` MPU-401 |
| `8986h` | R/W | Expansion 2 — `[1:0]` Tandy sound · `[3:2]` Sound Blaster · `[5:4]` Sound Blaster IRQ |
| `8987h` | R/W | CRT offset — `[3:0]` H · `[6:4]` V · `[7]` override |
| `8988h` | R/W | Sync width — `[2:0]` VSync · `[5:3]` HSync (`0` = OSD) |
| `8989h` | R | Effective CPU/audio — speed `[1:0]` · Fake FLAGS `[3]` · OPL2 `[5:4]` · Audio 220h `[7:6]` |
| `898Ah` | R | Effective memory/video/input — EMS `[0]` · UMB `[1]` · VGA 13h+ `[2]` · joy 1 `[4:3]` · joy 2 `[6:5]` · swap `[7]` |
| `898Bh` | R | Effective input/MIDI/audio — joy sync `[0]` · MT32-pi `[1]` · MPU-401 `[2]` · Tandy `[4:3]` · SB IRQ7 `[5]`; `[7:6] = 10b` status-extension marker |
| `898Ch` | R | Effective CRT position — H `[3:0]` · V `[6:4]` |
| `898Dh` | R | Effective sync widths — VSync `[2:0]` · HSync `[5:3]`; `[7:6]` are OSD-match flags for VSync/HSync |
| `898Eh` | R | OSD-match flags `[7:0]` |
| `898Fh` | R | OSD-match flags `[15:8]` |

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
| MPU-401 | 2 | OSD | enabled | disabled | — | |
| Tandy sound | 2 | OSD | disabled | enabled | — | |
| Sound Blaster | 2 | OSD | enabled | disabled | — | |
| Sound Blaster IRQ | 2 | OSD | IRQ5 | IRQ7 | reserved | |

Speed is the only field wider than two bits, because it picks between four
choices rather than three. Values above `4` are not choices, so they read as
defer rather than aliasing onto a speed.

The effective status bytes use canonical menu values rather than the raw
override encodings: speed is `0..3` for 4.77/7.16/9.54/Max; OPL2 is `0..2`
for Adlib/SB FM/disabled; Audio 220h is `0..2` for C/MS/Sound Blaster/disabled;
joysticks are `0..2` for analog/digital/disabled; and the remaining boolean
fields use `0=off` or `0=disabled`, `1=on` or `1=enabled`. Tandy uses the low
bit of its two-bit field, and Sound Blaster IRQ uses `0=IRQ5`, `1=IRQ7`.

The OSD-match mask is ordered as follows: bit 0 speed, 1 Fake 286 FLAGS, 2
OPL2, 3 Audio 220h, 4 EMS, 5 UMB, 6 joystick 1, 7 joystick 2, 8 swap, 9 joy
sync, 10 MT32-pi, 11 MPU-401, 12 Tandy, 13 Sound Blaster IRQ, 14 CRT H, 15
CRT V, 16 VSync and 17 HSync. The two high bits (16 and 17) are carried in
`898Dh[7:6]`; the other flags are in `898Eh` and `898Fh`. A field is marked as
matching when its effective value equals the live OSD value, even if an
explicit XTEGACTL override selected that same value.

VGA 13h+ controls only *whether* the extension is present, not *which* timing
profile it uses. The core already carries those as separate signals
(`vga_mode13_osd` and `vga_mode13_native`), so the program decides whether and
the user keeps deciding which — Native or 60 Hz — from the OSD.

Tandy sound defers to a menu option like everything else above, but whether the
SN76489 exists at all is still a build-time choice (`ENABLE_TANDY_AUDIO` in
`config.tcl`), so the field cannot switch on hardware that is not there —
enforced again at the chip select itself, so a stray write cannot reach a
device that was never built. That build gate used to be the *only* thing zero
could defer to, because the menu had no status bit left for it; now that one is
free, zero defers to the menu the same way EMS or UMB does.

MPU-401 works the same way as EMS and UMB: the menu option is the master
switch — with it off, the card is gone from the bus entirely and `330h`/`331h`
read back as if nothing were there. The MT32-pi menu page hides itself in that
case too, the same way it already hides when no mt32-pi is detected, since
there is nothing left for it to configure. The field earns
its place for the same reason Tandy's does, and Tandy's is worth repeating
here because it is the same failure shape: a game that probes `330h`, finds an
MPU-401 and picks Roland/MIDI output over its own OPL2 fallback may not be the
device you wanted it to find, and `nompu` takes the card away for that program
without disturbing anything else — no reset needed, same as every other field
here.

## The Sound Blaster takes 220h from the C/MS

Both cards live at 220h and they collide on `226h`/`227h`, where one puts
its DSP reset and the other its detection register. Only one of them can
answer, so the OSD offers them as a single three-way choice and cannot ask
for both.

These two fields are independent, though, and a program can set either.
When both say yes the Sound Blaster wins: a program that went out of its
way to ask for one is a better guess at intent than a default left
enabled. Asking for the Sound Blaster therefore takes the C/MS away for
that program, and giving it back is a matter of clearing the field.

The *Hardware → Sound Blaster IRQ* OSD option selects the default interrupt
line, independently as IRQ5 or IRQ7.
The OSD's default is IRQ5; `XTEGACTL sbirq=5` and `XTEGACTL sbirq=7` select a
line for the current program, while omitting the option (or using
`sbirq=auto`) follows the OSD. The override is stored in bits `[5:4]` of
`8986h`, with `0` meaning OSD, `1` meaning IRQ5 and `2` meaning IRQ7.

## Screen geometry

Centring a picture is per-program work rather than a property of the
machine — the offsets that suit one game's overscan suit the next one
badly — so a launcher can set them at `8987h` on its way past.

The offsets cannot use the usual rule where a zero field means defer,
because zero is a real offset. Bit 7 says whether the register is
speaking at all: clear it and the OSD's own H and V offsets apply, set it
and the register's do.

The sync widths at `8988h` use the same zero-as-defer rule as the other
fields: zero follows the OSD and a non-zero value is a per-program override.
Their OSD entries use the first six extended status bits, `status[69:64]`,
which are persisted by the normal core CFG file. With both XTEGACTL fields
clear, the core therefore follows the saved or currently selected OSD values;
writing a non-zero field takes precedence until XTEGACTL is reset.

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

**Display settings.** The tool exposes CRT H/V offsets and sync widths for
launchers that need a per-program adjustment. The 350-line mode, aspect ratio,
scanline filter and monochrome tint remain user display preferences.

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

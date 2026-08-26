XTEGACTL - per-program hardware control for the PCXT-EGA core
=============================================================

Sets the machine up the way a program wants it, from DOS, without walking the
OSD. Meant to sit in a batch file next to the thing it configures:

    XTEGACTL 4.77 adlib joy1=digital
    GAME.EXE
    XTEGACTL reset

Every setting applies immediately. There is nothing here that needs a machine
reset, and that is the whole point of the tool.


OPTIONS
-------

  CPU       4.77  7.16  9.54  max
            fake286  nofake286

  Audio     adlib          OPL2 at 388h only
            sbfm           OPL2 at 388h and 228h
            noadlib        no OPL2
            cms  nocms      C/MS at 220h or not
            sb   nosb       Sound Blaster at 220h or not
            sbirq=auto|5|7  Sound Blaster IRQ (OSD default is IRQ5)

            "sbirq=5" and "sbirq=7" select the Sound Blaster interrupt line.
            "sbirq=auto" (or omitting the option) follows the OSD.

  Memory    ems  noems
            umb  noumb

  Input     joy1=analog | joy1=digital | joy1=off
            joy2=analog | joy2=digital | joy2=off
            swap  noswap
            joysync  nojoysync

  MIDI      mt32           MT32-pi in MT-32 mode
            gm             MT32-pi in General MIDI mode

  Tandy     tandy  notandy

            The SN76489 at 0C0h. Left unnamed, this defers to the OSD's Tandy
            Sound menu option like everything else here. Whether the chip
            exists at all is still set when the core is built, though, so it
            can never switch on a chip that was not built in.

            Useful because detection cuts both ways: a game that probes 0C0h,
            finds a Tandy and picks its Tandy music driver may not be the one
            you wanted. "notandy" takes the chip away for that program only.

  CRT       hpos=0..15  vpos=0..7  crt=auto

            Setting either position enables the CRT-position override. Specify
            both values when setting a position; an omitted value is zero.
            "crt=auto" leaves both positions under OSD control.

  Sync      hsync=auto|0..7  vsync=auto|0..7

            Auto is the default. Fixed HSync values are units of 16 pixel
            clocks; fixed VSync values are scanlines.

  reset     hand every setting back to the OSD and disable VGA 13h+
  status    print effective values and mark values matching the OSD


HOW IT BEHAVES
--------------

Anything not named on the command line is left to the OSD. The menu stays in
charge of it, and changing the menu still works. VGA 13h+ is the exception:
it starts disabled, `VGATSR.COM` enables it, and ordinary XTEGACTL commands
leave that state untouched.

`XTEGACTL status` reports the effective value of every runtime setting, even
when that value comes from the OSD. Values followed by `(OSD)` match the live
menu setting; an explicit program override that happens to select the same
value is also marked `(OSD)`. VGA 13h+ is reported as the actual `on`/`off`
state and has no OSD marker because `VGATSR.COM`, not a menu enable setting,
owns that extension.

The status extension is read-only at `8989h`-`898Fh`. Cores that predate it are
detected by the tool and use the older override-only display instead of showing
misleading zero values.

Settings are not cumulative. Each run rewrites the whole register file, so a
setting left behind by one program never leaks into the next. That means a
batch file only has to name what it needs, and "XTEGACTL reset" puts
everything back. `reset` also disables VGA 13h+; run `VGATSR.COM` again if
the extension is needed afterwards.

A warm restart (CTRL+ALT+DEL) does not clear the overrides. A machine reset
does - from the OSD, or by reloading the core.


WHAT IS NOT HERE, AND WHY
-------------------------

Three OSD options are only sampled while the machine is in reset: CPU Type,
Monitor, and 2nd SD card. A program cannot usefully change those - it would
have to reboot the machine to make them take, which from a batch file is
indistinguishable from a crash. They also describe the user's machine rather
than the program running on it. They stay in the OSD, which now tells you when
one of them is waiting on a reset.

The CRT positions and sync widths can be set for a program when a launcher
needs them. The 350-line mode, aspect ratio, scanline filter and monochrome
tint remain user display preferences.

Audio volume, boost and stereo mix are user preferences for the same reason.

BIOS Writable, the storage mapping and the boot splash are either dangerous to
change from a running program or meaningless once one is running.


IF IT SAYS THE CORE DOES NOT HAVE THE PORT BLOCK
------------------------------------------------

The tool checks for a signature byte before writing anything. This tool
travels in the disk image while the RBF is updated separately, so running a
new XTEGACTL on an older core is a normal thing to end up doing. Rather than
writing into dead ports and appearing to do nothing, it stops and says so.
Update the PCXT-EGA RBF.


RELATION TO XTCTL
-----------------

XTEGACTL replaces XTCTL on this core. It is not a new version of it: the port
moved, the register layout is different, and the option names are different.
XTCTL is still what the parent PCXT core uses, and it still works there.

On PCXT-EGA, XTCTL's composite, border and a000hoff options had quietly become
no-ops - the features they controlled do not exist in this fork - and its
speed option names never matched the speeds they selected: "5Mhz" selected
4.77 MHz, "8Mhz" selected 7.16, "10Mhz" selected 9.54, and "AT4Mhz" selected
the maximum. XTEGACTL names the actual speeds.


BUILDING
--------

Open Watcom:

    wmake

Builds for the 8088, so it runs on the core in its shipped configuration
rather than only after the 8086 option has been picked in the OSD.

Open Watcom also has a Linux build, which cross-compiles this fine:

Download the portable v2 build from:

    https://openwatcom.org/ftp/source/ow_portable_v2_stable.zip

Then unpack it and set the toolchain environment (the portable package uses
`binl` on Linux):

    export WATCOM=$HOME/ow-portable-v2-stable
    export PATH=$WATCOM/binl:$PATH
    export INCLUDE=$WATCOM/h
    wmake -a

Note -l=com in the makefile. Without it the linker emits an MZ executable, and
calling that XTEGACTL.COM does not make it one: DOS would load the header bytes
as code and the program would die on its first instruction.

XTEGACTL writes diagnostics directly through DOS rather than using `stdio`.
This avoids the Open Watcom startup allocation for stream structures, which can
fail before `main` on a DOS configuration with very little conventional memory.

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
            cms  nocms

  Memory    ems  noems
            umb  noumb

  Video     vga13  novga13

  Input     joy1=analog | joy1=digital | joy1=off
            joy2=analog | joy2=digital | joy2=off
            swap  noswap
            joysync  nojoysync

  MIDI      mt32           MT32-pi in MT-32 mode
            gm             MT32-pi in General MIDI mode

  Tandy     tandy  notandy

            The SN76489 at 0C0h. Unlike everything else here this has no menu
            option behind it - whether the chip exists at all is set when the
            core is built - so leaving it unnamed follows the build rather than
            a setting, and it cannot switch on a chip that was not built in.

            Useful because detection cuts both ways: a game that probes 0C0h,
            finds a Tandy and picks its Tandy music driver may not be the one
            you wanted. "notandy" takes the chip away for that program only.

  reset     hand every setting back to the OSD
  status    print what is currently overridden


HOW IT BEHAVES
--------------

Anything not named on the command line is left to the OSD. The menu stays in
charge of it, and changing the menu still works.

Settings are not cumulative. Each run rewrites the whole register file, so a
setting left behind by one program never leaks into the next. That means a
batch file only has to name what it needs, and "XTEGACTL reset" puts
everything back.

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

Display settings - CRT H/V offset, sync widths, 350-line mode, aspect ratio,
scandoubler, monochrome tint - belong to whatever the user has plugged in, not
to the program. A game moving them would decentre a picture the user has no
reason to connect back to the game.

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

    export WATCOM=$HOME/watcom
    export PATH=$WATCOM/binl64:$PATH
    export INCLUDE=$WATCOM/h
    wmake

Note -l=com in the makefile. Without it the linker emits an MZ executable, and
calling that XTEGACTL.COM does not make it one: DOS would load the header bytes
as code and the program would die on its first instruction.

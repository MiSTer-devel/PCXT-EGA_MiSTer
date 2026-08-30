@ECHO OFF
REM PCXT-EGA reference environment. Keep BLASTER IRQ in step with the OSD.
SET PATH=C:\UTIL;%PATH%
SET BLASTER=A220 I5 D1 T4
REM SOUND and MIDI are conventions used by Creative software, not core setup.
SET SOUND=C:\SB
SET MIDI=SYNTH:1 MAP:E MODE:0
C:\UTIL\CTMOUSE\CTMOUSE.EXE

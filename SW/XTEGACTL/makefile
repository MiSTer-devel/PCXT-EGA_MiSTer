# Open Watcom.
#
# -0      keep the output on the 8088 this core boots as by default: the 8086
#         selection is an OSD option, so a .COM built for 186 or later would
#         fault on a machine left in its shipped configuration.
# -mt     tiny model, which is what a .COM has to be: one segment, no
#         relocations.
# -l=com  emit a real .COM. Without it -lr produces an MZ executable, and
#         naming that .COM does not make it one - DOS would load the header
#         bytes as code and the program would die on its first instruction.
all: XTEGACTL.COM

XTEGACTL.COM: XTEGACTL.C
	wcl -q -y -0 -s -d0 -mt -l=com -we -wx -k1024 -os XTEGACTL.C -fe=XTEGACTL.COM

# The host toolchain names the intermediate .obj on DOS/Windows and .o on
# Linux, so sweep both.
clean:
	if exist *.obj del *.obj
	if exist *.o del *.o
	if exist *.map del *.map
	if exist *.bak del *.bak

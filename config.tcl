# PCXT-EGA configuration
set_global_assignment -name VERILOG_MACRO "ENABLE_OPL2=1"
set_global_assignment -name VERILOG_MACRO "ENABLE_CMS=1"
set_global_assignment -name VERILOG_MACRO "ENABLE_EMS=1"
set_global_assignment -name VERILOG_MACRO "ENABLE_UMB=1"
# Tandy 1000 sound: an SN76489 at 0C0h..0CFh (set to 0 to omit it from the
# build). Audio only - this fork has no Tandy video or keyboard.
set_global_assignment -name VERILOG_MACRO "ENABLE_TANDY_AUDIO=1"
# MPU-401 / MT32-pi and HPS USB MIDI support (set to 0 to omit it from the build).
set_global_assignment -name VERILOG_MACRO "ENABLE_MIDI=1"
# Sound Blaster Pro at 220h: 8-bit DSP on DMA 1 and selectable IRQ 5/7, the
# CT1345 mixer,
# and FM through the OPL2 this core already has (set to 0 to omit it from the
# build). Exclusive with C/MS at runtime - see xtegactl.sv - because the two
# collide on 226h/227h.
set_global_assignment -name VERILOG_MACRO "ENABLE_SB=1"

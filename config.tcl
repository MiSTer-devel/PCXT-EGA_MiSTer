# PCXT-EGA configuration
set_global_assignment -name VERILOG_MACRO "ENABLE_OPL2=1"
set_global_assignment -name VERILOG_MACRO "ENABLE_CMS=1"
set_global_assignment -name VERILOG_MACRO "ENABLE_EMS=1"
set_global_assignment -name VERILOG_MACRO "ENABLE_UMB=1"
# MPU-401 / MT32-pi and HPS USB MIDI support (set to 0 to omit it from the build).
set_global_assignment -name VERILOG_MACRO "ENABLE_MIDI=1"

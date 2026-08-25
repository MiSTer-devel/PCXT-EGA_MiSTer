//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

`ifndef ENABLE_MIDI
`define ENABLE_MIDI 1
`endif
`ifndef CONF_STR_SYSTEM
`define CONF_STR_SYSTEM (`ENABLE_MIDI ? "PCXT-EGA;UART115200:115200,MIDI;" : "PCXT-EGA;UART115200:115200;")
`endif
`ifndef ENABLE_OPL2
`define ENABLE_OPL2 0
`endif
`ifndef ENABLE_CMS
`define ENABLE_CMS 0
`endif
`ifndef ENABLE_EMS
`define ENABLE_EMS 0
`endif
`ifndef ENABLE_UMB
`define ENABLE_UMB 0
`endif
`ifndef ENABLE_TANDY_AUDIO
`define ENABLE_TANDY_AUDIO 0
`endif

module emu
    (
        //Master input clock
        input         CLK_50M,

        //Async reset from top-level module.
        //Can be used as initial reset.
        input         RESET,

        //Must be passed to hps_io module
        inout  [48:0] HPS_BUS,

        //Base video clock. Usually equals to CLK_SYS.
        output        CLK_VIDEO,

        //Multiple resolutions are supported using different CE_PIXEL rates.
        //Must be based on CLK_VIDEO
        output        CE_PIXEL,

        //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
        //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
        output [12:0] VIDEO_ARX,
        output [12:0] VIDEO_ARY,

        output  [7:0] VGA_R,
        output  [7:0] VGA_G,
        output  [7:0] VGA_B,
        output        VGA_HS,
        output        VGA_VS,
        output        VGA_DE,    // = ~(VBlank | HBlank)
        output        VGA_F1,
        output [1:0]  VGA_SL,
        output        VGA_SCALER, // Force VGA scaler
        output        VGA_DISABLE,

        input  [11:0] HDMI_WIDTH,
        input  [11:0] HDMI_HEIGHT,
        output        HDMI_FREEZE,
        output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

		`ifdef MISTER_FB
        // Use framebuffer in DDRAM (USE_FB=1 in qsf)
        // FB_FORMAT:
        //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
        //    [3]   : 0=16bits 565 1=16bits 1555
        //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
        //
        // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
        output        FB_EN,
        output  [4:0] FB_FORMAT,
        output [11:0] FB_WIDTH,
        output [11:0] FB_HEIGHT,
        output [31:0] FB_BASE,
        output [13:0] FB_STRIDE,
        input         FB_VBL,
        input         FB_LL,
        output        FB_FORCE_BLANK,

		`ifdef MISTER_FB_PALETTE
        // Palette control for 8bit modes.
        // Ignored for other video modes.
        output        FB_PAL_CLK,
        output  [7:0] FB_PAL_ADDR,
        output [23:0] FB_PAL_DOUT,
        input  [23:0] FB_PAL_DIN,
        output        FB_PAL_WR,
		`endif
		`endif

        output        LED_USER,  // 1 - ON, 0 - OFF.

        // b[1]: 0 - LED status is system status OR'd with b[0]
        //       1 - LED status is controled solely by b[0]
        // hint: supply 2'b00 to let the system control the LED.
        output  [1:0] LED_POWER,
        output  [1:0] LED_DISK,

        // I/O board button press simulation (active high)
        // b[1]: user button
        // b[0]: osd button
        output  [1:0] BUTTONS,

        input         CLK_AUDIO, // 24.576 MHz
        output [15:0] AUDIO_L,
        output [15:0] AUDIO_R,
        output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
        output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

        //ADC
        inout   [3:0] ADC_BUS,

        //SD-SPI
        output        SD_SCK,
        output        SD_MOSI,
        input         SD_MISO,
        output        SD_CS,
        input         SD_CD,

        //High latency DDR3 RAM interface
        //Use for non-critical time purposes
        output        DDRAM_CLK,
        input         DDRAM_BUSY,
        output  [7:0] DDRAM_BURSTCNT,
        output [28:0] DDRAM_ADDR,
        input  [63:0] DDRAM_DOUT,
        input         DDRAM_DOUT_READY,
        output        DDRAM_RD,
        output [63:0] DDRAM_DIN,
        output  [7:0] DDRAM_BE,
        output        DDRAM_WE,

        //SDRAM interface with lower latency
        output        SDRAM_CLK,
        output        SDRAM_CKE,
        output [12:0] SDRAM_A,
        output  [1:0] SDRAM_BA,
        inout  [15:0] SDRAM_DQ,
        output        SDRAM_DQML,
        output        SDRAM_DQMH,
        output        SDRAM_nCS,
        output        SDRAM_nCAS,
        output        SDRAM_nRAS,
        output        SDRAM_nWE,

		`ifdef MISTER_DUAL_SDRAM
        //Secondary SDRAM
        //Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
        input         SDRAM2_EN,
        output        SDRAM2_CLK,
        output [12:0] SDRAM2_A,
        output  [1:0] SDRAM2_BA,
        inout  [15:0] SDRAM2_DQ,
        output        SDRAM2_nCS,
        output        SDRAM2_nCAS,
        output        SDRAM2_nRAS,
        output        SDRAM2_nWE,
		`endif

        input         UART_CTS,
        output        UART_RTS,
        input         UART_RXD,
        output        UART_TXD,
        output        UART_DTR,
        input         UART_DSR,

        // Open-drain User port.
        // 0 - D+/RX
        // 1 - D-/TX
        // 2..6 - USR2..USR6
        // Set USER_OUT to 1 to read from USER_IN.
        input   [6:0] USER_IN,
        output  [6:0] USER_OUT,

        input         OSD_STATUS
    );

    ///////// Default values for ports not used in this core /////////

    assign ADC_BUS  = 'Z;
    //assign USER_OUT = '1;
    //assign {UART_RTS, UART_TXD, UART_DTR} = 0;
    assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
    //assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
    assign SDRAM_CLK = clk_chipset;
    assign VGA_SCALER = 0;
    assign VGA_DISABLE = 0;
    assign HDMI_FREEZE = 0;
    assign HDMI_BLACKOUT = 0;
    assign HDMI_BOB_DEINT = 0;

    assign LED_DISK = 0;
    assign LED_POWER = 0;
    assign BUTTONS = 0;

    assign LED_USER = 0;
    //led fdd_led(clk_cpu, |mgmt_req[7:6], LED_USER);


    //////////////////////////////////////////////////////////////////
    // Status Bit Map:
    //              Upper                          Lower
    // 0         1         2         3          4         5         6
    // 01234567890123456789012345678901 23456789012345678901234567890123
    // 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
    // XXXXX XXXXXXXXXXXXXXXXXXXXXXXXXX XXXXXXXX

	`include "build_id.v"

    localparam CONF_STR_ROM = "P1FC0,ROM,PCXT BIOS:;";
    localparam CONF_STR_CMS = (`ENABLE_CMS ? "P2OT,C/MS Audio,Enabled,Disabled;" : "");
    localparam CONF_STR_OPL2 = (`ENABLE_OPL2 ? "P2oAB,OPL2,Adlib 388h,SB FM 388h/228h, Disabled;" : "");
    localparam CONF_STR_EMS = (`ENABLE_EMS ? "P3O5,2MB EMS D000-DFFF,Enabled,Disabled;P3-;" : "");
    localparam CONF_STR_UMB = (`ENABLE_UMB ? "P3OC,UMB C400-CFFF,Enabled,Disabled;P3-;" : "");
    localparam CONF_STR_MIDI = (`ENABLE_MIDI ? "P3O6,USER I/O,MIDI,COM2;P3-;h3P4,MT32-pi;h3P4-;h3P4OD,Use MT32-pi,Yes,No;h3P4-;h3P4o9,MT32-pi Mode,MT-32,General MIDI;h3P4O34,MT32-pi ROM,MT-32 v1,MT-32 v2,CM-32L,Reserved;h3P4oSU,MT32-pi SoundFont,#0,#1,#2,#3,#4,#5,#6,#7;h3P4-;h3P4r8,Reset Hanging Notes;h3P4-;" : "");

    // Menumask bits 4 and 5 mark a missing PCXT or EGA BIOS.  The machine is
    // held in reset until both are present, so say so at the top of the menu
    // rather than leaving the user to guess why nothing boots.
    localparam CONF_STR_HALT = {
		"h4-,HALTED: no PCXT BIOS selected;",
		"h5-,HALTED: no EGA BIOS selected;"
	};

    // Read back by the framework through info_req/info and drawn as an OSD
    // notice.  The box is 32 columns wide; commas separate the two messages,
    // so neither may contain one.
    localparam CONF_STR_INFO = {
		"I,",
		"No PCXT BIOS selected\n",
		"Machine halted\n",
		"OSD: System & BIOS,",
		"No EGA BIOS selected\n",
		"Machine halted\n",
		"OSD: System & BIOS,",
		"That setting is applied\n",
		"when the machine resets;"
	};

    localparam CONF_STR = {
		`CONF_STR_SYSTEM,
		CONF_STR_HALT,
		"S0,IMGIMAVFD,Floppy A:;",
		"S1,IMGIMAVFD,Floppy B:;",
		"OJK,Write Protect,None,A:,B:,A: & B:;",
		"-;",
		"S2,VHD,IDE 0-0;",
		"S3,VHD,IDE 0-1;",
		"OLM,2nd SD card,Disable,IDE 0-0,IDE 0-1;",
		"-;",
		"OHI,CPU Speed,4.77MHz,7.16MHz,9.54MHz,Max;",
		"-;",
		"P1,System & BIOS;",
		"P1-;",
		"P1O7,Boot Splash Screen,Yes,No;",
		"P1oV,CPU Type,8088,8086;",
		"P1oL,Fake 286 FLAGS,Off,On;",
		"P1-;",
		CONF_STR_ROM,
		"P1FC2,ROM,EC00 BIOS:;",
		"P1FC3,ROM,EGA BIOS:;",
		"P1-;",
		"P1OUV,BIOS Writable,None,EC00,Main,All;",
		"P1-;",	
		"P2,Audio & Video;",
		"P2-;",
		CONF_STR_CMS,
		CONF_STR_OPL2,
		"P2o01,Speaker Volume,1,2,3,4;",
		"P2o45,Audio Boost,No,2x,4x;",
		"P2o67,Stereo Mix,none,25%,50%,100%;",
		"P2-;",
		"P2oEH,CRT H offset,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15;",
		"P2oIK,CRT V offset,0,1,2,3,4,5,6,7;",        
		"P2oMO,VSync Width,Auto,1,2,3,4,5,6,7;",
		"P2oPR,HSync Width,Auto,1,2,3,4,5,6,7;",
        "P2-;",
		"P2O12,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
		"P2O89,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
		"P2OEG,Display,Full Color,Green,Amber,B&W,Red,Blue,Fuchsia,Purple;",
		"P2OAB,VGA 13h+,Off,Native,60Hz;",
		"P2o23,350-line CRT,Native,480i 15 kHz,240p 15 kHz;",
		"P2-;",
		"P3,Hardware;",
		"P3-;",
		"P3oCD,Monitor,5154/ECD,5153/CGA,5151/MDA;",
		"P3-;",
		CONF_STR_EMS,
		CONF_STR_UMB,
		"P3ONO,Joystick 1, Analog, Digital, Disabled;",
		"P3OPQ,Joystick 2, Analog, Digital, Disabled;",
		"P3OR,Sync Joy to CPU Speed,No,Yes;",
		"P3OS,Swap Joysticks,No,Yes;",
		"P3-;",
		CONF_STR_MIDI,
		"-;",
		"R0,Reset & apply settings;",
		"J,Fire 1,Fire 2;",
		CONF_STR_INFO,
		"V,v",`BUILD_DATE
	};

    wire forced_scandoubler;
    wire vga_mode13_active_video;
    wire vga_mode13_pixel_toggle;
    wire ega_dot_toggle;
    wire ega_dot_clock_sel;
    wire ega_scandouble_active;
    wire ega_vmode_toggle;
    wire        ega_mode350;
    wire [11:0] ega_active_dots;
    wire [9:0]  ega_active_lines;
    wire [1:0] buttons;
    wire [63:0] status;
    // Native restores the original 31.4 kHz / 70 Hz Mode 13h raster. 60Hz is
    // the CRT-TV-compatible 15.7 kHz timing previously exposed as "On".
    wire [1:0] vga_mode13_profile_osd = status[11:10];
    wire       vga_mode13_osd = |vga_mode13_profile_osd;
    wire       vga_mode13_native_osd = (vga_mode13_profile_osd == 2'b01);
    // Status bit 63 is the pending CPU selection. The value presented to the
    // BIU is latched only during reset; changing the menu alone cannot change
    // queue depth or bus width while an instruction is in flight.
    wire        cpu_type_8086_osd = status[63];
    // Status bit 53 makes PUSHF report zero in reserved FLAGS bits 12:15,
    // matching a real-mode 80286 for legacy CPU probes.  Unlike the CPU type
    // this is applied live: it only gates a mux on the PUSHF operand path, so
    // the worst a mid-run change can do is decide the PUSHF of that instant.
    wire        fake_286_flags_osd = status[53];
    wire        is8086_applied;
    // Status bits 45:44 are the pending physical-monitor switch selection.
    // ega_monitor_profile_applied is only updated while the machine is held
    // in reset, just as a real EGA card samples its switches during POST.
    wire  [1:0] ega_monitor_profile_osd = status[45:44];
    wire  [1:0] ega_monitor_profile_applied;
    // XTEGACTL. The register file is decoded down in the chipset; what the
    // fields mean is resolved here, where the menu status lives. Every field
    // reads zero as "leave it to the OSD", so with nothing written the machine
    // behaves exactly as the menu says.
    wire [7:0]  xtegactl_cpu, xtegactl_exp, xtegactl_vid, xtegactl_inp, xtegactl_midi, xtegactl_exp2;
    wire [1:0]  eff_speed;
    wire        eff_fake286;
    wire [1:0]  eff_opl2;
    wire        eff_cms, eff_ems, eff_umb, eff_vga13;
    wire        eff_joy1_digital, eff_joy1_disable;
    wire        eff_joy2_digital, eff_joy2_disable;
    wire        eff_joy_sync, eff_joy_swap, eff_mt32_gm, eff_tandy;

    xtegactl_resolve xtegactl_apply (
        .reg_cpu          (xtegactl_cpu),
        .reg_exp          (xtegactl_exp),
        .reg_vid          (xtegactl_vid),
        .reg_inp          (xtegactl_inp),
        .reg_midi         (xtegactl_midi),
        .reg_exp2         (xtegactl_exp2),
        .osd_speed        (status[18:17]),
        .osd_fake286      (fake_286_flags_osd),
        .osd_opl2         (status[43:42]),
        .osd_cms          (~status[29]),
        .osd_ems          (~status[5]),
        .osd_umb          (~status[12]),
        .osd_vga13        (vga_mode13_osd),
        .osd_joy1_digital (status[23]),
        .osd_joy1_disable (status[24]),
        .osd_joy2_digital (status[25]),
        .osd_joy2_disable (status[26]),
        .osd_joy_sync     (status[27]),
        .osd_joy_swap     (status[28]),
        .osd_mt32_gm      (status[41]),
        .build_tandy      (`ENABLE_TANDY_AUDIO ? 1'b1 : 1'b0),
        .eff_speed        (eff_speed),
        .eff_fake286      (eff_fake286),
        .eff_opl2         (eff_opl2),
        .eff_cms          (eff_cms),
        .eff_ems          (eff_ems),
        .eff_umb          (eff_umb),
        .eff_vga13        (eff_vga13),
        .eff_joy1_digital (eff_joy1_digital),
        .eff_joy1_disable (eff_joy1_disable),
        .eff_joy2_digital (eff_joy2_digital),
        .eff_joy2_disable (eff_joy2_disable),
        .eff_joy_sync     (eff_joy_sync),
        .eff_joy_swap     (eff_joy_swap),
        .eff_mt32_gm      (eff_mt32_gm),
        .eff_tandy        (eff_tandy)
    );

    wire [7:0]  uart_mode;

    //Keyboard Ps2
    wire        ps2_kbd_clk_out;
    wire        ps2_kbd_data_out;
    wire        ps2_kbd_clk_in;
    wire        ps2_kbd_data_in;
    // Decoded key stream, used only to catch F12 while the machine is in reset.
    wire [10:0] ps2_key;

    //Mouse PS2
    wire        ps2_mouse_clk_out;
    wire        ps2_mouse_data_out;
    wire        ps2_mouse_clk_in;
    wire        ps2_mouse_data_in;

    wire        ioctl_download;
    wire  [7:0] ioctl_index;
    wire        ioctl_wr;
    wire [24:0] ioctl_addr;
    wire [15:0] ioctl_data;
    reg         ioctl_wait;

    wire [21:0] gamma_bus;

    wire [13:0] joy0, joy1;
    wire [15:0] joya0, joya1;
    // Bit order set by tandy_pcjr_joy: P1 type, P1 disable, P2 type, P2
    // disable, turbo sync.
    wire [4:0]  joy_opts = {eff_joy_sync, eff_joy2_disable, eff_joy2_digital,
                            eff_joy1_disable, eff_joy1_digital};

    wire [1:0] scale = status[2:1];
    wire [2:0] screen_mode = status[16:14];
    wire [1:0] ar = status[9:8];
    wire [2:0] vsync_width_osd = status[56:54];  // 0=Auto (use register), 1-7=override
    wire [2:0] hsync_width_osd = status[59:57];  // 0=Auto, 1-7=fixed width (Nx16 pixel clocks)

    reg [1:0]   scale_video_ff;
    reg [2:0]   screen_mode_video_ff;
    wire        video_scandoubler_en = (scale_video_ff > 0) || forced_scandoubler;
    // bits 2:0 have no h0/h1/h2 entries in CONF_STR; bit3 exposes MT32-pi;
    // bits 5:4 reveal the two "halted, no BIOS" lines at the top of the menu.
    wire [15:0] status_menumask = {10'd0, bios_missing_ega, bios_missing_pcxt,
                                   (`ENABLE_MIDI & mt32_available), 3'b111};

    wire VGA_VBlank_border;
    wire std_hsyncwidth;
    wire pause_core;

    always @(posedge clk_57_272)
    begin
        scale_video_ff          <= scale;
        screen_mode_video_ff    <= screen_mode;
        VIDEO_ARX               <= (!ar) ? 12'd4 : (ar - 1'd1);
        VIDEO_ARY               <= (!ar) ? 12'd3 : 12'd0;
    end

    // F12KEYMOD hands F12 to the machine and reserves Win+F12 for the menu,
    // which is what the splash has always told people to expect.  MiSTer only
    // assumes that for cores literally named PCXT, Tandy1000 or PCjr, so
    // without it plain F12 opened the OSD here and pause/credits was
    // unreachable.
    hps_io #(.CONF_STR(CONF_STR), .PS2DIV(2000), .PS2WE(1), .WIDE(1), .F12KEYMOD(1)) hps_io 
	(
		.clk_sys(clk_chipset),
		.HPS_BUS(HPS_BUS),
		.EXT_BUS(EXT_BUS),
		.gamma_bus(gamma_bus),

		.forced_scandoubler(forced_scandoubler),

		.buttons(buttons),
		.status(status),
		.status_menumask(status_menumask),
		.info_req(info_req),
		.info(info),
		.new_vmode(ega_vmode_toggle),

		.uart_mode(uart_mode),

		.ps2_key(ps2_key),
		.ps2_kbd_clk_in		(ps2_kbd_clk_out),
		.ps2_kbd_data_in	(ps2_kbd_data_out),
		.ps2_kbd_clk_out	(ps2_kbd_clk_in),
		.ps2_kbd_data_out	(ps2_kbd_data_in),

		.ps2_mouse_clk_out    (ps2_mouse_clk_out),
		.ps2_mouse_data_out   (ps2_mouse_data_out),
		.ps2_mouse_clk_in     (ps2_mouse_clk_in),
		.ps2_mouse_data_in    (ps2_mouse_data_in),

		.joystick_0(joy0),
		.joystick_1(joy1),
		.joystick_l_analog_0(joya0),
		.joystick_l_analog_1(joya1),

		//ioctl
		.ioctl_download(ioctl_download),
		.ioctl_index(ioctl_index),
		.ioctl_wr(ioctl_wr),
		.ioctl_addr(ioctl_addr),
		.ioctl_dout(ioctl_data),
		.ioctl_wait(ioctl_wait)
	);


    wire [15:0] mgmt_din;
    wire [15:0] mgmt_dout;
    wire [15:0] mgmt_addr;
    wire        mgmt_rd;
    wire        mgmt_wr;
    wire  [7:0] mgmt_req;
    assign mgmt_req[5:3] = 3'b000;

    wire [35:0] EXT_BUS;
    hps_ext hps_ext  
	(
		.clk_sys(clk_chipset),
		.EXT_BUS(EXT_BUS),

		.ext_din(mgmt_din),
		.ext_dout(mgmt_dout),
		.ext_addr(mgmt_addr),
		.ext_rd(mgmt_rd),
		.ext_wr(mgmt_wr),

		.ext_req(mgmt_req),
		.ext_hotswap(2'b00)
	);

    //
    ///////////////////////   CLOCKS   /////////////////////////////
    //

    wire clk_sys;
    wire pll_locked;

    wire clk_100;
    wire clk_28_636;
    wire clk_57_272;
    wire clk_video_out_ps;
    reg clk_14_318 = 1'b0;
    wire clk_cpu;
    logic cpu_ce_posedge;
    logic cpu_ce_negedge;
    logic peripheral_ce;
    wire clk_chipset;

    localparam [27:0] cur_rate = 28'd50000000;

    pll pll 
	(
		.refclk(CLK_50M),
		.rst(0),
		.outclk_0(clk_100),
        .outclk_1(clk_chipset),
		.locked(pll_locked)
	);

    wire pll_system_locked;

    pll_system pll_system_inst (
        .refclk(CLK_50M),
        .rst(0),
        .outclk_0(clk_28_636),
        .outclk_1(clk_57_272),
        .outclk_2(clk_video_out_ps),
        .locked(pll_system_locked)
    );

    wire reset_wire = RESET | status[0] | buttons[1] | !pll_locked | !pll_system_locked  | splashscreen | splash_pending;
    wire video_retime_reset = RESET | status[0] | buttons[1] | !pll_locked | !pll_system_locked | splash_pending;
    (* ASYNC_REG = "TRUE" *) logic [1:0] video_retime_reset_sync = 2'b11;
    wire video_retime_reset_local = video_retime_reset_sync[1];

    // The output retime registers run on the phase-shifted video clock.
    // Reset asserts asynchronously but is released only on that clock.
    always_ff @(posedge clk_video_out_ps or posedge video_retime_reset) begin
        if (video_retime_reset)
            video_retime_reset_sync <= 2'b11;
        else
            video_retime_reset_sync <= {video_retime_reset_sync[0], 1'b0};
    end
    wire reset_sdram_wire = RESET | !pll_locked;

    //////////////////////////////////////////////////////////////////

    // TODO: messy, use a single clock domain at least
    always @(posedge clk_28_636)
    begin
        clk_14_318 <= ~clk_14_318;  // 14.318Mhz, UART reference and splash timebase
    end

    //////////////////////////////////////////////////////////////////

    logic  biu_done;
    logic  [7:0] clock_cycle_counter_division_ratio;
    logic  [7:0] clock_cycle_counter_decrement_value;
    logic        shift_read_timing;
    logic  [1:0] ram_read_wait_cycle;
    logic  [1:0] ram_write_wait_cycle;
    logic        cycle_accrate;
    logic  [1:0] clk_select;
    wire   [1:0] clk_select_next = eff_speed;

    always @(posedge clk_chipset, posedge reset)
    begin
        if (reset)
            clk_select <= 2'b00;
        else if (biu_done)
            clk_select <= clk_select_next;
    end

    XT_CE_Generator u_XT_CE_Generator
    (
        .clock                              (clk_chipset),
        .reset                              (reset),
        .clk_select_load                    (biu_done),
        .clk_select                         (clk_select_next),
        .cpu_clk_pin                        (clk_cpu),
        .cpu_ce_posedge                     (cpu_ce_posedge),
        .cpu_ce_negedge                     (cpu_ce_negedge),
        .peripheral_ce                      (peripheral_ce),
        .cycle_accrate                      (cycle_accrate),
        .clock_cycle_counter_division_ratio (clock_cycle_counter_division_ratio),
        .clock_cycle_counter_decrement_value(clock_cycle_counter_decrement_value),
        .shift_read_timing                  (shift_read_timing),
        .ram_read_wait_cycle                (ram_read_wait_cycle),
        .ram_write_wait_cycle               (ram_write_wait_cycle)
    );
    //////////////////////////////////////////////////////////////////

    logic reset = 1'b1;
    logic [15:0] reset_count = 16'h0000;
    logic reset_sdram = 1'b1;
    logic [15:0] reset_sdram_count = 16'h0000;

    always @(posedge clk_chipset, posedge reset_wire)
    begin
        if (reset_wire)
        begin
            reset <= 1'b1;
            reset_count <= 16'h0000;
        end
        else if (reset)
        begin
            if (reset_count != 16'hffff)
            begin
                reset <= 1'b1;
                reset_count <= reset_count + 16'h0001;
            end
            else
            begin
                reset <= 1'b0;
                reset_count <= reset_count;
            end
        end
        else
        begin
            reset <= 1'b0;
            reset_count <= reset_count;
        end
    end

    // Track the OSD selection throughout the stretched reset interval so the
    // final stable value is ready before the CPU starts executing the BIOS.
    // Changes made while the machine is running remain pending until reset.
    ega_monitor_profile_latch monitor_profile_latch (
        .clock        (clk_chipset),
        .reset_active (reset),
        .selected     (ega_monitor_profile_osd),
        .applied      (ega_monitor_profile_applied)
    );

    cpu_type_latch cpu_type_apply_latch (
        .clock                 (clk_chipset),
        .reset_active          (reset),
        .selected_8086         (cpu_type_8086_osd),
        .is8086                (is8086_applied)
    );

    // Fake 286 FLAGS is live, so it now crosses from the chipset domain that
    // hps_io drives into the core clock the EU mux is evaluated on. While it
    // was reset-latched the value only ever moved with the CPU held in reset
    // and no synchronizer was needed; a running change needs one.
    (* ASYNC_REG = "TRUE" *) logic [1:0] fake_286_flags_meta = 2'b00;
    wire fake_286_flags_applied = fake_286_flags_meta[1];

    always_ff @(posedge clk_100)
        fake_286_flags_meta <= {fake_286_flags_meta[0], eff_fake286};

    logic reset_cpu_ff = 1'b1;
    logic reset_cpu = 1'b1;
    logic [15:0] reset_cpu_count = 16'h0000;

    always @(negedge clk_chipset, posedge reset)
    begin
        if (reset)
            reset_cpu_ff <= 1'b1;
        else
            reset_cpu_ff <= reset;
    end

    always @(negedge clk_chipset, posedge reset)
    begin
        if (reset)
        begin
            reset_cpu <= 1'b1;
            reset_cpu_count <= 16'h0000;
        end
        else if (reset_cpu)
        begin
            reset_cpu <= reset_cpu_ff;
            reset_cpu_count <= 16'h0000;
        end
        else
        begin
            if (reset_cpu_count != 16'h002A)
            begin
                reset_cpu <= reset_cpu_ff;
                reset_cpu_count <= reset_cpu_count + 16'h0001;
            end
            else
            begin
                reset_cpu <= 1'b0;
                reset_cpu_count <= reset_cpu_count;
            end
        end
    end

    always @(posedge clk_chipset, posedge reset_sdram_wire)
    begin
        if (reset_sdram_wire)
        begin
            reset_sdram <= 1'b1;
            reset_sdram_count <= 16'h0000;
        end
        else if (reset_sdram)
        begin
            if (reset_sdram_count != 16'hffff)
            begin
                reset_sdram <= 1'b1;
                reset_sdram_count <= reset_sdram_count + 16'h0001;
            end
            else
            begin
                reset_sdram <= 1'b0;
                reset_sdram_count <= reset_sdram_count;
            end
        end
        else
        begin
            reset_sdram <= 1'b0;
            reset_sdram_count <= reset_sdram_count;
        end
    end

    //
    ///////////////////////   BIOS LOADER   ////////////////////////////
    //

    reg [4:0]  bios_load_state = 4'h0;
    reg [2:0]  bios_protect_flag;
    reg        bios_access_request;
    reg [19:0] bios_access_address;
    reg [15:0] bios_write_data;
    reg        bios_write_n;
    reg [7:0]  bios_write_wait_cnt;
    reg        bios_write_byte_cnt;
    wire       ega_bios_loaded;
    wire       ega_bios_write_protect;
    wire [1:0] ega_video_switches;
    wire select_pcxt  = (ioctl_index[5:0] == 0) && (ioctl_addr[24:16] == 9'b000000000);
    wire select_xtide = ioctl_index == 2;
    wire select_ega_bios = (ioctl_index[5:0] == 3) && (ioctl_addr[24:16] == 9'b000000000);

    // File identity, rather than the current address, defines the lifetime of
    // an upload.  ioctl_addr is not guaranteed to have the new file's first
    // address until its first data beat arrives.
    wire ega_bios_download_active = ioctl_download && (ioctl_index[5:0] == 6'd3);
    wire ega_bios_write_complete = (bios_load_state == 4'h04) &&
                                   bios_write_byte_cnt && select_ega_bios;

    // The loader returns to state 01 between every 16-bit word.  Treating that
    // state as the start of a new EGA download cleared the presence flag again
    // after every word (and once more at end-of-file), so the XT motherboard
    // switches continued to advertise CGA even though an EGA ROM was present.
    ega_bios_loaded_latch ega_bios_presence (
        .clock              (clk_chipset),
        .reset              (reset_sdram),
        .sdram_initialized  (initilized_sdram),
        .download_active    (ega_bios_download_active),
        .write_complete     (ega_bios_write_complete),
        .loaded             (ega_bios_loaded),
        .write_protect      (ega_bios_write_protect),
        .video_switches     (ega_video_switches)
    );

    // Same rule for the main BIOS.  Without it the 8088 is released into an
    // erased F000 segment, runs off into whatever the SDRAM happens to hold and
    // reprograms the CRTC to a raster nothing can display - which is what the
    // "splash, then black screen" reports on 15 kHz sets turned out to be.
    wire pcxt_bios_loaded;
    wire pcxt_bios_download_active = ioctl_download && (ioctl_index[5:0] == 6'd0);
    wire pcxt_bios_write_complete = (bios_load_state == 4'h04) &&
                                    bios_write_byte_cnt && select_pcxt;

    rom_presence_latch pcxt_bios_presence (
        .clock              (clk_chipset),
        .reset              (reset_sdram),
        .sdram_initialized  (initilized_sdram),
        .download_active    (pcxt_bios_download_active),
        .write_complete     (pcxt_bios_write_complete),
        .loaded             (pcxt_bios_loaded)
    );

    // Reported one at a time, main BIOS first: an EGA ROM is no use without a
    // machine to run it on, so naming both at once would only be noise.
    wire bios_missing_pcxt = ~pcxt_bios_loaded;
    wire bios_missing_ega  = pcxt_bios_loaded & ~ega_bios_loaded;

    wire [19:0] bios_access_address_wire = select_pcxt  ? { 4'b1111, ioctl_addr[15:0]} :
         select_xtide ? { 6'b111011, ioctl_addr[13:0]} :
         select_ega_bios ? { 4'b1100, ioctl_addr[15:0]} :
         20'hFFFFF;

    wire bios_load_n = ~(ioctl_download & (select_pcxt | select_xtide | select_ega_bios));

    always @(posedge clk_chipset, posedge reset_sdram)
    begin
        if (reset_sdram)
        begin
            bios_protect_flag   <= 3'b011;
            bios_access_request <= 1'b0;
            bios_access_address <= 20'hFFFFF;
            bios_write_data     <= 16'hFFFF;
            bios_write_n        <= 1'b1;
            bios_write_wait_cnt <= 'h0;
            bios_write_byte_cnt <= 1'h0;
            ioctl_wait          <= 1'b1;
            bios_load_state     <= 4'h00;
        end
        else if (~initilized_sdram)
        begin
            bios_protect_flag   <= 3'b011;
            bios_access_request <= 1'b0;
            bios_access_address <= 20'hFFFFF;
            bios_write_data     <= 16'hFFFF;
            bios_write_n        <= 1'b1;
            bios_write_wait_cnt <= 'h0;
            bios_write_byte_cnt <= 1'h0;
            ioctl_wait          <= 1'b1;
            bios_load_state     <= 4'h00;
        end
        else
        begin
            casez (bios_load_state)
                4'h00:
                begin
                    bios_protect_flag   <= {ega_bios_write_protect, ~status[31:30]};  // ega/f000/ec00 protection
                    bios_access_address <= 20'hFFFFF;
                    bios_write_data     <= 16'hFFFF;
                    bios_write_n        <= 1'b1;
                    bios_write_wait_cnt <= 'h0;
                    bios_write_byte_cnt <= 1'h0;
                    if (~ioctl_download)
                    begin
                        bios_access_request <= 1'b0;
                        ioctl_wait          <= 1'b0;
                    end
                    else
                    begin
                        bios_access_request <= 1'b1;
                        ioctl_wait          <= 1'b1;
                    end

                    if ((ioctl_download) && (~processor_ready) && (address_direction))
                        bios_load_state <= 4'h01;
                    else
                        bios_load_state <= 4'h00;
                end
                4'h01:
                begin
                    bios_protect_flag   <= 3'b000;
                    bios_access_request <= 1'b1;
                    bios_write_byte_cnt <= 1'h0;
                    if (~ioctl_download)
                    begin
                        bios_access_address <= 20'hFFFFF;
                        bios_write_data     <= 16'hFFFF;
                        bios_write_n        <= 1'b1;
                        bios_write_wait_cnt <= 'h0;
                        ioctl_wait          <= 1'b0;
                        bios_load_state     <= 4'h00;
                    end
                    else if ((~ioctl_wr) || (bios_load_n))
                    begin
                        bios_access_address <= 20'hFFFFF;
                        bios_write_data     <= 16'hFFFF;
                        bios_write_n        <= 1'b1;
                        bios_write_wait_cnt <= 'h0;
                        ioctl_wait          <= 1'b0;
                        bios_load_state     <= 4'h01;
                    end
                    else
                    begin
                        bios_access_address <= bios_access_address_wire;
                        bios_write_data     <= ioctl_data;
                        bios_write_n        <= 1'b1;
                        bios_write_wait_cnt <= 'h0;
                        ioctl_wait          <= 1'b1;
                        bios_load_state     <= 4'h02;
                    end
                end
                4'h02:
                begin
                    bios_protect_flag   <= 3'b000;
                    bios_access_request <= 1'b1;
                    bios_access_address <= bios_access_address;
                    bios_write_data     <= bios_write_data;
                    bios_write_byte_cnt <= bios_write_byte_cnt;
                    ioctl_wait          <= 1'b1;
                    bios_write_wait_cnt <= bios_write_wait_cnt + 'h1;

                    if (bios_write_wait_cnt != 'd20)
                    begin
                        bios_write_n        <= 1'b0;
                        bios_load_state     <= 4'h02;
                    end
                    else
                    begin
                        bios_write_n        <= 1'b1;
                        bios_load_state     <= 4'h03;
                    end
                end
                4'h03:
                begin
                    bios_protect_flag   <= 3'b000;
                    bios_access_request <= 1'b1;
                    bios_access_address <= bios_access_address;
                    bios_write_data     <= bios_write_data;
                    bios_write_n        <= 1'b1;
                    bios_write_byte_cnt <= bios_write_byte_cnt;
                    ioctl_wait          <= 1'b1;
                    bios_write_wait_cnt <= bios_write_wait_cnt + 'h1;

                    if (bios_write_wait_cnt != 'h40)
                        bios_load_state     <= 4'h03;
                    else
                        bios_load_state     <= 4'h04;
                end
                4'h04:
                begin
                    bios_protect_flag   <= 3'b000;
                    bios_access_request <= 1'b1;
                    bios_access_address <= bios_access_address + 'h1;
                    bios_write_data     <= {8'hFF, bios_write_data[15:8]};
                    bios_write_n        <= 1'b1;
                    bios_write_wait_cnt <= 'h0;
                    bios_write_byte_cnt <= ~bios_write_byte_cnt;
                    ioctl_wait          <= 1'b1;
                    if (bios_write_byte_cnt == 1'b0)
                        bios_load_state     <= 4'h02;
                    else
                        bios_load_state     <= 4'h01;
                end
                default:
                begin
                    bios_protect_flag   <= {ega_bios_write_protect, 2'b11};
                    bios_access_request <= 1'b0;
                    bios_access_address <= 20'hFFFFF;
                    bios_write_data     <= 16'hFFFF;
                    bios_write_n        <= 1'b1;
                    bios_write_wait_cnt <= 'h0;
                    bios_write_byte_cnt <= 1'h0;
                    ioctl_wait          <= 1'b0;
                    bios_load_state     <= 4'h00;
                end
            endcase
        end
    end


    //////////////////////////////////////////////////////////////////

    //
    // Splash screen
    //
    reg splash_off = 1'b1;
    reg [24:0] splash_cnt = 0;
    reg [3:0] splash_cnt2 = 0;
    reg splash_timed = 1'b0;
    reg splash_pending = 1'b1;
    reg [23:0] splash_boot_cnt = 24'd0;
    reg phys_reset_hold = 0;
    reg [23:0] phys_reset_cnt = 24'd0;
    localparam [23:0] PHYS_RESET_HOLD = 24'd2863600;
    localparam [23:0] SPLASH_BOOT_WAIT = 24'd14318000;

    always @ (posedge clk_14_318)
    begin
        splash_off <= status[7];
        if (RESET || buttons[1])
        begin
            phys_reset_hold <= 1'b1;
            phys_reset_cnt <= 24'd0;
        end
        else if (phys_reset_hold)
        begin
            if (phys_reset_cnt == PHYS_RESET_HOLD)
                phys_reset_hold <= 1'b0;
            else
                phys_reset_cnt <= phys_reset_cnt + 24'd1;
        end

        if (splash_pending)
        begin
            if (~splash_off)
            begin
                splash_timed <= 1'b1;
                splash_cnt <= 0;
                splash_cnt2 <= 0;
                splash_pending <= 1'b0;
                splash_boot_cnt <= 24'd0;
            end
            else if (splash_boot_cnt == SPLASH_BOOT_WAIT)
            begin
                splash_pending <= 1'b0;
            end
            else
            begin
                splash_boot_cnt <= splash_boot_cnt + 24'd1;
            end
        end
        else if (splash_timed)
        begin
            if (splash_off)
            begin
                splash_timed <= 0;
            end
            else if (splash_paused)
            begin
                // F12: hold the picture, and with it the machine, until asked
                // again.  Turning the splash off in the OSD still dismisses it,
                // so this cannot be a way to get stuck.
                splash_cnt <= splash_cnt;
            end
            else if(splash_cnt2 == 5) // 5 seconds delay
            begin
                splash_timed <= 0;
            end
            else if (splash_cnt == 14318000)
            begin // 1 second at 14.318Mhz
                splash_cnt2 <= splash_cnt2 + 1;
                splash_cnt <= 0;
            end
            else
                splash_cnt <= splash_cnt + 1;
        end

    end

    //
    // Splash pause
    //
    // The legend the splash draws is only true if F12 reaches something while
    // the splash is up.  The keyboard controller that decodes it is inside the
    // machine, and the machine is in reset for as long as the splash is on
    // screen, so it has to be caught out here instead.
    wire splash_paused;

    splash_f12_pause splash_pause (
        .clock         (clk_14_318),
        .splash_active (splash_timed),
        .ps2_key       (ps2_key),
        .paused        (splash_paused)
    );

    //
    // Missing BIOS hold
    //
    // Both ROMs arrive over ioctl while the machine is already held in reset
    // for the splash, so the check costs nothing extra: at the moment that hold
    // would be released, either they are there or they are not.
    //
    // If one is missing the hold simply never ends.  The 8088 therefore never
    // executes, never touches the CRTC, and the raster stays on the power-on
    // 640x200 that the splash is authored for - which is the whole point, since
    // that is the one mode every 15 kHz television can lock to.  A set that
    // could show the splash can show this.
    //
    // The splash is put back up for it even when the OSD has it switched off.
    // A held black frame is indistinguishable from the failure it is meant to
    // explain, and the picture is what draws the eye to the notice.
    //
    // splash_pending is only ever cleared and splash_timed is only ever set
    // from it, so the boot phase falls exactly once and the hold takes over on
    // that same edge, with no clock in which the CPU could start.
    wire bios_hold;
    wire [7:0] info;
    wire info_req;
    wire [7:0] bios_info;
    wire       bios_info_req;
    // Driven by reset_pending_notice, instantiated with the MMC block below
    // because the 2nd SD card mapping it watches is declared there.
    wire [7:0] pending_info;
    wire       pending_info_req;

    bios_hold_notice bios_notice (
        .clock             (clk_14_318),
        .splash_boot_phase (splash_pending | splash_timed),
        .bios_missing_pcxt (bios_missing_pcxt),
        .bios_missing_ega  (bios_missing_ega),
        .hold              (bios_hold),
        .info              (bios_info),
        .info_req          (bios_info_req)
    );

    // The halt notice wins the info box: its machine is stopped, and the
    // reset-pending one is only worth reading on a machine that is running.
    // reset_pending_notice is held off by the same signal, so in practice the
    // two never ask at once.
    assign info     = bios_info_req ? bios_info : pending_info;
    assign info_req = bios_info_req | pending_info_req;

    wire splashscreen = splash_timed | bios_hold;

    //
    // Input F/F PS2_CLK
    //
    logic   device_clock_ff;
    logic   device_clock;

    always_ff @(negedge clk_chipset, posedge reset)
    begin
        if (reset)
        begin
            device_clock_ff <= 1'b0;
            device_clock    <= 1'b0;
        end
        else
        begin
            device_clock_ff <= ps2_kbd_clk_in;
            device_clock    <= device_clock_ff ;
        end
    end


    //
    // Input F/F PS2_DAT
    //
    logic   device_data_ff;
    logic   device_data;

    always_ff @(negedge clk_chipset, posedge reset)
    begin
        if (reset)
        begin
            device_data_ff <= 1'b0;
            device_data    <= 1'b0;
        end
        else
        begin
            device_data_ff <= ps2_kbd_data_in;
            device_data    <= device_data_ff;
        end
    end


    wire [7:0] data_bus;
    wire INTA_n;
    wire [19:0] cpu_ad_out;
    reg  [19:0] cpu_address;
    wire [7:0] cpu_data_bus;
    wire [15:0] data_bus_word;          // 8086 wide read
    wire [15:0] cpu_data_bus_word;       // 8086 wide write
    wire        word_read_possible;      // SDRAM can serve the latched address wide
    wire        word_read_request;
    wire        word_write_request;
    wire processor_ready;
    wire interrupt_to_cpu;
    wire address_latch_enable;
    wire address_direction;

    wire lock_n;
    wire [2:0]processor_status;

    wire [3:0]   dma_acknowledge_n;

    logic   [7:0]   port_b_out;
    logic   [7:0]   port_c_in;
    wire    [1:0]   fdd_present;
    reg     [7:0]   sw;

    wire    [5:0]   sw_base;
    wire    [1:0]   sw_floppy;

    // sw_base[5:4] is the motherboard video switch pair the BIOS copies into bits
    // 5:4 of the equipment word at 40:10. 2'b00 means "adapter with its own option
    // ROM" (EGA), 2'b10 means CGA 80x25. Loading the EGA BIOS is what installs the
    // card, so track it: otherwise the equipment word claims CGA and software that
    // trusts it, such as Titus The Fox, picks the CGA path and renders nothing.
    assign  sw_base = {ega_video_switches, 4'b1101};
    assign  sw_floppy = fdd_present[1] ? 2'b01 : 2'b00;
    assign  sw = {sw_floppy, sw_base}; // DIP switches (video adapter and floppy count)
    assign  port_c_in[3:0] = port_b_out[3] ? sw[7:4] : sw[3:0];


    wire ems_enabled_sel = `ENABLE_EMS ? eff_ems : 1'b0;
    wire [1:0] ems_address_sel = 2'b01; // Fixed D000 page frame avoids EGA and XT-IDE ROM conflicts.
    wire umb_enabled_sel = `ENABLE_UMB ? eff_umb : 1'b0;

    always @(posedge clk_chipset)
    begin
        if (address_latch_enable)
            cpu_address <= cpu_ad_out;
        else
            cpu_address <= cpu_address;
    end

    CHIPSET #(.clk_rate(cur_rate)) u_CHIPSET
	(
		.clock                              (clk_chipset),
		.cpu_ce_posedge                     (cpu_ce_posedge),
		.cpu_ce_negedge                     (cpu_ce_negedge),
		.clk_sys                            (clk_chipset),
		.peripheral_ce                      (peripheral_ce),
		.clk_select                         (clk_select),
		.reset                              (reset_cpu),
		.video_reset                        (video_retime_reset),
		.sdram_reset                        (reset_sdram),
		.cpu_address                        (cpu_address),
		.cpu_data_bus                       (cpu_data_bus),
		.processor_status                   (processor_status),
		.processor_lock_n                   (lock_n),
	//	.processor_transmit_or_receive_n    (processor_transmit_or_receive_n),
		.processor_ready                    (processor_ready),
		.interrupt_to_cpu                   (interrupt_to_cpu),
		.splashscreen                       (splashscreen),
		.std_hsyncwidth                     (std_hsyncwidth),
		.clk_video                        (clk_28_636),
		.de_o                               (de_o),
		.VGA_R                              (r),
		.VGA_G                              (g),
		.VGA_B                              (b),
		.VGA_HSYNC                          (HSync),
		.VGA_VSYNC                          (VSync),
		.VGA_HBlank                         (HBlank),
		.VGA_VBlank                         (VBlank),
		.VGA_VBlank_border                  (VGA_VBlank_border),
		.vga_mode13_osd                    (eff_vga13),
		.vga_mode13_native                 (vga_mode13_native_osd),
		.ega_monitor_profile               (ega_monitor_profile_applied),
		.vga_mode13_active_out             (vga_mode13_active_video),
		.vga_mode13_pixel_toggle_out        (vga_mode13_pixel_toggle),
	//	.address                            (address),
		.address_ext                        (bios_access_address),
		.ext_access_request                 (bios_access_request),
		.address_direction                  (address_direction),
		.data_bus                           (data_bus),
		// Private 16-bit SDRAM path, beside the public 8-bit chipset bus.
		.word_read_request                  (word_read_request),
		.word_write_request                 (word_write_request),
		.data_bus_word_in                   (cpu_data_bus_word),
		.data_bus_word                      (data_bus_word),
		.word_read_possible                 (word_read_possible),
		.data_bus_ext                       (bios_write_data[7:0]),
	//	.data_bus_direction                 (data_bus_direction),
		.address_latch_enable               (address_latch_enable),
	//  .io_channel_check                   (),
		.io_channel_ready                   (1'b1),
		.interrupt_request                  (0),    // use?	-> It does not seem to be necessary.
	//  .io_read_n                          (io_read_n),
		.io_read_n_ext                      (1'b1),
	//  .io_read_n_direction                (io_read_n_direction),
	//  .io_write_n                         (io_write_n),
		.io_write_n_ext                     (1'b1),
	//  .io_write_n_direction               (io_write_n_direction),
	//  .memory_read_n                      (memory_read_n),
		.memory_read_n_ext                  (1'b1),
	//  .memory_read_n_direction            (memory_read_n_direction),
	//  .memory_write_n                     (memory_write_n),
		.memory_write_n_ext                 (bios_write_n),
	//  .memory_write_n_direction           (memory_write_n_direction),
		.dma_request                        (0),    // use?	-> I don't know if it will ever be necessary, at least not during testing.
		.dma_acknowledge_n                  (dma_acknowledge_n),
	//  .address_enable_n                   (address_enable_n),
	//  .terminal_count_n                   (terminal_count_n)
		.port_b_out                         (port_b_out),
		.port_c_in                          (port_c_in),
		.port_b_in                          (port_b_out),
		.speaker_out                        (speaker_out),
		.ps2_clock                          (device_clock),
		.ps2_data                           (device_data),
		.ps2_clock_out                      (ps2_kbd_clk_out),
		.ps2_data_out                       (ps2_kbd_data_out),
		.ps2_mouseclk_in                    (ps2_mouse_clk_out),
		.ps2_mousedat_in                    (ps2_mouse_data_out),
		.ps2_mouseclk_out                   (ps2_mouse_clk_in),
		.ps2_mousedat_out                   (ps2_mouse_data_in),
		.joy_opts                           (joy_opts),           //Joy0-Disabled, Joy0-Type, Joy1-Disabled, Joy1-Type, turbo_sync
		.joy0                               (eff_joy_swap ? joy1 : joy0),
		.joy1                               (eff_joy_swap ? joy0 : joy1),
		.joya0                              (eff_joy_swap ? joya1 : joya0),
		.joya1                              (eff_joy_swap ? joya0 : joya1),
		.jtopl2_snd_e                       (jtopl2_snd_e),
		.tandy_snd_e                        (tandy_snd_e),
		.tandy_en                           (eff_tandy),
		.opl2_io                            (eff_opl2),
		.cms_en                             (eff_cms),
		.o_cms_l                            (cms_l_snd_e),
		.o_cms_r                            (cms_r_snd_e),
		.clk_uart                           (clk_uart2_en),
		.uart2_rx                           (uart_rx),
		.uart2_tx                           (uart_tx),
		.uart2_cts_n                        (uart_cts),
		.uart2_dcd_n                        (uart_dcd),
		.uart2_dsr_n                        (uart_dsr),
		.uart2_rts_n                        (uart_rts),
		.uart2_dtr_n                        (uart_dtr),
		.clk_midi                           (clk_midi_en),
		.midi_rx                            (midi_rx),
		.midi_tx                            (midi_tx),
		.enable_sdram                       (1'b1),
		.initilized_sdram                   (initilized_sdram),
		.sdram_clock                        (SDRAM_CLK),
		.sdram_address                      (SDRAM_A),
		.sdram_cke                          (SDRAM_CKE),
		.sdram_cs                           (SDRAM_nCS),
		.sdram_ras                          (SDRAM_nRAS),
		.sdram_cas                          (SDRAM_nCAS),
		.sdram_we                           (SDRAM_nWE),
		.sdram_ba                           (SDRAM_BA),
		.sdram_dq_in                        (SDRAM_DQ_IN),
		.sdram_dq_out                       (SDRAM_DQ_OUT),
		.sdram_dq_io                        (SDRAM_DQ_IO),
		.sdram_ldqm                         (SDRAM_DQML),
		.sdram_udqm                         (SDRAM_DQMH),
		.ems_enabled                        (ems_enabled_sel),
		.ems_address                        (ems_address_sel),
		.umb_enabled                        (umb_enabled_sel),
		.bios_protect_flag                  (bios_protect_flag),
		.use_mmc                            (use_mmc),
		.spi_clk                            (spi_clk),
		.spi_cs                             (spi_cs),
		.spi_mosi                           (spi_mosi),
		.spi_miso                           (spi_miso),
		.mgmt_readdata                      (mgmt_din),
		.mgmt_writedata                     (mgmt_dout),
		.mgmt_address                       (mgmt_addr),
		.mgmt_write                         (mgmt_wr),
		.mgmt_read                          (mgmt_rd),
		.floppy_wp                          (status[20:19]),
		.fdd_present                        (fdd_present),
		.fdd_request                        (mgmt_req[7:6]),
		.ide0_request                       (mgmt_req[2:0]),
		.xtegactl_cpu                       (xtegactl_cpu),
		.xtegactl_exp                       (xtegactl_exp),
		.xtegactl_vid                       (xtegactl_vid),
		.xtegactl_inp                       (xtegactl_inp),
		.xtegactl_midi                      (xtegactl_midi),
		.wait_count_clk_en                  (cpu_ce_negedge),
		.ram_read_wait_cycle                (ram_read_wait_cycle),
		.ram_write_wait_cycle               (ram_write_wait_cycle),
		.pause_core                         (pause_core),
		.video_scandoubler_en                  (video_scandoubler_en),
		.ega_dot_toggle                     (ega_dot_toggle),
		.ega_dot_clock_sel                  (ega_dot_clock_sel),
		.ega_scandouble_active              (ega_scandouble_active),
		.ega_vmode_toggle_out               (ega_vmode_toggle),
		.ega_mode350                        (ega_mode350),
		.ega_active_dots                    (ega_active_dots),
		.ega_active_lines                   (ega_active_lines),
		.crt_h_offset                       (status[49:46]),
		.crt_v_offset                       (status[52:50]),
		.vsync_width_osd                    (vsync_width_osd),
		.hsync_width_osd                    (hsync_width_osd)
	);

    wire [15:0] SDRAM_DQ_IN;
    wire [15:0] SDRAM_DQ_OUT;
    wire        SDRAM_DQ_IO;
    wire        initilized_sdram;

    assign SDRAM_DQ_IN = SDRAM_DQ;
    assign SDRAM_DQ = ~SDRAM_DQ_IO ? SDRAM_DQ_OUT : 16'hZZZZ;

    wire s6_3_mux;
    wire [2:0] SEGMENT;

    i8088 B1 	
	(
		.CORE_CLK(clk_100),
		.CLK(clk_cpu),

		.RESET(reset_cpu),
		.READY(processor_ready && ~pause_core),
		.NMI(1'b0),
		.INTR(interrupt_to_cpu),

		.ad_out(cpu_ad_out),
		.dout(cpu_data_bus),
		.din(data_bus),

		.lock_n(lock_n),
		.s6_3_mux(s6_3_mux),
		.s2_s0_out(processor_status),
		.SEGMENT(SEGMENT),

		.biu_done(biu_done),
		.cycle_accrate(cycle_accrate),
		.clock_cycle_counter_division_ratio(clock_cycle_counter_division_ratio),
		.clock_cycle_counter_decrement_value(clock_cycle_counter_decrement_value),
		.shift_read_timing(shift_read_timing),

		// The CPU type is frozen outside reset so queue depth and bus width
		// cannot change in the middle of an instruction or bus cycle. Fake 286
		// FLAGS carries no such state and tracks the menu as it is changed.
		.is8086(is8086_applied),
		.fake286_flags(fake_286_flags_applied),
		.word_read_request(word_read_request),
		.word_write_request(word_write_request),
		.data_bus_word_out(cpu_data_bus_word),
		.data_bus_word(data_bus_word),
		.word_access_possible(word_read_possible)
	);

    //
    ////////////////////////////  AUDIO  ///////////////////////////////////
    //

    wire [15:0] cms_l_snd_e;
    wire [16:0] cms_l_snd = {cms_l_snd_e[15],cms_l_snd_e};
    wire [15:0] cms_r_snd_e;
    wire [16:0] cms_r_snd = {cms_r_snd_e[15],cms_r_snd_e};
	 
    wire [15:0] jtopl2_snd_e;
    wire [16:0] jtopl2_snd = {jtopl2_snd_e[15], jtopl2_snd_e};
    // Tandy 1000 sound. Sign-extended from 11 bits and scaled the way the
    // parent PCXT does it, except for where the level comes from: the parent
    // has a "Tandy Volume" menu option and this fork has no status bit left to
    // spend on one, so it rides the Speaker Volume setting instead. Both are
    // internal beeper-class sources, and turning one down without the other is
    // not something a user is likely to want.
    wire [10:0] tandy_snd_e;
    wire [16:0] tandy_snd = `ENABLE_TANDY_AUDIO
        ? {{{2{tandy_snd_e[10]}}, {4{tandy_snd_e[10]}}, tandy_snd_e} << status[33:32], 2'b00}
        : 17'd0;
    wire [16:0] spk_vol =  {2'b00, {3'b000,~speaker_out} << status[33:32], 11'd0};
    wire        speaker_out;

    localparam [3:0] comp_f1 = 4;
    localparam [3:0] comp_a1 = 2;
    localparam       comp_x1 = ((32767 * (comp_f1 - 1)) / ((comp_f1 * comp_a1) - 1)) + 1; // +1 to make sure it won't overflow
    localparam       comp_b1 = comp_x1 * comp_a1;

    localparam [3:0] comp_f2 = 8;
    localparam [3:0] comp_a2 = 4;
    localparam       comp_x2 = ((32767 * (comp_f2 - 1)) / ((comp_f2 * comp_a2) - 1)) + 1; // +1 to make sure it won't overflow
    localparam       comp_b2 = comp_x2 * comp_a2;

    function [15:0] compr;
        input [15:0] inp;
        reg [15:0] v, v1, v2;
        begin
            v  = inp[15] ? (~inp) + 1'd1 : inp;
            v1 = (v < comp_x1[15:0]) ? (v * comp_a1) : (((v - comp_x1[15:0])/comp_f1) + comp_b1[15:0]);
            v2 = (v < comp_x2[15:0]) ? (v * comp_a2) : (((v - comp_x2[15:0])/comp_f2) + comp_b2[15:0]);
            v  = status[37] ? v2 : v1;
            compr = inp[15] ? ~(v-1'd1) : v;
        end
    endfunction

    reg [15:0] cmp_l;
    reg [15:0] out_l;
    always @(posedge clk_chipset)
    begin
        reg [16:0] tmp_l;

        tmp_l <= jtopl2_snd + cms_l_snd + tandy_snd + spk_vol + mt32_l_snd;

        // clamp the output
        out_l <= (^tmp_l[16:15]) ? {tmp_l[16], {15{tmp_l[15]}}} : tmp_l[15:0];

        cmp_l <= compr(out_l);
    end
	 
    reg [15:0] cmp_r;
    reg [15:0] out_r;
    always @(posedge clk_chipset)
    begin
        reg [16:0] tmp_r;

        tmp_r <= jtopl2_snd + cms_r_snd + tandy_snd + spk_vol + mt32_r_snd;

        // clamp the output
        out_r <= (^tmp_r[16:15]) ? {tmp_r[16], {15{tmp_r[15]}}} : tmp_r[15:0];

        cmp_r <= compr(out_r);
    end

    assign AUDIO_L   = pause_core ? 1'b0 : status[37:36] ? cmp_l : out_l;
    assign AUDIO_R   = pause_core ? 1'b0 : status[37:36] ? cmp_r : out_r;
    assign AUDIO_S   = 1;
    assign AUDIO_MIX = status[39:38];

    //
    ////////////////////////////  UART  ///////////////////////////////////
    //

    //assign USER_OUT = {1'b1, 1'b1, uart_dtr, 1'b1, uart_rts, uart_tx, 1'b1};

    //
    // Pin | USB Name |   |Signal
    // ----+----------+---+-------------
    // 0   | D+       | I |RX
    // 1   | D-       | O |TX
    // 2   | TX-      | O |RTS
    // 3   | GND_d    | I |CTS
    // 4   | RX+      | O |DTR
    // 5   | RX-      | I |DSR
    // 6   | TX+      | I |DCD
    //

    logic clk_uart_ff_1;
    logic clk_uart_ff_2;
    logic clk_uart_ff_3;
    logic clk_uart_en;
    logic clk_uart2_en;
    logic [2:0] clk_uart2_counter;

    // MIDI baud reference for the MPU-401. Derived straight from the 50MHz
    // clk_chipset rather than the 14.318MHz UART reference, because 50MHz
    // divides exactly: 50e6 / (4 * 16 * 25) = 31250 baud, zero error.
    // (The 14.318MHz path can only reach 30858 baud, -1.25%.) ao486 likewise
    // feeds its MPU a dedicated exact-rate clock instead of the COM reference.
    logic [1:0] clk_midi_counter = 2'd0;
    logic       clk_midi_en = 1'b0;

    always @(posedge clk_chipset)
    begin
        if (clk_midi_counter == 2'd3)
        begin
            clk_midi_counter <= 2'd0;
            clk_midi_en      <= 1'b1;
        end
        else
        begin
            clk_midi_counter <= clk_midi_counter + 2'd1;
            clk_midi_en      <= 1'b0;
        end
    end

    always @(posedge clk_chipset)
    begin
        clk_uart_ff_1 <= clk_14_318;
        clk_uart_ff_2 <= clk_uart_ff_1;
        clk_uart_ff_3 <= clk_uart_ff_2;
        clk_uart_en   <= ~clk_uart_ff_3 & clk_uart_ff_2;
    end

    always @(posedge clk_chipset)
    begin
        if (clk_uart_en)
        begin
            if (3'd7 != clk_uart2_counter)
            begin
                clk_uart2_counter <= clk_uart2_counter +3'd1;
                clk_uart2_en <= 1'b0;
            end
            else
            begin
                clk_uart2_counter <= 3'd0;
                clk_uart2_en <= 1'b1;
            end
        end
        else
        begin
            clk_uart2_counter <= clk_uart2_counter;
            clk_uart2_en <= 1'b0;
        end
    end

    wire uart_tx, uart_rts, uart_dtr;

    // Selecting MIDI in the MiSTer UART menu hands these pins to the HPS, which
    // bridges them to a USB MIDI device. That gives the MPU-401 a second possible
    // destination besides the mt32-pi on the user port, and is the only way to
    // reach a USB MIDI interface - the user port cannot see one. ao486 gates the
    // same way on uart_mode >= 3.
    //
    // COM2, not COM1, is what normally owns these pins here (COM1 is the internal
    // serial mouse), so COM2 is the port that has to let go of them.
    wire hps_midi = `ENABLE_MIDI && (uart_mode >= 8'd3);

    assign UART_TXD = hps_midi ? midi_tx : uart_tx;
    assign UART_RTS = ~hps_midi & uart_rts;
    assign UART_DTR = ~hps_midi & uart_dtr;

    // Idle high, never low: a UART input held at 0 is a break condition, the same
    // trap the USER_OUT default fell into. Holding DCD deasserted also keeps the
    // handover from looking like a carrier transition to a guest with COM2 open.
    wire uart_rx  = hps_midi | UART_RXD;
    wire uart_cts = hps_midi | UART_CTS;
    wire uart_dsr = hps_midi | UART_DSR;
    wire uart_dcd = hps_midi | UART_DTR;


    /// UART2

    // USER_IO is time-shared between the COM2 passthrough (default) and the
    // MT32-pi bridge below - only one can be connected at a time.
    // Default (0) is MT32-pi, matching ao486: at core load, before the saved
    // config arrives, we must already be in the safe non-driving state.
    wire user_io_mt32 = `ENABLE_MIDI && ~status[6];

    // The COM2-over-USER_IO path is dead code in this core: uart2_tx/rts/dtr have
    // no driver, so they synthesise to constant 0 and would actively pull pins
    // 1, 2 and 4 low. Pins 2 and 4 are *outputs* of an attached mt32-pi (I2S), so
    // that is a direct output-vs-output contention, and pin 1 low is a permanent
    // MIDI break. COM2 is also the power-on default before the saved config is
    // applied, so this happened on every core load. Release the pins instead;
    // ao486 never hits this because its COM2 signals are real and idle high.
    assign USER_OUT = user_io_mt32 ? mt32_user_out : 7'h7F;

    //
    // Pin | USB Name |   |Signal
    // ----+----------+---+-------------
    // 0   | D+       | I |RX
    // 1   | D-       | O |TX
    // 2   | TX-      | O |RTS
    // 3   | GND_d    | I |CTS
    // 4   | RX+      | O |DTR
    // 5   | RX-      | I |DSR
    // 6   | TX+      | I |DCD
    //

    wire uart2_tx, uart2_rts, uart2_dtr;

    wire uart2_rx  = user_io_mt32 | USER_IN[0];
    wire uart2_cts = user_io_mt32 | USER_IN[3];
    wire uart2_dsr = user_io_mt32 | USER_IN[5];
    wire uart2_dcd = user_io_mt32 | USER_IN[6];

    //
    ////////////////////////////  MT32-pi  //////////////////////////////////
    //
    // Bridges the MPU-401 UART-mode MIDI interface (rtl/uart/mpu401.sv, wired
    // through the chipset above) to an external mt32-pi device connected on
    // USER_IO. See sys/mt32pi.sv for the wire protocol (MIDI serial + I2S
    // audio in + I2C status/LCD mirror).
    //

    wire        mt32_disable  = status[13];
    // Deliberately NOT reset_wire: that one stays asserted for the whole boot
    // splash (~5s), which would hold the I2C slave silent long enough for the
    // mt32-pi's I2C master to give up. Mirror ao486 and use only the genuine
    // system/user resets.
    wire        mt32_reset    = status[40] | RESET | status[0] | buttons[1];
    wire        mt32_mode_req = eff_mt32_gm;
    wire  [1:0] mt32_rom_req  = status[4:3];
    wire  [7:0] mt32_sf_req   = {5'd0, status[62:60]};

    wire [15:0] mt32_i2s_r, mt32_i2s_l;
    wire  [7:0] mt32_mode, mt32_rom, mt32_sf;
    wire        mt32_lcd_en, mt32_lcd_pix, mt32_lcd_update;
    wire        mt32_newmode;
    wire        mt32_available;
    // Gate on the user's explicit USER_IO selection, NOT on mt32_available.
    // The I2C handshake is only an auto-detect convenience for the OSD; tying
    // the audio path to it means a perfectly working mt32-pi stays silent
    // whenever that handshake does not happen - which is exactly what we hit.
    wire        mt32_use  = user_io_mt32 & ~mt32_disable;
    wire        mt32_mute = user_io_mt32 &  mt32_disable;

    wire  [6:0] mt32_user_out;
    wire        midi_tx;              // driven by the CHIPSET's mpu401 instance
    wire        mt32_pi_midi_rx;
    // Three sources in priority order: the HPS bridge when the UART menu is set
    // to MIDI, the mt32-pi on the user port otherwise, and idle-high when neither
    // is connected. The transmit side needs no such priority - it simply reaches
    // both destinations at once, which is what a MIDI thru does anyway.
    wire        midi_rx = hps_midi    ? UART_RXD        :
                          user_io_mt32 ? mt32_pi_midi_rx : 1'b1;

    mt32pi mt32pi
    (
        .CLK_AUDIO       (CLK_AUDIO),

        .CLK_VIDEO       (CLK_VIDEO),
        .CE_PIXEL        (CE_PIXEL),
        .VGA_VS          (VGA_VS),
        .VGA_DE          (VGA_DE),

        .USER_IN         (USER_IN),
        .USER_OUT        (mt32_user_out),

        .reset           (mt32_reset),
        .midi_tx         (midi_tx | mt32_mute),
        .midi_rx         (mt32_pi_midi_rx),

        .mt32_i2s_r      (mt32_i2s_r),
        .mt32_i2s_l      (mt32_i2s_l),

        .mt32_available  (mt32_available),

        .mt32_mode_req   (mt32_mode_req),
        .mt32_rom_req    (mt32_rom_req),
        .mt32_sf_req     (mt32_sf_req),

        .mt32_mode       (mt32_mode),
        .mt32_rom        (mt32_rom),
        .mt32_sf         (mt32_sf),
        .mt32_newmode    (mt32_newmode),

        .mt32_lcd_en     (mt32_lcd_en),
        .mt32_lcd_pix    (mt32_lcd_pix),
        .mt32_lcd_update (mt32_lcd_update)
    );

    wire signed [16:0] mt32_i2s_l_ext = {mt32_i2s_l[15], mt32_i2s_l};
    wire signed [16:0] mt32_i2s_r_ext = {mt32_i2s_r[15], mt32_i2s_r};
    wire [16:0] mt32_l_snd = mt32_use ? mt32_i2s_l_ext : 17'd0;
    wire [16:0] mt32_r_snd = mt32_use ? mt32_i2s_r_ext : 17'd0;

    //
    ///////////////////////   MMC     ///////////////////////
    //
    logic [1:0]  use_mmc;
    logic spi_clk;
    logic spi_cs;
    logic spi_mosi;
    logic spi_miso;

    always @(posedge clk_chipset)
        if (reset)
            use_mmc <= status[22:21];
        else
            use_mmc <= use_mmc;

    // Every menu option that is sampled only while reset is asserted. Each one
    // exposes both the selection and what the machine is actually running on,
    // so a plain comparison is all "pending" means. It reads false throughout
    // reset, because that is exactly when the latches track their source, so
    // this cannot fire on the way out of a cold boot.
    wire reset_pending = (cpu_type_8086_osd       != is8086_applied)
                       | (ega_monitor_profile_osd != ega_monitor_profile_applied)
                       | (status[22:21]           != use_mmc);

    reset_pending_notice reset_notice (
        .clock      (clk_14_318),
        .pending    (reset_pending),
        .osd_status (OSD_STATUS),
        .suppress   (bios_hold),
        .info       (pending_info),
        .info_req   (pending_info_req)
    );

    assign  SD_SCK      = spi_clk;
    assign  SD_MOSI     = spi_mosi;
    assign  spi_miso    = SD_MISO;
    assign  SD_CS       = spi_cs;

    //
    ///////////////////////   VIDEO   ///////////////////////
    //

    wire HBlank;
    wire HSync;
    wire VBlank;
    wire VSync;
    wire de_o;
    wire [5:0] r, g, b;
    reg [7:0] raux_video, gaux_video, baux_video;
	 wire [7:0] VGA_R_AUX, VGA_G_AUX, VGA_B_AUX;
    wire CLK_VIDEO_PIPELINE;
    wire CE_PIXEL_CREDITS;

    wire  [7:0] VGA_R_video;
    wire  [7:0] VGA_G_video;
    wire  [7:0] VGA_B_video;
    wire        VGA_HS_video;
    wire        VGA_VS_video;
    wire        VGA_DE_video;
    wire [21:0] gamma_bus_video;
    wire        CE_PIXEL_video;
    reg         ce_pixel_28 = 1'b0;
    wire        vga_video_direct = vga_mode13_active_video;

    // The EGA dot rate is no longer a fixed 14.318 MHz: in the 16.257 MHz
    // modes consecutive dots can land on adjacent clk_28_636 edges, which in
    // this domain would be a single wide level with only one rising edge.  The
    // EGA exports a toggle instead, one flip per dot.  Exactly one
    // synchroniser stage before the XOR: both clocks come from pll_system with
    // a 2:1 ratio and no phase shift, and a second stage would push the enable
    // past the end of the short dots of the 16.257 MHz pattern.
    reg         ega_dot_toggle_d = 1'b0;
    reg         ega_dot_toggle_dd = 1'b0;

    always @(posedge clk_57_272)
    begin
        ega_dot_toggle_d  <= ega_dot_toggle;
        ega_dot_toggle_dd <= ega_dot_toggle_d;
    end

    wire        ce_pixel_dot = ega_dot_toggle_d ^ ega_dot_toggle_dd;

    // vga_mode13_active_video always drives the 15 kHz CRT TV compatible
    // mode13h raster (rtl/video/vga_mode13_timing.v), whose real pixel rate
    // is one flip per displayed pixel, not per clk_28_636 cycle. Same
    // toggle-crossing idiom as ce_pixel_dot above, so the framework's
    // active-window measurement (the OSD Information line) reports the real
    // pixel count instead of the raw dot-clock count.
    reg         vga_mode13_pixel_toggle_d = 1'b0;
    reg         vga_mode13_pixel_toggle_dd = 1'b0;

    always @(posedge clk_57_272)
    begin
        vga_mode13_pixel_toggle_d  <= vga_mode13_pixel_toggle;
        vga_mode13_pixel_toggle_dd <= vga_mode13_pixel_toggle_d;
    end

    wire        ce_pixel_mode13 = vga_mode13_pixel_toggle_d ^ vga_mode13_pixel_toggle_dd;
    wire        ce_pixel_video = ega_scandouble_active ? ce_pixel_28
                                : vga_video_direct       ? ce_pixel_mode13
                                : ce_pixel_dot;

    reg  [7:0]  VGA_R_video_src = 8'd0;
    reg  [7:0]  VGA_G_video_src = 8'd0;
    reg  [7:0]  VGA_B_video_src = 8'd0;
    reg         VGA_HS_video_src = 1'b0;
    reg         VGA_VS_video_src = 1'b0;
    reg         VGA_DE_video_src = 1'b0;
    reg         LHBL_video_src = 1'b1;
    reg         LVBL_video_src = 1'b1;
    reg         CE_PIXEL_video_src = 1'b0;
    reg  [7:0]  VGA_R_video_ps = 8'd0;
    reg  [7:0]  VGA_G_video_ps = 8'd0;
    reg  [7:0]  VGA_B_video_ps = 8'd0;
    reg         VGA_HS_video_ps = 1'b0;
    reg         VGA_VS_video_ps = 1'b0;
    reg         VGA_DE_video_ps = 1'b0;
    reg         LHBL_video_ps = 1'b1;
    reg         LVBL_video_ps = 1'b1;
    reg         CE_PIXEL_video_ps = 1'b0;
    reg         CE_PIXEL_video_ps_d = 1'b0;
    reg  [7:0]  VGA_R_video_hdmi, VGA_G_video_hdmi, VGA_B_video_hdmi;
    reg         VGA_HS_video_hdmi, VGA_VS_video_hdmi, VGA_DE_video_hdmi;
    reg         LHBL_video_hdmi, LVBL_video_hdmi;
    reg         CE_PIXEL_video_hdmi = 1'b0;

    assign CLK_VIDEO = clk_video_out_ps;
    assign CLK_VIDEO_PIPELINE = clk_57_272;

    always @(posedge clk_57_272)
        ce_pixel_28 <= ~ce_pixel_28;

    assign VGA_SL = {scale_video_ff==3, scale_video_ff==2};

    wire   scandoubler = video_scandoubler_en;

    wire color = (screen_mode_video_ff == 3'd0);

    // The credits are the reason to pause at all, so they follow the splash
    // hold as well as the machine's own pause key.  Only the overlay does:
    // audio and CPU ready still key off pause_core alone, because during the
    // splash there is no machine running to silence or stall.
    reg        video_credits_show_buf;
    reg        video_credits_show;

    always @ (posedge clk_video_out_ps) begin
        video_credits_show_buf  <= pause_core | splash_paused;
        video_credits_show      <= video_credits_show_buf;
    end

    wire LHBL = (ega_scandouble_active || vga_video_direct) ? HBlank : ~de_o;
    wire LVBL = VBlank;

    wire haux_video, vaux_video, hbaux_video, vbaux_video;

    // Sync and blanking go through the converter with the colour so they come
    // out of it with the same delay.  Mode 13h only takes the undelayed pair
    // below in Full Color: once a monochrome Display option is picked it has
    // to run through the converter like every other mode, both for the tint
    // and to stay time-aligned with it, or the picture is full colour again.
    video_monochrome_converter video_mono
	(
		.clk_vid(CLK_VIDEO_PIPELINE),
		.ce_pix(ce_pixel_video),

		.R({r, 2'b00}),
		.G({g, 2'b00}),
		.B({b, 2'b00}),

		.HSync(HSync),
		.VSync(VSync),
		.HBlank(LHBL),
		.VBlank(LVBL),

		.gfx_mode(screen_mode_video_ff),

		.R_OUT(raux_video),
		.G_OUT(gaux_video),
		.B_OUT(baux_video),

		.HSync_OUT(haux_video),
		.VSync_OUT(vaux_video),
		.HBlank_OUT(hbaux_video),
		.VBlank_OUT(vbaux_video)
	);

    wire       pre2x_LHBL, pre2x_LVBL;
    wire [7:0] pre2x_r, pre2x_g, pre2x_b;
    wire [23:0] credits_rgb_out;
    wire vga_video_direct_color = vga_video_direct && color;
    wire [7:0] bypass_r = vga_video_direct_color ? {r, r[5:4]} : raux_video;
    wire [7:0] bypass_g = vga_video_direct_color ? {g, g[5:4]} : gaux_video;
    wire [7:0] bypass_b = vga_video_direct_color ? {b, b[5:4]} : baux_video;
    wire bypass_hs = vga_video_direct_color ? HSync : haux_video;
    wire bypass_vs = vga_video_direct_color ? VSync : vaux_video;
    wire bypass_hb = vga_video_direct_color ? LHBL  : hbaux_video;
    wire bypass_vb = vga_video_direct_color ? LVBL  : vbaux_video;

    ///////////////////  350-LINE CRT OUTPUT, 720x480i  ///////////////////
    //
    // EGA and MDA modes with more than 240 active lines scan at 18-22 kHz and
    // no television locks to that. They are captured into DDRAM a frame at a
    // time and read back out on a 15.734 kHz interlaced raster, which is the
    // only way to show all 350 lines without throwing half of them away.
    //
    // Everything else - CGA, mode 13h, the boot splash - takes the bypass
    // above untouched, and so does 350 lines when the OSD option is off.
    //
    // The capture taps the picture after the monochrome converter, so the
    // Display option is already applied and a green or amber screen is
    // captured the way it is shown.

    // 0 native, 1 the captured picture interlaced, 2 the same picture
    // progressively.
    //
    // 480i shows all 350 lines and flickers on high contrast text; 240p is
    // steady and drops a third of them. Which of the two is better belongs to
    // the television and the eye in front of it, so both are offered.
    wire [1:0] crt480i_mode = status[35:34];
    wire crt480i_osd  = |crt480i_mode;
    wire crt480i_prog = crt480i_mode[1];

    // The detector runs in the 28.636 MHz video domain and these change once a
    // frame. Two stages across to the pipeline clock, which is the same PLL at
    // twice the rate.
    reg        mode350_s1, mode350_s2;
    reg [11:0] adots_s1, adots_s2;
    reg [9:0]  alines_s1, alines_s2;

    always @(posedge CLK_VIDEO_PIPELINE) begin
        mode350_s1 <= ega_mode350;  mode350_s2 <= mode350_s1;
        adots_s1   <= ega_active_dots;  adots_s2  <= adots_s1;
        alines_s1  <= ega_active_lines; alines_s2 <= alines_s1;
    end

    wire fb_enable = mode350_s2 & crt480i_osd;

    wire [7:0]  cap_burstcnt;
    wire [28:0] cap_addr;
    wire [63:0] cap_din;
    wire        cap_we;
    wire        cap_busy;
    wire [1:0]  fb_frame_buffer;
    wire [11:0] fb_frame_width;
    wire [9:0]  fb_frame_height;
    wire [13:0] fb_frame_stride;
    wire        fb_frame_valid;
    wire [1:0]  fb_reading_buffer;

    ega_fb_capture fb_capture (
        .clk(CLK_VIDEO_PIPELINE),
        .reset(video_retime_reset),
        .enable(fb_enable),
        .ce_pix(ce_pixel_video),
        .r(bypass_r), .g(bypass_g), .b(bypass_b),
        .de(~bypass_hb & ~bypass_vb),
        .vblank(bypass_vb),
        .active_dots(adots_s2),
        .active_lines(alines_s2),
        .reading_buffer(fb_reading_buffer),
        .ddram_busy(cap_busy),
        .ddram_burstcnt(cap_burstcnt),
        .ddram_addr(cap_addr),
        .ddram_din(cap_din),
        .ddram_be(),
        .ddram_we(cap_we),
        .frame_buffer(fb_frame_buffer),
        .frame_width(fb_frame_width),
        .frame_height(fb_frame_height),
        .frame_stride(fb_frame_stride),
        .frame_seq(),
        .frame_valid(fb_frame_valid),
        .overrun()
    );

    wire        fb_rd_req;
    wire [28:0] fb_rd_addr;
    wire [7:0]  fb_rd_burstcnt;
    wire        fb_rd_grant;
    wire [63:0] fb_rd_data;
    wire        fb_rd_data_valid;

    wire [7:0]  fb_r, fb_g, fb_b;
    wire        fb_hs, fb_vs, fb_hb, fb_vb, fb_de, fb_field, fb_ce_pix;

    ega_fb_readout fb_readout (
        .clk(CLK_VIDEO_PIPELINE),
        .reset(video_retime_reset),
        .enable(fb_enable),
        .progressive(crt480i_prog),
        .crt_h_offset(status[49:46]),
        .crt_v_offset(status[52:50]),
        .frame_buffer(fb_frame_buffer),
        .frame_width(fb_frame_width),
        .frame_height(fb_frame_height),
        .frame_stride(fb_frame_stride),
        .frame_valid(fb_frame_valid),
        .rd_req(fb_rd_req),
        .rd_addr(fb_rd_addr),
        .rd_burstcnt(fb_rd_burstcnt),
        .rd_grant(fb_rd_grant),
        .rd_data(fb_rd_data),
        .rd_data_valid(fb_rd_data_valid),
        .r(fb_r), .g(fb_g), .b(fb_b),
        .hsync(fb_hs), .vsync(fb_vs), .hblank(fb_hb), .vblank(fb_vb),
        .de(fb_de), .field(fb_field), .ce_pix(fb_ce_pix),
        .reading_buffer(fb_reading_buffer)
    );

    // The memory runs on the video pipeline clock, so the capture, the
    // raster that reads it back and DDRAM itself are all one domain and
    // nothing has to cross between them.
    assign DDRAM_CLK = CLK_VIDEO_PIPELINE;

    ega_ddr_arbiter fb_arbiter (
        .clk(CLK_VIDEO_PIPELINE),
        .reset(video_retime_reset),
        .ddram_busy(DDRAM_BUSY),
        .ddram_burstcnt(DDRAM_BURSTCNT),
        .ddram_addr(DDRAM_ADDR),
        .ddram_din(DDRAM_DIN),
        .ddram_be(DDRAM_BE),
        .ddram_we(DDRAM_WE),
        .ddram_rd(DDRAM_RD),
        .ddram_dout(DDRAM_DOUT),
        .ddram_dout_ready(DDRAM_DOUT_READY),
        .rd_req(fb_rd_req),
        .rd_addr(fb_rd_addr),
        .rd_burstcnt(fb_rd_burstcnt),
        .rd_grant(fb_rd_grant),
        .rd_data(fb_rd_data),
        .rd_data_valid(fb_rd_data_valid),
        .wr_req(cap_we),
        .wr_addr(cap_addr),
        .wr_burstcnt(cap_burstcnt),
        .wr_din(cap_din),
        .wr_busy_out(cap_busy),
        .wr_grant()
    );

    // The path only changes with both rasters blanked, so neither side is ever
    // cut off mid-picture. The two are unrelated in phase, so a window turns up
    // within a frame or two of the request; until then the picture carries on
    // as it was, which is what should happen.
    reg crt480i_active = 1'b0;

    always @(posedge CLK_VIDEO_PIPELINE) begin
        if (video_retime_reset)
            crt480i_active <= 1'b0;
        else if (bypass_vb && fb_vb)
            crt480i_active <= fb_enable & fb_frame_valid;
    end

    wire [7:0] video_mixer_r = crt480i_active ? fb_r  : bypass_r;
    wire [7:0] video_mixer_g = crt480i_active ? fb_g  : bypass_g;
    wire [7:0] video_mixer_b = crt480i_active ? fb_b  : bypass_b;
    wire video_mixer_hs = crt480i_active ? fb_hs : bypass_hs;
    wire video_mixer_vs = crt480i_active ? fb_vs : bypass_vs;
    wire video_mixer_hb = crt480i_active ? fb_hb : bypass_hb;
    wire video_mixer_vb = crt480i_active ? fb_vb : bypass_vb;
    wire ce_pixel_mixer = crt480i_active ? fb_ce_pix : ce_pixel_video;

    // The credits overlay and the framework's active-window measurement follow
    // whichever raster is actually being emitted.
    wire LHBL_out = crt480i_active ? fb_hb : LHBL;
    wire LVBL_out = crt480i_active ? fb_vb : LVBL;

    // Which field is on the wire. It moves once per field, far slower than
    // anything else here, so two flops across to the output clock are enough.
    reg vga_f1_ps1 = 1'b0, vga_f1_ps2 = 1'b0;

    always @(posedge clk_video_out_ps) begin
        vga_f1_ps1 <= crt480i_active & fb_field;
        vga_f1_ps2 <= vga_f1_ps1;
    end

    assign VGA_F1 = vga_f1_ps2;
	 

	video_mixer #(.GAMMA(1)) video_mixer_main
	(
		.*,

		.CLK_VIDEO(CLK_VIDEO_PIPELINE),
		.CE_PIXEL(CE_PIXEL_video),
		.ce_pix(ce_pixel_mixer),

		.freeze_sync(),

		.R(video_mixer_r),
		.G(video_mixer_g),
		.B(video_mixer_b),

		.HBlank(video_mixer_hb),
		.VBlank(video_mixer_vb),
		.HSync(video_mixer_hs),
		.VSync(video_mixer_vs),

		.scandoubler(1'b0),
		.hq2x(scale_video_ff==1),
		.gamma_bus(gamma_bus_video),

		.VGA_R(VGA_R_video),
		.VGA_G(VGA_G_video),
		.VGA_B(VGA_B_video),
		.VGA_VS(VGA_VS_video),
		.VGA_HS(VGA_HS_video),
		.VGA_DE(VGA_DE_video)

	);

    always @(posedge clk_57_272)
    begin
        VGA_R_video_src <= VGA_R_video;
        VGA_G_video_src <= VGA_G_video;
        VGA_B_video_src <= VGA_B_video;
        VGA_HS_video_src <= VGA_HS_video;
        VGA_VS_video_src <= VGA_VS_video;
        VGA_DE_video_src <= VGA_DE_video;
        LHBL_video_src <= LHBL_out;
        LVBL_video_src <= LVBL_out;
        CE_PIXEL_video_src <= CE_PIXEL_video;
    end

    // Retimes the exact-frequency video output onto a phase-shifted sibling clock.
    always @(posedge clk_video_out_ps or posedge video_retime_reset_local)
    begin
        if (video_retime_reset_local)
        begin
            VGA_R_video_ps <= 8'd0;
            VGA_G_video_ps <= 8'd0;
            VGA_B_video_ps <= 8'd0;
            VGA_HS_video_ps <= 1'b0;
            VGA_VS_video_ps <= 1'b0;
            VGA_DE_video_ps <= 1'b0;
            LHBL_video_ps <= 1'b1;
            LVBL_video_ps <= 1'b1;
            CE_PIXEL_video_ps <= 1'b0;
            CE_PIXEL_video_ps_d <= 1'b0;
            VGA_R_video_hdmi <= 8'd0;
            VGA_G_video_hdmi <= 8'd0;
            VGA_B_video_hdmi <= 8'd0;
            VGA_HS_video_hdmi <= 1'b0;
            VGA_VS_video_hdmi <= 1'b0;
            VGA_DE_video_hdmi <= 1'b0;
            LHBL_video_hdmi <= 1'b1;
            LVBL_video_hdmi <= 1'b1;
            CE_PIXEL_video_hdmi <= 1'b0;
        end
        else
        begin
            CE_PIXEL_video_hdmi <= CE_PIXEL_video_ps & ~CE_PIXEL_video_ps_d;
            if (CE_PIXEL_video_ps & ~CE_PIXEL_video_ps_d)
            begin
                VGA_R_video_hdmi <= VGA_R_video_ps;
                VGA_G_video_hdmi <= VGA_G_video_ps;
                VGA_B_video_hdmi <= VGA_B_video_ps;
                VGA_HS_video_hdmi <= VGA_HS_video_ps;
                VGA_VS_video_hdmi <= VGA_VS_video_ps;
                VGA_DE_video_hdmi <= VGA_DE_video_ps;
                LHBL_video_hdmi <= LHBL_video_ps;
                LVBL_video_hdmi <= LVBL_video_ps;
            end

            CE_PIXEL_video_ps_d <= CE_PIXEL_video_ps;
            CE_PIXEL_video_ps <= CE_PIXEL_video_src;
            VGA_R_video_ps <= VGA_R_video_src;
            VGA_G_video_ps <= VGA_G_video_src;
            VGA_B_video_ps <= VGA_B_video_src;
            VGA_HS_video_ps <= VGA_HS_video_src;
            VGA_VS_video_ps <= VGA_VS_video_src;
            VGA_DE_video_ps <= VGA_DE_video_src;
            LHBL_video_ps <= LHBL_video_src;
            LVBL_video_ps <= LVBL_video_src;
        end
    end

    assign VGA_R_AUX  =  VGA_R_video_hdmi;
    assign VGA_G_AUX  =  VGA_G_video_hdmi;
    assign VGA_B_AUX  =  VGA_B_video_hdmi;
    assign VGA_HS =  VGA_HS_video_hdmi;
    assign VGA_VS =  VGA_VS_video_hdmi;
    assign gamma_bus =  gamma_bus_video;
    assign CE_PIXEL  =  CE_PIXEL_video_hdmi;
    assign CE_PIXEL_CREDITS = CE_PIXEL_video_hdmi;
    wire credits_hb = LHBL_video_hdmi;
    wire credits_vb = LVBL_video_hdmi;
    jtframe_credits #(
        .PAGES  (4),
        .COLW   (8),
        .BLKPOL (1)
    // Reset from the domain it actually runs in.  The machine's reset is held
    // for as long as the splash is on screen, which would have kept the
    // overlay blank exactly where it is now wanted.  Nothing is lost by the
    // change: the scroll position is re-seeded on every rising edge of
    // enable regardless, so each pause still starts the credits from the top.
    ) u_credits(
        .rst        ( video_retime_reset_local ),
        .clk        ( clk_video_out_ps ),
        .pxl_cen    ( CE_PIXEL_CREDITS ),

        // input image
        .HB         ( credits_hb  ),
        .VB         ( credits_vb ),
        .rgb_in     ( { VGA_R_AUX, VGA_G_AUX, VGA_B_AUX } ),
        .rotate     ( 2'd0  ),
        .toggle     ( 1'b0  ),
        .fast_scroll( 1'b0  ),
        .border     ( 1'b0 ),

        .vram_din   ( 8'h0  ),
        .vram_dout  (       ),
        .vram_addr  ( 8'h0  ),
        .vram_we    ( 1'b0  ),
        .vram_ctrl  ( 3'b0  ),
        .enable     ( video_credits_show ),

        // output image
        .HB_out     ( pre2x_LHBL      ),
        .VB_out     ( pre2x_LVBL      ),
        .rgb_out    ( credits_rgb_out )
    );

    // The credits block registers RGB once on CE_PIXEL, even while its overlay
    // is disabled.  Register the already-processed DE on that same event; using
    // VGA_DE_video_hdmi directly opens the active window one pixel before the
    // corresponding credits_rgb_out sample and clips the last pixel instead.
    reg VGA_DE_credits = 1'b0;
    always @(posedge clk_video_out_ps or posedge video_retime_reset_local) begin
        if (video_retime_reset_local)
            VGA_DE_credits <= 1'b0;
        else if (CE_PIXEL_CREDITS)
            VGA_DE_credits <= VGA_DE_video_hdmi;
    end

    assign VGA_DE = VGA_DE_credits;
    assign {VGA_R, VGA_G, VGA_B} = credits_rgb_out;


endmodule

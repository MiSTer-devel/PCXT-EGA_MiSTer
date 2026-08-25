// What the XTEGACTL registers mean, and how they combine with the OSD.
//
// Every field encodes 0 as "leave it to the OSD" and 1..N as the N choices in
// the same order the menu lists them.  So the power-on state of all zeroes is
// plain OSD behaviour, a program overrides only what it cares about, and a
// setting left behind by an earlier program cannot quietly capture an option
// nobody meant to touch.  It also means the tool never has to read the menu
// back to leave something alone: writing zero is how you say "not mine".
//
// Purely combinational, and kept apart from the port block so it can sit at
// the top level where the OSD status is, rather than dragging status bits
// down through the chipset just to be muxed and handed back.

`default_nettype none

module xtegactl_resolve (
    // Raw registers from the port block.
    input  wire  [7:0] reg_cpu,
    input  wire  [7:0] reg_exp,
    input  wire  [7:0] reg_vid,
    input  wire  [7:0] reg_inp,
    input  wire  [7:0] reg_midi,
    input  wire  [7:0] reg_exp2,

    // What the OSD currently asks for.
    input  wire  [1:0] osd_speed,        // 0=4.77  1=7.16  2=9.54  3=Max
    input  wire        osd_fake286,
    input  wire  [1:0] osd_opl2,         // 0=388h  1=388h+228h  2=off
    input  wire        osd_cms,
    input  wire        osd_sb,
    input  wire        osd_ems,
    input  wire        osd_umb,
    input  wire        osd_vga13,
    input  wire        osd_joy1_digital,
    input  wire        osd_joy1_disable,
    input  wire        osd_joy2_digital,
    input  wire        osd_joy2_disable,
    input  wire        osd_joy_sync,
    input  wire        osd_joy_swap,
    input  wire        osd_mt32_gm,
    // Tandy sound has no menu option to defer to - it is a build-time choice -
    // so this is what the build says, and zero means "whatever the build says"
    // rather than "whatever the menu says".  The distinction only shows when
    // the chip is compiled out: the field then cannot switch on hardware that
    // is not there, which is also enforced at the chip select itself.
    input  wire  [7:0] reg_crt,
    input  wire  [7:0] reg_sync,
    input  wire  [3:0] osd_crt_h,
    input  wire  [2:0] osd_crt_v,
    input  wire        build_sb,
    input  wire        build_tandy,

    // What the machine should actually run on.
    output wire  [1:0] eff_speed,
    output wire        eff_fake286,
    output wire  [1:0] eff_opl2,
    output wire        eff_cms,
    output wire        eff_sb,
    output wire        eff_ems,
    output wire        eff_umb,
    output wire        eff_vga13,
    output wire        eff_joy1_digital,
    output wire        eff_joy1_disable,
    output wire        eff_joy2_digital,
    output wire        eff_joy2_disable,
    output wire        eff_joy_sync,
    output wire        eff_joy_swap,
    output wire        eff_mt32_gm,
    output wire        eff_tandy,
    output wire  [3:0] eff_crt_h,
    output wire  [2:0] eff_crt_v,
    output wire  [2:0] eff_vsync_w,
    output wire  [2:0] eff_hsync_w
);

    // Named so the resolution below reads as the table in the header rather
    // than as bit arithmetic.
    wire [2:0] f_speed   = reg_cpu[2:0];
    wire [1:0] f_fake286 = reg_cpu[4:3];
    wire [1:0] f_opl2    = reg_exp[1:0];
    wire [1:0] f_cms     = reg_exp[3:2];
    wire [1:0] f_ems     = reg_exp[5:4];
    wire [1:0] f_umb     = reg_exp[7:6];
    wire [1:0] f_vga13   = reg_vid[1:0];
    wire [1:0] f_joy1    = reg_inp[1:0];
    wire [1:0] f_joy2    = reg_inp[3:2];
    wire [1:0] f_swap    = reg_inp[5:4];
    wire [1:0] f_sync    = reg_inp[7:6];
    wire [1:0] f_mt32    = reg_midi[1:0];
    wire [1:0] f_tandy   = reg_exp2[1:0];
    wire [1:0] f_sb      = reg_exp2[3:2];

    // Screen geometry, meant to be set by a launcher just before it hands
    // over to a game - centring the picture is per-program work, not a
    // property of the machine.
    //
    // The offsets cannot use the usual "zero defers to the OSD" rule,
    // because zero is a real offset, so they carry an explicit override
    // bit instead. The sync widths have no menu entry left to defer to and
    // take the register as their only source; zero is Auto there, and zero
    // is the reset value, so an untouched core starts in Auto.
    wire [3:0] f_crt_h   = reg_crt[3:0];
    wire [2:0] f_crt_v   = reg_crt[6:4];
    wire       f_crt_ovr = reg_crt[7];
    wire [2:0] f_vsync_w = reg_sync[2:0];
    wire [2:0] f_hsync_w = reg_sync[5:3];

    // Speed is the one field wider than two bits, because it picks between
    // four choices rather than three.  Values above Max are not choices, so
    // they read as "leave it to the OSD" rather than aliasing onto a speed.
    wire speed_override = (f_speed >= 3'd1) & (f_speed <= 3'd4);
    assign eff_speed = speed_override ? (f_speed[1:0] - 2'd1) : osd_speed;

    // 1 selects the first menu entry, 2 the second.
    assign eff_fake286 = (f_fake286 == 2'd0) ? osd_fake286  : (f_fake286 == 2'd2);
    assign eff_opl2    = (f_opl2    == 2'd0) ? osd_opl2     : (f_opl2 - 2'd1);
    // The Sound Blaster and the C/MS share 220h and collide on 226h/227h -
    // one puts its DSP reset there, the other its detection register - so
    // only one of them may answer. The OSD offers them as a single
    // three-way choice and so cannot ask for both, but the XTEGACTL fields
    // are independent and a program can set either. The Sound Blaster wins
    // that tie, because a program that went out of its way to ask for one
    // is the better guess at intent than a default left enabled.
    wire cms_selected  = (f_cms == 2'd0) ? osd_cms : (f_cms == 2'd1);
    assign eff_sb      = build_sb & ((f_sb == 2'd0) ? osd_sb : (f_sb == 2'd1));
    assign eff_cms     = cms_selected & ~eff_sb;
    assign eff_ems     = (f_ems     == 2'd0) ? osd_ems      : (f_ems   == 2'd1);
    assign eff_umb     = (f_umb     == 2'd0) ? osd_umb      : (f_umb   == 2'd1);
    assign eff_vga13   = (f_vga13   == 2'd0) ? osd_vga13    : (f_vga13 == 2'd2);
    assign eff_joy_swap= (f_swap    == 2'd0) ? osd_joy_swap : (f_swap  == 2'd2);
    assign eff_joy_sync= (f_sync    == 2'd0) ? osd_joy_sync : (f_sync  == 2'd2);
    assign eff_mt32_gm = (f_mt32    == 2'd0) ? osd_mt32_gm  : (f_mt32  == 2'd2);
    assign eff_tandy   = (f_tandy   == 2'd0) ? build_tandy  : (f_tandy == 2'd1);

    assign eff_crt_h   = f_crt_ovr ? f_crt_h : osd_crt_h;
    assign eff_crt_v   = f_crt_ovr ? f_crt_v : osd_crt_v;
    assign eff_vsync_w = f_vsync_w;
    assign eff_hsync_w = f_hsync_w;

    // Analog, Digital and Disabled are one menu option but two signals: the
    // core carries the stick type and the disable separately.
    assign eff_joy1_digital = (f_joy1 == 2'd0) ? osd_joy1_digital : (f_joy1 == 2'd2);
    assign eff_joy1_disable = (f_joy1 == 2'd0) ? osd_joy1_disable : (f_joy1 == 2'd3);
    assign eff_joy2_digital = (f_joy2 == 2'd0) ? osd_joy2_digital : (f_joy2 == 2'd2);
    assign eff_joy2_disable = (f_joy2 == 2'd0) ? osd_joy2_disable : (f_joy2 == 2'd3);

endmodule

`default_nettype wire

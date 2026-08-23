//============================================================================
//
//  VGA mode 13h 320x200 timing. The selectable Native profile restores the
//  original free-running ~31.4 kHz / 70 Hz Mode 13h scan; the 60 Hz profile
//  is the 15 kHz CRT-TV-compatible raster used by older builds.
//
//  The 60 Hz geometry below is the CGA/EGA 200-line raster, dot for dot: 1824
//  clk_28_636 clocks/line (912 CGA dots at 14.318 MHz, ~15.70 kHz) and 262
//  lines/frame (~59.9 Hz), with the active window, sync width and porches in
//  the same places. A TV therefore sees a signal geometrically identical to
//  the EGA/CGA modes this core already displays correctly, and centres it the
//  same way, instead of needing its own set of porches.
//
//  Each of the 320 source pixels is 4 clocks wide, so the active window is
//  1280 clocks - exactly the 640 dots CGA spends at 14.318 MHz. pixel_toggle
//  is emitted every 2 clocks, so the framework measures 640x200 here as well,
//  letting one MiSTer.ini video section and one set of OSD offsets cover both
//  paths.
//
//  The framebuffer is random-access, so only the raster that reads it
//  changes; every source line is still shown exactly once.
//
//============================================================================

module vga_mode13_timing(
    input  wire        clock,
    input  wire        reset,
    input  wire        enable,
    input  wire        native_70hz,
    // 00 320x200, 01 360x200, 10 320x240. Packed Mode 13h supplies 00.
    input  wire [1:0]  mode_x_profile,
    input  wire [3:0]  crt_h_offset,
    input  wire [2:0]  crt_v_offset,
    output wire [9:0]  pixel_x,
    output wire [9:0]  pixel_y,
    output wire        active,
    output wire        hblank,
    output wire        vblank,
    output wire        hsync,
    output wire        vsync,
    output wire        line_start,
    output wire        frame_start,
    output reg         pixel_toggle
);

    // 320 source pixels x 4 clocks = the 1280 clocks CGA spends on its 640
    // dots; the porches are CGA's 80/80/112 dots, also doubled, less the 16
    // clocks of bias described below.
    localparam [10:0] TV_H_ACTIVE = 11'd1280;
    localparam [10:0] TV_H_FRONT  = 11'd144;
    localparam [10:0] TV_H_SYNC   = 11'd160;
    localparam [10:0] TV_H_BACK   = 11'd240;
    localparam [10:0] TV_H_TOTAL  = TV_H_ACTIVE + TV_H_FRONT + TV_H_SYNC + TV_H_BACK;

    // CGA's 200-line field: 24 lines of front porch, a 16-line VSYNC and 22
    // lines of back porch around the 200 active lines, again with a 1-line
    // bias applied.
    localparam [9:0] TV_V_ACTIVE = 10'd200;
    localparam [9:0] TV_V_FRONT  = 10'd25;
    localparam [9:0] TV_V_SYNC   = 10'd16;
    localparam [9:0] TV_V_BACK   = 10'd21;
    localparam [9:0] TV_V_TOTAL  = TV_V_ACTIVE + TV_V_FRONT + TV_V_SYNC + TV_V_BACK;

    // These are the original timing constants from the first Mode 13h
    // implementation. With the existing 28.636 MHz clock they are 31.4 kHz
    // and 69.99 Hz (28.636 MHz / 912 / 449), so no PLL is needed.
    localparam [10:0] NATIVE_H_ACTIVE = 11'd640;
    localparam [10:0] NATIVE_H_FRONT  = 11'd24;
    localparam [10:0] NATIVE_H_SYNC   = 11'd96;
    localparam [10:0] NATIVE_H_BACK   = 11'd152;
    localparam [10:0] NATIVE_H_TOTAL  = NATIVE_H_ACTIVE + NATIVE_H_FRONT + NATIVE_H_SYNC + NATIVE_H_BACK;
    localparam [9:0]  NATIVE_V_ACTIVE = 10'd200;
    localparam [9:0]  NATIVE_V_FRONT  = 10'd12;
    localparam [9:0]  NATIVE_V_SYNC   = 10'd2;
    localparam [9:0]  NATIVE_V_BACK   = 10'd235;
    localparam [9:0]  NATIVE_V_TOTAL  = NATIVE_V_ACTIVE + NATIVE_V_FRONT + NATIVE_V_SYNC + NATIVE_V_BACK;

    localparam [1:0] PROFILE_360X200 = 2'd1;
    localparam [1:0] PROFILE_320X240 = 2'd2;
    wire mode_x_360 = (mode_x_profile == PROFILE_360X200);
    wire mode_x_240 = (mode_x_profile == PROFILE_320X240);

    // Keep both output-raster totals unchanged. 360-wide mode borrows blank
    // time for its wider active area; 320x240 borrows vertical blank time.
    // The 60 Hz path therefore remains a 15.70 kHz / 59.9 Hz TV raster with
    // no PLL. Native preserves its existing 31.4 kHz / 70 Hz frame totals.
    wire [10:0] h_active = mode_x_360 ? (native_70hz ? 11'd720 : 11'd1440)
                                       : (native_70hz ? NATIVE_H_ACTIVE : TV_H_ACTIVE);
    wire [10:0] h_front  = mode_x_360 ? (native_70hz ? 11'd24 : 11'd112)
                                       : (native_70hz ? NATIVE_H_FRONT : TV_H_FRONT);
    wire [10:0] h_sync   = native_70hz ? NATIVE_H_SYNC : TV_H_SYNC;
    wire [10:0] h_total  = native_70hz ? NATIVE_H_TOTAL : TV_H_TOTAL;
    wire [9:0]  v_active = mode_x_240 ? 10'd240
                                       : (native_70hz ? NATIVE_V_ACTIVE : TV_V_ACTIVE);
    // 240 direct lines leave only 22 raster lines blank in the 262-line 60 Hz
    // profile. This is deliberately exposed for hardware testing; an eight
    // line front porch still leaves CRT V offsets 0..7 safe from underflow.
    wire [9:0]  v_front  = mode_x_240 ? (native_70hz ? 10'd12 : 10'd8)
                                       : (native_70hz ? NATIVE_V_FRONT : TV_V_FRONT);
    wire [9:0]  v_sync   = mode_x_240 ? (native_70hz ? 10'd2 : 10'd3)
                                       : (native_70hz ? NATIVE_V_SYNC : TV_V_SYNC);
    wire [9:0]  v_total  = native_70hz ? NATIVE_V_TOTAL : TV_V_TOTAL;

    // CRT H/V offset (PCXT-EGA.sv OSD), matching how the EGA CRTC applies the
    // same two settings. There, a higher offset takes delay off HSYNC/VSYNC
    // (UM6845R.v hsync_delay_index / vsync_delay_index), which lengthens the
    // sync-to-picture gap that positions the image on a CRT - so a higher
    // offset moves the picture right and down. Shrinking the front porch moves
    // SYNC earlier here for the same effect, and in the same steps the EGA path
    // uses: 4 clocks (2 dots, its 640-wide hres_mode) and 1 line.
    //
    // The porches above are then biased 16 clocks right and 1 line up from
    // pure CGA geometry, measured on a 15 kHz TV, so that the OSD values which
    // centre the EGA path centre this one too and a single setting serves both.
    // H_TOTAL/V_TOTAL are untouched by the offsets, so the TV never loses lock
    // while adjusting.
    wire [10:0] eff_h_front = native_70hz ? h_front : h_front - {5'd0, crt_h_offset, 2'd0};
    wire [9:0]  eff_v_front = native_70hz ? v_front : v_front - {7'd0, crt_v_offset};

    reg [10:0] h_count = 11'd0;
    reg [9:0]  v_count = 10'd0;

    wire h_last = (h_count == h_total - 11'd1);
    wire v_last = (v_count == v_total - 10'd1);

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            h_count <= 11'd0;
            v_count <= 10'd0;
        end else if (!enable) begin
            h_count <= 11'd0;
            v_count <= 10'd0;
        end else if (h_last) begin
            h_count <= 11'd0;
            if (v_last)
                v_count <= 10'd0;
            else
                v_count <= v_count + 10'd1;
        end else begin
            h_count <= h_count + 11'd1;
        end
    end

    // Native doubles every source pixel; the 60 Hz profile quadruples it to
    // preserve its 640-pixel active width on the 15 kHz raster.
    assign pixel_x = native_70hz ? {1'b0, h_count[10:1]} : {1'b0, h_count[10:2]};
    assign pixel_y = v_count;
    assign active = enable && (h_count < h_active) && (v_count < v_active);
    assign hblank = !enable || (h_count >= h_active);
    assign vblank = !enable || (v_count >= v_active);
    assign hsync = enable &&
                   (h_count >= (h_active + eff_h_front)) &&
                   (h_count <  (h_active + eff_h_front + h_sync));
    assign vsync = enable &&
                   (v_count >= (v_active + eff_v_front)) &&
                   (v_count <  (v_active + eff_v_front + v_sync));
    assign line_start = enable && (h_count == 11'd0);
    assign frame_start = line_start && (v_count == 10'd0);

    // pixel_toggle flips once per physical output pixel. The native profile
    // has a 28.636 MHz pixel clock; the 60 Hz profile emits one pixel every
    // two clocks so its 1280 active clocks remain 640 output pixels.
    wire [10:0] out_pixel_x = native_70hz ? h_count : {1'b0, h_count[10:1]};

    reg [10:0] out_pixel_x_q = 11'd0;
    wire      pixel_tick = enable && (out_pixel_x != out_pixel_x_q);

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            out_pixel_x_q <= 10'd0;
            pixel_toggle  <= 1'b0;
        end else begin
            out_pixel_x_q <= out_pixel_x;
            if (pixel_tick)
                pixel_toggle <= ~pixel_toggle;
        end
    end

endmodule

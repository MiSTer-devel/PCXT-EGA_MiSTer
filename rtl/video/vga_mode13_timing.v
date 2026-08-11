//============================================================================
//
//  VGA mode 13h 320x200 timing, re-timed onto a 15 kHz CRT TV compatible
//  raster instead of the original free-running ~31.4 kHz mode 13h scan.
//
//  The geometry below is the CGA/EGA 200-line raster, dot for dot: 1824
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
    localparam [10:0] H_ACTIVE = 11'd1280;
    localparam [10:0] H_FRONT  = 11'd144;
    localparam [10:0] H_SYNC   = 11'd160;
    localparam [10:0] H_BACK   = 11'd240;
    localparam [10:0] H_TOTAL  = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;

    // CGA's 200-line field: 24 lines of front porch, a 16-line VSYNC and 22
    // lines of back porch around the 200 active lines, again with a 1-line
    // bias applied.
    localparam [9:0] V_ACTIVE = 10'd200;
    localparam [9:0] V_FRONT  = 10'd25;
    localparam [9:0] V_SYNC   = 10'd16;
    localparam [9:0] V_BACK   = 10'd21;
    localparam [9:0] V_TOTAL  = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;

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
    wire [10:0] eff_H_FRONT = H_FRONT - {5'd0, crt_h_offset, 2'd0};
    wire [9:0]  eff_V_FRONT = V_FRONT - {7'd0, crt_v_offset};

    reg [10:0] h_count = 11'd0;
    reg [9:0]  v_count = 10'd0;

    wire h_last = (h_count == H_TOTAL - 11'd1);
    wire v_last = (v_count == V_TOTAL - 10'd1);

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

    // Source pixel index: one framebuffer pixel per 4 clocks, so 0..319
    // across the active window.
    assign pixel_x = {1'b0, h_count[10:2]};
    assign pixel_y = v_count;
    assign active = enable && (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
    assign hblank = !enable || (h_count >= H_ACTIVE);
    assign vblank = !enable || (v_count >= V_ACTIVE);
    assign hsync = enable &&
                   (h_count >= (H_ACTIVE + eff_H_FRONT)) &&
                   (h_count <  (H_ACTIVE + eff_H_FRONT + H_SYNC));
    assign vsync = enable &&
                   (v_count >= (V_ACTIVE + eff_V_FRONT)) &&
                   (v_count <  (V_ACTIVE + eff_V_FRONT + V_SYNC));
    assign line_start = enable && (h_count == 11'd0);
    assign frame_start = line_start && (v_count == 10'd0);

    // pixel_toggle flips once per output pixel - every 2 clocks, so the 1280
    // active clocks measure as 640 pixels, matching what the framework reports
    // for the CGA/EGA modes rather than the 320 source pixels or the raw
    // dot-clock count. A level toggle, safe to cross a clock domain with a
    // single synchroniser stage and an XOR, unlike a one-cycle pulse.
    wire [9:0] out_pixel_x = h_count[10:1];

    reg [9:0] out_pixel_x_q = 10'd0;
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

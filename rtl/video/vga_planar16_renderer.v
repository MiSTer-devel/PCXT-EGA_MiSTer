//============================================================================
//
//  Bounded VGA 320x200x16 planar renderer
//
//  This is the VGA counterpart of the core's fixed Mode-X output profiles,
//  not a generic programmable VGA CRTC. It keeps the established Native/60Hz
//  rasters while honouring the three display controls used by scrolling VGA
//  mode 0Dh software: Start Address, Offset, Horizontal Pel Panning and
//  Line Compare split-screen restart.
//
//============================================================================

module vga_planar16_renderer(
    input  wire        clock,
    input  wire        reset,
    input  wire        enable,
    input  wire        native_70hz,
    input  wire [3:0]  crt_h_offset,
    input  wire [2:0]  crt_v_offset,
    input  wire [15:0] crtc_start_address,
    input  wire [7:0]  crtc_offset,
    input  wire [9:0]  crtc_line_compare,
    input  wire [3:0]  attr_pixel_pan,
    input  wire        split_panning_suppress,

    output wire [15:0] vram_addr,
    output wire        vram_read_en,
    input  wire [7:0]  vram_plane0,
    input  wire [7:0]  vram_plane1,
    input  wire [7:0]  vram_plane2,
    input  wire [7:0]  vram_plane3,
    input  wire        vram_data_valid,

    output wire [3:0]  plane_index,
    output wire        pixel_valid,
    output wire        de,
    output reg         hsync,
    output reg         vsync,
    output reg         hblank,
    output reg         vblank,
    output wire        pixel_toggle
);

    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire timing_active;
    wire timing_hblank;
    wire timing_vblank;
    wire timing_hsync;
    wire timing_vsync;

    reg [15:0] start_address_latched = 16'h0000;
    reg [2:0]  bit_select_q = 3'd7;
    reg        render_en_q = 1'b0;
    reg        timing_vsync_q = 1'b0;

    // In VGA byte mode the CRTC Offset is in words. Standard mode 0Dh uses
    // 20 (40 bytes); scrolling variants commonly use 21..23. Keep this
    // deliberately narrow and fall back to the BIOS stride outside it.
    wire offset_in_range = (crtc_offset >= 8'd20) &&
                           (crtc_offset <= 8'd23);
    wire [7:0] stride_bytes = offset_in_range ?
                              {crtc_offset[6:0], 1'b0} : 8'd40;

    // VGA Line Compare restarts the display address at zero on the following
    // physical scanline. The fixed 320x200 raster samples one line from each
    // doubled pair, hence the first lower output line is
    // ceil((LineCompare + 1) / 2). This is the split-screen arrangement used
    // by Viking Child: the scrolling playfield starts at 2000h while the
    // fixed control panel remains at address zero.
    wire split_active = (crtc_line_compare < 10'd400);
    wire [10:0] line_compare_plus_two = {1'b0, crtc_line_compare} + 11'd2;
    wire [9:0] split_start_y = line_compare_plus_two[10:1];
    wire below_split = split_active && (pixel_y >= split_start_y);
    wire [10:0] physical_y = {pixel_y, 1'b0};
    wire [10:0] split_physical_y = {1'b0, crtc_line_compare} + 11'd1;
    wire [10:0] source_physical_y = below_split ?
                                      (physical_y - split_physical_y) : physical_y;
    wire [9:0] source_y = source_physical_y[10:1];

    // Attribute Mode Control bit 5 resets pel panning below Line Compare.
    wire [2:0] pan_pixels = (below_split && split_panning_suppress) ? 3'd0 :
                                                                      attr_pixel_pan[2:0];
    wire [10:0] source_x = {1'b0, pixel_x} + {8'd0, pan_pixels};

    // The accepted strides are 40, 42, 44 and 46 bytes. Explicit shift/add
    // cases keep this small and prevent inference of a generic multiplier.
    reg [17:0] row_base;
    always @(*) begin
        case (stride_bytes)
            8'd40: row_base = ({8'b0, source_y} << 5) +
                               ({8'b0, source_y} << 3);
            8'd42: row_base = ({8'b0, source_y} << 5) +
                               ({8'b0, source_y} << 3) +
                               ({8'b0, source_y} << 1);
            8'd44: row_base = ({8'b0, source_y} << 5) +
                               ({8'b0, source_y} << 3) +
                               ({8'b0, source_y} << 2);
            default: row_base = ({8'b0, source_y} << 5) +
                                ({8'b0, source_y} << 3) +
                                ({8'b0, source_y} << 2) +
                                ({8'b0, source_y} << 1);
        endcase
    end

    wire [17:0] byte_offset = row_base + {10'b0, source_x[10:3]};
    wire [16:0] display_base = below_split ? 17'h00000 :
                                                {1'b0, start_address_latched};
    wire [16:0] plane_address = display_base +
                                {1'b0, byte_offset[15:0]};

    vga_mode13_timing timing (
        .clock          (clock),
        .reset          (reset),
        .enable         (enable),
        .native_70hz    (native_70hz),
        .mode_x_profile (2'd0),
        .crt_h_offset   (crt_h_offset),
        .crt_v_offset   (crt_v_offset),
        .pixel_x        (pixel_x),
        .pixel_y        (pixel_y),
        .active         (timing_active),
        .hblank         (timing_hblank),
        .vblank         (timing_vblank),
        .hsync          (timing_hsync),
        .vsync          (timing_vsync),
        .line_start     (),
        .frame_start    (),
        .pixel_toggle   (pixel_toggle)
    );

    assign vram_addr = plane_address[15:0];
    assign vram_read_en = timing_active;
    assign plane_index = vram_data_valid ?
                         {vram_plane3[bit_select_q],
                          vram_plane2[bit_select_q],
                          vram_plane1[bit_select_q],
                          vram_plane0[bit_select_q]} : 4'h0;
    assign pixel_valid = vram_data_valid & render_en_q;
    assign de = pixel_valid;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            start_address_latched <= 16'h0000;
            bit_select_q <= 3'd7;
            render_en_q <= 1'b0;
            timing_vsync_q <= 1'b0;
            hsync <= 1'b0;
            vsync <= 1'b0;
            hblank <= 1'b1;
            vblank <= 1'b1;
        end else begin
            if (timing_vsync && !timing_vsync_q)
                start_address_latched <= crtc_start_address;

            timing_vsync_q <= timing_vsync;
            bit_select_q <= 3'd7 - source_x[2:0];
            render_en_q <= vram_read_en;
            hsync <= timing_hsync;
            vsync <= timing_vsync;
            hblank <= timing_hblank;
            vblank <= timing_vblank;
        end
    end

endmodule

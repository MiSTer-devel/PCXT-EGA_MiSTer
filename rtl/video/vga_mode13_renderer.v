//============================================================================
//
//  VGA mode 13h packed-pixel renderer
//
//============================================================================

module vga_mode13_renderer(
    input  wire        clock,
    input  wire        reset,
    input  wire        enable,
    input  wire        native_70hz,
    input  wire [3:0]  crt_h_offset,
    input  wire [2:0]  crt_v_offset,

    output wire [15:0] framebuffer_addr,
    output wire        framebuffer_read_en,
    input  wire [7:0]  framebuffer_pixel,
    input  wire        framebuffer_data_valid,

    output wire [7:0]  dac_index,
    input  wire [5:0]  dac_red,
    input  wire [5:0]  dac_green,
    input  wire [5:0]  dac_blue,

    output wire [5:0]  red,
    output wire [5:0]  green,
    output wire [5:0]  blue,
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
    wire address_render_en;

    reg render_en_q = 1'b0;

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

    vga_mode13_address address (
        .pixel_x            (pixel_x),
        .pixel_y            (pixel_y),
        .framebuffer_addr   (framebuffer_addr),
        .render_en          (address_render_en)
    );

    assign framebuffer_read_en = timing_active & address_render_en;
    assign dac_index = framebuffer_data_valid ? framebuffer_pixel : 8'h00;
    assign de = framebuffer_data_valid & render_en_q;
    assign red = de ? dac_red : 6'h00;
    assign green = de ? dac_green : 6'h00;
    assign blue = de ? dac_blue : 6'h00;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            render_en_q <= 1'b0;
            hsync <= 1'b0;
            vsync <= 1'b0;
            hblank <= 1'b1;
            vblank <= 1'b1;
        end else begin
            render_en_q <= framebuffer_read_en;
            hsync <= timing_hsync;
            vsync <= timing_vsync;
            hblank <= timing_hblank;
            vblank <= timing_vblank;
        end
    end

endmodule

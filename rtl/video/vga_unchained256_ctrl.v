//============================================================================
//
//  VGA packed/unchained mode 13h route selection
//
//============================================================================

module vga_unchained256_ctrl(
    input  wire       mode13_active,
    input  wire       chain4,
    input  wire       shift256,
    input  wire       graphics_mode,
    input  wire [1:0] mem_map_sel,
    // CRTC values are only used to select the two deliberately supported
    // extensions. Anything else stays on the established 320x200 renderer.
    input  wire [7:0] crtc_h_displayed,
    input  wire [9:0] crtc_v_displayed,
    output wire       packed_active,
    output wire       unchained_active,
    output wire [1:0] unchained_profile
);

    // VGA permits the unchained planar layout through both A0000 apertures:
    // GC06 map 00 exposes the full A0000-BFFFF range and map 01 exposes the
    // usual A0000-AFFFF 64K window. Some software (including Little Engine)
    // deliberately selects map 00, so rejecting it falls back to the packed
    // framebuffer renderer and interprets four planes as one byte stream.
    wire a000_aperture = (mem_map_sel == 2'b00) ||
                         (mem_map_sel == 2'b01);
    assign unchained_active = mode13_active & ~chain4 & shift256 &
                              graphics_mode & a000_aperture;
    assign packed_active = mode13_active & ~unchained_active;

    // Standard Mode 13h uses 80 CRTC characters (R1 = 79). The common
    // 360x200 VGA variant uses 90 characters (CRTC R1 = 59h), while 320x240
    // raises the physical display end to 480 scanlines. R9 is deliberately
    // not part of profile selection: software may animate Maximum Scan Line
    // while retaining the same Mode-X memory layout. The renderer remains
    // profile-based rather than a generic VGA CRTC implementation.
    localparam [1:0] PROFILE_320X200 = 2'd0;
    localparam [1:0] PROFILE_360X200 = 2'd1;
    localparam [1:0] PROFILE_320X240 = 2'd2;

    wire crtc_80_columns = (crtc_h_displayed == 8'd79);
    wire mode_360x200 = (crtc_h_displayed == 8'd89) &
                        (crtc_v_displayed == 10'd400);
    wire mode_320x240 = crtc_80_columns & (crtc_v_displayed == 10'd480);

    assign unchained_profile = !unchained_active ? PROFILE_320X200 :
                               mode_360x200      ? PROFILE_360X200 :
                               mode_320x240      ? PROFILE_320X240 :
                                                  PROFILE_320X200;

endmodule

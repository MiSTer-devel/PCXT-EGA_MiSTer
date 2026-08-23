`timescale 1ns/1ps

module vga_unchained256_ctrl_tb;
    reg mode13_active = 1'b0;
    reg chain4 = 1'b1;
    reg shift256 = 1'b0;
    reg graphics_mode = 1'b0;
    reg [1:0] mem_map_sel = 2'b00;
    reg [7:0] crtc_h_displayed = 8'd79;
    reg [9:0] crtc_v_displayed = 10'd400;
    wire packed_active;
    wire unchained_active;
    wire [1:0] unchained_profile;
    integer errors = 0;

    vga_unchained256_ctrl dut (
        .mode13_active(mode13_active), .chain4(chain4),
        .shift256(shift256), .graphics_mode(graphics_mode),
        .mem_map_sel(mem_map_sel), .crtc_h_displayed(crtc_h_displayed),
        .crtc_v_displayed(crtc_v_displayed),
        .packed_active(packed_active),
        .unchained_active(unchained_active), .unchained_profile(unchained_profile)
    );

    task check;
        input expected_packed;
        input expected_unchained;
        input [1:0] expected_profile;
        input [127:0] tag;
        begin
            #1;
            if ((packed_active !== expected_packed) ||
                (unchained_active !== expected_unchained) ||
                (unchained_profile !== expected_profile)) begin
                errors = errors + 1;
                $display("FAIL: %0s packed=%b unchained=%b profile=%0d", tag,
                         packed_active, unchained_active, unchained_profile);
            end
        end
    endtask

    initial begin
        check(1'b0, 1'b0, 2'd0, "outside mode 13h");
        mode13_active = 1'b1;
        check(1'b1, 1'b0, 2'd0, "mode 13h defaults to packed");
        shift256 = 1'b1; graphics_mode = 1'b1; mem_map_sel = 2'b01;
        check(1'b1, 1'b0, 2'd0, "Chain-4 keeps packed route");
        chain4 = 1'b0;
        check(1'b0, 1'b1, 2'd0, "unchained 320x200 selects planar route");
        crtc_h_displayed = 8'd89;
        check(1'b0, 1'b1, 2'd1, "90-character CRTC selects 360x200");
        crtc_h_displayed = 8'd79; crtc_v_displayed = 10'd480;
        check(1'b0, 1'b1, 2'd2, "480 physical scanlines select 320x240");
        check(1'b0, 1'b1, 2'd2, "320x240 profile ignores maximum scanline changes");
        crtc_v_displayed = 10'd400;
        shift256 = 1'b0;
        check(1'b1, 1'b0, 2'd0, "Shift256 is required");
        shift256 = 1'b1; graphics_mode = 1'b0;
        check(1'b1, 1'b0, 2'd0, "graphics mode is required");
        graphics_mode = 1'b1; mem_map_sel = 2'b00;
        check(1'b0, 1'b1, 2'd0, "A000 128K map is also planar");
        mem_map_sel = 2'b10;
        check(1'b1, 1'b0, 2'd0, "B000 aperture is not Mode X");
        mode13_active = 1'b0; mem_map_sel = 2'b01;
        check(1'b0, 1'b0, 2'd0, "leaving mode 13h restores EGA route");

        if (errors == 0) $display("RESULT: PASS");
        else $display("RESULT: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule

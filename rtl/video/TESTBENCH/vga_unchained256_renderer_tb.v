`timescale 1ns/1ps

module vga_unchained256_renderer_tb;
    reg clock = 1'b0;
    always #5 clock = ~clock;

    reg reset = 1'b1;
    reg enable = 1'b1;
    reg [1:0] mode_x_profile = 2'd0;
    reg [15:0] crtc_start_address = 16'h0000;
    reg [7:0] crtc_offset = 8'd40;
    reg [9:0] crtc_line_compare = 10'h1FF;
    reg [4:0] crtc_max_scan = 5'd1;
    reg [3:0] attr_pixel_pan = 4'd0;
    reg split_panning_suppress = 1'b0;
    reg [7:0] plane0 = 8'h10;
    reg [7:0] plane1 = 8'h21;
    reg [7:0] plane2 = 8'h32;
    reg [7:0] plane3 = 8'h43;
    reg data_valid = 1'b1;
    wire [15:0] vram_addr;
    wire vram_read_en;
    wire [7:0] dac_index;
    integer errors = 0;
    integer maxscan_i;
    integer y_i;
    integer expected_row;

    vga_unchained256_renderer dut (
        .clock(clock), .reset(reset), .enable(enable), .native_70hz(1'b0),
        .mode_x_profile(mode_x_profile),
        .crt_h_offset(4'd0), .crt_v_offset(3'd0),
        .crtc_start_address(crtc_start_address),
        .crtc_offset(crtc_offset), .crtc_line_compare(crtc_line_compare),
        .crtc_max_scan(crtc_max_scan),
        .attr_pixel_pan(attr_pixel_pan), .split_panning_suppress(split_panning_suppress),
        .vram_addr(vram_addr), .vram_read_en(vram_read_en),
        .vram_plane0(plane0), .vram_plane1(plane1),
        .vram_plane2(plane2), .vram_plane3(plane3),
        .vram_data_valid(data_valid), .dac_index(dac_index),
        .dac_red(6'h00), .dac_green(6'h00), .dac_blue(6'h00),
        .red(), .green(), .blue(), .de(), .hsync(), .vsync(),
        .hblank(), .vblank(), .pixel_toggle()
    );

    task check_addr;
        input [9:0] x;
        input [9:0] y;
        input [15:0] expected;
        begin
            force dut.pixel_x = x;
            force dut.pixel_y = y;
            #1;
            if (vram_addr !== expected) begin
                errors = errors + 1;
                $display("FAIL: x=%0d y=%0d addr=%04h expected=%04h",
                         x, y, vram_addr, expected);
            end
        end
    endtask

    task check_plane;
        input [9:0] x;
        input [7:0] expected;
        begin
            force dut.pixel_x = x;
            @(posedge clock); #1;
            if (dac_index !== expected) begin
                errors = errors + 1;
                $display("FAIL: x=%0d index=%02h expected=%02h",
                         x, dac_index, expected);
            end
        end
    endtask

    initial begin
        repeat (2) @(posedge clock);
        reset = 1'b0;
        force dut.frame_start = 1'b0;
        force dut.timing_vsync = 1'b0;
        force dut.timing_active = 1'b1;

        check_addr(10'd0,   10'd0,   16'h0000);
        check_addr(10'd3,   10'd0,   16'h0000);
        check_addr(10'd4,   10'd0,   16'h0001);
        check_addr(10'd319, 10'd0,   16'h004F);
        check_addr(10'd0,   10'd1,   16'h0050);
        check_addr(10'd319, 10'd199, 16'h3E7F);

        mode_x_profile = 2'd1;
        crtc_offset = 8'd45;
        check_addr(10'd0,   10'd1,   16'h005A);
        check_addr(10'd359, 10'd199, 16'h464F);

        mode_x_profile = 2'd2;
        crtc_offset = 8'd40;
        check_addr(10'd319, 10'd239, 16'h4AFF);
        // Cute Demo's 336-pixel virtual map uses CRTC Offset 42 = 84 bytes.
        crtc_offset = 8'd42;
        check_addr(10'd319, 10'd239, 16'h4EBB);
        // Its 0,2,4,6 pel values map to 0,1,2,3 source pixels.
        attr_pixel_pan = 4'd6;
        check_addr(10'd1,   10'd0,   16'h0001);
        attr_pixel_pan = 4'd0;

        // Maximum Scan Line repeats source rows but keeps the 320x240 output
        // profile selected. R9=7 repeats one source row across four outputs.
        crtc_max_scan = 5'd7;
        check_addr(10'd0,   10'd4,   16'h0054);
        crtc_max_scan = 5'd1;

        // Exhaust the visible 320x240 range for every supported repeat value.
        // This also proves the shift/add reciprocal networks are bit-exact
        // replacements for division by 3, 5, 6 and 7.
        for (maxscan_i = 0; maxscan_i < 8; maxscan_i = maxscan_i + 1) begin
            crtc_max_scan = maxscan_i[4:0];
            for (y_i = 0; y_i < 240; y_i = y_i + 1) begin
                expected_row = ((2 * y_i) / (maxscan_i + 1)) * 84;
                check_addr(10'd0, y_i[9:0], expected_row[15:0]);
            end
        end
        crtc_max_scan = 5'd1;

        // Line Compare restarts the lower screen at address zero. A compare
        // at physical line 3 starts the reduced output's third line at zero.
        crtc_start_address = 16'h3E80;
        force dut.timing_vsync = 1'b1;
        @(posedge clock); #1;
        force dut.timing_vsync = 1'b0;
        @(posedge clock); #1;
        crtc_line_compare = 10'd3;
        check_addr(10'd0, 10'd1, 16'h3ED4);
        check_addr(10'd0, 10'd2, 16'h0000);
        attr_pixel_pan = 4'd6;
        split_panning_suppress = 1'b1;
        check_addr(10'd1, 10'd2, 16'h0000);
        split_panning_suppress = 1'b0;
        attr_pixel_pan = 4'd0;
        crtc_line_compare = 10'h1FF;
        crtc_start_address = 16'h0000;
        force dut.timing_vsync = 1'b1;
        @(posedge clock); #1;
        force dut.timing_vsync = 1'b0;
        @(posedge clock); #1;
        mode_x_profile = 2'd0;
        crtc_offset = 8'd40;

        check_plane(10'd0, plane0);
        check_plane(10'd1, plane1);
        check_plane(10'd2, plane2);
        check_plane(10'd3, plane3);

        // A write during the frame remains pending.
        crtc_start_address = 16'h3E80;
        check_addr(10'd0, 10'd1, 16'h0050);
        // The next vertical retrace changes the complete fetch base atomically.
        force dut.timing_vsync = 1'b1;
        @(posedge clock); #1;
        force dut.timing_vsync = 1'b0;
        @(posedge clock); #1;
        check_addr(10'd0,   10'd0,   16'h3E80);
        check_addr(10'd0,   10'd1,   16'h3ED0);
        check_addr(10'd319, 10'd199, 16'h7CFF);

        if (errors == 0) $display("RESULT: PASS");
        else $display("RESULT: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule

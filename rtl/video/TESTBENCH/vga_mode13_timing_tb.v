`timescale 1ns/1ps

module vga_mode13_timing_tb;
    reg clock = 1'b0;
    always #5 clock = ~clock;

    reg reset = 1'b1;
    reg enable = 1'b1;
    reg native_70hz = 1'b0;
    reg [1:0] mode_x_profile = 2'd0;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire active;
    wire hsync;
    wire vsync;
    integer errors = 0;

    vga_mode13_timing dut (
        .clock(clock), .reset(reset), .enable(enable),
        .native_70hz(native_70hz), .mode_x_profile(mode_x_profile),
        .crt_h_offset(4'd0), .crt_v_offset(3'd0),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .active(active),
        .hblank(), .vblank(), .hsync(hsync), .vsync(vsync),
        .line_start(), .frame_start(), .pixel_toggle()
    );

    task check;
        input condition;
        input [8*64-1:0] message;
        begin
            if (!condition) begin
                errors = errors + 1;
                $display("FAIL: %0s (h=%0d v=%0d)", message, dut.h_count, dut.v_count);
            end
        end
    endtask

    task reset_timing;
        input native;
        input [1:0] profile;
        begin
            native_70hz = native;
            mode_x_profile = profile;
            reset = 1'b1;
            repeat (2) @(posedge clock);
            reset = 1'b0;
        end
    endtask

    initial begin
        // Native is the historical 912x449 raster: 28.636 MHz / 912 / 449.
        reset_timing(1'b1, 2'd0);
        // The reset release shares a clock edge with this initial block, so
        // the first counted generator edge follows it by one simulation tick.
        repeat (911) @(posedge clock);
        #1 check((dut.h_count == 0) && (dut.v_count == 1),
                  "native line total must be 912 clocks");
        repeat (912 * 448) @(posedge clock);
        #1 check((dut.h_count == 0) && (dut.v_count == 0),
                  "native frame total must be 912 x 449 clocks");

        force dut.h_count = 11'd638; force dut.v_count = 10'd0; #1;
        check(active && (pixel_x == 10'd319), "native active width must be 640 pixels");
        force dut.h_count = 11'd640; #1;
        check(!active, "native active area must end at clock 640");
        force dut.h_count = 11'd664; #1;
        check(hsync, "native HSYNC must start at clock 664");
        force dut.h_count = 11'd760; #1;
        check(!hsync, "native HSYNC must be 96 clocks wide");
        force dut.v_count = 10'd212; #1;
        check(vsync, "native VSYNC must start at line 212");
        force dut.v_count = 10'd214; #1;
        check(!vsync, "native VSYNC must be 2 lines wide");
        release dut.h_count; release dut.v_count;

        // 60 Hz retains the existing TV-compatible 1824x262 raster.
        reset_timing(1'b0, 2'd0);
        repeat (1823) @(posedge clock);
        #1 check((dut.h_count == 0) && (dut.v_count == 1),
                  "60Hz line total must be 1824 clocks");
        repeat (1824 * 261) @(posedge clock);
        #1 check((dut.h_count == 0) && (dut.v_count == 0),
                  "60Hz frame total must be 1824 x 262 clocks");

        // 360x200 keeps both 60 Hz totals while widening the source and the
        // visible output to 360 and 720 pixels respectively.
        reset_timing(1'b0, 2'd1);
        force dut.h_count = 11'd1438; force dut.v_count = 10'd0; #1;
        check(active && (pixel_x == 10'd359), "360x200 active width must be 360 source pixels");
        force dut.h_count = 11'd1440; #1;
        check(!active, "360x200 active area must end at clock 1440");
        release dut.h_count; release dut.v_count;

        // 320x240 intentionally uses the direct 262-line 15 kHz raster so
        // it can be tested on televisions without a capture/scaler path.
        reset_timing(1'b0, 2'd2);
        force dut.h_count = 11'd1278; force dut.v_count = 10'd239; #1;
        check(active && (pixel_x == 10'd319) && (pixel_y == 10'd239),
              "320x240 must include source pixel 319,239");
        force dut.v_count = 10'd240; #1;
        check(!active, "320x240 active area must end at line 240");
        force dut.v_count = 10'd248; #1;
        check(vsync, "320x240 60Hz VSYNC must start at line 248");
        force dut.v_count = 10'd251; #1;
        check(!vsync, "320x240 60Hz VSYNC must be 3 lines wide");
        release dut.h_count; release dut.v_count;

        if (errors == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule

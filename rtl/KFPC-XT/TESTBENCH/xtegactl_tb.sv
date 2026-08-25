//============================================================================
//
//  XTEGACTL port block regression.
//
//  Two properties matter.  The block must sit clear of the on-board chip
//  select decoder, which ignores address[15:10] and would otherwise let a
//  write here reach the DMA page registers.  And every field must treat zero
//  as "leave it to the OSD", so that the power-on state is plain OSD
//  behaviour and one program's leftovers cannot capture an unrelated option.
//
//    iverilog -g2012 -o xtegactl_tb TESTBENCH/xtegactl_tb.sv HDL/xtegactl.sv
//    vvp xtegactl_tb
//
//============================================================================

`timescale 1ns/1ps

module xtegactl_tb;

    logic clock = 1'b0;
    logic reset = 1'b1;
    always #5 clock = ~clock;

    logic [15:0] address          = 16'h0000;
    logic        address_enable_n = 1'b0;
    logic        io_read_n        = 1'b1;
    logic        io_write_n       = 1'b1;
    logic  [7:0] data_in          = 8'h00;
    wire   [7:0] data_out;
    wire         output_enable;

    // A deliberately non-default OSD, so "deferred to the OSD" cannot pass by
    // accidentally matching a zero.
    logic [1:0] osd_speed        = 2'd2;    // 9.54 MHz
    logic       osd_fake286      = 1'b1;
    logic [1:0] osd_opl2         = 2'd1;    // SB FM
    logic       osd_cms          = 1'b1;
    logic       osd_ems          = 1'b1;
    logic       osd_umb          = 1'b1;
    logic       osd_vga13        = 1'b1;
    logic       osd_joy1_digital = 1'b1;
    logic       osd_joy1_disable = 1'b0;
    logic       osd_joy2_digital = 1'b0;
    logic       osd_joy2_disable = 1'b1;
    logic       osd_joy_sync     = 1'b1;
    logic       osd_joy_swap     = 1'b1;
    logic       osd_mt32_gm      = 1'b1;

    wire [1:0] eff_speed;
    wire       eff_fake286;
    wire [1:0] eff_opl2;
    wire       eff_cms, eff_ems, eff_umb, eff_vga13;
    wire       eff_joy1_digital, eff_joy1_disable;
    wire       eff_joy2_digital, eff_joy2_disable;
    wire       eff_joy_sync, eff_joy_swap, eff_mt32_gm;

    wire [7:0] reg_cpu, reg_exp, reg_vid, reg_inp, reg_midi;

    xtegactl dut (
        .clock(clock), .reset(reset),
        .address(address), .address_enable_n(address_enable_n),
        .io_read_n(io_read_n), .io_write_n(io_write_n),
        .data_in(data_in), .data_out(data_out), .output_enable(output_enable),
        .reg_cpu(reg_cpu), .reg_exp(reg_exp), .reg_vid(reg_vid),
        .reg_inp(reg_inp), .reg_midi(reg_midi)
    );

    xtegactl_resolve res (
        .reg_cpu(reg_cpu), .reg_exp(reg_exp), .reg_vid(reg_vid),
        .reg_inp(reg_inp), .reg_midi(reg_midi),
        .osd_speed(osd_speed), .osd_fake286(osd_fake286), .osd_opl2(osd_opl2),
        .osd_cms(osd_cms), .osd_ems(osd_ems), .osd_umb(osd_umb),
        .osd_vga13(osd_vga13),
        .osd_joy1_digital(osd_joy1_digital), .osd_joy1_disable(osd_joy1_disable),
        .osd_joy2_digital(osd_joy2_digital), .osd_joy2_disable(osd_joy2_disable),
        .osd_joy_sync(osd_joy_sync), .osd_joy_swap(osd_joy_swap),
        .osd_mt32_gm(osd_mt32_gm),
        .eff_speed(eff_speed), .eff_fake286(eff_fake286), .eff_opl2(eff_opl2),
        .eff_cms(eff_cms), .eff_ems(eff_ems), .eff_umb(eff_umb),
        .eff_vga13(eff_vga13),
        .eff_joy1_digital(eff_joy1_digital), .eff_joy1_disable(eff_joy1_disable),
        .eff_joy2_digital(eff_joy2_digital), .eff_joy2_disable(eff_joy2_disable),
        .eff_joy_sync(eff_joy_sync), .eff_joy_swap(eff_joy_swap),
        .eff_mt32_gm(eff_mt32_gm)
    );

    integer errors = 0;

    task automatic fail(input string tag);
        begin
            errors = errors + 1;
            $display("FAIL: %s", tag);
        end
    endtask

    task automatic chk(input string tag, input logic got, input logic exp);
        begin
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL: %s got=%0b expected=%0b", tag, got, exp);
            end
        end
    endtask

    task automatic chk2(input string tag, input logic [1:0] got, input logic [1:0] exp);
        begin
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL: %s got=%0d expected=%0d", tag, got, exp);
            end
        end
    endtask

    task automatic io_write(input [15:0] port, input [7:0] value);
        begin
            @(negedge clock);
            address = port; data_in = value; io_write_n = 1'b0;
            @(posedge clock);
            @(negedge clock);
            io_write_n = 1'b1;
        end
    endtask

    task automatic io_read(input [15:0] port, output [7:0] value);
        begin
            @(negedge clock);
            address = port; io_read_n = 1'b0;
            #1 value = data_out;
            if (!output_enable) fail("read did not drive the bus");
            @(negedge clock);
            io_read_n = 1'b1;
        end
    endtask

    logic [7:0] rd;

    initial begin
        repeat (2) @(posedge clock);
        reset = 1'b0;
        repeat (2) @(posedge clock);

        // ---- everything defers to the OSD out of reset --------------------
        chk2("speed defers",      eff_speed,        2'd2);
        chk ("fake286 defers",    eff_fake286,      1'b1);
        chk2("opl2 defers",       eff_opl2,         2'd1);
        chk ("cms defers",        eff_cms,          1'b1);
        chk ("ems defers",        eff_ems,          1'b1);
        chk ("umb defers",        eff_umb,          1'b1);
        chk ("vga13 defers",      eff_vga13,        1'b1);
        chk ("joy1 type defers",  eff_joy1_digital, 1'b1);
        chk ("joy2 dis defers",   eff_joy2_disable, 1'b1);
        chk ("joy sync defers",   eff_joy_sync,     1'b1);
        chk ("joy swap defers",   eff_joy_swap,     1'b1);
        chk ("mt32 defers",       eff_mt32_gm,      1'b1);

        // ---- signature ----------------------------------------------------
        io_read(16'h8980, rd);
        if (rd !== 8'h45) fail($sformatf("signature read %02h expected 45", rd));

        // The signature is read only.
        io_write(16'h8980, 8'hFF);
        io_read(16'h8980, rd);
        if (rd !== 8'h45) fail("signature accepted a write");

        // ---- speed ---------------------------------------------------------
        io_write(16'h8981, 8'h01); chk2("speed 1 selects 4.77", eff_speed, 2'd0);
        io_write(16'h8981, 8'h02); chk2("speed 2 selects 7.16", eff_speed, 2'd1);
        io_write(16'h8981, 8'h03); chk2("speed 3 selects 9.54", eff_speed, 2'd2);
        io_write(16'h8981, 8'h04); chk2("speed 4 selects Max",  eff_speed, 2'd3);
        // Out of range is not a speed, so it must fall back rather than alias.
        io_write(16'h8981, 8'h05); chk2("speed 5 falls back to the OSD", eff_speed, 2'd2);
        io_write(16'h8981, 8'h07); chk2("speed 7 falls back to the OSD", eff_speed, 2'd2);
        io_write(16'h8981, 8'h00); chk2("speed 0 defers again", eff_speed, 2'd2);

        // ---- fake 286, in the same register --------------------------------
        io_write(16'h8981, 8'h08); chk("fake286 1 forces off", eff_fake286, 1'b0);
        io_write(16'h8981, 8'h10); chk("fake286 2 forces on",  eff_fake286, 1'b1);
        osd_fake286 = 1'b0;
        io_write(16'h8981, 8'h10); chk("fake286 2 forces on over a clear OSD", eff_fake286, 1'b1);
        io_write(16'h8981, 8'h00); chk("fake286 defers again", eff_fake286, 1'b0);
        osd_fake286 = 1'b1;

        // Speed and fake 286 share a register and must not disturb each other.
        io_write(16'h8981, 8'h0A);      // speed=2, fake286=1 (off)
        chk2("speed survives a neighbouring field", eff_speed, 2'd1);
        chk ("fake286 survives a neighbouring field", eff_fake286, 1'b0);
        io_write(16'h8981, 8'h00);

        // ---- expansion ------------------------------------------------------
        io_write(16'h8982, 8'h01); chk2("opl2 1 selects Adlib", eff_opl2, 2'd0);
        io_write(16'h8982, 8'h02); chk2("opl2 2 selects SB FM", eff_opl2, 2'd1);
        io_write(16'h8982, 8'h03); chk2("opl2 3 disables",      eff_opl2, 2'd2);

        io_write(16'h8982, 8'h04); chk("cms 1 enables",  eff_cms, 1'b1);
        io_write(16'h8982, 8'h08); chk("cms 2 disables", eff_cms, 1'b0);
        io_write(16'h8982, 8'h10); chk("ems 1 enables",  eff_ems, 1'b1);
        io_write(16'h8982, 8'h20); chk("ems 2 disables", eff_ems, 1'b0);
        io_write(16'h8982, 8'h40); chk("umb 1 enables",  eff_umb, 1'b1);
        io_write(16'h8982, 8'h80); chk("umb 2 disables", eff_umb, 1'b0);

        // All four at once, each a different choice.
        io_write(16'h8982, 8'hA7);      // umb=2 ems=2 cms=1 opl2=3
        chk2("opl2 in a full register", eff_opl2, 2'd2);
        chk ("cms in a full register",  eff_cms,  1'b1);
        chk ("ems in a full register",  eff_ems,  1'b0);
        chk ("umb in a full register",  eff_umb,  1'b0);
        io_write(16'h8982, 8'h00);
        chk("cms defers again", eff_cms, 1'b1);

        // ---- video -----------------------------------------------------------
        io_write(16'h8983, 8'h01); chk("vga13 1 forces off", eff_vga13, 1'b0);
        io_write(16'h8983, 8'h02); chk("vga13 2 forces on",  eff_vga13, 1'b1);
        osd_vga13 = 1'b0;
        io_write(16'h8983, 8'h02); chk("vga13 2 forces on over a clear OSD", eff_vga13, 1'b1);
        io_write(16'h8983, 8'h00); chk("vga13 defers again", eff_vga13, 1'b0);
        osd_vga13 = 1'b1;

        // ---- input ------------------------------------------------------------
        io_write(16'h8984, 8'h01);
        chk("joy1 analog clears digital", eff_joy1_digital, 1'b0);
        chk("joy1 analog clears disable", eff_joy1_disable, 1'b0);
        io_write(16'h8984, 8'h02);
        chk("joy1 digital sets digital",  eff_joy1_digital, 1'b1);
        chk("joy1 digital clears disable", eff_joy1_disable, 1'b0);
        io_write(16'h8984, 8'h03);
        chk("joy1 disabled sets disable", eff_joy1_disable, 1'b1);

        io_write(16'h8984, 8'h0C);      // joy2 = 3, disabled
        chk("joy2 disabled sets disable", eff_joy2_disable, 1'b1);
        chk("joy1 defers while joy2 is set", eff_joy1_digital, 1'b1);

        io_write(16'h8984, 8'h10); chk("swap 1 is normal",   eff_joy_swap, 1'b0);
        io_write(16'h8984, 8'h20); chk("swap 2 swaps",       eff_joy_swap, 1'b1);
        io_write(16'h8984, 8'h40); chk("joy sync 1 is off",  eff_joy_sync, 1'b0);
        io_write(16'h8984, 8'h80); chk("joy sync 2 is on",   eff_joy_sync, 1'b1);
        io_write(16'h8984, 8'h00);

        // ---- MIDI --------------------------------------------------------------
        io_write(16'h8985, 8'h01); chk("mt32 1 selects MT-32",       eff_mt32_gm, 1'b0);
        io_write(16'h8985, 8'h02); chk("mt32 2 selects General MIDI", eff_mt32_gm, 1'b1);
        io_write(16'h8985, 8'h00); chk("mt32 defers again",          eff_mt32_gm, 1'b1);

        // ---- readback ------------------------------------------------------------
        io_write(16'h8981, 8'h12);
        io_read (16'h8981, rd);
        if (rd !== 8'h12) fail($sformatf("cpu register read %02h expected 12", rd));
        io_write(16'h8984, 8'h5A);
        io_read (16'h8984, rd);
        if (rd !== 8'h5A) fail($sformatf("input register read %02h expected 5A", rd));

        // ---- reserved ports --------------------------------------------------------
        io_write(16'h8986, 8'hFF);
        io_read (16'h8986, rd);
        if (rd !== 8'h00) fail($sformatf("reserved port read %02h expected 00", rd));
        io_read (16'h898F, rd);
        if (rd !== 8'h00) fail($sformatf("reserved port 898F read %02h expected 00", rd));

        // ---- the block keeps to itself ------------------------------------------------
        // 8888h is the retired port, and any of its neighbours would land on the
        // on-board decoder.  Nothing here may answer for them.
        @(negedge clock);
        address = 16'h8888; io_read_n = 1'b0;
        #1 if (output_enable) fail("answered for the retired 8888h port");
        io_read_n = 1'b1;

        @(negedge clock);
        address = 16'h8990; io_read_n = 1'b0;
        #1 if (output_enable) fail("answered past the end of the block");
        io_read_n = 1'b1;

        // A write must not be taken while the DMA controller owns the bus.
        @(negedge clock);
        address_enable_n = 1'b1;
        io_write(16'h8983, 8'h01);
        address_enable_n = 1'b0;
        chk("ignored a write made during a DMA cycle", eff_vga13, 1'b1);

        // ---- reset returns everything to the OSD -----------------------------------------
        io_write(16'h8982, 8'hAA);
        reset = 1'b1;
        repeat (2) @(posedge clock);
        reset = 1'b0;
        chk("reset returns cms to the OSD", eff_cms, 1'b1);
        chk("reset returns umb to the OSD", eff_umb, 1'b1);
        io_read(16'h8982, rd);
        if (rd !== 8'h00) fail($sformatf("expansion register survived reset as %02h", rd));

        if (errors == 0)
            $display("RESULT: PASS (XTEGACTL decodes clear of the on-board block and defers on zero)");
        else
            $display("RESULT: FAIL (%0d checks)", errors);
        $finish;
    end

endmodule

//============================================================================
//
//  The sequential read lookahead must be a cache that is never wrong.
//
//  RAM.sv now reads two words per SDRAM transaction and parks the second one,
//  so the next sequential byte can be answered without an ACTIVE/PRECHARGE pair.
//  That is the only reason it exists: on an 8-bit bus with a four-byte prefetch
//  queue, roughly half of all bus traffic is sequential instruction fetch.
//
//  A cache that is merely fast is worthless here. The failure this bench exists
//  to catch is a stale byte: the CPU asks for an address, the latch answers with
//  what used to be there, and the machine executes or loads the wrong value with
//  no bus cycle to show for it. Two properties therefore have to hold together,
//  and neither one alone is the test:
//
//    * every read returns what memory holds at that address, and
//    * a hit issues no SDRAM READ command at all.
//
//  Checking only the first would pass a lookahead that never hits. Checking only
//  the second would pass one that hits with garbage. Every case below asserts
//  both, by counting SDRAM READ commands across the access.
//
//  The SDRAM model is behavioural but it is not a stub: it samples commands off
//  the real pins, honours CAS latency 2, and serves the column that KFSDRAM
//  actually drove. That matters for the wrap case - KFSDRAM's burst counter is
//  `address[8:0] + access_counter`, nine bits, so a burst starting at column 511
//  wraps to column 0 of the SAME row instead of advancing to the next row. The
//  word it brings back is not address+1, and if the RTL parked it under that
//  name every read at a 512-byte boundary would be answered with a byte from
//  512 bytes below.
//
//  Refresh is left running throughout rather than avoided. A refresh can land in
//  the middle of a burst, and the latch has to survive it - refresh changes no
//  data, so a lookahead invalidated by refresh would merely be slow, but a burst
//  cut short by one would be wrong.
//
//============================================================================

`timescale 1ns / 1ps

module ram_lookahead_tb;

    logic clock = 1'b0;
    logic reset = 1'b1;
    always #10 clock = ~clock;          // 50 MHz, matching clk_chipset

    logic [19:0] address          = 20'h00000;
    logic [7:0]  data_in          = 8'h00;
    logic        memory_read_n    = 1'b1;
    logic        memory_write_n   = 1'b1;
    logic        no_command_state = 1'b1;

    wire [7:0]  data_out;
    wire        memory_access_ready;
    wire        ram_address_select_n;
    wire        initilized_sdram;
    wire [12:0] sdram_address;
    wire        sdram_cke, sdram_cs, sdram_ras, sdram_cas, sdram_we;
    wire [1:0]  sdram_ba;
    wire [15:0] sdram_dq_out;
    wire        sdram_dq_io, sdram_ldqm, sdram_udqm;

    logic [15:0] sdram_dq_in;
    logic [6:0]  map_ems [0:3];

    RAM dut (
        .clock                 (clock),
        .reset                 (reset),
        .enable_sdram          (1'b1),
        .initilized_sdram      (initilized_sdram),
        .address               (address),
        .internal_data_bus     (data_in),
        .data_bus_out          (data_out),
        .memory_read_n         (memory_read_n),
        .memory_write_n        (memory_write_n),
        .no_command_state      (no_command_state),
        .memory_access_ready   (memory_access_ready),
        .ram_address_select_n  (ram_address_select_n),
        .sdram_address         (sdram_address),
        .sdram_cke             (sdram_cke),
        .sdram_cs              (sdram_cs),
        .sdram_ras             (sdram_ras),
        .sdram_cas             (sdram_cas),
        .sdram_we              (sdram_we),
        .sdram_ba              (sdram_ba),
        .sdram_dq_in           (sdram_dq_in),
        .sdram_dq_out          (sdram_dq_out),
        .sdram_dq_io           (sdram_dq_io),
        .sdram_ldqm            (sdram_ldqm),
        .sdram_udqm            (sdram_udqm),
        .map_ems               (map_ems),
        .ems_b1                (1'b0),
        .ems_b2                (1'b0),
        .ems_b3                (1'b0),
        .ems_b4                (1'b0),
        .umb_enabled           (1'b1),
        .bios_protect_flag     (3'b000),
        .wait_count_clk_en     (1'b1),
        .clk_select            (clk_select),
        .ram_read_wait_cycle   (2'd0),
        .ram_write_wait_cycle  (2'd0)
    );

    //------------------------------------------------------------------------
    // Behavioural SDRAM
    //------------------------------------------------------------------------
    // Word-addressed exactly the way RAM.sv drives it: column = addr[8:0], row
    // = addr[21:9], bank = addr[23:22] and always 0. The test window is 8 KB so
    // a dense array is enough, and it spans the 512-word column boundary the
    // wrap case needs.
    localparam integer MEM_WORDS = 8192;
    logic [15:0] mem [0:MEM_WORDS-1];

    logic [12:0] act_row  = 13'd0;
    logic [1:0]  act_bank = 2'd0;

    // Command decode off the real pins.
    wire cmd_active = ~sdram_cs & ~sdram_ras &  sdram_cas &  sdram_we;
    wire cmd_read   = ~sdram_cs &  sdram_ras & ~sdram_cas &  sdram_we;
    wire cmd_write  = ~sdram_cs &  sdram_ras & ~sdram_cas & ~sdram_we;

    integer sdram_reads     = 0;
    integer sdram_writes    = 0;
    // ACTIVE is one per transaction, and the transaction is what the change
    // removes. Two bytes in a burst still cost two column commands; what they
    // no longer cost is a second ACTIVE and a second PRECHARGE, which is where
    // the 7-clocks-per-byte went. Counting column commands instead would say
    // nothing had improved, because in that unit nothing has.
    integer sdram_activates = 0;

    logic [15:0] rdata_d1 = 16'h0000;
    logic [15:0] rdata_d2 = 16'h0000;

    wire [23:0] cmd_full_address = {act_bank, act_row, sdram_address[8:0]};

    always @(posedge clock) begin
        if (cmd_active) begin
            act_row         <= sdram_address;
            act_bank        <= sdram_ba;
            sdram_activates <= sdram_activates + 1;
        end

        // CAS latency 2: the command is sampled on this edge and the data has
        // to be on the bus to be sampled two edges later, so it goes through
        // two register stages before reaching sdram_dq_in.
        if (cmd_read) begin
            rdata_d1    <= mem[cmd_full_address[12:0]];
            sdram_reads <= sdram_reads + 1;
        end
        rdata_d2 <= rdata_d1;

        if (cmd_write && !sdram_ldqm) begin
            mem[cmd_full_address[12:0]][7:0] <= sdram_dq_out[7:0];
            sdram_writes <= sdram_writes + 1;
        end
    end

    assign sdram_dq_in = rdata_d2;

    //------------------------------------------------------------------------
    // Scoreboard
    //------------------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    // What memory should hold at a byte address, independent of the DUT.
    function automatic [7:0] expected_byte(input [19:0] a);
        expected_byte = a[7:0] ^ {3'b000, a[12:8]} ^ 8'h5A;
    endfunction

    task automatic fail_msg(input string message);
        begin
            fail_count = fail_count + 1;
            $display("  FAIL  %s", message);
        end
    endtask

    //------------------------------------------------------------------------
    // Bus cycles
    //------------------------------------------------------------------------
    integer reads_before;
    logic [7:0] captured;

    // Drive MEMR until RAM reports the access complete, capturing the byte the
    // instant readiness is asserted - which is where a real bus cycle takes it.
    task automatic read_held(input logic [19:0] a);
        integer guard;
        begin
            reads_before = sdram_reads;
            @(negedge clock);
            address          = a;
            no_command_state = 1'b0;
            memory_read_n    = 1'b0;

            guard = 0;
            while (memory_access_ready && (guard < 2000)) begin
                @(posedge clock); #1; guard = guard + 1;
            end
            guard = 0;
            while (!memory_access_ready && (guard < 2000)) begin
                @(posedge clock); #1; guard = guard + 1;
            end
            if (!memory_access_ready)
                fail_msg("read never completed");

            captured = data_out;

            @(negedge clock);
            memory_read_n    = 1'b1;
            no_command_state = 1'b1;
            @(negedge clock);
        end
    endtask

    task automatic write_held(input logic [19:0] a, input logic [7:0] d);
        integer guard;
        begin
            @(negedge clock);
            address          = a;
            data_in          = d;
            no_command_state = 1'b0;
            memory_write_n   = 1'b0;

            guard = 0;
            while (memory_access_ready && (guard < 2000)) begin
                @(posedge clock); #1; guard = guard + 1;
            end
            guard = 0;
            while (!memory_access_ready && (guard < 2000)) begin
                @(posedge clock); #1; guard = guard + 1;
            end

            @(negedge clock);
            memory_write_n   = 1'b1;
            no_command_state = 1'b1;
            @(negedge clock);
        end
    endtask

    // The two properties, always asserted together.
    //   want_hit = 1 : must be answered from the latch, no SDRAM READ at all
    //   want_hit = 0 : must go to the SDRAM
    task automatic check_read(input logic [19:0] a,
                              input logic [7:0]  expect_data,
                              input bit          want_hit,
                              input string       label);
        integer issued;
        begin
            read_held(a);
            issued = sdram_reads - reads_before;

            if (captured !== expect_data)
                fail_msg($sformatf("%s: addr %05h returned %02h, memory holds %02h",
                                   label, a, captured, expect_data));
            else if (want_hit && (issued != 0))
                fail_msg($sformatf("%s: addr %05h was correct but issued %0d SDRAM reads - not a hit",
                                   label, a, issued));
            else if (!want_hit && (issued == 0))
                fail_msg($sformatf("%s: addr %05h answered from the latch when it must not be",
                                   label, a));
            else begin
                pass_count = pass_count + 1;
                $display("  PASS  %-34s addr %05h -> %02h  (%0d SDRAM reads)",
                         label, a, captured, issued);
            end
        end
    endtask

    task automatic wait_idle;
        integer guard;
        begin
            guard = 0;
            while (((dut.state !== 3'd0) || !dut.idle) && (guard < 2000)) begin
                @(posedge clock); #1; guard = guard + 1;
            end
        end
    endtask

    //------------------------------------------------------------------------
    integer i;
    integer sweep_reads;
    integer sweep_bytes;
    integer slow_reads;
    logic [1:0] clk_select = 2'b11;

    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1)
            mem[i] = {~(i[7:0] ^ {3'b000, i[12:8]} ^ 8'h5A),
                        i[7:0] ^ {3'b000, i[12:8]} ^ 8'h5A};

        map_ems[0] = 7'd0; map_ems[1] = 7'd0;
        map_ems[2] = 7'd0; map_ems[3] = 7'd0;

        $display("");
        $display("=== the sequential read lookahead must never be wrong ===");
        $display("");

        repeat (5) @(posedge clock);
        reset = 1'b0;
        repeat (10100) @(posedge clock);     // KFSDRAM power-up wait
        wait_idle;

        // ---- the basic pair ------------------------------------------------
        check_read(20'h00100, expected_byte(20'h00100), 1'b0, "cold read");
        check_read(20'h00101, expected_byte(20'h00101), 1'b1, "next byte, from the latch");

        // ---- a hit does not consume the entry ------------------------------
        check_read(20'h00101, expected_byte(20'h00101), 1'b1, "same byte again");

        // ---- non-sequential goes back to memory ----------------------------
        check_read(20'h00400, expected_byte(20'h00400), 1'b0, "jump away");
        check_read(20'h00401, expected_byte(20'h00401), 1'b1, "and stream again");

        // ---- a write to the parked byte must invalidate it -----------------
        check_read(20'h00500, expected_byte(20'h00500), 1'b0, "arm at 00501");
        write_held(20'h00501, 8'hC7);
        mem[13'h0501][7:0] = 8'hC7;          // keep the model in step
        check_read(20'h00501, 8'hC7, 1'b0, "written byte, latch dropped");

        // ---- a write elsewhere must NOT invalidate it ----------------------
        check_read(20'h00600, expected_byte(20'h00600), 1'b0, "arm at 00601");
        write_held(20'h00ABC, 8'h3E);
        mem[13'h0ABC][7:0] = 8'h3E;
        check_read(20'h00601, expected_byte(20'h00601), 1'b1, "unrelated write, still a hit");

        // ---- the column wrap ------------------------------------------------
        // 0001FF is column 511. KFSDRAM's burst counter would fetch column 0 of
        // the same row, which is 000000 and not 000200, so the lookahead has to
        // stand down here.
        check_read(20'h001FF, expected_byte(20'h001FF), 1'b0, "read at column 511");
        check_read(20'h00200, expected_byte(20'h00200), 1'b0, "across the row, not from latch");
        check_read(20'h00201, expected_byte(20'h00201), 1'b1, "streaming resumes after it");

        // ---- two streams at once, which one entry cannot do -----------------
        // Every read that is allowed to park overwrites an entry, and an
        // instruction fetch is a memory read like any other. With one entry the
        // byte parked by a data read is gone before the next data read asks for
        // it, because the BIU refilled its queue in between - so the latch did
        // nothing at all in code that interleaves fetch with data, which is most
        // code.
        //
        // Hardware measurement showed exactly that: a loop over strided
        // addresses and a loop over sequential ones came back identical at
        // every speed, including the two where this is switched on. Both were
        // missing every time.
        //
        // The four checks below are the regression for the fix. On a
        // single-entry latch the two "survives" cases fail, because opening the
        // second stream destroys the first.
        wait_idle;
        check_read(20'h00800, expected_byte(20'h00800), 1'b0, "stream A opens");
        check_read(20'h00900, expected_byte(20'h00900), 1'b0, "stream B opens");
        check_read(20'h00801, expected_byte(20'h00801), 1'b1, "A survives B");
        check_read(20'h00901, expected_byte(20'h00901), 1'b1, "B survives A");

        // Two entries, and exactly two. A third and a fourth stream have to
        // push the first two out, or this is a cache and needs a cache's
        // invalidation argument rather than this one's.
        check_read(20'h00A00, expected_byte(20'h00A00), 1'b0, "stream C opens");
        check_read(20'h00B00, expected_byte(20'h00B00), 1'b0, "stream D opens");
        check_read(20'h00801, expected_byte(20'h00801), 1'b0, "two entries, not four");

        // A write still clears whichever entry it lands on, whichever that is.
        check_read(20'h00C00, expected_byte(20'h00C00), 1'b0, "arm at 00C01");
        write_held(20'h00C01, 8'h9E);
        mem[13'h0C01][7:0] = 8'h9E;
        check_read(20'h00C01, 8'h9E, 1'b0, "written byte, entry dropped");

        // ---- what the whole thing is for ------------------------------------
        // A sequential run must cost about one SDRAM read per two bytes. This is
        // the only case that measures the benefit rather than the correctness,
        // and it is still a correctness check on every byte.
        wait_idle;
        sweep_reads = sdram_activates;
        sweep_bytes = 0;
        for (i = 20'h01000; i < 20'h01040; i = i + 1) begin
            read_held(i[19:0]);
            sweep_bytes = sweep_bytes + 1;
            if (captured !== expected_byte(i[19:0]))
                fail_msg($sformatf("sweep: addr %05h returned %02h, memory holds %02h",
                                   i[19:0], captured, expected_byte(i[19:0])));
        end
        sweep_reads = sdram_activates - sweep_reads;

        $display("");
        $display("  sequential sweep: %0d bytes cost %0d SDRAM transactions (%0d without the latch)",
                 sweep_bytes, sweep_reads, sweep_bytes);
        if (sweep_reads > (sweep_bytes * 3) / 4) begin
            fail_msg($sformatf("sweep: %0d transactions for %0d bytes - the latch is barely hitting",
                               sweep_reads, sweep_bytes));
        end
        else begin
            pass_count = pass_count + 1;
            $display("  PASS  sequential run costs about half the SDRAM transactions");
        end

        // ---- and it must switch off cleanly ---------------------------------
        // The two cycle-accurate settings below 9.54MHz do not take the burst:
        // there the extra clock inside KFSDRAM's READ state costs more than the
        // hits give back. With the gate low every byte must cost its own
        // transaction again, and every byte must still be right.
        clk_select = 2'b01;
        wait_idle;
        slow_reads = sdram_activates;
        for (i = 20'h02000; i < 20'h02040; i = i + 1) begin
            read_held(i[19:0]);
            if (captured !== expected_byte(i[19:0]))
                fail_msg($sformatf("gated off: addr %05h returned %02h, memory holds %02h",
                                   i[19:0], captured, expected_byte(i[19:0])));
        end
        slow_reads = sdram_activates - slow_reads;

        $display("");
        $display("  gated off at 7.16MHz: 64 bytes cost %0d SDRAM transactions", slow_reads);
        if (slow_reads != 64)
            fail_msg($sformatf("gated off: %0d transactions for 64 bytes, expected 64", slow_reads));
        else begin
            pass_count = pass_count + 1;
            $display("  PASS  the burst is off below 9.54MHz");
        end

        // A latch left over from the fast setting must not answer once the gate
        // is low, and must not answer with stale data when it goes high again.
        clk_select = 2'b11;
        check_read(20'h03000, expected_byte(20'h03000), 1'b0, "back on: cold read");
        check_read(20'h03001, expected_byte(20'h03001), 1'b1, "back on: streams again");
        clk_select = 2'b00;
        check_read(20'h03002, expected_byte(20'h03002), 1'b0, "gate low: no hit from latch");

        $display("");
        $display("%0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS");
        else                 $display("RESULT: FAIL");
        $display("");
        $finish;
    end

endmodule

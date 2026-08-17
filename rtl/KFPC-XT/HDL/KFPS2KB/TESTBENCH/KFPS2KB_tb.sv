
`define TB_CYCLE        20
`define TB_FINISH_COUNT 20000

module KFPS2KB_tm();

    timeunit        1ns;
    timeprecision   10ps;

    //
    // Generate wave file to check
    //
`ifdef IVERILOG
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end
`endif

    //
    // Generate clock
    //
    logic   clock;
    initial clock = 1'b1;
    always #(`TB_CYCLE / 2) clock = ~clock;

    //
    // Generate reset
    //
    logic reset;
    initial begin
        reset = 1'b1;
            # (`TB_CYCLE * 10)
        reset = 1'b0;
    end

    //
    // Cycle counter
    //
    logic   [31:0]  tb_cycle_counter;
    always_ff @(negedge clock, posedge reset) begin
        if (reset)
            tb_cycle_counter <= 32'h0;
        else
            tb_cycle_counter <= tb_cycle_counter + 32'h1;
    end

    always_comb begin
        if (tb_cycle_counter == `TB_FINISH_COUNT) begin
            $display("***** SIMULATION TIMEOUT ***** at %d", tb_cycle_counter);
`ifdef IVERILOG
            $finish;
`elsif  MODELSIM
            $stop;
`else
            $finish;
`endif
        end
    end

    //
    // Module under test
    //
    // Both added to KFPS2KB by this fork: peripheral_ce carries the bus rate,
    // and pause_core is the F12 pause the splash advertises.
    logic           peripheral_ce;
    logic           pause_core;
    logic           device_clock;
    logic           device_data;

    logic           irq;
    logic   [7:0]   keycode;
    logic           clear_keycode;

    KFPS2KB #(.over_time (16'd6)
    ) u_KFPS2KB (.*);


    //
    // Task : Initialization
    //
    task TASK_INIT();
    begin
        #(`TB_CYCLE * 0);
        peripheral_ce = 1'b1;
        device_clock  = 1'b1;
        device_data   = 1'b1;
        clear_keycode = 1'b0;
        #(`TB_CYCLE * 12);
        // Step off the clock grid, once, for everything that follows.
        // Every delay in this bench is a whole TB_CYCLE and the clock
        // period is one TB_CYCLE, so without this skew every device_clock
        // transition lands exactly on a rising edge of clock.  The edge
        // detector registers prev_device_clock on that same edge, so the
        // difference it looks for was never visible and not one byte was
        // ever received.
        #(`TB_CYCLE / 4);
    end
    endtask

    //
    // Task : Send Serial
    //
    task TASK_SEND_SERIAL(input [10:0] data);
    begin
        #(`TB_CYCLE * 0);
        device_clock  = 1'b1;
        device_data   = 1'b1;
        clear_keycode = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = data[10];
        #(`TB_CYCLE * 3);
        device_clock  = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = data[9];
        #(`TB_CYCLE * 3);
        device_clock  = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = data[8];
        #(`TB_CYCLE * 3);
        device_clock  = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = data[7];
        #(`TB_CYCLE * 3);
        device_clock  = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = data[6];
        #(`TB_CYCLE * 3);
        device_clock  = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = data[5];
        #(`TB_CYCLE * 3);
        device_clock  = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = data[4];
        #(`TB_CYCLE * 3);
        device_clock  = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = data[3];
        #(`TB_CYCLE * 3);
        device_clock  = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = data[2];
        #(`TB_CYCLE * 3);
        device_clock  = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = data[1];
        #(`TB_CYCLE * 3);
        device_clock  = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = data[0];
        #(`TB_CYCLE * 3);
        device_clock  = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = 1'b1;
        #(`TB_CYCLE * 1);
    end
    endtask

    //
    // Task : TEST TIMEOUUT
    //
    task TASK_TEST_TIMEOUT(input [10:0] data);
    begin
        #(`TB_CYCLE * 0);
        device_clock  = 1'b1;
        device_data   = 1'b1;
        clear_keycode = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = data[10];
        #(`TB_CYCLE * 3);
        device_clock  = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = data[9];
        #(`TB_CYCLE * 3);
        device_clock  = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = data[8];
        #(`TB_CYCLE * 3);
        device_clock  = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = data[7];
        #(`TB_CYCLE * 3);
        device_clock  = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        device_data   = data[6];
        #(`TB_CYCLE * 3);
        device_clock  = 1'b0;
        #(`TB_CYCLE * 3);
        device_clock  = 1'b1;
        #(`TB_CYCLE * 6);
    end
    endtask


    //
    // Test pattern
    //
    initial begin
        TASK_INIT();

        // Make code
        TASK_SEND_SERIAL(11'b0_1010_1010_1_1);
        #(`TB_CYCLE * 10);

        clear_keycode = 1'b1;
        #(`TB_CYCLE * 1);
        clear_keycode = 1'b0;

        // Break code
        TASK_SEND_SERIAL(11'b0_0000_1111_1_1);
        #(`TB_CYCLE * 1);
        TASK_SEND_SERIAL(11'b0_0000_1000_0_1);
        #(`TB_CYCLE * 10);

        clear_keycode = 1'b1;
        #(`TB_CYCLE * 1);
        clear_keycode = 1'b0;

        // Parity error
        TASK_SEND_SERIAL(11'b0_0101_0101_0_1);
        #(`TB_CYCLE * 10);

        clear_keycode = 1'b1;
        #(`TB_CYCLE * 1);
        clear_keycode = 1'b0;

        // Buffer overrun
        TASK_SEND_SERIAL(11'b0_1111_0000_1_1);
        TASK_SEND_SERIAL(11'b0_0000_1111_1_1);

        clear_keycode = 1'b1;
        #(`TB_CYCLE * 1);
        clear_keycode = 1'b0;

        // F12 pause.  Set 2 scancode 07, sent LSB first with odd parity, so
        // 11'b0_1110_0000_0_1 for the make and F0 07 for the break.  This is a
        // PCXT addition and nothing covered it.
        $display("***** TEST F12 ***** at %d", tb_cycle_counter);
        clear_keycode = 1'b1;
        #(`TB_CYCLE * 1);
        clear_keycode = 1'b0;
        #(`TB_CYCLE * 10);

        // The make alone must do nothing, or auto-repeat would chatter the
        // pause while the key is held down.
        TASK_SEND_SERIAL(11'b0_1110_0000_0_1);
        #(`TB_CYCLE * 10);
        if (pause_core !== 1'b0)
            $display("FAIL: F12 make toggled the pause");
        if (irq !== 1'b0)
            $display("FAIL: F12 make was passed to the machine");

        // The break enters it, and F12 itself never reaches the machine.
        TASK_SEND_SERIAL(11'b0_0000_1111_1_1);
        #(`TB_CYCLE * 1);
        TASK_SEND_SERIAL(11'b0_1110_0000_0_1);
        #(`TB_CYCLE * 10);
        if (pause_core !== 1'b1)
            $display("FAIL: F12 break did not enter the pause");
        if (irq !== 1'b0)
            $display("FAIL: F12 break was passed to the machine");

        // While paused the keyboard belongs to the credits.  Anything else
        // typed is swallowed rather than queued up for the machine.
        TASK_SEND_SERIAL(11'b0_1010_1010_1_1);
        #(`TB_CYCLE * 10);
        if (irq !== 1'b0)
            $display("FAIL: a key reached the machine while paused");

        // And pressing it again leaves.
        TASK_SEND_SERIAL(11'b0_1110_0000_0_1);
        #(`TB_CYCLE * 10);
        TASK_SEND_SERIAL(11'b0_0000_1111_1_1);
        #(`TB_CYCLE * 1);
        TASK_SEND_SERIAL(11'b0_1110_0000_0_1);
        #(`TB_CYCLE * 10);
        if (pause_core !== 1'b0)
            $display("FAIL: second F12 did not leave the pause");

        clear_keycode = 1'b1;
        #(`TB_CYCLE * 1);
        clear_keycode = 1'b0;
        #(`TB_CYCLE * 10);

        // Test timeout
        TASK_TEST_TIMEOUT(11'b0_0101_0101_0_1);

        #(`TB_CYCLE * 1);
        // End of simulation
`ifdef IVERILOG
        $finish;
`elsif  MODELSIM
        $stop;
`else
        $finish;
`endif
    end

endmodule


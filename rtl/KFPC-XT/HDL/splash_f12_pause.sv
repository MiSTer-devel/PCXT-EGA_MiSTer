// F12 while the boot splash is on screen holds it there.
//
// The splash runs with the whole machine in reset, so the keyboard controller
// that normally decodes F12 into pause_core is in reset with it and never sees
// the key.  That is why the legend the splash draws was true everywhere except
// on the splash itself.  This watches the framework's decoded key stream
// instead, which is upstream of the machine and unaffected by its reset.
//
// Toggled on the break code, as the keyboard controller does, so holding the
// key down does not chatter the pause through auto-repeat.

module splash_f12_pause (
    input  logic        clock,          // splash timebase
    input  logic        splash_active,  // the timed splash owns the screen
    // {toggle, pressed, extended, code} from hps_io, in another clock domain.
    input  logic [10:0] ps2_key,
    output logic        paused
);

    localparam [7:0] PS2_SET2_F12 = 8'h07;

    // Three stages on the toggle against two on the data puts the new code in
    // key_sync[1] on the same cycle the toggle edge is reported, rather than
    // one cycle before it arrives.
    (* ASYNC_REG = "TRUE" *) logic [2:0] toggle_sync = 3'b000;
    (* ASYNC_REG = "TRUE" *) logic [9:0] key_sync_0  = 10'd0;
    logic [9:0] key_sync_1 = 10'd0;

    wire key_event = toggle_sync[2] ^ toggle_sync[1];
    wire f12_break = key_event & ~key_sync_1[9] & ~key_sync_1[8] &
                     (key_sync_1[7:0] == PS2_SET2_F12);

    initial paused = 1'b0;

    always_ff @(posedge clock) begin
        toggle_sync <= {toggle_sync[1:0], ps2_key[10]};
        key_sync_0  <= ps2_key[9:0];
        key_sync_1  <= key_sync_0;

        // Nothing to hold once the splash is gone, and the next boot starts
        // from a clean slate.
        if (!splash_active)
            paused <= 1'b0;
        else if (f12_break)
            paused <= ~paused;
    end

endmodule

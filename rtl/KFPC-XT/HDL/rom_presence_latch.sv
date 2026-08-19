// Tracks whether a ROM image has been uploaded over ioctl since power-on.
//
// MiSTer re-sends every "FC" file at core start, so a set flag means the OSD
// has a file selected for that slot and its contents are in memory.  A clear
// flag means nothing has ever been sent for it, and the slot is empty.
module rom_presence_latch (
    input  logic clock,
    input  logic reset,
    input  logic sdram_initialized,
    input  logic download_active,
    input  logic write_complete,
    output logic loaded
);

    logic download_active_q;

    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            download_active_q <= 1'b0;
            loaded <= 1'b0;
        end else if (!sdram_initialized) begin
            download_active_q <= 1'b0;
            loaded <= 1'b0;
        end else begin
            download_active_q <= download_active;

            // Invalidate the old image once per file, not once per word.  The
            // loader returns to its idle state between every 16-bit word, so a
            // per-word rule would clear the flag again after each one.
            if (download_active && !download_active_q)
                loaded <= 1'b0;
            else if (download_active && write_complete)
                loaded <= 1'b1;
        end
    end

endmodule

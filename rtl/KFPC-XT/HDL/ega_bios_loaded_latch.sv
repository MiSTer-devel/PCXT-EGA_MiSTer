module ega_bios_loaded_latch (
    input  logic clock,
    input  logic reset,
    input  logic sdram_initialized,
    input  logic download_active,
    input  logic write_complete,
    output logic loaded,
    output wire  write_protect,
    output wire [1:0] video_switches
);

    logic download_active_q;

    // A present option ROM is both read-only and advertised to the XT BIOS as
    // an adapter with its own firmware.  Without one, retain the CGA fallback.
    assign write_protect  = loaded;
    assign video_switches = loaded ? 2'b00 : 2'b10;

    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            download_active_q <= 1'b0;
            loaded <= 1'b0;
        end else if (!sdram_initialized) begin
            download_active_q <= 1'b0;
            loaded <= 1'b0;
        end else begin
            download_active_q <= download_active;

            // Invalidate the old image once per file, not once per word.
            if (download_active && !download_active_q)
                loaded <= 1'b0;
            else if (download_active && write_complete)
                loaded <= 1'b1;
        end
    end

endmodule

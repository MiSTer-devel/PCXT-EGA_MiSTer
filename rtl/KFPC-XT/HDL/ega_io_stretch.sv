//
// KFPC-XT video I/O posted-write stretcher
//
// The video card lives in its own clock domain (28.636 MHz) and receives the
// I/O bus through per-bit two-stage synchronisers plus a two-identical-samples
// qualifier in ega_top. That crossing has no handshake: a write lands only if
// the IOW pulse stays low, with stable address and data, long enough for the
// far side to sample it twice - about 6 to 7 video clocks, 210-245 ns, in the
// worst case phase.
//
// At the PC/AT 3.5MHz speed setting the virtual 8088 runs at 25 MHz and an I/O
// write pulse is about 3 T-states plus the io_settle floor: near 200 ns. That
// sits exactly on the requirement, so whether any given write survives depends
// on the momentary phase between two free-running clocks - and on placement,
// which is why unrelated builds moved it. The writes software issues most are
// CRTC index/data pairs (cursor updates, one per character printed); a lost
// index desynchronises the pair and the data byte lands in whatever register
// the index last named. That is the slow on-screen corruption at this speed.
//
// This module makes the crossing correct by construction. A write is captured
// in the chipset domain, where the cycle is synchronous, and presented to the
// video domain as a pulse of guaranteed minimum width followed by a guaranteed
// minimum gap. While the CPU's own assertion persists the capture follows the
// live bus, so at the slower speeds - where the real pulse already exceeds the
// minimum - the presented cycle is the real one and nothing changes.
//
// Three details protect the corners:
//
//  * The captured cycle is presented with its address enable held active for
//    the whole synthetic pulse. The real cycle was a CPU cycle; if DMA takes
//    the bus while the tail of the pulse is still draining, the live AEN would
//    otherwise gate the decode off mid-write in ega_top.
//
//  * Reads are masked while a stretch is in flight. The presented address
//    still belongs to the captured write, and several video ports have read
//    side effects (3DAh resets the attribute flip-flop, 3C9h advances the DAC
//    read state), so a read strobe must not be seen against that address.
//
//  * access_ready backpressures any NEW I/O cycle that begins while a stretch
//    is draining, using the arm-at-cycle-start pattern the ready path already
//    relies on: the stall level is low before the new cycle's first clock, so
//    its wait states are armed in time. The cycle that produced the stretch is
//    never stalled by it.
//
module ega_io_stretch
    #(
        // 14 chipset clocks = 280 ns = 8 video clocks presented low;
        // 8 chipset clocks = 160 ns = 4.6 video clocks presented high.
        // Both clear the far side's worst case with margin.
        parameter int MIN_LOW_TICKS  = 14,
        parameter int MIN_HIGH_TICKS = 8
    )
    (
        input   logic           clock,
        input   logic           reset,

        input   logic           io_write_n,
        input   logic           io_read_n,
        input   logic           address_enable_n,
        input   logic   [14:0]  address,
        input   logic   [7:0]   write_data,

        output  logic   [14:0]  video_address,
        output  logic   [7:0]   video_data,
        output  logic           video_io_write_n,
        output  logic           video_io_read_n,
        output  logic           video_address_enable_n,
        output  logic           access_ready
    );

    typedef enum logic [1:0] {
        IDLE,
        STRETCH_LOW,
        STRETCH_HIGH
    } state_t;

    state_t         state;
    logic   [4:0]   ticks;
    // The current io_write_n assertion has been captured; cleared when the
    // strobe returns high. One assertion is captured exactly once.
    logic           strobe_seen;

    wire    cpu_write       = ~io_write_n & ~address_enable_n;
    wire    cpu_read        = ~io_read_n  & ~address_enable_n;
    wire    original_active = strobe_seen & ~io_write_n;

    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            state            <= IDLE;
            ticks            <= 5'd0;
            strobe_seen      <= 1'b0;
            video_address    <= 15'd0;
            video_data       <= 8'd0;
        end
        else begin
            if (io_write_n)
                strobe_seen <= 1'b0;

            case (state)
                IDLE: begin
                    // Same behaviour the live path had: the address holds
                    // under either strobe so reads keep theirs, the data
                    // follows only under the write strobe.
                    if (cpu_write | cpu_read)
                        video_address <= address;
                    if (cpu_write)
                        video_data <= write_data;
                    if (cpu_write & ~strobe_seen) begin
                        strobe_seen <= 1'b1;
                        ticks       <= MIN_LOW_TICKS[4:0];
                        state       <= STRETCH_LOW;
                    end
                end

                STRETCH_LOW: begin
                    // Track the live bus while the CPU still drives the
                    // original assertion, exactly as the live path did; the
                    // values freeze when the CPU moves on.
                    if (original_active) begin
                        video_address <= address;
                        video_data    <= write_data;
                    end
                    if (ticks != 5'd0)
                        ticks <= ticks - 5'd1;
                    else if (~original_active) begin
                        ticks <= MIN_HIGH_TICKS[4:0];
                        state <= STRETCH_HIGH;
                    end
                end

                STRETCH_HIGH: begin
                    if (ticks != 5'd0)
                        ticks <= ticks - 5'd1;
                    else
                        state <= IDLE;
                end

                default:
                    state <= IDLE;
            endcase
        end
    end

    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            video_io_write_n       <= 1'b1;
            video_io_read_n        <= 1'b1;
            video_address_enable_n <= 1'b1;
        end
        else begin
            video_io_write_n       <= ~(state == STRETCH_LOW);
            video_io_read_n        <= (state == IDLE) ? io_read_n : 1'b1;
            video_address_enable_n <= (state == IDLE) ? address_enable_n : 1'b0;
        end
    end

    // A new write is one whose assertion has not been captured yet. The
    // original write never stalls on its own stretch.
    wire    new_write_pending = cpu_write & ~strobe_seen;

    assign  access_ready = (state == IDLE) | ~(new_write_pending | cpu_read);

endmodule

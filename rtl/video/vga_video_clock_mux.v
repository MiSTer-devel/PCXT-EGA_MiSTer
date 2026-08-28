// Select the pixel clock used by the private VGA raster.  Quartus maps this
// to a Cyclone V clock-control block, so changing Native/60Hz cannot create a
// logic-generated clock glitch.  The simple mux keeps RTL simulations free
// from a dependency on the Intel primitive library.
module vga_video_clock_mux (
    input  wire clk_legacy,
    input  wire clk_native,
    input  wire select_native,
    output wire clk_video
);

`ifdef ALTERA_RESERVED_QIS
    // Use the same hard clock selector as MiSTer's HDMI/direct-video path.
    cyclonev_clkselect video_clock_control (
        // On Cyclone V the two PLL-fed inputs are inclk[2] and inclk[3].
        .inclk({clk_native, clk_legacy, 2'b00}),
        .clkselect({1'b1, select_native}),
        .outclk(clk_video)
    );
`else
    assign clk_video = select_native ? clk_native : clk_legacy;
`endif

endmodule

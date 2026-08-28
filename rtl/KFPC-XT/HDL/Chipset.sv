//
// MiSTer PCXT Chipset
// Ported by @spark2k06
//
// Based on KFPC-XT written by @kitune-san
//
module CHIPSET #(
        parameter clk_rate = 28'd50000000)
        (
        input   logic           clock,
        input   logic           cpu_ce_posedge,
        input   logic           cpu_ce_negedge,
        input   logic           clk_sys,
        input   logic           peripheral_ce,
        input   logic   [1:0]   clk_select,
        input   logic           reset,
        input   logic           video_reset,
        input   logic           sdram_reset,
        // CPU
        input   logic   [19:0]  cpu_address,
        input   logic   [7:0]   cpu_data_bus,
        input   logic   [2:0]   processor_status,
        input   logic           processor_lock_n,
        output  logic           processor_transmit_or_receive_n,
        output  logic           processor_ready,
        output  logic           interrupt_to_cpu,
        // SplashScreen
        input   logic           splashscreen,
        // VGA
        output  logic           std_hsyncwidth,
        input   logic           clk_video,
        output  logic           de_o,
        output  logic   [5:0]   VGA_R,
        output  logic   [5:0]   VGA_G,
        output  logic   [5:0]   VGA_B,
        output  logic           VGA_HSYNC,
        output  logic           VGA_VSYNC,
        output  logic           VGA_HBlank,
        output  logic           VGA_VBlank,
        output  logic           VGA_VBlank_border,
        input   logic           vga_mode13_osd,
        input   logic           vga_mode13_native,
        input   logic   [1:0]   ega_monitor_profile,
        output  logic           vga_mode13_active_out,
        output  logic           vga_mode13_wide_clock_out,
        output  logic           vga_mode13_pixel_toggle_out,
        // I/O Ports
        output  logic   [19:0]  address,
        input   logic   [19:0]  address_ext,
        output  logic           address_direction,
        output  logic   [7:0]   data_bus,
        // The private 16-bit SDRAM path, for an 8086 bus cycle. Steps 2 and 5 of
        // docs/8086-adaptation.md. It runs beside the 8-bit bus rather than
        // widening it: everything on the expansion side - video memory, the
        // BIOS ROM, every peripheral - stays eight bits wide, which is what an
        // XT-class expansion bus was and what an 8086 XT-clone's steering
        // logic presented to software anyway.
        //
        // Only SDRAM answers it. word_read_possible (the historical signal
        // name, now used for either direction) says so for the address
        // currently latched, and it is about the memory map alone - the CPU
        // side still has to check that the access is a word at an even
        // address, which is the half of the question it is the one that knows.
        input   logic           word_read_request,
        input   logic           word_write_request,
        input   logic   [15:0]  data_bus_word_in,
        output  logic   [15:0]  data_bus_word,
        output  logic           word_read_possible,
        input   logic   [7:0]   data_bus_ext,
        output  logic           data_bus_direction,
        output  logic           address_latch_enable,
        input   logic           io_channel_check,
        input   logic           io_channel_ready,
        input   logic   [7:0]   interrupt_request,
        output  logic           io_read_n,
        input   logic           io_read_n_ext,
        output  logic           io_read_n_direction,
        output  logic           io_write_n,
        input   logic           io_write_n_ext,
        output  logic           io_write_n_direction,
        output  logic           memory_read_n,
        input   logic           memory_read_n_ext,
        output  logic           memory_read_n_direction,
        output  logic           memory_write_n,
        input   logic           memory_write_n_ext,
        output  logic           memory_write_n_direction,
        input   logic           ext_access_request,
        input   logic   [3:0]   dma_request,
        output  logic   [3:0]   dma_acknowledge_n,
        output  logic           address_enable_n,
        output  logic           terminal_count_n,
        // Peripherals
        output  logic   [2:0]   timer_counter_out,
        output  logic           speaker_out,
        output  logic   [7:0]   port_a_out,
        output  logic           port_a_io,
        input   logic   [7:0]   port_b_in,
        output  logic   [7:0]   port_b_out,
        output  logic           port_b_io,
        input   logic   [7:0]   port_c_in,
        output  logic   [7:0]   port_c_out,
        output  logic   [7:0]   port_c_io,
        input   logic           ps2_clock,
        input   logic           ps2_data,
        output  logic           ps2_clock_out,
        output  logic           ps2_data_out,
        input   logic           ps2_mouseclk_in,
        input   logic           ps2_mousedat_in,
        output  logic           ps2_mouseclk_out,
        output  logic           ps2_mousedat_out,
        input   logic   [4:0]   joy_opts,
        input   logic   [13:0]  joy0,
        input   logic   [13:0]  joy1,
        input   logic   [15:0]  joya0,
        input   logic   [15:0]  joya1,
        // JTOPL
        output  logic   [15:0]  jtopl2_snd_e,
        // Tandy 1000 sound
        output  logic   [10:0]  tandy_snd_e,
        input   logic           tandy_en,
        input   logic   [1:0]   opl2_io,
        // C/MS Audio
        input   logic           sb_en,
        input   logic           sb_irq7,
        output  logic   [15:0]  sb_snd_l,
        output  logic   [15:0]  sb_snd_r,
        input   logic           cms_en,
        output  logic   [15:0]  o_cms_l,
        output  logic   [15:0]  o_cms_r,
        // UART
        input   logic           clk_uart,
        input   logic           uart2_rx,
        output  logic           uart2_tx,
        input   logic           uart2_cts_n,
        input   logic           uart2_dcd_n,
        input   logic           uart2_dsr_n,
        output  logic           uart2_rts_n,
        output  logic           uart2_dtr_n,
        // MPU-401 (MIDI / MT32-pi)
        input   logic           clk_midi,
        input   logic           midi_rx,
        output  logic           midi_tx,
        input   logic           mpu401_enabled,
        // SDRAM
        input   logic           enable_sdram,
        output  logic           initilized_sdram,
        input   logic           sdram_clock,    // 50MHz
        output  logic   [12:0]  sdram_address,
        output  logic           sdram_cke,
        output  logic           sdram_cs,
        output  logic           sdram_ras,
        output  logic           sdram_cas,
        output  logic           sdram_we,
        output  logic   [1:0]   sdram_ba,
        input   logic   [15:0]  sdram_dq_in,
        output  logic   [15:0]  sdram_dq_out,
        output  logic           sdram_dq_io,
        output  logic           sdram_ldqm,
        output  logic           sdram_udqm,
        // EMS
        input   logic           ems_enabled,
        input   logic   [1:0]   ems_address,
        // UMB
        input   logic           umb_enabled,
        // BIOS
        input  logic    [2:0]   bios_protect_flag,
        // MMC interface
        input   logic   [1:0]   use_mmc,
        output  logic           spi_clk,
        output  logic           spi_cs,
        output  logic           spi_mosi,
        input   logic           spi_miso,
        // FDD
        input   logic   [15:0]  mgmt_address,
        input   logic           mgmt_read,
        output  logic   [15:0]  mgmt_readdata,
        input   logic           mgmt_write,
        input   logic   [15:0]  mgmt_writedata,
        input   logic   [1:0]   floppy_wp,
        output  logic   [1:0]   fdd_present,
        output  logic   [1:0]   fdd_request,
        output  logic   [2:0]   ide0_request,
        // XTEGACTL register file
        output  logic   [7:0]   xtegactl_cpu,
        output  logic   [7:0]   xtegactl_exp,
        output  logic   [7:0]   xtegactl_vid,
        output  logic   [7:0]   xtegactl_inp,
        output  logic   [7:0]   xtegactl_midi,
        output  logic   [7:0]   xtegactl_exp2,
        output  logic   [7:0]   xtegactl_crt,
        output  logic   [7:0]   xtegactl_sync,
        // Read-only effective XTEGACTL status, supplied by the top level
        // where the OSD values are available.
        input   logic   [39:0]  xtegactl_status_effective,
        input   logic   [17:0]  xtegactl_status_osd_match,
        // RAM wait mode
        input   logic           wait_count_clk_en,
        input   logic   [1:0]   ram_read_wait_cycle,
        input   logic   [1:0]   ram_write_wait_cycle,
        // Others
        output  logic           pause_core,
        input   logic           video_scandoubler_en,
        // EGA dot clock status, clk_video domain
        output  logic           ega_dot_toggle,
        output  logic           ega_dot_clock_sel,
        output  logic           ega_scandouble_active,
        output  logic           ega_vmode_toggle_out,
        output  logic           ega_mode350,
        output  logic   [11:0]  ega_active_dots,
        output  logic   [9:0]   ega_active_lines,
        input   logic   [3:0]   crt_h_offset,
        input   logic   [2:0]   crt_v_offset,
        input   logic   [2:0]   vsync_width_osd,
        input   logic   [2:0]   hsync_width_osd

    );

	 logic   [19:0]  latch_address;
	 
    logic           dma_ready;
    logic           dma_wait_n;
    logic           interrupt_acknowledge_n;
    logic           dma_chip_select_n;
    logic           dma_page_chip_select_n;
    logic           memory_access_ready;
    logic           video_memory_access_ready;
    logic           video_io_access_ready;
    // Stays high with the Tandy chip compiled out, so it costs nothing then.
    logic           tandy_snd_rdy;
    logic           ram_address_select_n;
    logic   [7:0]   internal_data_bus;
    logic   [7:0]   internal_data_bus_ext;
    logic   [7:0]   internal_data_bus_chipset;
    logic   [7:0]   internal_data_bus_ram;
    logic   [15:0]  internal_data_bus_ram_word;
    logic           data_bus_out_from_chipset;
    logic           internal_data_bus_direction;
    logic           no_command_state;
    logic           prev_timer_count_1;
    logic           DRQ0;

    logic   [6:0]   map_ems[0:3];
    logic           ena_ems[0:3];
    logic           ems_b1;
    logic           ems_b2;
    logic           ems_b3;
    logic           ems_b4;
    logic           fdd_dma_req;
    logic           sb_dma_req;

    // IBM-compatible BIOSes announce a warm reboot by writing 1234h to the
    // BIOS Data Area at 0040:0072.  Detect that bus transaction here, where
    // both the ordinary 8088 byte bus and the 8086 private word path are
    // visible, before handing the event to the peripheral register file.
    logic           warm_boot_marker_event;

    //
    // I/O settle guard
    //
    // io_channel_ready is currently wired to a constant '1' at the top
    // level: no I/O device (FDC, XT2IDE, KFMMC, UART, RTC, OPL2, ...) can
    // request a wait state of its own. Their response pipelines are a fixed
    // number of chipset clocks long, sized against the roomy I/O cycle at
    // the slower CPU speeds. At the fastest CPU speed setting that cycle
    // shrinks to a couple of chipset clocks, so add back a small, speed
    // dependent floor of extra wait at the start of every I/O cycle -- the
    // same role the 5160's one I/O wait state plays on real hardware.
    logic   [2:0]   io_settle_count;
    logic           prev_io_active;
    wire            io_active = ~io_read_n | ~io_write_n;

    function automatic logic [2:0] io_settle_ticks(input logic [1:0] sel);
        case (sel)
            2'b11:   io_settle_ticks = 3'd4;
            default: io_settle_ticks = 3'd0;
        endcase
    endfunction

    always_ff @(posedge clock, posedge reset) begin
        if (reset) begin
            prev_io_active  <= 1'b0;
            io_settle_count <= 3'd0;
        end
        else begin
            prev_io_active <= io_active;
            if (io_active && ~prev_io_active)
                io_settle_count <= io_settle_ticks(clk_select);
            else if (io_settle_count != 3'd0)
                io_settle_count <= io_settle_count - 3'd1;
        end
    end

    wire    io_settle_ready = (io_settle_count == 3'd0);


    always_ff @(posedge clock)
    begin
        if (reset)
            prev_timer_count_1 <= 1'b1;
        else
            prev_timer_count_1 <= timer_counter_out[1];
    end

    always_ff @(posedge clock, posedge reset)
    begin
        if (reset)
            DRQ0 <= 1'b0;
        else if (~dma_acknowledge_n[0])
            DRQ0 <= 1'b0;
        else if (~prev_timer_count_1 & timer_counter_out[1])
            DRQ0 <= 1'b1;
        else
            DRQ0 <= DRQ0;
    end

    READY u_READY 
    (
        .clock                              (clock),
        .cpu_ce_posedge                     (cpu_ce_posedge),
        .cpu_ce_negedge                     (cpu_ce_negedge),
        .reset                              (reset),
        .processor_ready                    (processor_ready),
        .dma_ready                          (dma_ready),
        .dma_wait_n                         (dma_wait_n),
        .io_channel_ready                   (io_channel_ready & memory_access_ready & video_memory_access_ready & io_settle_ready & video_io_access_ready & tandy_snd_rdy),
        .io_read_n                          (io_read_n),
        .io_write_n                         (io_write_n),
        .memory_read_n                      (memory_read_n),
        .memory_write_n                     (memory_write_n),
        .dma0_acknowledge_n                 (dma_acknowledge_n[0]),
        .address_enable_n                   (address_enable_n),
        .clk_select                         (clk_select)
    );

    BUS_ARBITER u_BUS_ARBITER 
    (
        .clock                              (clock),
        .cpu_ce_posedge                     (cpu_ce_posedge),
        .cpu_ce_negedge                     (cpu_ce_negedge),
        .reset                              (reset),
        .cpu_address                        (cpu_address),
        .cpu_data_bus                       (cpu_data_bus),
        .processor_status                   (processor_status),
        .processor_lock_n                   (processor_lock_n),
        .processor_transmit_or_receive_n    (processor_transmit_or_receive_n),
        .dma_ready                          (dma_ready),
        .dma_wait_n                         (dma_wait_n),
        .interrupt_acknowledge_n            (interrupt_acknowledge_n),
        .dma_chip_select_n                  (dma_chip_select_n),
        .dma_page_chip_select_n             (dma_page_chip_select_n),
        .address                            (address),
        .address_ext                        (address_ext),
        .address_direction                  (address_direction),
        .data_bus_ext                       (internal_data_bus_ext),
        .internal_data_bus                  (internal_data_bus),
        .data_bus_direction                 (internal_data_bus_direction),
        .address_latch_enable               (address_latch_enable),
        .io_read_n                          (io_read_n),
        .io_read_n_ext                      (io_read_n_ext),
        .io_read_n_direction                (io_read_n_direction),
        .io_write_n                         (io_write_n),
        .io_write_n_ext                     (io_write_n_ext),
        .io_write_n_direction               (io_write_n_direction),
        .memory_read_n                      (memory_read_n),
        .memory_read_n_ext                  (memory_read_n_ext),
        .memory_read_n_direction            (memory_read_n_direction),
        .memory_write_n                     (memory_write_n),
        .memory_write_n_ext                 (memory_write_n_ext),
        .memory_write_n_direction           (memory_write_n_direction),
        .no_command_state                   (no_command_state),
        .ext_access_request                 (ext_access_request),
        .dma_request                        ({dma_request[3], fdd_dma_req, sb_dma_req, DRQ0}),
        .dma_acknowledge_n                  (dma_acknowledge_n),
        .address_enable_n                   (address_enable_n),
        .terminal_count_n                   (terminal_count_n)
    );

    warm_boot_marker_detector u_warm_boot_marker_detector (
        .clock              (clock),
        .reset              (reset),
        .address            (address),
        .address_enable_n   (address_enable_n),
        .memory_write_n     (memory_write_n),
        .byte_data          (internal_data_bus),
        .word_write_request (word_write_request),
        .word_data          (data_bus_word_in),
        .warm_boot_event    (warm_boot_marker_event)
    );

    PERIPHERALS #(.clk_rate(clk_rate)) u_PERIPHERALS 
    (
        .clock                              (clock),
        .clk_sys                            (clk_sys),
        .cpu_ce_posedge                     (cpu_ce_posedge),
        .cpu_ce_negedge                     (cpu_ce_negedge),
        .clk_uart                           (clk_uart),
        .peripheral_ce                      (peripheral_ce),
        .clk_select                         (clk_select),
        .reset                              (reset),
        .video_reset                        (video_reset),
        .interrupt_to_cpu                   (interrupt_to_cpu),
        .interrupt_acknowledge_n            (interrupt_acknowledge_n),
        .dma_chip_select_n                  (dma_chip_select_n),
        .dma_page_chip_select_n             (dma_page_chip_select_n),
        .splashscreen                       (splashscreen),
        .std_hsyncwidth                     (std_hsyncwidth),
        .clk_video                        (clk_video),
        .de_o                               (de_o),
        .VGA_R                              (VGA_R),
        .VGA_G                              (VGA_G),
        .VGA_B                              (VGA_B),
        .VGA_HSYNC                          (VGA_HSYNC),
        .VGA_VSYNC                          (VGA_VSYNC),
        .VGA_HBlank                         (VGA_HBlank),
        .VGA_VBlank                         (VGA_VBlank),
        .VGA_VBlank_border                  (VGA_VBlank_border),		  
        .address                            (address),
	    .latch_address                      (latch_address),
        .internal_data_bus                  (internal_data_bus),
        .data_bus_out                       (internal_data_bus_chipset),
        .data_bus_out_from_chipset          (data_bus_out_from_chipset),
        .interrupt_request                  (interrupt_request),
        .io_read_n                          (io_read_n),
        .io_write_n                         (io_write_n),
        .memory_read_n                      (memory_read_n),
        .memory_write_n                     (memory_write_n),
        .address_enable_n                   (address_enable_n),
        .warm_boot_marker_event             (warm_boot_marker_event),
        .video_memory_access_ready            (video_memory_access_ready),
        .video_io_access_ready              (video_io_access_ready),
        .timer_counter_out                  (timer_counter_out),
        .speaker_out                        (speaker_out),
        .port_a_out                         (port_a_out),
        .port_a_io                          (port_a_io),
        .port_b_in                          (port_b_in),
        .port_b_out                         (port_b_out),
        .port_b_io                          (port_b_io),
        .port_c_in                          (port_c_in),
        .port_c_out                         (port_c_out),
        .port_c_io                          (port_c_io),
        .ps2_clock                          (ps2_clock),
        .ps2_data                           (ps2_data),
        .ps2_mouseclk_in                    (ps2_mouseclk_in),
        .ps2_mousedat_in                    (ps2_mousedat_in),
        .ps2_mouseclk_out                   (ps2_mouseclk_out),
        .ps2_mousedat_out                   (ps2_mousedat_out),
        .joy_opts                           (joy_opts),
        .joy0                               (joy0),
        .joy1                               (joy1),
        .joya0                              (joya0),
        .joya1                              (joya1),
        .ps2_clock_out                      (ps2_clock_out),
        .ps2_data_out                       (ps2_data_out),
        .jtopl2_snd_e                       (jtopl2_snd_e),
        .tandy_snd_e                        (tandy_snd_e),
        .tandy_snd_rdy                      (tandy_snd_rdy),
        .tandy_en                           (tandy_en),
        .opl2_io                            (opl2_io),
        .sb_en                              (sb_en),
        .sb_irq7                            (sb_irq7),
        .sb_snd_l                           (sb_snd_l),
        .sb_snd_r                           (sb_snd_r),
        .sb_dma_req                         (sb_dma_req),
        .sb_dma_ack                         (~dma_acknowledge_n[1]),
        .cms_en                             (cms_en),
        .o_cms_l                            (o_cms_l),
        .o_cms_r                            (o_cms_r),
        .uart2_rx                           (uart2_rx),
        .uart2_tx                           (uart2_tx),
        .uart2_cts_n                        (uart2_cts_n),
        .uart2_dcd_n                        (uart2_dcd_n),
        .uart2_dsr_n                        (uart2_dsr_n),
        .uart2_rts_n                        (uart2_rts_n),
        .uart2_dtr_n                        (uart2_dtr_n),
        .clk_midi                          (clk_midi),
        .midi_rx                           (midi_rx),
        .midi_tx                           (midi_tx),
        .mpu401_enabled                    (mpu401_enabled),
        .ems_enabled                       (ems_enabled),
        .ems_address                       (ems_address),
        .map_ems                           (map_ems),
        .ena_ems                           (ena_ems),
        .ems_b1                            (ems_b1),
        .ems_b2                            (ems_b2),
        .ems_b3                            (ems_b3),
        .ems_b4                            (ems_b4),
        .use_mmc                            (use_mmc),
        .spi_clk                            (spi_clk),
        .spi_cs                             (spi_cs),
        .spi_mosi                           (spi_mosi),
        .spi_miso                           (spi_miso),
        .mgmt_address                       (mgmt_address),
        .mgmt_read                          (mgmt_read),
        .mgmt_readdata                      (mgmt_readdata),
        .mgmt_write                         (mgmt_write),
        .mgmt_writedata                     (mgmt_writedata),
        .floppy_wp                          (floppy_wp),
        .fdd_present                        (fdd_present),
        .fdd_request                        (fdd_request),
        .ide0_request                       (ide0_request),
        .fdd_dma_req                        (fdd_dma_req),
        .fdd_dma_ack                        (~dma_acknowledge_n[2]),
        .terminal_count                     (terminal_count_n),
        .xtegactl_cpu                       (xtegactl_cpu),
        .xtegactl_exp                       (xtegactl_exp),
        .xtegactl_vid                       (xtegactl_vid),
        .xtegactl_inp                       (xtegactl_inp),
        .xtegactl_midi                      (xtegactl_midi),
        .xtegactl_exp2                      (xtegactl_exp2),
        .xtegactl_crt                       (xtegactl_crt),
        .xtegactl_sync                      (xtegactl_sync),
        .xtegactl_status_effective          (xtegactl_status_effective),
        .xtegactl_status_osd_match          (xtegactl_status_osd_match),
        .pause_core                         (pause_core),
        .video_scandoubler_en                  (video_scandoubler_en),
        .ega_dot_toggle                     (ega_dot_toggle),
        .ega_dot_clock_sel                  (ega_dot_clock_sel),
        .ega_scandouble_active_out          (ega_scandouble_active),
        .ega_vmode_toggle_out               (ega_vmode_toggle_out),
        .ega_mode350                        (ega_mode350),
        .ega_active_dots                    (ega_active_dots),
        .ega_active_lines                   (ega_active_lines),
        .vga_mode13_osd                    (vga_mode13_osd),
        .vga_mode13_native                 (vga_mode13_native),
        .ega_monitor_profile               (ega_monitor_profile),
        .vga_mode13_active_out             (vga_mode13_active_out),
        .vga_mode13_wide_clock_out         (vga_mode13_wide_clock_out),
        .vga_mode13_pixel_toggle_out        (vga_mode13_pixel_toggle_out),
        .crt_h_offset                       (crt_h_offset),
        .crt_v_offset                       (crt_v_offset),
        .vsync_width_osd                    (vsync_width_osd),
        .hsync_width_osd                    (hsync_width_osd)
    );

    RAM u_RAM 
    (
        .clock                              (sdram_clock),
        .reset                              (sdram_reset),
        .enable_sdram                       (enable_sdram),
        .initilized_sdram                   (initilized_sdram),
        .address                            (latch_address),
        .internal_data_bus                  (internal_data_bus),
        .data_bus_out                       (internal_data_bus_ram),
        .word_read_request                  (word_read_request),
        .word_write_request                 (word_write_request),
        .data_bus_in_word                   (data_bus_word_in),
        .data_bus_out_word                  (internal_data_bus_ram_word),
        .memory_read_n                      (memory_read_n),
        .memory_write_n                     (memory_write_n),
        .no_command_state                   (no_command_state),
        .memory_access_ready                (memory_access_ready),
        .ram_address_select_n               (ram_address_select_n),
        .sdram_address                      (sdram_address),
        .sdram_cke                          (sdram_cke),
        .sdram_cs                           (sdram_cs),
        .sdram_ras                          (sdram_ras),
        .sdram_cas                          (sdram_cas),
        .sdram_we                           (sdram_we),
        .sdram_ba                           (sdram_ba),
        .sdram_dq_in                        (sdram_dq_in),
        .sdram_dq_out                       (sdram_dq_out),
        .sdram_dq_io                        (sdram_dq_io),
        .sdram_ldqm                         (sdram_ldqm),
        .sdram_udqm                         (sdram_udqm),
        .map_ems                            (map_ems),
        .ems_b1                             (ems_b1),
        .ems_b2                             (ems_b2),
        .ems_b3                             (ems_b3),
        .ems_b4                             (ems_b4),
        .umb_enabled                        (umb_enabled),
        .bios_protect_flag                  (bios_protect_flag),
        .wait_count_clk_en                  (wait_count_clk_en),
        .ram_read_wait_cycle                (ram_read_wait_cycle),
        .ram_write_wait_cycle               (ram_write_wait_cycle),
        .clk_select                         (clk_select)
    );

    assign  data_bus = internal_data_bus;

    // The word never joins the byte multiplexer below. It has one source and
    // one destination, it is only meaningful for the cycle the CPU asked a
    // word for, and putting it through the same arbitration would mean giving
    // every other device a 16-bit port it has nothing to put on.
    assign  data_bus_word = internal_data_bus_ram_word;

    // ram_address_select_n is combinational on the latched address, so this
    // settles as soon as the address does and is available to the CPU well
    // before it has to commit to a wide cycle. It covers the decode holes -
    // video memory, an unmapped EMS frame, the UMB window when it is off -
    // because those are the places a wide read would come back with whatever
    // RAM.sv happened to be holding.
    assign  word_read_possible = ~ram_address_select_n;

    always_comb
    begin
        if (data_bus_out_from_chipset)
        begin
            internal_data_bus_ext = internal_data_bus_chipset;
            data_bus_direction    = 1'b0;
        end
        else if ((~ram_address_select_n) && (~memory_read_n))
        begin
            internal_data_bus_ext = internal_data_bus_ram;
            data_bus_direction    = 1'b0;
        end
        else
        begin
            if (internal_data_bus_direction == 1'b1)
            begin
                internal_data_bus_ext = data_bus_ext;
                data_bus_direction    = 1'b1;
            end
            else
            begin
                internal_data_bus_ext = 0;
                data_bus_direction    = 1'b0;
            end
        end
    end

endmodule

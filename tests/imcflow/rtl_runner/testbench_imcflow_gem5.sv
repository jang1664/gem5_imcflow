`timescale 1ns / 1ps

`include "axi/assign.svh"
`include "params.svh"

module testbench_imcflow_gem5
  import imcflow_pkg::*;
  #(
    parameter int unsigned AXI_DATA_WIDTH = imcflow_pkg::IO_DATA_WIDTH,
    parameter int unsigned AXI_ADDR_WIDTH = imcflow_pkg::IO_ADDR_WIDTH,
    parameter int unsigned AXI_STRB_WIDTH = imcflow_pkg::IO_STROBE_WIDTH,
    parameter int unsigned AXI_USER_WIDTH = 1,
    parameter int unsigned AXI_ID_WIDTH = 1,

    parameter int unsigned TCDM_ADDR_WIDTH = imcflow_pkg::IO_ADDR_WIDTH,
    parameter int unsigned TCDM_DATA_WIDTH = imcflow_pkg::IO_DATA_WIDTH,
    parameter int unsigned TCDM_BE_WIDTH = imcflow_pkg::IO_STROBE_WIDTH,

    parameter int unsigned MaxCycle = 4000000,
    parameter int unsigned RstCycle = 10,
    parameter int unsigned StandByCycles = 5,
    parameter real InputDelayMin = 3.0,
    parameter real InputDelayMax = 5.5,
    parameter time CyclTime = 10ns,
    parameter real PERIOD = 10
  );

  // Import DPI-C functions for socket server
  import "DPI-C" function int socket_server_init(input int port);
  import "DPI-C" function int socket_server_accept();
  import "DPI-C" function int socket_has_transaction();
  import "DPI-C" function int socket_recv_transaction(
      output int is_write,
      output int unsigned addr,
      output int unsigned data
  );
  import "DPI-C" function int socket_send_response(input int unsigned data);
  import "DPI-C" function void socket_server_close();

  // Clock and reset signals
  logic clk;
  logic rstn;

  // AXI interface signals between AXI master and imcflow_with_axi
  wire [AXI_ID_WIDTH-1:0]   axi_awid;
  wire [AXI_ADDR_WIDTH-1:0] axi_awaddr;
  wire [7:0]                axi_awlen;
  wire [2:0]                axi_awsize;
  wire [1:0]                axi_awburst;
  wire                      axi_awlock;
  wire [3:0]                axi_awcache;
  wire [2:0]                axi_awprot;
  wire [3:0]                axi_awregion;
  wire [3:0]                axi_awqos;
  wire [AXI_USER_WIDTH-1:0] axi_awuser;
  wire [5:0]                axi_awatop;
  wire                      axi_awvalid;
  wire                      axi_awready;

  wire [AXI_DATA_WIDTH-1:0] axi_wdata;
  wire [AXI_STRB_WIDTH-1:0] axi_wstrb;
  wire                      axi_wlast;
  wire [AXI_USER_WIDTH-1:0] axi_wuser;
  wire                      axi_wvalid;
  wire                      axi_wready;

  wire [AXI_ID_WIDTH-1:0]   axi_bid;
  wire [1:0]                axi_bresp;
  wire [AXI_USER_WIDTH-1:0] axi_buser;
  wire                      axi_bvalid;
  wire                      axi_bready;

  wire [AXI_ID_WIDTH-1:0]   axi_arid;
  wire [AXI_ADDR_WIDTH-1:0] axi_araddr;
  wire [7:0]                axi_arlen;
  wire [2:0]                axi_arsize;
  wire [1:0]                axi_arburst;
  wire                      axi_arlock;
  wire [3:0]                axi_arcache;
  wire [2:0]                axi_arprot;
  wire [3:0]                axi_arregion;
  wire [3:0]                axi_arqos;
  wire [AXI_USER_WIDTH-1:0] axi_aruser;
  wire                      axi_arvalid;
  wire                      axi_arready;

  wire [AXI_ID_WIDTH-1:0]   axi_rid;
  wire [AXI_DATA_WIDTH-1:0] axi_rdata;
  wire [1:0]                axi_rresp;
  wire                      axi_rlast;
  wire [AXI_USER_WIDTH-1:0] axi_ruser;
  wire                      axi_rvalid;
  wire                      axi_rready;

  // Interrupt signals
  wire interrupt_ack_i;
  wire interrupt_o;

  wire inode_0_state_o;
  wire imcflow_state_o;
  wire aggregator_err_o;
  wire imcflow_reg_access_o;

  // ==================================================================
  // Clock and reset generation
  // ==================================================================
  clk_rst_gen #(
      .ClkPeriod(CyclTime),
      .RstClkCycles(RstCycle),
      .StandByCycles(StandByCycles)
  ) i_clk_gen (
      .clk_o (clk),
      .rstn_o(rstn)
  );

  // ==================================================================
  // AXI Master for Socket Transactions
  // ==================================================================
  AXI_BUS_DV #(
      .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
      .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
      .AXI_ID_WIDTH  (AXI_ID_WIDTH),
      .AXI_USER_WIDTH(AXI_USER_WIDTH)
  ) axi_master_dv (clk);

  // AXI signal assignments - connect axi_master_dv to imcflow_with_axi wire ports
  assign axi_awid         = axi_master_dv.aw_id;
  assign axi_awaddr       = axi_master_dv.aw_addr;
  assign axi_awlen        = axi_master_dv.aw_len;
  assign axi_awsize       = axi_master_dv.aw_size;
  assign axi_awburst      = axi_master_dv.aw_burst;
  assign axi_awlock       = axi_master_dv.aw_lock;
  assign axi_awcache      = axi_master_dv.aw_cache;
  assign axi_awprot       = axi_master_dv.aw_prot;
  assign axi_awqos        = axi_master_dv.aw_qos;
  assign axi_awregion     = axi_master_dv.aw_region;
  assign axi_awatop       = axi_master_dv.aw_atop;
  assign axi_awuser       = axi_master_dv.aw_user;
  assign axi_awvalid      = axi_master_dv.aw_valid;
  assign axi_master_dv.aw_ready = axi_awready;

  assign axi_wdata        = axi_master_dv.w_data;
  assign axi_wstrb        = axi_master_dv.w_strb;
  assign axi_wlast        = axi_master_dv.w_last;
  assign axi_wuser        = axi_master_dv.w_user;
  assign axi_wvalid       = axi_master_dv.w_valid;
  assign axi_master_dv.w_ready  = axi_wready;

  assign axi_master_dv.b_id     = axi_bid;
  assign axi_master_dv.b_resp   = axi_bresp;
  assign axi_master_dv.b_user   = axi_buser;
  assign axi_master_dv.b_valid  = axi_bvalid;
  assign axi_bready       = axi_master_dv.b_ready;

  assign axi_arid         = axi_master_dv.ar_id;
  assign axi_araddr       = axi_master_dv.ar_addr;
  assign axi_arlen        = axi_master_dv.ar_len;
  assign axi_arsize       = axi_master_dv.ar_size;
  assign axi_arburst      = axi_master_dv.ar_burst;
  assign axi_arlock       = axi_master_dv.ar_lock;
  assign axi_arcache      = axi_master_dv.ar_cache;
  assign axi_arprot       = axi_master_dv.ar_prot;
  assign axi_arqos        = axi_master_dv.ar_qos;
  assign axi_arregion     = axi_master_dv.ar_region;
  assign axi_aruser       = axi_master_dv.ar_user;
  assign axi_arvalid      = axi_master_dv.ar_valid;
  assign axi_master_dv.ar_ready = axi_arready;

  assign axi_master_dv.r_id     = axi_rid;
  assign axi_master_dv.r_data   = axi_rdata;
  assign axi_master_dv.r_resp   = axi_rresp;
  assign axi_master_dv.r_last   = axi_rlast;
  assign axi_master_dv.r_user   = axi_ruser;
  assign axi_master_dv.r_valid  = axi_rvalid;
  assign axi_rready       = axi_master_dv.r_ready;
  typedef axi_test::axi_driver #(
      .AW(AXI_ADDR_WIDTH),
      .DW(AXI_DATA_WIDTH),
      .IW(AXI_ID_WIDTH),
      .UW(AXI_USER_WIDTH),
      .TA(200ps),
      .TT(700ps)
  ) axi_driver_t;

  axi_driver_t axi_master_drv = new(axi_master_dv);

  // AXI transaction beats
  axi_test::axi_ax_beat #(
      .AW(int'(AXI_ADDR_WIDTH)),
      .IW(int'(AXI_ID_WIDTH)),
      .UW(int'(AXI_USER_WIDTH))
  ) write_ax_beat = new();

  axi_test::axi_w_beat #(
      .DW(int'(AXI_DATA_WIDTH)),
      .UW(int'(AXI_USER_WIDTH))
  ) w_beat = new();

  axi_test::axi_b_beat #(
      .IW(int'(AXI_ID_WIDTH)),
      .UW(int'(AXI_USER_WIDTH))
  ) b_beat = new();

  axi_test::axi_ax_beat #(
      .AW(int'(AXI_ADDR_WIDTH)),
      .IW(int'(AXI_ID_WIDTH)),
      .UW(int'(AXI_USER_WIDTH))
  ) read_ax_beat = new();

  axi_test::axi_r_beat #(
      .DW(int'(AXI_DATA_WIDTH)),
      .UW(int'(AXI_USER_WIDTH)),
      .IW(int'(AXI_ID_WIDTH))
  ) r_beat = new();

  // ==================================================================
  // ImcFlow RTL instance
  // ==================================================================
  imcflow_with_axi #(
      .AXI_ID_WIDTH    (AXI_ID_WIDTH),
      .AXI_USER_WIDTH  (AXI_USER_WIDTH),
      .AXI_DATA_WIDTH  (AXI_DATA_WIDTH),
      .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH),
      .TCDM_DATA_WIDTH (TCDM_DATA_WIDTH),
      .TCDM_ADDR_WIDTH (TCDM_ADDR_WIDTH),
      .AXI_STRB_WIDTH  (AXI_STRB_WIDTH),
      .TCDM_BE_WIDTH   (TCDM_BE_WIDTH)
  ) u_imcflow_with_axi (
      .clk             (clk),
      .rstn            (rstn),

      // AXI interface
      .axi_awid        (axi_awid),
      .axi_awaddr      (axi_awaddr),
      .axi_awlen       (axi_awlen),
      .axi_awsize      (axi_awsize),
      .axi_awburst     (axi_awburst),
      .axi_awlock      (axi_awlock),
      .axi_awcache     (axi_awcache),
      .axi_awprot      (axi_awprot),
      .axi_awregion    (axi_awregion),
      .axi_awqos       (axi_awqos),
      .axi_awuser      (axi_awuser),
      .axi_awatop      (axi_awatop),
      .axi_awvalid     (axi_awvalid),
      .axi_awready     (axi_awready),

      .axi_wdata       (axi_wdata),
      .axi_wstrb       (axi_wstrb),
      .axi_wlast       (axi_wlast),
      .axi_wuser       (axi_wuser),
      .axi_wvalid      (axi_wvalid),
      .axi_wready      (axi_wready),

      .axi_bid         (axi_bid),
      .axi_bresp       (axi_bresp),
      .axi_buser       (axi_buser),
      .axi_bvalid      (axi_bvalid),
      .axi_bready      (axi_bready),

      .axi_arid        (axi_arid),
      .axi_araddr      (axi_araddr),
      .axi_arlen       (axi_arlen),
      .axi_arsize      (axi_arsize),
      .axi_arburst     (axi_arburst),
      .axi_arlock      (axi_arlock),
      .axi_arcache     (axi_arcache),
      .axi_arprot      (axi_arprot),
      .axi_arregion    (axi_arregion),
      .axi_arqos       (axi_arqos),
      .axi_aruser      (axi_aruser),
      .axi_arvalid     (axi_arvalid),
      .axi_arready     (axi_arready),

      .axi_rid         (axi_rid),
      .axi_rdata       (axi_rdata),
      .axi_rresp       (axi_rresp),
      .axi_rlast       (axi_rlast),
      .axi_ruser       (axi_ruser),
      .axi_rvalid      (axi_rvalid),
      .axi_rready      (axi_rready),

      // Interrupt interface
      .interrupt_ack_i (interrupt_ack_i),
      .interrupt_o     (interrupt_o),

      .inode_0_state_o(inode_0_state_o),
      .imcflow_state_o(imcflow_state_o),
      .aggregator_err_o(aggregator_err_o),
      .imcflow_reg_access_o(imcflow_reg_access_o)
  );

  // ==================================================================
  // Socket Transaction Handling
  // ==================================================================

  // Transaction variables
  int is_write;
  int unsigned addr;
  int unsigned data;
  int result;
  int no_transaction_count;
  int transaction_received_count = 0;

  // Task to perform AXI write
  task axi_write_single(input logic [AXI_ADDR_WIDTH-1:0] addr, input logic [AXI_DATA_WIDTH-1:0] data);
    @(posedge clk);
    write_ax_beat.ax_len  = 0;  // Single beat (length = 1)
    write_ax_beat.ax_size = 2;  // 4 bytes (2^2)
    write_ax_beat.ax_addr = addr;
    axi_master_drv.send_aw(write_ax_beat);

    w_beat.w_data = data;
    w_beat.w_strb = 4'hf;  // All bytes valid
    w_beat.w_last = 1'b1;  // Single beat
    axi_master_drv.send_w(w_beat);

    axi_master_drv.recv_b(b_beat);
  endtask

  // Task to perform AXI read
  task axi_read_single(input logic [AXI_ADDR_WIDTH-1:0] addr, output logic [AXI_DATA_WIDTH-1:0] data);
    @(posedge clk);
    read_ax_beat.ax_len  = 0;  // Single beat (length = 1)
    read_ax_beat.ax_size = 2;  // 4 bytes (2^2)
    read_ax_beat.ax_addr = addr;
    axi_master_drv.send_ar(read_ax_beat);

    axi_master_drv.recv_r(r_beat);
    data = r_beat.r_data;
  endtask

  // Main socket server and transaction processing
  initial begin
    // FSDB waveform dumping for Verdi
    $fsdbDumpfile("imcflow_gem5.fsdb");
    $fsdbDumpvars(0, testbench_imcflow_gem5);
    $fsdbDumpMDA();

    $display("=== Starting ImcFlow RTL Co-Simulation with gem5 ===\n");

    // Initialize AXI master
    axi_master_drv.reset_master();

    // Wait for reset to complete
    wait(rstn == 1'b1);
    repeat(10) @(posedge clk);

    // Initialize socket server
    $display("[SV] Initializing socket server on port 9999");
    result = socket_server_init(9999);
    if (result != 0) begin
      $display("[SV] ERROR: Failed to initialize socket server");
      $finish;
    end

    // Wait for client connection
    $display("[SV] Waiting for gem5 client connection...");
    result = socket_server_accept();
    if (result != 0) begin
      $display("[SV] ERROR: Failed to accept client");
      $finish;
    end

    $display("[SV] gem5 connected! Starting transaction processing...\n");

    // Main loop: process transactions
    no_transaction_count = 0;
    forever begin
      // Check if transaction is available
      result = socket_has_transaction();

      if (result > 0) begin
        no_transaction_count = 0; // Reset counter
        transaction_received_count++; // Count transactions

        // Transaction available - receive it
        result = socket_recv_transaction(is_write, addr, data);
        if (result != 0) begin
          $display("[SV] ERROR: Failed to receive transaction");
          break;
        end

        // Process the transaction via AXI
        if (is_write) begin
          automatic logic [AXI_ADDR_WIDTH-1:0] axi_addr;
          automatic logic [19:0] byte_offset;

          byte_offset = addr[19:0];
          axi_addr = byte_offset;

          $display("[SV] Processing WRITE: addr=0x%08x -> AXI addr=0x%05x, data=0x%08x",
                   addr, axi_addr, data);

          axi_write_single(axi_addr, data);

        end else begin
          automatic logic [AXI_ADDR_WIDTH-1:0] axi_addr;
          automatic logic [19:0] byte_offset;
          automatic logic [AXI_DATA_WIDTH-1:0] read_data;

          byte_offset = addr[19:0];
          axi_addr = byte_offset;

          $display("[SV] Processing READ: addr=0x%08x -> AXI addr=0x%05x", addr, axi_addr);

          axi_read_single(axi_addr, read_data);

          $display("[SV] Read data: 0x%08x", read_data);

          // Send response to gem5
          result = socket_send_response(read_data);
          if (result != 0) begin
            $display("[SV] ERROR: Failed to send response");
            break;
          end
        end

        $display("");

      end else if (result < 0) begin
        // Error occurred or client disconnected
        $display("[SV] gem5 disconnected or error occurred");
        break;
      end else begin
        // No transaction available, wait a bit
        no_transaction_count++;

        // If we haven't received ANY transactions yet, wait longer (gem5 initialization)
        // Once we get transactions, use shorter timeout
        if (transaction_received_count == 0) begin
          // Still waiting for first transaction - be very patient (200 seconds)
          if (no_transaction_count > 2000000) begin
            $display("[SV] No transactions after 200s, giving up");
            break;
          end
        end else begin
          // Got transactions, now wait for more with shorter timeout (10 seconds)
          if (no_transaction_count > 100000) begin
            $display("[SV] No more transactions for 10s after receiving %0d transactions",
                     transaction_received_count);
            $display("[SV] Assuming test complete");
            break;
          end
        end
        #100000; // 100000 time units (wait longer between polls)
      end
    end

    $display("\n[SV] Closing socket server");
    socket_server_close();

    $display("\n=== ImcFlow RTL Co-Simulation Completed ===");
    $display("Total transactions processed: %0d", transaction_received_count);
    $finish;
  end

  // Timeout watchdog (300 seconds of simulation time to allow gem5 initialization)
  initial begin
    #300_000_000_000; // 300 billion time units timeout (5 minutes)
    $display("\n[SV] GLOBAL TIMEOUT (300s) - forcing finish");
    socket_server_close();
    $finish;
  end

  // Simulation timeout based on MaxCycle
  initial begin
    #(CyclTime * MaxCycle);
    $display("####################################");
    $display("#     The testbench force quit     #");
    $display("####################################");
    socket_server_close();
    $finish;
  end

endmodule

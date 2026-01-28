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
  reg  interrupt_ack_i;
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
  // Automatic Interrupt Acknowledgment for Polling Mode
  // ==================================================================
  // DESIGN DECISION: Polling vs Interrupt-based Synchronization
  //
  // This testbench uses POLLING mode instead of interrupt-based synchronization:
  // - gem5 host code polls STATE_REG_IDX until it returns to IDLE
  // - No interrupt handler is present in the gem5 simulation
  // - However, imcflow_with_axi RTL still generates interrupt_o signals
  //
  // PROBLEM: If interrupt_ack_i is not asserted, the ImcFlow state machine
  // can enter a bad state waiting for acknowledgment that never comes.
  //
  // SOLUTION: Automatically generate interrupt_ack_i one cycle after
  // interrupt_o is raised. This keeps the RTL state machine healthy while
  // allowing the host to use polling for synchronization.
  //
  // NOTE: If migrating to interrupt-based mode in the future, disable this
  // auto-ack logic and handle interrupt_ack_i from the host via MMIO.
  // ==================================================================

  reg interrupt_o_delayed;

  // Auto-acknowledge interrupts one cycle after they are raised
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      interrupt_ack_i <= 1'b0;
      interrupt_o_delayed <= 1'b0;
    end else begin
      interrupt_o_delayed <= interrupt_o;
      // Generate ack pulse when interrupt rises
      interrupt_ack_i <= interrupt_o && !interrupt_o_delayed;
    end
  end

  // ==================================================================
  // Socket Transaction Handling
  // ==================================================================

  // Transaction variables
  int is_write;
  int unsigned addr;
  int unsigned data;
  int result;
  int no_transaction_count;
  longint unsigned transaction_received_count = 0;  // 64-bit to prevent overflow

  // Runtime configuration: socket port (can be overridden with +SOCKET_PORT=<port>)
  int unsigned socket_port = 9999;

  // SRAM backdoor optimization control
  // Can be controlled via plusarg: +SRAM_BACKDOOR=1 or +SRAM_BACKDOOR=0
  // Default: enabled (1) for performance
  bit sram_backdoor_enable = 1'b1;

  // FSIM logging infrastructure
  `ifdef FSIM
  utils::FdManager fdm = utils::FdManager::get_inst();
  `endif
  int log_fd;
  string log_file_path;

  // Memory map constants for direct SRAM access optimization
  // Based on params.svh and imcflow_pkg.sv
  localparam int unsigned REG_BASE = 32'h0;
  localparam int unsigned REG_SIZE = 32'h80;  // 128 bytes
  localparam int unsigned INODE_BASE = 32'h80;  // 128
  localparam int unsigned INODE_IMEM_SIZE = 32'h400;  // 1024 bytes
  localparam int unsigned INODE_DMEM_SIZE = 32'h10000;  // 65536 bytes
  localparam int unsigned INODE_SPACE_SIZE = INODE_IMEM_SIZE + INODE_DMEM_SIZE;  // 66560 bytes per inode
  localparam int unsigned NUM_INODES = 4;  // CORE_NUM_HEIGHT = 4

  initial begin
    // Get log directory from plusarg, default to "logs/fsim_logs"
    if (!$value$plusargs("FSIM_LOG_DIR=%s", log_file_path)) begin
      log_file_path = "logs/fsim_logs";
    end
  end

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

  // ==================================================================
  // Direct SRAM Access Tasks (Bypass AXI for Performance)
  // ==================================================================

  // Helper function: Apply bit interleaving for IMEM (32-bit data, 8-way mux)
  function automatic void apply_imem_bit_interleaving(
    input logic [31:0] data_in,
    input logic [2:0] col_addr,
    inout logic [255:0] mem_row
  );
    for (int i = 0; i < 32; i++) begin
      int phys_bit;
      if (i < 16)
        phys_bit = (15 - i) * 8 + col_addr;
      else
        phys_bit = i * 8 + col_addr;
      mem_row[phys_bit] = data_in[i];
    end
  endfunction

  // Helper function: Extract bit interleaving for IMEM (32-bit data, 8-way mux)
  function automatic logic [31:0] extract_imem_bit_interleaving(
    input logic [255:0] mem_row,
    input logic [2:0] col_addr
  );
    logic [31:0] data_out;
    for (int i = 0; i < 32; i++) begin
      int phys_bit;
      if (i < 16)
        phys_bit = (15 - i) * 8 + col_addr;
      else
        phys_bit = i * 8 + col_addr;
      data_out[i] = mem_row[phys_bit];
    end
    return data_out;
  endfunction

  // Helper function: Apply bit interleaving for DMEM (32-bit data, 4-way mux)
  function automatic void apply_dmem_bit_interleaving(
    input logic [31:0] data_in,
    input logic [1:0] mux_sel,
    input logic [7:0] bit_offset,
    inout logic [1023:0] mem_row
  );
    for (int i = 0; i < 32; i++) begin
      int bit_idx = bit_offset + i;
      int phys_bit;
      if (bit_idx < 128)
        phys_bit = (127 - bit_idx) * 4 + mux_sel;
      else
        phys_bit = bit_idx * 4 + mux_sel;
      mem_row[phys_bit] = data_in[i];
    end
  endfunction

  // Helper function: Extract bit interleaving for DMEM (32-bit data, 4-way mux)
  function automatic logic [31:0] extract_dmem_bit_interleaving(
    input logic [1023:0] mem_row,
    input logic [1:0] mux_sel,
    input logic [7:0] bit_offset
  );
    logic [31:0] data_out;
    for (int i = 0; i < 32; i++) begin
      int bit_idx = bit_offset + i;
      int phys_bit;
      if (bit_idx < 128)
        phys_bit = (127 - bit_idx) * 4 + mux_sel;
      else
        phys_bit = bit_idx * 4 + mux_sel;
      data_out[i] = mem_row[phys_bit];
    end
    return data_out;
  endfunction

  // Task to directly write to INODE IMEM SRAM (bypasses AXI transaction overhead)
  // Hierarchical path: testbench -> imcflow_with_axi -> imcflow_impl -> core_row[N].core_col[0].inode.u_intf_node -> if_stage -> u_imem_intf_node -> u_mem
  // IMEM structure: 32-bit wide SRAM, 256 words deep
  // Compiled memory (ln28fds_mc_ra1_hdr_lvt_256x32m8b1c1): reg [255:0] mem [0:31] - 32 rows of 256-bit
  // Behavioral memory: reg [31:0] sram [0:255] - 256 words of 32-bit
  // gem5 sends 32-bit accesses, so byte_addr / 4 = word_addr
  task sram_write_imem(input int unsigned inode_id, input logic [15:0] byte_addr, input logic [31:0] data);
    logic [7:0] word_addr;   // 256 words = 8-bit address
    logic [4:0] row_addr;    // For compiled memory: 32 rows
    logic [2:0] col_addr;    // For compiled memory: 8 columns (ymux)
    logic [7:0] bit_offset;  // For compiled memory: bit position in 256-bit row
    logic [255:0] mem_row;   // For compiled memory: full 256-bit row

    if (!sram_backdoor_enable) begin
      $error("[SRAM_WRITE_IMEM] Backdoor disabled but called! This should not happen.");
      return;
    end

    @(posedge clk);

    // Calculate SRAM word address (32-bit word = 4 bytes)
    word_addr = byte_addr[9:2];  // Divide by 4 to get word address

    // For compiled memory: 256 words organized as 32 rows × 8 columns (ymux=8)
    // Physical organization: reg [255:0] mem [0:31]
    // Address mapping: row = addr[7:3], mux = addr[2:0]
    // Bit interleaving: row[(15-i)*8 + mux] for bit[i] where i < 16
    //                   row[i*8 + mux] for bit[i] where i >= 16
    row_addr = word_addr[7:3];   // Upper 5 bits = row address
    col_addr = word_addr[2:0];   // Lower 3 bits = column address (ymux)

`ifdef TARGET_SYNTHESIS_OR_MEM_MODEL
    // Access compiled memory model with bit interleaving
    case (inode_id)
      0: begin
        mem_row = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[0].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.gen_ra1_256x32m8b1c1.mem.mem[row_addr];
        apply_imem_bit_interleaving(data, col_addr, mem_row);
        force testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[0].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.gen_ra1_256x32m8b1c1.mem.mem[row_addr] = mem_row;
      end
      1: begin
        mem_row = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[1].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.gen_ra1_256x32m8b1c1.mem.mem[row_addr];
        apply_imem_bit_interleaving(data, col_addr, mem_row);
        force testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[1].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.gen_ra1_256x32m8b1c1.mem.mem[row_addr] = mem_row;
      end
      2: begin
        mem_row = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[2].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.gen_ra1_256x32m8b1c1.mem.mem[row_addr];
        apply_imem_bit_interleaving(data, col_addr, mem_row);
        force testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[2].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.gen_ra1_256x32m8b1c1.mem.mem[row_addr] = mem_row;
      end
      3: begin
        mem_row = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[3].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.gen_ra1_256x32m8b1c1.mem.mem[row_addr];
        apply_imem_bit_interleaving(data, col_addr, mem_row);
        force testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[3].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.gen_ra1_256x32m8b1c1.mem.mem[row_addr] = mem_row;
      end
      default: $error("[SRAM_WRITE_IMEM] Invalid inode_id: %0d (must be 0-3)", inode_id);
    endcase
`else
    // Access behavioral memory model
    case (inode_id)
      0: force testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[0].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.sram[word_addr] = data;
      1: force testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[1].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.sram[word_addr] = data;
      2: force testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[2].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.sram[word_addr] = data;
      3: force testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[3].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.sram[word_addr] = data;
      default: $error("[SRAM_WRITE_IMEM] Invalid inode_id: %0d (must be 0-3)", inode_id);
    endcase
`endif

    // Release after one clock
    @(posedge clk);
`ifdef TARGET_SYNTHESIS_OR_MEM_MODEL
    case (inode_id)
      0: release testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[0].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.gen_ra1_256x32m8b1c1.mem.mem[row_addr];
      1: release testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[1].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.gen_ra1_256x32m8b1c1.mem.mem[row_addr];
      2: release testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[2].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.gen_ra1_256x32m8b1c1.mem.mem[row_addr];
      3: release testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[3].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.gen_ra1_256x32m8b1c1.mem.mem[row_addr];
      default: ;
    endcase
`else
    case (inode_id)
      0: release testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[0].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.sram[word_addr];
      1: release testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[1].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.sram[word_addr];
      2: release testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[2].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.sram[word_addr];
      3: release testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[3].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.sram[word_addr];
      default: ;
    endcase
`endif

`ifdef TARGET_SYNTHESIS_OR_MEM_MODEL
    $display("[SRAM_DIRECT] IMEM WRITE (compiled): inode=%0d, byte_addr=0x%04x (mem[0x%02x], col=%0d), data=0x%08x",
             inode_id, byte_addr, row_addr, col_addr, data);
`else
    $display("[SRAM_DIRECT] IMEM WRITE (behavioral): inode=%0d, byte_addr=0x%04x (sram[0x%02x]), data=0x%08x",
             inode_id, byte_addr, word_addr, data);
`endif
  endtask

  // Task to directly read from INODE IMEM SRAM
  task sram_read_imem(input int unsigned inode_id, input logic [15:0] byte_addr, output logic [31:0] data);
    logic [7:0] word_addr;
    logic [4:0] row_addr;    // For compiled memory: 32 rows
    logic [2:0] col_addr;    // For compiled memory: 8 columns (ymux)
    logic [7:0] bit_offset;  // For compiled memory: bit position in 256-bit row
    logic [255:0] mem_row;   // For compiled memory: full 256-bit row

    if (!sram_backdoor_enable) begin
      $error("[SRAM_READ_IMEM] Backdoor disabled but called! This should not happen.");
      data = 'x;
      return;
    end

    @(posedge clk);

    // Calculate SRAM word address
    word_addr = byte_addr[9:2];

    // For compiled memory: 256 words organized as 32 rows × 8 columns (ymux=8)
    // Physical organization: reg [255:0] mem [0:31]
    // Address mapping: row = addr[7:3], mux = addr[2:0]
    // Bit interleaving: row[(15-i)*8 + mux] for bit[i] where i < 16
    //                   row[i*8 + mux] for bit[i] where i >= 16
    row_addr = word_addr[7:3];   // Upper 5 bits = row address
    col_addr = word_addr[2:0];   // Lower 3 bits = column address (ymux)

`ifdef TARGET_SYNTHESIS_OR_MEM_MODEL
    // Access compiled memory model with bit interleaving
    case (inode_id)
      0: data = extract_imem_bit_interleaving(testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[0].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.gen_ra1_256x32m8b1c1.mem.mem[row_addr], col_addr);
      1: data = extract_imem_bit_interleaving(testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[1].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.gen_ra1_256x32m8b1c1.mem.mem[row_addr], col_addr);
      2: data = extract_imem_bit_interleaving(testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[2].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.gen_ra1_256x32m8b1c1.mem.mem[row_addr], col_addr);
      3: data = extract_imem_bit_interleaving(testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[3].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.gen_ra1_256x32m8b1c1.mem.mem[row_addr], col_addr);
      default: begin
        $error("[SRAM_READ_IMEM] Invalid inode_id: %0d (must be 0-3)", inode_id);
        data = 'x;
      end
    endcase
`else
    // Access behavioral memory model
    case (inode_id)
      0: data = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[0].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.sram[word_addr];
      1: data = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[1].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.sram[word_addr];
      2: data = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[2].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.sram[word_addr];
      3: data = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[3].core_col[0].inode.u_intf_node.if_stage.u_imem_intf_node.u_mem.sram[word_addr];
      default: begin
        $error("[SRAM_READ_IMEM] Invalid inode_id: %0d (must be 0-3)", inode_id);
        data = 'x;
      end
    endcase
`endif

`ifdef TARGET_SYNTHESIS_OR_MEM_MODEL
    $display("[SRAM_DIRECT] IMEM READ (compiled): inode=%0d, byte_addr=0x%04x (mem[0x%02x], col=%0d), data=0x%08x",
             inode_id, byte_addr, row_addr, col_addr, data);
`else
    $display("[SRAM_DIRECT] IMEM READ (behavioral): inode=%0d, byte_addr=0x%04x (sram[0x%02x]), data=0x%08x",
             inode_id, byte_addr, word_addr, data);
`endif
  endtask

  // Task to directly write to INODE DMEM SRAM
  // Hierarchical path: testbench -> imcflow_with_axi -> imcflow_impl -> core_row[N].core_col[0].inode.u_intf_node -> mem_stage -> u_mem
  // DMEM structure: 256-bit wide SRAM, 2048 words deep
  // Compiled memory (ln28fds_mc_ra1w_hdr_lvt_2048x256m4b1c1): reg [1023:0] mem [0:511] - 512 rows of 1024-bit (4×256-bit)
  // Behavioral memory: reg [255:0] sram [0:2047] - 2048 words of 256-bit
  // gem5 sends 32-bit accesses, so we need to:
  //   1. Calculate SRAM word address: sram_addr = byte_addr / 32 (divide by 256-bit word size in bytes)
  //   2. Calculate bit offset within 256-bit word: bit_offset = (byte_addr % 32) * 8
  //   3. Write/read 32-bit slice: sram[sram_addr][bit_offset +: 32]
  task sram_write_dmem(input int unsigned inode_id, input logic [15:0] byte_addr, input logic [31:0] data);
    logic [10:0] sram_addr;     // 2048 words = 11-bit address (behavioral)
    logic [4:0] byte_offset;    // 0-31 byte offset within 256-bit word
    logic [7:0] bit_offset;     // 0-248 bit offset (byte_offset * 8)
    logic [255:0] sram_word;    // 256-bit word for behavioral SRAM
    logic [8:0] row_addr;       // For compiled memory: 512 rows
    logic [1:0] mux_sel;        // For compiled memory: 4-way mux
    logic [9:0] mem_bit_offset; // For compiled memory: bit position in 1024-bit row
    logic [1023:0] mem_row;     // For compiled memory: full 1024-bit row

    if (!sram_backdoor_enable) begin
      $error("[SRAM_WRITE_DMEM] Backdoor disabled but called! This should not happen.");
      return;
    end

    @(posedge clk);

    // Calculate SRAM word address and byte offset
    sram_addr = byte_addr[15:5];     // Upper bits: word address (divide by 32 bytes)
    byte_offset = byte_addr[4:0];    // Lower 5 bits: byte offset within word
    bit_offset = {byte_offset, 3'b000};  // Convert to bit offset (multiply by 8)

    // For compiled memory: 2048 words organized as 512 rows × 4 mux (ymux=4)
    // Physical organization: reg [1023:0] mem [0:511]
    // Address mapping: row = addr[10:2], mux = addr[1:0]
    // Bit interleaving: row[(127-i)*4 + mux] for bit[i] where i < 128
    //                   row[i*4 + mux] for bit[i] where i >= 128
    row_addr = sram_addr[10:2];      // Upper 9 bits = row address
    mux_sel = sram_addr[1:0];        // Lower 2 bits = mux select (4-way)

`ifdef TARGET_SYNTHESIS_OR_MEM_MODEL
    // Access compiled memory model with bit interleaving
    case (inode_id)
      0: begin
        mem_row = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[0].core_col[0].inode.u_intf_node.mem_stage.u_mem.gen_ra1w_2048x256m4b1c1.mem.mem[row_addr];
        apply_dmem_bit_interleaving(data, mux_sel, bit_offset, mem_row);
        force testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[0].core_col[0].inode.u_intf_node.mem_stage.u_mem.gen_ra1w_2048x256m4b1c1.mem.mem[row_addr] = mem_row;
      end
      1: begin
        mem_row = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[1].core_col[0].inode.u_intf_node.mem_stage.u_mem.gen_ra1w_2048x256m4b1c1.mem.mem[row_addr];
        apply_dmem_bit_interleaving(data, mux_sel, bit_offset, mem_row);
        force testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[1].core_col[0].inode.u_intf_node.mem_stage.u_mem.gen_ra1w_2048x256m4b1c1.mem.mem[row_addr] = mem_row;
      end
      2: begin
        mem_row = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[2].core_col[0].inode.u_intf_node.mem_stage.u_mem.gen_ra1w_2048x256m4b1c1.mem.mem[row_addr];
        apply_dmem_bit_interleaving(data, mux_sel, bit_offset, mem_row);
        force testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[2].core_col[0].inode.u_intf_node.mem_stage.u_mem.gen_ra1w_2048x256m4b1c1.mem.mem[row_addr] = mem_row;
      end
      3: begin
        mem_row = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[3].core_col[0].inode.u_intf_node.mem_stage.u_mem.gen_ra1w_2048x256m4b1c1.mem.mem[row_addr];
        apply_dmem_bit_interleaving(data, mux_sel, bit_offset, mem_row);
        force testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[3].core_col[0].inode.u_intf_node.mem_stage.u_mem.gen_ra1w_2048x256m4b1c1.mem.mem[row_addr] = mem_row;
      end
      default: $error("[SRAM_WRITE_DMEM] Invalid inode_id: %0d (must be 0-3)", inode_id);
    endcase
`else
    // Access behavioral memory model
    // Read-modify-write for 32-bit slice within 256-bit word
    case (inode_id)
      0: begin
        sram_word = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[0].core_col[0].inode.u_intf_node.mem_stage.u_mem.sram[sram_addr];
        sram_word[bit_offset +: 32] = data;  // Update 32-bit slice
        force testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[0].core_col[0].inode.u_intf_node.mem_stage.u_mem.sram[sram_addr] = sram_word;
      end
      1: begin
        sram_word = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[1].core_col[0].inode.u_intf_node.mem_stage.u_mem.sram[sram_addr];
        sram_word[bit_offset +: 32] = data;
        force testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[1].core_col[0].inode.u_intf_node.mem_stage.u_mem.sram[sram_addr] = sram_word;
      end
      2: begin
        sram_word = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[2].core_col[0].inode.u_intf_node.mem_stage.u_mem.sram[sram_addr];
        sram_word[bit_offset +: 32] = data;
        force testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[2].core_col[0].inode.u_intf_node.mem_stage.u_mem.sram[sram_addr] = sram_word;
      end
      3: begin
        sram_word = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[3].core_col[0].inode.u_intf_node.mem_stage.u_mem.sram[sram_addr];
        sram_word[bit_offset +: 32] = data;
        force testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[3].core_col[0].inode.u_intf_node.mem_stage.u_mem.sram[sram_addr] = sram_word;
      end
      default: $error("[SRAM_WRITE_DMEM] Invalid inode_id: %0d (must be 0-3)", inode_id);
    endcase
`endif

    // Release after one clock
    @(posedge clk);
`ifdef TARGET_SYNTHESIS_OR_MEM_MODEL
    case (inode_id)
      0: release testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[0].core_col[0].inode.u_intf_node.mem_stage.u_mem.gen_ra1w_2048x256m4b1c1.mem.mem[row_addr];
      1: release testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[1].core_col[0].inode.u_intf_node.mem_stage.u_mem.gen_ra1w_2048x256m4b1c1.mem.mem[row_addr];
      2: release testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[2].core_col[0].inode.u_intf_node.mem_stage.u_mem.gen_ra1w_2048x256m4b1c1.mem.mem[row_addr];
      3: release testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[3].core_col[0].inode.u_intf_node.mem_stage.u_mem.gen_ra1w_2048x256m4b1c1.mem.mem[row_addr];
      default: ;
    endcase
`else
    case (inode_id)
      0: release testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[0].core_col[0].inode.u_intf_node.mem_stage.u_mem.sram[sram_addr];
      1: release testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[1].core_col[0].inode.u_intf_node.mem_stage.u_mem.sram[sram_addr];
      2: release testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[2].core_col[0].inode.u_intf_node.mem_stage.u_mem.sram[sram_addr];
      3: release testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[3].core_col[0].inode.u_intf_node.mem_stage.u_mem.sram[sram_addr];
      default: ;
    endcase
`endif

`ifdef TARGET_SYNTHESIS_OR_MEM_MODEL
    $display("[SRAM_DIRECT] DMEM WRITE (compiled): inode=%0d, byte_addr=0x%04x (mem[0x%03x], mux=%0d, bit_offset=%0d), data=0x%08x",
             inode_id, byte_addr, row_addr, mux_sel, bit_offset, data);
`else
    $display("[SRAM_DIRECT] DMEM WRITE (behavioral): inode=%0d, byte_addr=0x%04x (sram[0x%03x][%0d +: 32]), data=0x%08x",
             inode_id, byte_addr, sram_addr, bit_offset, data);
`endif
  endtask

  // Task to directly read from INODE DMEM SRAM
  task sram_read_dmem(input int unsigned inode_id, input logic [15:0] byte_addr, output logic [31:0] data);
    logic [10:0] sram_addr;     // 2048 words = 11-bit address (behavioral)
    logic [4:0] byte_offset;    // 0-31 byte offset within 256-bit word
    logic [7:0] bit_offset;     // 0-248 bit offset (byte_offset * 8)
    logic [255:0] sram_word;    // 256-bit word for behavioral SRAM
    logic [8:0] row_addr;       // For compiled memory: 512 rows
    logic [1:0] mux_sel;        // For compiled memory: 4-way mux
    logic [9:0] mem_bit_offset; // For compiled memory: bit position in 1024-bit row
    logic [1023:0] mem_row;     // For compiled memory: full 1024-bit row

    if (!sram_backdoor_enable) begin
      $error("[SRAM_READ_DMEM] Backdoor disabled but called! This should not happen.");
      data = 'x;
      return;
    end

    @(posedge clk);

    // Calculate SRAM word address and byte offset
    sram_addr = byte_addr[15:5];
    byte_offset = byte_addr[4:0];
    bit_offset = {byte_offset, 3'b000};

    // For compiled memory: 2048 words organized as 512 rows × 4 mux (ymux=4)
    // Physical organization: reg [1023:0] mem [0:511]
    // Address mapping: row = addr[10:2], mux = addr[1:0]
    // Bit interleaving: row[(127-i)*4 + mux] for bit[i] where i < 128
    //                   row[i*4 + mux] for bit[i] where i >= 128
    row_addr = sram_addr[10:2];      // Upper 9 bits = row address
    mux_sel = sram_addr[1:0];        // Lower 2 bits = mux select (4-way)

`ifdef TARGET_SYNTHESIS_OR_MEM_MODEL
    // Access compiled memory model with bit interleaving
    case (inode_id)
      0: data = extract_dmem_bit_interleaving(testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[0].core_col[0].inode.u_intf_node.mem_stage.u_mem.gen_ra1w_2048x256m4b1c1.mem.mem[row_addr], mux_sel, bit_offset);
      1: data = extract_dmem_bit_interleaving(testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[1].core_col[0].inode.u_intf_node.mem_stage.u_mem.gen_ra1w_2048x256m4b1c1.mem.mem[row_addr], mux_sel, bit_offset);
      2: data = extract_dmem_bit_interleaving(testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[2].core_col[0].inode.u_intf_node.mem_stage.u_mem.gen_ra1w_2048x256m4b1c1.mem.mem[row_addr], mux_sel, bit_offset);
      3: data = extract_dmem_bit_interleaving(testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[3].core_col[0].inode.u_intf_node.mem_stage.u_mem.gen_ra1w_2048x256m4b1c1.mem.mem[row_addr], mux_sel, bit_offset);
      default: begin
        $error("[SRAM_READ_DMEM] Invalid inode_id: %0d (must be 0-3)", inode_id);
        data = 'x;
      end
    endcase
`else
    // Access behavioral memory model
    // Read 256-bit word and extract 32-bit slice
    case (inode_id)
      0: begin
        sram_word = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[0].core_col[0].inode.u_intf_node.mem_stage.u_mem.sram[sram_addr];
        data = sram_word[bit_offset +: 32];
      end
      1: begin
        sram_word = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[1].core_col[0].inode.u_intf_node.mem_stage.u_mem.sram[sram_addr];
        data = sram_word[bit_offset +: 32];
      end
      2: begin
        sram_word = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[2].core_col[0].inode.u_intf_node.mem_stage.u_mem.sram[sram_addr];
        data = sram_word[bit_offset +: 32];
      end
      3: begin
        sram_word = testbench_imcflow_gem5.u_imcflow_with_axi.u_imcflow_impl.core_row[3].core_col[0].inode.u_intf_node.mem_stage.u_mem.sram[sram_addr];
        data = sram_word[bit_offset +: 32];
      end
      default: begin
        $error("[SRAM_READ_DMEM] Invalid inode_id: %0d (must be 0-3)", inode_id);
        data = 'x;
      end
    endcase
`endif

`ifdef TARGET_SYNTHESIS_OR_MEM_MODEL
    $display("[SRAM_DIRECT] DMEM READ (compiled): inode=%0d, byte_addr=0x%04x (mem[0x%03x], mux=%0d, bit_offset=%0d), data=0x%08x",
             inode_id, byte_addr, row_addr, mux_sel, bit_offset, data);
`else
    $display("[SRAM_DIRECT] DMEM READ (behavioral): inode=%0d, byte_addr=0x%04x (sram[0x%03x][%0d +: 32]), data=0x%08x",
             inode_id, byte_addr, sram_addr, bit_offset, data);
`endif
  endtask

  // Main socket server and transaction processing
  initial begin
    // FSDB waveform dumping for Verdi
    $fsdbDumpfile("imcflow_gem5.fsdb");
    $fsdbDumpvars(0, "+all", "+parameter", "+functions", testbench_imcflow_gem5);
    $fsdbDumpMDA();

    // Check for SRAM backdoor enable/disable
    if ($value$plusargs("SRAM_BACKDOOR=%d", sram_backdoor_enable)) begin
      $display("[CONFIG] SRAM backdoor override from plusarg: %s", sram_backdoor_enable ? "ENABLED" : "DISABLED");
    end else begin
      $display("[CONFIG] SRAM backdoor using default: %s", sram_backdoor_enable ? "ENABLED" : "DISABLED");
    end

    $display("=== Starting ImcFlow RTL Co-Simulation with gem5 ===");
    if (sram_backdoor_enable) begin
      $display("[OPTIMIZATION] Direct SRAM backdoor access: ENABLED");
      $display("[OPTIMIZATION]   - IMEM: 32-bit direct access (bypasses AXI)");
      $display("[OPTIMIZATION]   - DMEM: 256-bit slice access (bypasses AXI)");
      $display("[OPTIMIZATION]   - Expected speedup: 5-10x for memory operations");
    end else begin
      $display("[OPTIMIZATION] Direct SRAM backdoor access: DISABLED");
      $display("[OPTIMIZATION]   - All accesses use AXI protocol (slower but more accurate)");
    end
    $display("[OPTIMIZATION] Memory map: REG[0x%x-0x%x], INODE0_IMEM[0x%x-0x%x], INODE0_DMEM[0x%x-0x%x]",
             REG_BASE, REG_BASE + REG_SIZE - 1,
             INODE_BASE, INODE_BASE + INODE_IMEM_SIZE - 1,
             INODE_BASE + INODE_IMEM_SIZE, INODE_BASE + INODE_SPACE_SIZE - 1);
    $display("");

    // ==================================================================
    // Initialize FSIM logging infrastructure
    // ==================================================================
    // Create log directory and configure FdManager for $fdisplay outputs
    // When FSIM is defined, ModuleLogger instances in RTL modules will
    // create log files in logs/fsim_logs/{module_name}.log
    // ==================================================================
    $display("[FSIM] Creating log directory: %s", log_file_path);
    $system({"mkdir -p ", log_file_path});
    `ifdef FSIM
    fdm.set_log_file_path(log_file_path);
    `endif
    log_fd = $fopen({log_file_path, "/run.log"}, "w");
    $fdisplay(log_fd, "=== ImcFlow RTL Co-Simulation with gem5 ===");
    $fdisplay(log_fd, "Timestamp: %0t", $time);
    $fflush(log_fd);
    $display("[FSIM] Log files will be created in: %s/", log_file_path);
    $display("");

    // Initialize AXI master
    axi_master_drv.reset_master();

    // Wait for reset to complete
    wait(rstn == 1'b1);
    repeat(10) @(posedge clk);

    // Initialize socket server
    // Read port from runtime plusarg (defaults to 9999 if not specified)
    if (!$value$plusargs("SOCKET_PORT=%d", socket_port)) begin
      socket_port = 9999;  // Default port
    end
    $display("[SV] Initializing socket server on port %0d", socket_port);
    result = socket_server_init(socket_port);
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

        // ==================================================================
        // Process transaction with optimization:
        // - Register accesses: Use AXI (required for control logic)
        // - SRAM accesses: Direct hierarchical access (much faster!)
        // ==================================================================
        if (is_write) begin
          automatic logic [19:0] byte_offset;
          automatic logic [AXI_ADDR_WIDTH-1:0] axi_addr;
          automatic int unsigned inode_id;
          automatic logic [19:0] inode_offset;
          automatic logic [15:0] word_addr;

          byte_offset = addr[19:0];
          axi_addr = byte_offset;

          // Decode address to determine access path
          if (byte_offset < REG_BASE + REG_SIZE) begin
            // ========== REGISTER ACCESS: Use AXI ==========
            $display("[SV] Processing WRITE (REG via AXI): addr=0x%08x -> 0x%05x, data=0x%08x",
                     addr, axi_addr, data);
            axi_write_single(axi_addr, data);

          end else if (byte_offset >= INODE_BASE && byte_offset < INODE_BASE + (NUM_INODES * INODE_SPACE_SIZE)) begin
            // ========== INODE MEMORY ACCESS: Direct SRAM ==========
            inode_id = (byte_offset - INODE_BASE) / INODE_SPACE_SIZE;
            inode_offset = (byte_offset - INODE_BASE) % INODE_SPACE_SIZE;

            if (inode_id >= NUM_INODES) begin
              $error("[SV] Invalid inode_id=%0d computed from addr=0x%08x", inode_id, addr);
              axi_write_single(axi_addr, data);
            end else if (inode_offset < INODE_IMEM_SIZE) begin
              // IMEM write - check backdoor flag
              word_addr = inode_offset;  // Byte address within IMEM
              if (sram_backdoor_enable) begin
                $display("[SV] Processing WRITE (IMEM backdoor): addr=0x%08x -> inode=%0d, imem_byte_addr=0x%04x, data=0x%08x",
                         addr, inode_id, word_addr, data);
                sram_write_imem(inode_id, word_addr, data);
              end else begin
                $display("[SV] Processing WRITE (IMEM via AXI): addr=0x%08x -> 0x%05x, data=0x%08x",
                         addr, axi_addr, data);
                axi_write_single(axi_addr, data);
              end
            end else begin
              // DMEM write - check backdoor flag
              word_addr = inode_offset - INODE_IMEM_SIZE;  // Byte address within DMEM
              if (sram_backdoor_enable) begin
                $display("[SV] Processing WRITE (DMEM backdoor): addr=0x%08x -> inode=%0d, dmem_byte_addr=0x%04x, data=0x%08x",
                         addr, inode_id, word_addr, data);
                sram_write_dmem(inode_id, word_addr, data);
              end else begin
                $display("[SV] Processing WRITE (DMEM via AXI): addr=0x%08x -> 0x%05x, data=0x%08x",
                         addr, axi_addr, data);
                axi_write_single(axi_addr, data);
              end
            end

          end else begin
            // Unknown address range - use AXI as fallback
            $display("[SV] Processing WRITE (Unknown via AXI): addr=0x%08x -> 0x%05x, data=0x%08x",
                     addr, axi_addr, data);
            axi_write_single(axi_addr, data);
          end

        end else begin
          automatic logic [19:0] byte_offset;
          automatic logic [AXI_ADDR_WIDTH-1:0] axi_addr;
          automatic logic [AXI_DATA_WIDTH-1:0] read_data;
          automatic int unsigned inode_id;
          automatic logic [19:0] inode_offset;
          automatic logic [15:0] word_addr;

          byte_offset = addr[19:0];
          axi_addr = byte_offset;

          // Decode address to determine access path
          if (byte_offset < REG_BASE + REG_SIZE) begin
            // ========== REGISTER ACCESS: Use AXI ==========
            $display("[SV] Processing READ (REG via AXI): addr=0x%08x -> 0x%05x", addr, axi_addr);
            axi_read_single(axi_addr, read_data);

          end else if (byte_offset >= INODE_BASE && byte_offset < INODE_BASE + (NUM_INODES * INODE_SPACE_SIZE)) begin
            // ========== INODE MEMORY ACCESS: Direct SRAM ==========
            inode_id = (byte_offset - INODE_BASE) / INODE_SPACE_SIZE;
            inode_offset = (byte_offset - INODE_BASE) % INODE_SPACE_SIZE;

            if (inode_id >= NUM_INODES) begin
              $error("[SV] Invalid inode_id=%0d computed from addr=0x%08x", inode_id, addr);
              axi_read_single(axi_addr, read_data);
            end else if (inode_offset < INODE_IMEM_SIZE) begin
              // IMEM read - check backdoor flag
              word_addr = inode_offset;  // Byte address within IMEM
              if (sram_backdoor_enable) begin
                $display("[SV] Processing READ (IMEM backdoor): addr=0x%08x -> inode=%0d, imem_byte_addr=0x%04x",
                         addr, inode_id, word_addr);
                sram_read_imem(inode_id, word_addr, read_data);
              end else begin
                $display("[SV] Processing READ (IMEM via AXI): addr=0x%08x -> 0x%05x", addr, axi_addr);
                axi_read_single(axi_addr, read_data);
              end
            end else begin
              // DMEM read - check backdoor flag
              word_addr = inode_offset - INODE_IMEM_SIZE;  // Byte address within DMEM
              if (sram_backdoor_enable) begin
                $display("[SV] Processing READ (DMEM backdoor): addr=0x%08x -> inode=%0d, dmem_byte_addr=0x%04x",
                         addr, inode_id, word_addr);
                sram_read_dmem(inode_id, word_addr, read_data);
              end else begin
                $display("[SV] Processing READ (DMEM via AXI): addr=0x%08x -> 0x%05x", addr, axi_addr);
                axi_read_single(axi_addr, read_data);
              end
            end

          end else begin
            // Unknown address range - use AXI as fallback
            $display("[SV] Processing READ (Unknown via AXI): addr=0x%08x -> 0x%05x", addr, axi_addr);
            axi_read_single(axi_addr, read_data);
          end

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
          // Still waiting for first transaction - be very patient (2M cycles ~20ms at 10ns)
          if (no_transaction_count > 2000000) begin
            $display("[SV] No transactions after 2M cycles, giving up");
            break;
          end
        end else begin
          // Got transactions, now wait for more with shorter timeout (100k cycles ~1ms)
          if (no_transaction_count > 100000) begin
            $display("[SV] No more transactions for 100k cycles after receiving %0d transactions",
                     transaction_received_count);
            $display("[SV] Assuming test complete");
            break;
          end
        end
        @(posedge clk); // Wait for one clock cycle before next poll
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

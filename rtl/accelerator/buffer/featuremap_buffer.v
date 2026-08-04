`include "defines.vh"
`include "network_config.vh"
module featuremap_buffer #(
    parameter WIDTH         = 0,
    parameter DEPTH         = 0,
    parameter MEM_TYPE      = `BRAM_TYPE,
    parameter IMG_INIT_FILE = ""
) (
    input                                i_clk,
    input                                i_rstn,
    input  [`CLOG2_SAFE(`LAYER_NUM)-1:0] i_lyr_idx,
    input                                i_wr_swap,
    input                                i_rd_swap,
    //
    input                                i_re,
    input  [   `CLOG2_SAFE(DEPTH)-1 : 0] i_raddr,
    output                               o_rvld,
    output [                  WIDTH-1:0] o_rdout,
    //
    input                                i_we,
    input  [   `CLOG2_SAFE(DEPTH)-1 : 0] i_waddr,
    input  [                  WIDTH-1:0] i_wdin
);
  genvar g;
  // ====================== wire =========================== 
  wire                is_first_layer = (i_lyr_idx == 0);
  wire                is_last_layer = (i_lyr_idx == `LAYER_NUM - 1);
  wire                w_ibuf_rvld;
  wire [   WIDTH-1:0] w_ibuf_rdat;
  wire                w_dbuf_rvld;
  wire [   WIDTH-1:0] w_dbuf_rdat;
  wire                w_obuf_rvld;
  wire [`OPT_BIT-1:0] w_obuf_rdat;
  wire                w_ibuf_re = i_re && is_first_layer;
  wire                w_dbuf_re = i_re && !is_first_layer;

  wire                w_dbuf_we = i_we && !is_last_layer;
  wire                w_obuf_we = i_we && is_last_layer;
  // ====================== reg ============================ 
  // ====================== assign ========================= 
  // ====================== always ========================= 
  // ====================== module ========================= 
  // image buffer (DDR)
  simple_dual_port_ram #(
      .WIDTH    (`IPT_BIT),
      .DEPTH    (`MAX_IPT_AREA),
      .MEM_TYPE (`BRAM_TYPE),
      .INIT_FILE(IMG_INIT_FILE)
  ) input_buf (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_re   (w_ibuf_re),
      .i_raddr(i_raddr),
      .i_we   (),
      .i_waddr(),
      .i_wdin (),
      .o_rvld(w_ibuf_rvld),
      .o_rdout(w_ibuf_rdat)
  );
  // double buffer
  double_buffer #(
      .WIDTH   (WIDTH),
      .DEPTH   (DEPTH),
      .MEM_TYPE(`BRAM_TYPE)
  ) inst_double_buffer (
      .i_clk    (i_clk),
      .i_rstn   (i_rstn),
      .i_wr_swap(i_wr_swap),
      .i_rd_swap(i_rd_swap),
      .i_re     (w_dbuf_re),
      .i_raddr  (i_raddr),
      .o_rvld   (w_dbuf_rvld),
      .o_rdout  (w_dbuf_rdat),
      .i_we     (i_we),
      .i_waddr  (i_waddr),
      .i_wdin   (i_wdin)
  );
  // output buffer (DDR)
  simple_dual_port_ram #(
      .WIDTH    (`OPT_BIT),
      .DEPTH    (`MAX_OPT_AREA),
      .MEM_TYPE (`BRAM_TYPE),
      .INIT_FILE()
  ) opt_buf (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_re   (),
      .i_raddr(),
      .i_we   (w_obuf_we),
      .i_waddr(i_waddr),
      .i_wdin (i_wdin),
      .o_rvld (),
      .o_rdout()
  );
  // ====================== output =========================
  assign o_rvld  = is_first_layer ? w_ibuf_rvld : w_dbuf_rvld;
  assign o_rdout = is_first_layer ? w_ibuf_rdat : w_dbuf_rdat;
endmodule

`include "defines.vh"
`include "network_config.vh"
module featuremap_buffer #(
    parameter WIDTH         = 0,
    parameter DEPTH         = 0,
    parameter MEM_TYPE      = `BRAM_TYPE,
    parameter IMG_INIT_FILE = ""
) (
    input                             i_clk,
    input                             i_rstn,
    input                             i_is_first_lyr,
    input                             i_switch,
    //
    input                             i_re,
    input  [`CLOG2_SAFE(DEPTH)-1 : 0] i_raddr,
    //
    input                             i_we,
    input  [`CLOG2_SAFE(DEPTH)-1 : 0] i_waddr,
    input  [               WIDTH-1:0] i_wdat,
    // opt 
    output                            o_opt_vld,
    output [               WIDTH-1:0] o_opt_dout
);
  genvar g;
  // ====================== wire =========================== 
  wire             w_ibuf_vld;
  wire [WIDTH-1:0] w_ibuf_dat;
  wire             w_dbuf_vld;
  wire [WIDTH-1:0] w_dbuf_dat;
  wire             w_ibuf_re = i_re && i_is_first_lyr;
  wire             w_dbuf_re = i_re && !i_is_first_lyr;
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
      .o_vld  (w_ibuf_vld),
      .o_dout (w_ibuf_dat)
  );
  // double buffer
  double_buffer #(
      .WIDTH   (WIDTH),
      .DEPTH   (DEPTH),
      .MEM_TYPE(`BRAM_TYPE)
  ) inst_double_buffer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_switch  (i_switch),
      .i_re      (w_dbuf_re),
      .i_raddr   (i_raddr),
      .i_we      (i_we),
      .i_waddr   (i_waddr),
      .i_wdat    (i_wdin),
      .o_opt_vld (w_dbuf_vld),
      .o_opt_dout(w_dbuf_dat)
  );
  // ====================== output =========================
  assign o_opt_vld  = i_is_first_lyr ? w_ibuf_vld : w_dbuf_vld;
  assign o_opt_dout = i_is_first_lyr ? w_ibuf_dat : w_dbuf_dat;
endmodule

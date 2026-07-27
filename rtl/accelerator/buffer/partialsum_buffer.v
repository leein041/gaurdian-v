`include "defines.vh"
`include "network_config.vh"
module partialsum_buffer #(
    parameter WIDTH    = 0,
    parameter DEPTH    = 0,
    parameter MEM_TYPE = `BRAM_TYPE
) (
    input                             i_clk,
    input                             i_rstn,
    //
    input                             i_re,
    input  [`CLOG2_SAFE(DEPTH)-1 : 0] i_raddr,
    output                            o_rvld,
    output [               WIDTH-1:0] o_rdout,
    //
    input                             i_we,
    input  [`CLOG2_SAFE(DEPTH)-1 : 0] i_waddr,
    input  [               WIDTH-1:0] i_wdin,
    //
    output                            o_ipt_rdy,
    input                             i_opt_rdy
);
  // ====================== wire ===========================
  wire             fifo_psb_rdy;
  wire             psb_fifo_rvld;
  wire [WIDTH-1:0] psb_fifo_rdat;
  // ====================== module ========================= 
  // partial sum buffer (on-chip)
  bank_buffer #(
      .WIDTH     (WIDTH),
      .BANK_DEPTH(DEPTH),
      .MEM_TYPE  (MEM_TYPE),
      .BANK_NUM  (1)
  ) inst_partialsum_buf (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      //
      .i_re      (i_re),
      .i_raddr   (i_raddr),
      .o_rvld    (psb_fifo_rvld),
      .o_rdout   (psb_fifo_rdat),
      //
      .i_we      (i_we),
      .i_waddr   (i_waddr),
      .i_wdin    (i_wdin),
      //
      .i_bank_idx('b0),
      .o_ipt_rdy (o_ipt_rdy),
      .i_opt_rdy (fifo_psb_rdy)
  );
  fifo_buffer #(
      .WIDTH   (WIDTH),
      .DEPTH   (4),
      .MEM_TYPE(`REG_TYPE)
  ) inst_fifo (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // ipt
      .o_ipt_rdy (fifo_psb_rdy),
      .i_ipt_vld (psb_fifo_rvld),
      .i_ipt_din (psb_fifo_rdat),
      // opt
      .i_opt_rdy (i_opt_rdy),
      .o_opt_vld (o_rvld),
      .o_opt_dout(o_rdout)
  );
endmodule

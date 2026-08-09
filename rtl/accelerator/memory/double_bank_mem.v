`include "defines.vh"
`include "network_config.vh"
module double_bank_mem #(
    parameter WIDTH    = 0,
    parameter DEPTH    = 0,
    parameter MEM_TYPE = `BRAM_TYPE,
    parameter BANK_NUM = 0
) (
    input                              i_clk,
    input                              i_rstn,
    //
    input                              i_wr_dn,
    input                              i_rd_dn,
    input  [`CLOG2_SAFE(BANK_NUM)-1:0] i_bank_idx,
    //
    input                              i_re,
    input  [ `CLOG2_SAFE(DEPTH)-1 : 0] i_raddr,
    output                             o_rvld,
    output [     WIDTH * BANK_NUM-1:0] o_rdout,
    //
    input                              i_we,
    input  [ `CLOG2_SAFE(DEPTH)-1 : 0] i_waddr,
    input  [                WIDTH-1:0] i_wdin
);
  genvar g;
  // ====================== wire ===========================
  wire                       w_rvld        [0:1];
  wire [WIDTH* BANK_NUM-1:0] w_rdat        [0:1];
  wire                       w_buf_sel_vld;
  wire [WIDTH* BANK_NUM-1:0] w_buf_sel_dat;
  // ====================== reg ============================
  reg                        r_sel_wr_buf;
  reg                        r_sel_rd_buf;
  // ====================== assign =========================
  assign w_buf_sel_vld = (r_sel_rd_buf == 0) ? w_rvld[0] : w_rvld[1];
  assign w_buf_sel_dat = (r_sel_rd_buf == 0) ? w_rdat[0] : w_rdat[1];
  // ====================== always =========================
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_sel_wr_buf <= 'b0;
      r_sel_rd_buf <= 'b0;
    end else begin
      if (i_wr_dn) begin
        r_sel_wr_buf <= !r_sel_wr_buf;
      end
      if (i_rd_dn) begin
        r_sel_rd_buf <= !r_sel_rd_buf;
      end
    end
  end
  // ====================== module =========================

  // double buffer
  bank_mem #(
      .WIDTH     (WIDTH),
      .BANK_DEPTH(DEPTH),
      .MEM_TYPE  (MEM_TYPE),
      .BANK_NUM  (BANK_NUM)
  ) inst_buf_0 (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_re      (i_re && r_sel_rd_buf == 0),
      .i_raddr   (i_raddr),
      .o_rvld    (w_rvld[0]),
      .o_rdout   (w_rdat[0]),
      .i_bank_idx(i_bank_idx),
      .i_we      (i_we && r_sel_wr_buf == 0),
      .i_waddr   (i_waddr),
      .i_wdin    (i_wdin)
  );

  bank_mem #(
      .WIDTH     (WIDTH),
      .BANK_DEPTH(DEPTH),
      .MEM_TYPE  (MEM_TYPE),
      .BANK_NUM  (BANK_NUM)
  ) inst_buf_1 (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_re      (i_re && r_sel_rd_buf == 1),
      .i_raddr   (i_raddr),
      .o_rvld    (w_rvld[1]),
      .o_rdout   (w_rdat[1]),
      .i_bank_idx(i_bank_idx),
      .i_we      (i_we && r_sel_wr_buf == 1),
      .i_waddr   (i_waddr),
      .i_wdin    (i_wdin)
  );

  // ====================== output =========================  
  assign o_rvld  = w_buf_sel_vld;
  assign o_rdout = w_buf_sel_dat;
endmodule

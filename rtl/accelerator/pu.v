
`include "defines.vh"
`include "network_config.vh"
module pu #(
    parameter  CONV_AREA   = `CONV_3X3_SIDE * `CONV_3X3_SIDE,
    localparam PE_OPT_BIT  = `IPT_BIT + `WGT_BIT,
    localparam MAT_OPT_BIT = PE_OPT_BIT + $clog2(CONV_AREA),
    localparam PU_OPT_BIT  = MAT_OPT_BIT,
    localparam DUMMY       = 0
) (
    input                                      i_clk,
    input                                      i_rstn,
    input                                      i_clr,
    // wgt 
    input                                      i_wgt_vld,
    input  signed [            `WGT_BIT  -1:0] i_wgt_din,
    // ipt
    output                                     o_ipt_rdy,
    input                                      i_ipt_vld,
    input         [`IPT_BIT * CONV_AREA - 1:0] i_ipt_din,
    // opt
    input                                      i_opt_rdy,
    output                                     o_opt_vld,
    output signed [          PU_OPT_BIT - 1:0] o_opt_dout
);
  // ====================== parmeter =======================   
  integer i, j;
  genvar c, p;

  reg r_ptch_clr;  // clear signal
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) r_ptch_clr <= 1'b0;
    else r_ptch_clr <= i_clr;
  end

  wire                            w_mat_rdy;
  wire                            w_pe_rdy;
  wire                            w_pe_vld;
  wire [           CONV_AREA-1:0] w_pe_vld_bus;
  wire [PE_OPT_BIT*CONV_AREA-1:0] w_pe_dat;
  // ====================== reg ============================      
  // ====================== hand shake =====================   
  // ====================== assign =========================  
  assign w_pe_vld_bus = (w_pe_vld) ? {CONV_AREA{1'b1}} : 'd0;
  // ====================== always =========================  
  // ====================== Unpack / Pack ==================  
  // ====================== module =========================  
  pe_array #(
      .OPT_BIT(PE_OPT_BIT),
      .PE_NUM (CONV_AREA)
  ) inst_pe_array (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // wgt
      .i_wgt_din (i_wgt_din),
      .i_wgt_vld (i_wgt_vld),
      // ipt
      .i_ipt_din (i_ipt_din),
      .i_ipt_vld (i_ipt_vld),
      .o_ipt_rdy (o_ipt_rdy),
      // opt
      .i_opt_rdy (w_mat_rdy),
      .o_opt_vld (w_pe_vld),
      .o_opt_dout(w_pe_dat)
  );
  adder_tree #(
      .IPT_BIT(PE_OPT_BIT),
      .IPT_NUM(CONV_AREA)
  ) inst_mac_at (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // ipt
      .o_ipt_rdy (w_mat_rdy),
      .i_ipt_vld (w_pe_vld_bus),
      .i_ipt_din (w_pe_dat),
      // opt
      .i_opt_rdy (i_opt_rdy),
      .o_opt_vld (o_opt_vld),
      .o_opt_dout(o_opt_dout)
  );
endmodule

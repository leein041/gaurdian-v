
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
    //  
    input                                      i_ws_wr_sel,
    input                                      i_ws_rd_sel,
    input                                      i_req_wgt,
    // wgt
    input                                      i_wgt_vld,
    input  signed [            `WGT_BIT  -1:0] i_wgt_din,
    input         [                       3:0] i_kernel_area,
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
  // ====================== wire ===========================

  wire                            w_mat_rdy;
  wire                            w_pe_vld;
  reg  [           CONV_AREA-1:0] w_pe_vld_bus;
  wire [PE_OPT_BIT*CONV_AREA-1:0] w_pe_dat;
  // ====================== assign =========================  
  always @(*) begin
    w_pe_vld_bus = 'd0;
    if (w_pe_vld) begin
      if (i_kernel_area == 1) begin
        w_pe_vld_bus = {1'b1};
      end else if (i_kernel_area == `CONV_3X3_AREA) begin
        w_pe_vld_bus = {CONV_AREA{1'b1}};
      end
    end
  end
  // ====================== module =========================  
  pe_array #(
      .OPT_BIT(PE_OPT_BIT),
      .PE_NUM (CONV_AREA)
  ) inst_pe_array (
      .i_clk        (i_clk),
      .i_rstn       (i_rstn),
      .i_clr        (i_clr),
      // wgt
      .i_req_wgt    (i_req_wgt),
      .i_ws_wr_sel  (i_ws_wr_sel),
      .i_ws_rd_sel  (i_ws_rd_sel),
      .i_kernel_area(i_kernel_area),
      .i_wgt_din    (i_wgt_din),
      .i_wgt_vld    (i_wgt_vld),
      // ipt
      .i_ipt_din    (i_ipt_din),
      .i_ipt_vld    (i_ipt_vld),
      .o_ipt_rdy    (o_ipt_rdy),
      // opt
      .i_opt_rdy    (w_mat_rdy),
      .o_opt_vld    (w_pe_vld),
      .o_opt_dout   (w_pe_dat)
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

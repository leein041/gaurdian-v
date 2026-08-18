
`include "defines.vh"
`include "network_config.vh"
module pe #(
    localparam PE_OUT_BITS = `IPT_BIT + `WGT_BIT,
    localparam DUMMY       = 0
) (
    input                             i_clk,
    input                             i_rstn,
    input                             i_pe_en,
    // wgt 
    input  signed [   `WGT_BIT - 1:0] i_wgt_din,
    // ipt  
    input                             i_ipt_vld,
    input  signed [  `IPT_BIT  - 1:0] i_ipt_din,
    // opt  
    output                            o_opt_vld,
    output signed [PE_OUT_BITS - 1:0] o_opt_dout
);
  mac inst_mac_perf (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_mac_en  (i_pe_en),
      // wgt
      .i_wgt_din (i_wgt_din),
      // ipt  
      .i_ipt_vld (),
      .i_ipt_din (i_ipt_din),
      // opt  
      .o_opt_vld (),
      .o_opt_dout(o_opt_dout)
  );

endmodule



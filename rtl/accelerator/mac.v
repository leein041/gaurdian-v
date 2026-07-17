
`include "defines.vh"
`include "network_config.vh"
module mac #(
    localparam MAC_OUT_BITS = `IPT_BIT + `WGT_BIT,
    localparam DUMMY        = 0
) (
    input                              i_clk,
    input                              i_rstn,
    input                              i_mac_en,
    // wgt
    input  signed [    `WGT_BIT - 1:0] i_wgt_din,
    // ipt  
    input                              i_ipt_vld,
    input  signed [    `IPT_BIT - 1:0] i_ipt_din,
    // opt   
    output                             o_opt_vld,
    output signed [MAC_OUT_BITS - 1:0] o_opt_dout
);
  integer i;

  // ====================== wire =========================== 

  wire signed [MAC_OUT_BITS-1:0] w_mac_dat;

  //      ____            __                                           
  //     |  _ \ ___ _ __ / _| ___  _ __ _ __ ___   __ _ _ __   ___ ___ 
  //     | |_) / _ \ '__| |_ / _ \| '__| '_ ` _ \ / _` | '_ \ / __/ _ \
  //     |  __/  __/ |  |  _| (_) | |  | | | | | | (_| | | | | (_|  __/
  //     |_|   \___|_|  |_|  \___/|_|  |_| |_| |_|\__,_|_| |_|\___\___|
  //        
  dsp_mul_macro dsp (
      .CLK(i_clk),
      .CE (i_mac_en),
      .A  (i_ipt_din),
      .B  (i_wgt_din),
      .P  (w_mac_dat)
  );

  // ====================== output =========================
  assign o_opt_dout = w_mac_dat;
endmodule

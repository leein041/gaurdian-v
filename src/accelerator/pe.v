`timescale 1ns / 1ps
 
 
`include "defines.vh"
module pe #(
    parameter  INPUT_BITS   = 16,
    parameter  WEIGHT_BITS  = 16,
    parameter  PATCH_WIDTH  = 3,
    parameter  PATCH_HEIGHT = 3,
    localparam PATCH_AREA   = PATCH_WIDTH * PATCH_HEIGHT,
    localparam PATCH_SIZE   = INPUT_BITS * PATCH_AREA,
`ifdef RESOURCE
    localparam PE_OUT_BITS  = INPUT_BITS + WEIGHT_BITS + $clog2(PATCH_AREA),
`elsif BALANCE
    localparam PE_OUT_BITS  = INPUT_BITS + WEIGHT_BITS + $clog2(PATCH_HEIGHT),
`elsif PERFORMANCE
    localparam PE_OUT_BITS  = INPUT_BITS + WEIGHT_BITS,
`endif
    localparam DUMMY        = 0
) (
    input                             i_clk,
    input                             i_rstn,
    input                             i_pe_en,
    // wgt 
    input  signed [WEIGHT_BITS - 1:0] i_wgt_din,
    // ipt  
    input                             i_ipt_vld,
    input  signed [INPUT_BITS  - 1:0] i_ipt_din,
    // opt  
    output                            o_opt_vld,
    output signed [PE_OUT_BITS - 1:0] o_opt_dout
);
  //      ____                                    
  //     |  _ \ ___  ___  ___  _   _ _ __ ___ ___ 
  //     | |_) / _ \/ __|/ _ \| | | | '__/ __/ _ \
  //     |  _ <  __/\__ \ (_) | |_| | | | (_|  __/
  //     |_| \_\___||___/\___/ \__,_|_|  \___\___|
  //                                              
`ifdef RESOURCE
  mac #(
      .INPUT_BITS  (INPUT_BITS),
      .WEIGHT_BITS (WEIGHT_BITS),
      .PATCH_WIDTH (PATCH_WIDTH),
      .PATCH_HEIGHT(PATCH_HEIGHT)
  ) inst_mac_rsc (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_mac_en  (i_pe_en),
      // wgt
      .i_wgt_din (i_wgt_din),
      // ipt  
      .i_ipt_vld (i_ipt_vld),
      .i_ipt_din (i_ipt_din),
      // opt  
      .o_opt_vld (o_opt_vld),
      .o_opt_dout(o_opt_dout)
  );
  //      ____        _                      
  //     | __ )  __ _| | __ _ _ __   ___ ___ 
  //     |  _ \ / _` | |/ _` | '_ \ / __/ _ \
  //     | |_) | (_| | | (_| | | | | (_|  __/
  //     |____/ \__,_|_|\__,_|_| |_|\___\___|
  //                                         
`elsif BALANCE
  mac #(
      .INPUT_BITS  (INPUT_BITS),
      .WEIGHT_BITS (WEIGHT_BITS),
      .PATCH_WIDTH (PATCH_WIDTH),
      .PATCH_HEIGHT(PATCH_HEIGHT)
  ) inst_mac_bal (

      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_mac_en  (i_pe_en),
      // wgt
      .i_wgt_din (i_wgt_din),
      // ipt  
      .i_ipt_vld (i_ipt_vld),
      .i_ipt_din (i_ipt_din),
      // opt  
      .o_opt_vld (o_opt_vld),
      .o_opt_dout(o_opt_dout)
  );
  //      ____            __                                           
  //     |  _ \ ___ _ __ / _| ___  _ __ _ __ ___   __ _ _ __   ___ ___ 
  //     | |_) / _ \ '__| |_ / _ \| '__| '_ ` _ \ / _` | '_ \ / __/ _ \
  //     |  __/  __/ |  |  _| (_) | |  | | | | | | (_| | | | | (_|  __/
  //     |_|   \___|_|  |_|  \___/|_|  |_| |_| |_|\__,_|_| |_|\___\___|
  //                                                                   
`elsif PERFORMANCE
  mac #(
      .INPUT_BITS  (INPUT_BITS),
      .WEIGHT_BITS (WEIGHT_BITS),
      .PATCH_WIDTH (PATCH_WIDTH),
      .PATCH_HEIGHT(PATCH_HEIGHT)
  ) inst_mac_perf ( 
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_mac_en  (i_pe_en),
      // wgt
      .i_wgt_din (i_wgt_din),
      // ipt  
      .i_ipt_din (i_ipt_din),
      // opt  
      .o_opt_dout(o_opt_dout)
  );
`endif


endmodule



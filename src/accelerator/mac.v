`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/29 13:08:08
// Design Name: 
// Module Name: mac
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "defines.vh"
module mac #(
    parameter  INPUT_BITS   = 16,
    parameter  WEIGHT_BITS  = 16,
    parameter  PATCH_WIDTH  = 3,
    parameter  PATCH_HEIGHT = 3,
    localparam PATCH_AREA   = PATCH_WIDTH * PATCH_HEIGHT,
`ifdef RESOURCE
    localparam MAC_OUT_BITS = INPUT_BITS + WEIGHT_BITS + $clog2(PATCH_AREA),
`elsif BALANCE
    localparam MAC_OUT_BITS = INPUT_BITS + WEIGHT_BITS + $clog2(PATCH_HEIGHT),
`elsif PERFORMANCE
    localparam MAC_OUT_BITS = INPUT_BITS + WEIGHT_BITS,
`endif
    localparam DUMMY        = 0
) (
    input                              i_clk,
    input                              i_rstn,
    input                              i_mac_en,
    // wgt
    input  signed [ WEIGHT_BITS - 1:0] i_wgt_din,
    // ipt  
    input                              i_ipt_vld,
    input  signed [  INPUT_BITS - 1:0] i_ipt_din,
    // opt   
    output                             o_opt_vld,
    output signed [MAC_OUT_BITS - 1:0] o_opt_dout
);
  integer            i;

  // ====================== wire =========================== 
  wire signed [47:0] w_mac_dat;

`ifdef RESOURCE
  //      ____                                    
  //     |  _ \ ___  ___  ___  _   _ _ __ ___ ___ 
  //     | |_) / _ \/ __|/ _ \| | | | '__/ __/ _ \
  //     |  _ <  __/\__ \ (_) | |_| | | | (_|  __/
  //     |_| \_\___||___/\___/ \__,_|_|  \___\___|
  //                
  // ====================== parmeter =======================  
  localparam ACC_CNT = 8;
  // ====================== reg ============================ 
  reg                            r_opt_vld;
  reg        [$clog2(ACC_CNT):0] r_acc_cnt;
  reg signed [             47:0] r_acc_dat;
  // ====================== always ========================= 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_acc_cnt <= 'd0;
    end else if (i_ipt_vld) begin
      if (r_acc_cnt < ACC_CNT) r_acc_cnt <= r_acc_cnt + 'd1;
      else r_acc_cnt <= 'd0;
    end
  end
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_acc_dat <= 'd0;
    end else if (i_ipt_vld) begin
      if (r_acc_cnt != 'd0) r_acc_dat <= w_mac_dat;
      else r_acc_dat <= 'd0;
    end
  end
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_vld <= 'b0;
    end else begin
      if (r_acc_cnt < ACC_CNT) r_opt_vld <= 'b0;
      else r_opt_vld <= 1'b1;
    end
  end
  // ====================== module ========================= 
  dsp_mac_macro inst_mac (
      .CLK(i_clk),
      .CE (i_ipt_vld),
      .A  (i_ipt_din),
      .B  (i_wgt_din),
      .C  (r_acc_dat),
      .P  (w_mac_dat)
  );
  assign o_opt_vld = r_opt_vld;
`elsif BALANCE
  //      ____        _                      
  //     | __ )  __ _| | __ _ _ __   ___ ___ 
  //     |  _ \ / _` | |/ _` | '_ \ / __/ _ \
  //     | |_) | (_| | | (_| | | | | (_|  __/
  //     |____/ \__,_|_|\__,_|_| |_|\___\___|
  //     
  // ====================== parmeter =======================  
  localparam ACC_CNT = 2;
  // ====================== reg ============================ 
  reg                            r_opt_vld;
  reg        [$clog2(ACC_CNT):0] r_acc_cnt;
  reg signed [             47:0] r_acc_dat;
  // ====================== always ========================= 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_acc_cnt <= 'd0;
    end else if (i_ipt_vld) begin
      if (r_acc_cnt < ACC_CNT) r_acc_cnt <= r_acc_cnt + 'd1;
      else r_acc_cnt <= 'd0;
    end
  end
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_acc_dat <= 'd0;
    end else if (i_ipt_vld) begin
      if (r_acc_cnt != 'd0) r_acc_dat <= w_mac_dat;
      else r_acc_dat <= 'd0;
    end
  end
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_vld <= 'b0;
    end else begin
      if (r_acc_cnt < ACC_CNT) r_opt_vld <= 1'b0;
      else r_opt_vld <= 1'b1;
    end
  end
  // ====================== module ========================= 
  dsp_mac_macro inst_mac (
      .CLK(i_clk),
      .CE (i_ipt_vld),
      .A  (i_ipt_din),
      .B  (i_wgt_din),
      .C  (r_acc_dat),
      .P  (w_mac_dat)
  );
  assign o_opt_vld = r_opt_vld;
`elsif PERFORMANCE
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

`endif
  // ====================== output =========================
  assign o_opt_dout = w_mac_dat[MAC_OUT_BITS-1 : 0];  // 32 + 3 (add 로 인한 3비트 확장) 
endmodule

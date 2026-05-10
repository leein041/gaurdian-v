`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/23 15:34:14
// Design Name: 
// Module Name: TOP_prac1
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
module layer #(
    parameter RELU_EN       = 0,
    parameter PADDING_EN    = 0,
    parameter FMAP_WIDTH    = 5,
    parameter FMAP_HEIGHT   = 5,
    parameter INPUT_BITS    = 16,
    parameter INPUT_WIDTH   = 5,
    parameter INPUT_HEIGHT  = 5,
    parameter WEIGHT_BITS   = 16,
    parameter WEIGHT_WIDTH  = 3,
    parameter WEIGHT_HEIGHT = 3,
    parameter OUTPUT_BITS   = 32,
    parameter OUTPUT_WIDTH  = 3,
    parameter OUTPUT_HEIGHT = 3,
    parameter LINE_WIDTH    = 5,
    parameter LINE_HEIGHT   = 3,
    parameter PATCH_WIDTH   = 3,
    parameter PATCH_HEIGHT  = 3,
    parameter CHANNEL_NUM   = 1,
    parameter LAYER_NUM     = 1,

    localparam WEIGHT_AREA = WEIGHT_WIDTH * WEIGHT_HEIGHT,
    localparam WEIGHT_ADDR = $clog2(WEIGHT_AREA),
    localparam INPUT_AREA  = INPUT_WIDTH * INPUT_HEIGHT,
    localparam INPUT_ADDR  = $clog2(INPUT_AREA),
    localparam OUTPUT_AREA = OUTPUT_WIDTH * OUTPUT_HEIGHT,
    localparam OUTPUT_ADDR = $clog2(OUTPUT_AREA)
) (
    input                                    i_clk,
    input                                    i_rstn,
    input                                    i_st,
    // wgt  
    input                                    i_wgt_vld,
    input  [  WEIGHT_BITS * CHANNEL_NUM-1:0] i_wgt_din_pck,
    output                                   o_wgt_re,
    output [                WEIGHT_ADDR-1:0] o_wgt_raddr,
    output                                   o_wgt_rdn,
    // ipt
    output                                   o_ipt_re,
    output [                 INPUT_ADDR-1:0] o_ipt_raddr,
    output                                   o_ipt_rdy,
    input                                    i_ipt_vld,
    input  [INPUT_BITS * CHANNEL_NUM  - 1:0] i_ipt_din_pck,
    // opt
    input                                    i_opt_rdy,
    output                                   o_opt_vld,
    output [              OUTPUT_BITS - 1:0] o_opt_dout
);
  // ------------------ hand shake -------------------
  // ------------------- parmeter -------------------  
  // --------------------- wire ---------------------
  // debug
  wire dbg_stv = o_ipt_rdy && (!i_ipt_vld);
  wire dbg_bpss = !i_opt_rdy && o_opt_vld;

// ------------------------- reg ------------------------- 

// ------------------------ assign ----------------------- 
  // ------------------------ always ----------------------- 
  // ------------------- Unpack / Pack ------------------- 

  // ------------------------- module ---------------------- 

  local_ctl #(
      .PADDING_EN   (PADDING_EN),
      .FMAP_WIDTH   (FMAP_WIDTH),
      .FMAP_HEIGHT  (FMAP_HEIGHT),
      .INPUT_BITS   (INPUT_BITS),
      .INPUT_WIDTH  (INPUT_WIDTH),
      .INPUT_HEIGHT (INPUT_HEIGHT),
      .WEIGHT_BITS  (WEIGHT_BITS),
      .WEIGHT_WIDTH (WEIGHT_WIDTH),
      .WEIGHT_HEIGHT(WEIGHT_HEIGHT),
      .OUTPUT_BITS  (OUTPUT_BITS),
      .OUTPUT_WIDTH (OUTPUT_WIDTH),
      .OUTPUT_HEIGHT(OUTPUT_HEIGHT),
      .LINE_WIDTH   (LINE_WIDTH),
      .LINE_HEIGHT  (LINE_HEIGHT),
      .PATCH_WIDTH  (PATCH_WIDTH),
      .PATCH_HEIGHT (PATCH_HEIGHT),
      .CHANNEL_NUM  (CHANNEL_NUM)
  ) inst_local_ctl (
      .i_clk      (i_clk),
      .i_rstn     (i_rstn),
      .i_st       (i_st),
      // ipt 
      .i_ipt_vld  (i_ipt_vld),
      .o_ipt_rdy  (),
      // opt
      .i_opt_rdy  (i_opt_rdy),
      .o_opt_vld  (),
      // wgt
      .o_wgt_re   (o_wgt_re),
      .o_wgt_raddr(o_wgt_raddr),
      .o_wgt_rdn  (o_wgt_rdn)
  );
  // pu
  pu #(
      .CHANNEL_NUM  (CHANNEL_NUM),
      .RELU_EN      (RELU_EN),
      .PADDING_EN   (PADDING_EN),
      .FMAP_WIDTH   (FMAP_WIDTH),
      .FMAP_HEIGHT  (FMAP_HEIGHT),
      .INPUT_BITS   (INPUT_BITS),
      .INPUT_WIDTH  (INPUT_WIDTH),
      .INPUT_HEIGHT (INPUT_HEIGHT),
      .WEIGHT_BITS  (WEIGHT_BITS),
      .WEIGHT_WIDTH (WEIGHT_WIDTH),
      .WEIGHT_HEIGHT(WEIGHT_HEIGHT),
      .OUTPUT_BITS  (OUTPUT_BITS),
      .OUTPUT_WIDTH (OUTPUT_WIDTH),
      .OUTPUT_HEIGHT(OUTPUT_HEIGHT),
      .LINE_WIDTH   (LINE_WIDTH),
      .LINE_HEIGHT  (LINE_HEIGHT),
      .PATCH_WIDTH  (PATCH_WIDTH),
      .PATCH_HEIGHT (PATCH_HEIGHT)
  ) inst_pu (
      .i_clk         (i_clk),
      .i_rstn        (i_rstn),
      // wgt 
      .i_wgt_vld     (i_wgt_vld),
      .i_wgt_din_pck(i_wgt_din_pck),
      // ipt
      .o_ipt_rdy     (o_ipt_rdy),
      .i_ipt_vld     (i_ipt_vld),
      .i_ipt_din_pck(i_ipt_din_pck),
      // opt
      .i_opt_rdy     (i_opt_rdy),
      .o_opt_vld     (o_opt_vld),
      .o_opt_dout    (o_opt_dout)
  );

endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/23 16:06:57
// Design Name: 
// Module Name: PU
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



module pu #(
    parameter CHANNEL_NUM   = 1,
    parameter PADDING_EN    = 0,
    parameter RELU_EN       = 0,
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

    localparam PATCH_AREA  = PATCH_WIDTH * PATCH_HEIGHT,
    localparam PATCH_SIZE  = INPUT_BITS * PATCH_AREA,
    localparam OUTPUT_AREA = OUTPUT_WIDTH * OUTPUT_HEIGHT,
    localparam WEIGHT_ADDR = $clog2(WEIGHT_WIDTH * WEIGHT_HEIGHT * CHANNEL_NUM),
    localparam INPUT_ADDR  = $clog2(INPUT_WIDTH * INPUT_HEIGHT * CHANNEL_NUM),
    localparam OUTPUT_ADDR = $clog2(OUTPUT_WIDTH * OUTPUT_HEIGHT * CHANNEL_NUM)
) (
    input                                   i_clk,
    input                                   i_rstn,
    // wgt 
    input                                   i_wgt_vld,
    input  [WEIGHT_BITS * CHANNEL_NUM -1:0] i_wgt_din_pck,
    // previous layer 
    output                                  o_ipt_rdy,
    input                                   i_ipt_vld,
    input  [INPUT_BITS * CHANNEL_NUM - 1:0] i_ipt_din_pck,
    // next layer
    input                                   i_opt_rdy,
    output                                  o_opt_vld,
    output [             OUTPUT_BITS - 1:0] o_opt_dout
);

  // ------------------- parmeter -------------------    
  localparam IDLE = 3'd0;
  localparam SLIDE_WAIT = 3'd1;
  localparam SLIDE_BUSY = 3'd2;
  localparam SLIDE_DONE = 3'd3;
  localparam PROCESS_DONE = 3'd4;

  genvar c;
  genvar g;
  // --------------------- wire ---------------------
  // debug
  wire                                   dbg_stv = o_ipt_rdy && (!i_ipt_vld);
  wire                                   dbg_bpss = !i_opt_rdy && o_opt_vld;

  // I/O port 
  wire [              WEIGHT_BITS - 1:0] w_wgt_dat                           [ 0:CHANNEL_NUM-1];
  wire [               INPUT_BITS - 1:0] w_ipt_dat                           [ 0:CHANNEL_NUM-1];
  // line buffer
  wire                                   w_lbuf_rdy                          [0:CHANNEL_NUM -1];
  wire                                   w_lbuf_vld                          [ 0:CHANNEL_NUM-1];
  wire [               PATCH_SIZE - 1:0] w_lbuf_dat                          [ 0:CHANNEL_NUM-1];
  wire [              CHANNEL_NUM - 1:0] w_lbuf_vld_pck;
  wire [              CHANNEL_NUM - 1:0] w_lbuf_rdy_pck;
  // patch
  wire                                   w_ptch_en;
  wire                                   w_ptch_rdy                          [ 0:CHANNEL_NUM-1];
  wire                                   w_ptch_vld;
  wire [   INPUT_BITS *PATCH_AREA - 1:0] w_ptch_dat;
  // pe
  wire                                   w_pe_rdy                            [ 0:CHANNEL_NUM-1];
  wire                                   w_pe_vld                            [ 0:CHANNEL_NUM-1];
  wire [              OUTPUT_BITS - 1:0] w_pe_dat                            [ 0:CHANNEL_NUM-1];
  wire [              CHANNEL_NUM - 1:0] w_pe_rdy_pck;
  wire [              CHANNEL_NUM - 1:0] w_pe_vld_pck;
  wire [OUTPUT_BITS * CHANNEL_NUM - 1:0] w_pe_dat_pck;
  wire                                   w_pe_all_rdy;
  wire                                   w_pe_all_vld = &w_pe_vld_pck;
  // adder tree
  wire                                   w_at_rdy;
// ------------------------- reg ------------------------- 
  // ------------------ hand shake ------------------ 
  // ------------------------ always ----------------------- 
// ------------------------ assign ----------------------- 
  assign o_ipt_rdy = &w_lbuf_rdy_pck;
  assign w_pe_all_rdy = &w_pe_rdy_pck;
  // ------------------- Unpack / Pack -------------------  
  generate
    for (c = 0; c < CHANNEL_NUM; c = c + 1) begin
      // unpack 
      assign w_wgt_dat[c]                             = i_wgt_din_pck[WEIGHT_BITS*c+:WEIGHT_BITS];

      assign w_ipt_dat[c]                             = i_ipt_din_pck[INPUT_BITS*c+:INPUT_BITS];

      assign w_lbuf_rdy_pck[c]                        = w_lbuf_rdy[c];
      assign w_lbuf_vld_pck[c]                        = w_lbuf_vld[c];

      assign w_pe_rdy_pck[c]                          = w_pe_rdy[c];
      assign w_pe_vld_pck[c]                          = w_pe_vld[c];
      assign w_pe_dat_pck[OUTPUT_BITS*c+:OUTPUT_BITS] = w_pe_dat[c];
    end
  endgenerate

  // ------------------------- module ----------------------  
  generate
    for (g = 0; g < CHANNEL_NUM; g = g + 1) begin : LINE_BUFFER_ARRAY
      line_buffer #(
          .CHANNEL_NUM  (CHANNEL_NUM),
          .PADDING_EN   (PADDING_EN),
          .RELU_EN      (RELU_EN),
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
      ) inst_line_buffer (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          // ipt
          .o_ipt_rdy (w_lbuf_rdy[g]),
          .i_ipt_din (w_ipt_dat[g]),
          .i_ipt_vld (i_ipt_vld),
          // opt
          .i_opt_rdy (w_ptch_rdy[g]),
          .o_ptch_en (w_ptch_en),
          .o_opt_vld (w_lbuf_vld[g]),
          .o_opt_dout(w_lbuf_dat[g])
      );

      patch #(
          .PADDING_EN  (PADDING_EN),
          .INPUT_BITS  (INPUT_BITS),
          .INPUT_WIDTH (INPUT_WIDTH),
          .INPUT_HEIGHT(INPUT_HEIGHT),
          .PATCH_WIDTH (PATCH_WIDTH),
          .PATCH_HEIGHT(PATCH_HEIGHT)
      ) inst_patch (
          .i_clk         (i_clk),
          .i_rstn        (i_rstn),
          .i_ptch_en     (w_ptch_en),
          // ipt
          .i_ipt_din_pck(w_lbuf_dat[g]),
          .i_ipt_vld     (w_lbuf_vld[g]),
          .o_ipt_rdy     (w_ptch_rdy[g]),
          // opt
          .i_opt_rdy     (w_pe_all_rdy),
          .o_opt_vld     (w_ptch_vld),
          .o_opt_dout    (w_ptch_dat)
      );

      pe #(
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
      ) inst_pe (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .i_wgt_vld (i_wgt_vld),
          .i_wgt_din (w_wgt_dat[g]),
          // ipt
          .o_ipt_rdy (w_pe_rdy[g]),
          .i_ipt_vld (w_ptch_vld),
          .i_ipt_din (w_ptch_dat),
          // opt
          .i_opt_rdy (w_at_rdy),
          .o_opt_vld (w_pe_vld[g]),
          .o_opt_dout(w_pe_dat[g])
      );
    end
  endgenerate
  adder_tree #(
      .OUTPUT_BITS(OUTPUT_BITS),
      .INPUT_NUM  (CHANNEL_NUM)
  ) inst_adder_tree (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // ipt
      .o_ipt_rdy (w_at_rdy),
      .i_ipt_vld (w_pe_all_vld),  // 동시 작업이므로 대표로 0번 PE만 
      .i_ipt_din (w_pe_dat_pck),
      // opt
      .i_opt_rdy (i_opt_rdy),
      .o_opt_vld (o_opt_vld),
      .o_opt_dout(o_opt_dout)
  );
endmodule

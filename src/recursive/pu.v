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


// PU에는 3x3 개의 PE가 병렬로 배치되있으며, PATCH에서 9개 데이터를 가져와 각 PE에 뿌림
module pu #(
    parameter CHANNEL_NUM  = 1,
    parameter RELU_EN      = 0,
    parameter INPUT_BITS   = 16,
    parameter WEIGHT_BITS  = 16,
    parameter OUTPUT_BITS  = 32,
    parameter PATCH_WIDTH  = 3,
    parameter PATCH_HEIGHT = 3,
    parameter LINE_WIDTH   = 5,
    parameter LINE_HEIGHT  = 3,

    localparam PATCH_AREA = PATCH_WIDTH * PATCH_HEIGHT,
    localparam PATCH_SIZE = INPUT_BITS * PATCH_AREA
) (
    input                                    i_clk,
    input                                    i_rstn,
    // wgt 
    input                                    i_wgt_vld,
    input  [               WEIGHT_BITS -1:0] i_wgt_din,
    // ipt
    output                                   o_ipt_rdy,
    input                                    i_ipt_vld,
    input  [INPUT_BITS * PATCH_HEIGHT - 1:0] i_ipt_din,
    // opt
    input                                    i_opt_rdy,
    output                                   o_opt_vld,
    output [              OUTPUT_BITS - 1:0] o_opt_dout
);

  // ------------------- parmeter -------------------    
  localparam IDLE = 3'd0;
  localparam SLIDE_WAIT = 3'd1;
  localparam SLIDE_BUSY = 3'd2;
  localparam SLIDE_DONE = 3'd3;
  localparam PROCESS_DONE = 3'd4;

  genvar c;
  genvar p;
  // --------------------- wire --------------------- 
  // debug
  wire                              dbg_stv = o_ipt_rdy && (!i_ipt_vld);
  wire                              dbg_bpss = !i_opt_rdy && o_opt_vld;
  // wgt
  // patch  
  wire                              w_ptch_vld;
  wire [            INPUT_BITS-1:0] w_ptch_dat                          [0:PATCH_AREA-1];
  wire [INPUT_BITS *PATCH_AREA-1:0] w_ptch_dat_pck;
  // pe
  wire                              w_pe_vld                            [0:PATCH_AREA-1];
  wire [            PATCH_AREA-1:0] w_pe_vld_pck;
  wire [           OUTPUT_BITS-1:0] w_pe_dat                            [0:PATCH_AREA-1];
  wire [OUTPUT_BITS*PATCH_AREA-1:0] w_pe_dat_pck;
  // mac at
  wire                              w_mat_rdy;
  // ------------------------- reg ------------------------- 
  reg  [            PATCH_AREA-1:0] w_wgt_vld;
  reg  [      $clog2(PATCH_AREA):0] r_pe_cnt;
  // ------------------------ assign -----------------------   
  // ------------------------ always ----------------------- 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_pe_cnt <= 'd0;
    end else if (i_wgt_vld) begin
      if (r_pe_cnt == PATCH_AREA - 1) begin
        r_pe_cnt <= 'd0;
      end else begin
        r_pe_cnt <= r_pe_cnt + 'd1;
      end
    end
  end

  always @(*) begin
    w_wgt_vld = 'd0;
    if (i_wgt_vld && (r_pe_cnt < PATCH_AREA)) begin
      w_wgt_vld[r_pe_cnt] = 'b1;
    end
  end
  // ------------------- Unpack / Pack -------------------  
  generate
    for (p = 0; p < PATCH_AREA; p = p + 1) begin
      // patch
      assign w_ptch_dat[p]                            = w_ptch_dat_pck[p*INPUT_BITS+:INPUT_BITS];
      // pe
      assign w_pe_vld_pck[p]                          = w_pe_vld[p];
      assign w_pe_dat_pck[p*OUTPUT_BITS+:OUTPUT_BITS] = w_pe_dat[p];
    end
  endgenerate
  // ------------------------- module ----------------------  
  patch #(
      .INPUT_BITS  (INPUT_BITS),
      .PATCH_WIDTH (PATCH_WIDTH),
      .PATCH_HEIGHT(PATCH_HEIGHT),
      .LINE_WIDTH  (LINE_WIDTH),
      .LINE_HEIGHT (LINE_HEIGHT)
  ) inst_patch (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // ipt
      .i_ipt_din (i_ipt_din),
      .i_ipt_vld (i_ipt_vld),
      .o_ipt_rdy (o_ipt_rdy),
      // opt
      .i_opt_rdy (w_mat_rdy),
      .o_opt_vld (w_ptch_vld),
      .o_opt_dout(w_ptch_dat_pck)
  );
  generate
    for (p = 0; p < PATCH_AREA; p = p + 1) begin : LINE_BUFFER_ARRAY
      pe #(
          .INPUT_BITS  (INPUT_BITS),
          .WEIGHT_BITS (WEIGHT_BITS),
          .OUTPUT_BITS (OUTPUT_BITS),
          .PATCH_WIDTH (PATCH_WIDTH),
          .PATCH_HEIGHT(PATCH_HEIGHT)
      ) inst_pe (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .i_pe_en   (w_mat_rdy && w_ptch_vld),
          // wgt
          .i_wgt_vld (w_wgt_vld[p]),
          .i_wgt_din (i_wgt_din),
          // ipt 
          .i_ipt_vld (w_ptch_vld),
          .i_ipt_din (w_ptch_dat[p]),
          // opt 
          .o_opt_vld (w_pe_vld[p]),
          .o_opt_dout(w_pe_dat[p])
      );
    end
  endgenerate
  adder_tree #(
      .BITS     (OUTPUT_BITS),
      .INPUT_NUM(PATCH_AREA)
  ) inst_mac_at (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // ipt
      .o_ipt_rdy (w_mat_rdy),
      .i_ipt_vld (&w_pe_vld_pck),
      .i_ipt_din (w_pe_dat_pck),
      // opt
      .i_opt_rdy (i_opt_rdy),
      .o_opt_vld (o_opt_vld),
      .o_opt_dout(o_opt_dout)
  );

endmodule

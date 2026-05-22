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
module pu_8_8 #(
    parameter WEIGHT_BITS  = 16,
    parameter INPUT_BITS   = 16,
    parameter OUTPUT_BITS  = 36,
    parameter PATCH_WIDTH  = 3,
    parameter PATCH_HEIGHT = 3,
    // PU output bits: 36-bit-> 32(output) + 4(adder tree extension)  
    parameter LINE_WIDTH   = 5,
    parameter LINE_HEIGHT  = 3,

    localparam PATCH_AREA = PATCH_WIDTH * PATCH_HEIGHT,
    localparam PATCH_SIZE = INPUT_BITS * PATCH_AREA,

    localparam PE_OUTPUT_BIT  = INPUT_BITS + WEIGHT_BITS,
    localparam MAT_OUTPUT_BIT = PE_OUTPUT_BIT + $clog2(PATCH_AREA)
) (
    input                                           i_clk,
    input                                           i_rstn,
    input                                           i_clr,
    // wgt 
    input                                           i_wgt_vld,
    input  signed [               WEIGHT_BITS -1:0] i_wgt_din,
    // ipt
    output                                          o_ipt_rdy,
    input                                           i_ipt_vld,
    input  signed [INPUT_BITS * PATCH_HEIGHT - 1:0] i_ipt_din,
    // opt
    input                                           i_opt_rdy,
    output                                          o_opt_vld,
    output signed [           MAT_OUTPUT_BIT - 1:0] o_opt_dout
);
  // ------------------- parmeter -------------------      
  integer i;
  genvar c, p;
  // --------------------- wire ---------------------   
  // patch  
  wire                                         w_ptch_vld;
  wire signed [                INPUT_BITS-1:0] w_ptch_dat     [0:PATCH_HEIGHT-1];
  wire        [  INPUT_BITS *PATCH_HEIGHT-1:0] w_ptch_dat_pck;
  // pe             
  wire                                         w_pe_act;
  wire                                         w_pe_rdy;
  wire signed [             PE_OUTPUT_BIT-1:0] w_pe_dat       [0:PATCH_HEIGHT-1];
  wire        [PE_OUTPUT_BIT*PATCH_HEIGHT-1:0] w_pe_dat_pck;
  // mac at
  wire        [              PATCH_HEIGHT-1:0] w_mat_ipt_vld;
  wire                                         w_mat_rdy;
  // ------------------------- reg ------------------------- 
  reg         [        $clog2(PATCH_AREA)-1:0] r_wgt_cnt;
  reg         [               WEIGHT_BITS-1:0] r_wgt_dat      [  0:PATCH_AREA-1];
  reg         [          $clog2(PATCH_AREA):0] r_pe_cnt;
  reg                                          r_pe_vld;
  reg                                          r_pe_vld_dly1;
  reg                                          r_pe_vld_dly2;
  // ---------------------- hand shake ---------------------  
  assign w_pe_rdy      = w_mat_rdy || !r_pe_vld;
  assign w_pe_act      = w_ptch_vld && w_pe_rdy;
  // ------------------------ assign -----------------------   
  // mat
  assign w_mat_ipt_vld = (r_pe_vld) ? {PATCH_AREA{1'b1}} : 'd0;
  // ------------------------ always ----------------------- 
  // internal PE counter
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
  // weigt counter 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_wgt_cnt <= 'd0;
    end else begin
      if (i_clr) begin
        r_wgt_cnt <= 'd0;
      end else if (w_ptch_vld) begin
        if (r_wgt_cnt < PATCH_HEIGHT - 1) begin
          r_wgt_cnt <= r_wgt_cnt + 'd1;
        end else begin
          r_wgt_cnt <= 'd0;
        end
      end
    end
  end
  // weight data
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      for (i = 0; i < PATCH_AREA; i = i + 1) begin
        r_wgt_dat[i] <= 'd0;
      end
    end else if (i_wgt_vld) begin
      for (i = 1; i < PATCH_AREA; i = i + 1) begin
        r_wgt_dat[i] <= r_wgt_dat[i-1];
      end
      r_wgt_dat[0] <= i_wgt_din;
    end
  end


  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_pe_vld <= 'd0;
    end else if (w_pe_rdy) begin
      r_pe_vld      <= w_ptch_vld;
      r_pe_vld_dly1 <= r_pe_vld;
      r_pe_vld_dly2 <= r_pe_vld_dly1;
    end
  end
  // mac 딜레이
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_pe_vld <= 'd0;
    end else if (w_pe_rdy) begin
      r_pe_vld <= w_ptch_vld;
    end
  end
  // ------------------- Unpack / Pack -------------------  
  generate
    for (p = 0; p < PATCH_HEIGHT; p = p + 1) begin
      // patch
      assign w_ptch_dat[p] = w_ptch_dat_pck[p*INPUT_BITS+:INPUT_BITS];
      // pe 
      assign w_pe_dat_pck[p*PE_OUTPUT_BIT+:PE_OUTPUT_BIT] = w_pe_dat[p];
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
      .i_clr     (i_clr),
      // ipt
      .i_ipt_din (i_ipt_din),
      .i_ipt_vld (i_ipt_vld),
      .o_ipt_rdy (o_ipt_rdy),
      // opt
      .i_opt_rdy (w_pe_rdy),
      .o_opt_vld (w_ptch_vld),
      .o_opt_dout(w_ptch_dat_pck)
  );
  generate
    for (p = 0; p < PATCH_HEIGHT; p = p + 1) begin : LINE_BUFFER_ARRAY
      pe_8_8 #(
          .INPUT_BITS  (INPUT_BITS),
          .WEIGHT_BITS (WEIGHT_BITS),
          .OUTPUT_BITS (PE_OUTPUT_BIT),
          .PATCH_WIDTH (PATCH_WIDTH),
          .PATCH_HEIGHT(PATCH_HEIGHT)
      ) inst_pe (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .i_pe_en   (w_pe_act),
          // wgt 
          .i_wgt_din (r_wgt_dat[p*PATCH_WIDTH+r_wgt_cnt]),
          // ipt  
          .i_ipt_din (w_ptch_dat[p]),
          // opt  
          .o_opt_dout(w_pe_dat[p])
      );
    end
  endgenerate
  adder_tree #(
      .INPUT_BIT(PE_OUTPUT_BIT),
      .INPUT_NUM(PATCH_HEIGHT)
  ) inst_mac_at (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // ipt
      .o_ipt_rdy (w_mat_rdy),
      .i_ipt_vld (w_mat_ipt_vld),
      .i_ipt_din (w_pe_dat_pck),
      // opt
      .i_opt_rdy (i_opt_rdy),
      .o_opt_vld (o_opt_vld),
      .o_opt_dout(o_opt_dout)
  );
endmodule

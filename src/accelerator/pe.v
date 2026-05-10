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



module pe #(
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

    localparam PATCH_AREA = PATCH_WIDTH * PATCH_HEIGHT,
    localparam PATCH_SIZE = INPUT_BITS * PATCH_AREA

) (
    input                                 i_clk,
    input                                 i_rstn,
    // wgt
    input                                 i_wgt_vld,
    input  [           WEIGHT_BITS - 1:0] i_wgt_din,
    // ipt
    output                                o_ipt_rdy,
    input                                 i_ipt_vld,
    input  [INPUT_BITS *PATCH_AREA - 1:0] i_ipt_din,
    // opt
    input                                 i_opt_rdy,
    output                                o_opt_vld,
    output [           OUTPUT_BITS - 1:0] o_opt_dout
);
  // ------------------- parmeter -------------------   

  integer                                i;
  // --------------------- wire --------------------- 
  // debug
  wire                                   dbg_stv = o_ipt_rdy && (!i_ipt_vld);
  wire                                   dbg_bpss = !i_opt_rdy && o_opt_vld;
  // input 
  wire    [              INPUT_BITS-1:0] w_ipt_dat                           [0:PATCH_AREA-1];
  // mac 
  wire                                   w_mac_rdy                          [0:PATCH_AREA-1];
  wire                                   w_mac_vld                          [0:PATCH_AREA-1];
  wire    [             OUTPUT_BITS-1:0] w_mac_dat                          [0:PATCH_AREA-1];
  wire    [OUTPUT_BITS * PATCH_AREA-1:0] w_mac_opt_ppck;
  wire    [              PATCH_AREA-1:0] w_mac_rdy_pck;
  // adder tree
  wire                                   w_at_rdy;
  wire                                   w_at_vld;
  wire    [             OUTPUT_BITS-1:0] w_at_dat;
  // ? 
  wire                                   w_act = o_ipt_rdy && (i_ipt_vld);
// ------------------------- reg ------------------------- 
  // output 
  reg                                    r_opt_vld;
  reg     [           OUTPUT_BITS - 1:0] r_opt_dat;
  //
  reg     [             WEIGHT_BITS-1:0] r_wgt_dat                           [           0:8];
  reg                                    r_ipt_vld_dly;
  //reg  [                      1:0] r_pe_stat;
// ------------------------ assign ----------------------- 
  assign o_opt_vld  = r_opt_vld;
  assign o_opt_dout = r_opt_dat;
  assign o_ipt_rdy  = (i_opt_rdy || !o_opt_vld);  // 받을 준비 조건


  // ------------------ hand shake -------------------  
  // ------------------------ always ----------------------- 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_vld <= 'd0;
      r_opt_dat <= 'd0;
    end else begin
      if (o_ipt_rdy) begin
        r_opt_vld <= w_at_vld;  // 다음 입력이 있으면 유지(1), 없으면 해제(0)
        if (w_at_vld) begin
          r_opt_dat <= w_at_dat;  // 새로운 데이터 캡처
        end
      end
    end
  end

  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      for (i = 0; i < PATCH_AREA; i = i + 1) r_wgt_dat[i] <= 'd0;
    end else if (i_wgt_vld) begin
      r_wgt_dat[PATCH_AREA-1] <= i_wgt_din;
      for (i = 0; i < PATCH_AREA - 1; i = i + 1) r_wgt_dat[i] <= r_wgt_dat[i+1];
    end
  end
  // ------------------- Unpack / Pack -------------------  
  genvar c;
  generate
    for (c = 0; c < PATCH_AREA; c = c + 1) begin : UNPACKED
      assign w_mac_opt_ppck[OUTPUT_BITS*c+:OUTPUT_BITS] = w_mac_dat[c];
      assign w_mac_rdy_pck[c] = w_mac_rdy[c];
      assign w_ipt_dat[c] = i_ipt_din[INPUT_BITS*c+:INPUT_BITS];
    end
  endgenerate
  // ------------------------- module ---------------------- 

  genvar g;
  generate
    for (g = 0; g < PATCH_AREA; g = g + 1) begin : MAC_ARRAY
      mac #(
          .INPUT_BITS (INPUT_BITS),
          .WEIGHT_BITS(WEIGHT_BITS),
          .OUTPUT_BITS(OUTPUT_BITS)
      ) inst_mac (

          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          // wgt
          .i_wgt_din (r_wgt_dat[g]),
          // ipt
          .o_ipt_rdy (w_mac_rdy[g]),
          .i_ipt_vld (i_ipt_vld),
          .i_ipt_din (w_ipt_dat[g]),
          // opt
          .i_opt_rdy (w_at_rdy),
          .o_opt_vld (w_mac_vld[g]),
          .o_opt_dout(w_mac_dat[g])
      );
    end
  endgenerate

  adder_tree #(
      .OUTPUT_BITS(OUTPUT_BITS),
      .INPUT_NUM  (PATCH_AREA)
  ) inst_adder_tree (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // ipt
      .o_ipt_rdy (w_at_rdy),
      .i_ipt_vld (w_mac_vld[0]),
      .i_ipt_din (w_mac_opt_ppck),
      // opt
      .i_opt_rdy (i_opt_rdy),
      .o_opt_vld (w_at_vld),
      .o_opt_dout(w_at_dat)
  );
endmodule

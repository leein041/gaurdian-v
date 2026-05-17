`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/23 15:44:47
// Design Name: 
// Module Name: LINE_BUFFER
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

// 패치는 라인버퍼에서 3개씩 떼와서 3x3 만드는 저장소 역할
module patch #(
    parameter INPUT_BITS   = 16,
    parameter PATCH_WIDTH  = 3,
    parameter PATCH_HEIGHT = 3,
    parameter LINE_WIDTH   = 5,
    parameter LINE_HEIGHT  = 3,

    localparam PATCH_SIZE = INPUT_BITS * PATCH_WIDTH * PATCH_HEIGHT
) (
    input                                i_clk,
    input                                i_rstn,
    // ipt
    input  [INPUT_BITS*PATCH_HEIGHT-1:0] i_ipt_din,
    input                                i_ipt_vld,
    output                               o_ipt_rdy,
    // opt
    input                                i_opt_rdy,
    output                               o_opt_vld,
    output [            PATCH_SIZE- 1:0] o_opt_dout
);


  // ------------------- parmeter -------------------   
  integer i;
  integer j;
  genvar g;
  genvar h;
  // --------------------- wire ---------------------     
  wire w_act = o_ipt_rdy && i_ipt_vld;
  // ------------------ hand shake ------------------- 
  // ------------------------- reg -------------------------  
  // opt
  reg [$clog2(LINE_WIDTH)-1:0] r_ptch_cnt;
  reg [INPUT_BITS-1:0] r_ptch_dat[0:PATCH_HEIGHT-1][0:PATCH_WIDTH-1];
  reg r_opt_vld;

  reg [$clog2(LINE_HEIGHT)-1:0] r_prow[0:PATCH_HEIGHT-1];

  // ------------------------ assign -----------------------   
  // opt
  assign o_ipt_rdy = (i_opt_rdy || !o_opt_vld);
  assign o_opt_vld = r_opt_vld;
  // ------------------------ always ----------------------- 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_ptch_cnt <= 'd0;
      r_prow[0]  <= 'd0;
      r_prow[1]  <= 'd1;
      r_prow[2]  <= 'd2;
    end else if (w_act) begin
      if (r_ptch_cnt < LINE_WIDTH - 1) r_ptch_cnt <= r_ptch_cnt + 'd1;
      else begin
        r_ptch_cnt <= 'd0;
        r_prow[0]  <= r_prow[1];
        r_prow[1]  <= r_prow[2];
        r_prow[2]  <= r_prow[0];
      end
    end
  end

  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_vld <= 'b0;
      for (i = 0; i < PATCH_HEIGHT; i = i + 1) begin
        for (j = 0; j < PATCH_WIDTH; j = j + 1) begin
          r_ptch_dat[i][j] <= 'd0;
        end
      end
    end else begin
      if (o_ipt_rdy) r_opt_vld <= i_ipt_vld && (r_ptch_cnt >= PATCH_WIDTH - 1);
      if (w_act) begin
        for (i = 0; i < PATCH_HEIGHT; i = i + 1) begin
          for (j = 0; j < PATCH_WIDTH - 1; j = j + 1) begin
            r_ptch_dat[i][j] <= r_ptch_dat[i][j+1];
          end
          r_ptch_dat[i][PATCH_WIDTH-1] <= i_ipt_din[r_prow[i]*INPUT_BITS+:INPUT_BITS];
        end
      end
    end
  end

  // ------------------- Unpack / Pack -------------------  
  generate
    for (g = 0; g < PATCH_HEIGHT; g = g + 1) begin
      for (h = 0; h < PATCH_WIDTH; h = h + 1) begin
        assign o_opt_dout[(g*PATCH_WIDTH+h)*INPUT_BITS+:INPUT_BITS] = r_ptch_dat[g][h];
      end
    end
  endgenerate
  // ------------------------- module ---------------------- 


endmodule

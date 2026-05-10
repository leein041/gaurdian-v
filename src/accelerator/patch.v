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

module patch #(
    parameter PADDING_EN   = 0,
    parameter INPUT_BITS   = 16,
    parameter INPUT_WIDTH  = 5,
    parameter INPUT_HEIGHT = 5,
    parameter PATCH_WIDTH  = 3,
    parameter PATCH_HEIGHT = 3,

    localparam PATCH_SIZE = INPUT_BITS * PATCH_WIDTH * PATCH_HEIGHT
) (
    input                                i_clk,
    input                                i_rstn,
    input                                i_ptch_en,
    // ipt
    input  [INPUT_BITS*PATCH_HEIGHT-1:0] i_ipt_din_pck,
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
  // debug
  wire                  dbg_stv = o_ipt_rdy && (!i_ipt_vld);
  wire                  dbg_bpss = !i_opt_rdy && o_opt_vld;
  wire                  w_act = o_ipt_rdy && i_ipt_vld;
  // ------------------ hand shake ------------------- 
// ------------------------- reg -------------------------  
  // opt
  reg  [INPUT_BITS-1:0] r_opt_dat                           [0:PATCH_HEIGHT-1][0:PATCH_WIDTH-1];
  reg                   r_opt_vld;
// ------------------------ assign -----------------------   
  // opt
  assign o_opt_vld = r_opt_vld;
  assign o_ipt_rdy = (i_opt_rdy || !o_opt_vld);
  // ------------------------ always ----------------------- 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_vld <= 'd0;
      for (i = 0; i < PATCH_HEIGHT; i = i + 1) begin
        for (j = 0; j < PATCH_WIDTH; j = j + 1) begin
          r_opt_dat[i][j] <= 'd0;
        end
      end
    end else begin
      if (o_ipt_rdy) begin
        r_opt_vld <= i_ptch_en;
        if (i_ipt_vld) begin
          r_opt_dat[0][0] <= r_opt_dat[0][1];
          r_opt_dat[0][1] <= r_opt_dat[0][2];
          r_opt_dat[0][2] <= i_ipt_din_pck[0*INPUT_BITS+:INPUT_BITS];

          r_opt_dat[1][0] <= r_opt_dat[1][1];
          r_opt_dat[1][1] <= r_opt_dat[1][2];
          r_opt_dat[1][2] <= i_ipt_din_pck[1*INPUT_BITS+:INPUT_BITS];

          r_opt_dat[2][0] <= r_opt_dat[2][1];
          r_opt_dat[2][1] <= r_opt_dat[2][2];
          r_opt_dat[2][2] <= i_ipt_din_pck[2*INPUT_BITS+:INPUT_BITS];
        end
      end
    end
  end

  // ------------------- Unpack / Pack -------------------  
  generate
    for (g = 0; g < PATCH_HEIGHT; g = g + 1) begin
      for (h = 0; h < PATCH_WIDTH; h = h + 1) begin
        assign o_opt_dout[(g*PATCH_WIDTH+h)*INPUT_BITS+:INPUT_BITS] = r_opt_dat[g][h];
      end
    end
  endgenerate
  // ------------------------- module ---------------------- 


endmodule

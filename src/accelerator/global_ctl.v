
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/23 16:06:57
// Design Name: 
// Module Name: global_ctl
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



module global_ctl #(
    parameter LAYER_NUM        = 2,
    parameter INPUT_BITS       = 32'd16,
    parameter WEIGHT_BITS      = 32'd16,
    parameter OUTPUT_BITS      = 32'd32,
    parameter L1_PADDING_EN    = 32'd1,
    parameter L1_INPUT_WIDTH   = 32'd5,
    parameter L1_INPUT_HEIGHT  = 32'd5,
    parameter L1_FMAP_WIDTH    = L1_INPUT_WIDTH + (2 * L1_PADDING_EN),   // 7
    parameter L1_FMAP_HEIGHT   = L1_INPUT_HEIGHT + (2 * L1_PADDING_EN),  // 7
    parameter L1_WEIGHT_WIDTH  = 32'd3,
    parameter L1_WEIGHT_HEIGHT = 32'd3,
    parameter L1_OUTPUT_WIDTH  = 32'd5,                                  // (3 + 2 * 1)
    parameter L1_OUTPUT_HEIGHT = 32'd5,
    parameter L1_LINE_WIDTH    = L1_INPUT_WIDTH + (2 * L1_PADDING_EN),   // (5 + 2 * 1)
    parameter L1_LINE_HEIGHT   = 32'd3,
    parameter L1_PATCH_WIDTH   = 32'd3,
    parameter L1_PATCH_HEIGHT  = 32'd3,
    parameter L1_CHANNEL_NUM   = 32'd1,
    parameter L2_PADDING_EN    = 32'd1,
    parameter L2_INPUT_WIDTH   = 32'd5,
    parameter L2_INPUT_HEIGHT  = 32'd5,
    parameter L2_FMAP_WIDTH    = L2_INPUT_WIDTH + (2 * L2_PADDING_EN),   // 7
    parameter L2_FMAP_HEIGHT   = L2_INPUT_HEIGHT + (2 * L2_PADDING_EN),  // 7
    parameter L2_WEIGHT_WIDTH  = 32'd3,
    parameter L2_WEIGHT_HEIGHT = 32'd3,
    parameter L2_OUTPUT_WIDTH  = 32'd5,                                  // (3 + 2 * 1)
    parameter L2_OUTPUT_HEIGHT = 32'd5,
    parameter L2_LINE_WIDTH    = L2_INPUT_WIDTH + (2 * L2_PADDING_EN),   // (5 + 2 * 1)
    parameter L2_LINE_HEIGHT   = 32'd3,
    parameter L2_PATCH_WIDTH   = 32'd3,
    parameter L2_PATCH_HEIGHT  = 32'd3,
    parameter L2_CHANNEL_NUM   = 32'd1,

    // layer 1
    localparam L1_WEIGHT_AREA = L1_WEIGHT_WIDTH * L1_WEIGHT_HEIGHT,
    localparam L1_WEIGHT_ADDR = $clog2(L1_WEIGHT_AREA),
    localparam L1_INPUT_AREA  = L1_INPUT_WIDTH * L1_INPUT_HEIGHT,
    localparam L1_INPUT_ADDR  = $clog2(L1_INPUT_AREA),
    localparam L1_OUTPUT_AREA = L1_OUTPUT_WIDTH * L1_OUTPUT_HEIGHT,
    localparam L1_OUTPUT_ADDR = $clog2(L1_OUTPUT_AREA),
    localparam L1_FMAP_AREA   = L1_FMAP_WIDTH * L1_FMAP_HEIGHT,
    localparam L1_LINE_AREA   = L1_LINE_WIDTH * L1_LINE_HEIGHT,
    localparam L1_PATCH_AREA  = L1_PATCH_HEIGHT * L1_PATCH_WIDTH,
    localparam L1_PATCH_SIZE  = INPUT_BITS * L1_PATCH_AREA,
    // layer 2
    localparam L2_WEIGHT_AREA = L2_WEIGHT_WIDTH * L2_WEIGHT_HEIGHT,
    localparam L2_WEIGHT_ADDR = $clog2(L2_WEIGHT_AREA),
    localparam L2_INPUT_AREA  = L2_INPUT_WIDTH * L2_INPUT_HEIGHT,
    localparam L2_INPUT_ADDR  = $clog2(L2_INPUT_AREA),
    localparam L2_OUTPUT_AREA = L2_OUTPUT_WIDTH * L2_OUTPUT_HEIGHT,
    localparam L2_OUTPUT_ADDR = $clog2(L2_OUTPUT_AREA)
) (
    input                          i_clk,
    input                          i_rstn,
    input                          i_st,
    // layer 1 
    input                          i_lyr1_rdy,
    input                          i_lyr1_wrdn,
    // layer 2  
    input                          i_lyr2_wrdn,
    // input mem  
    output reg                     o_imem_re,
    output     [L1_INPUT_ADDR-1:0] o_imem_raddr
);
  // ------------------- parmeter ------------------- 

  localparam LP_IDLE = 4'd0;
  localparam LP_LOAD_WEIGHT = 4'd1;
  localparam LP_LOAD_INPUT = 4'd2;
  localparam LP_LOAD_PADD = 4'd3;
  localparam LP_SLIDE_START = 4'd4;
  localparam LP_SLIDE_DONE = 4'd6;
  localparam LP_STORE_OUTPUT = 4'd7;
  localparam LP_DONE = 4'd8;
  localparam LP_WAIT = 4'd9;
  // --------------------- wire --------------------- 
  // ------------------------- reg -------------------------  
  reg [$clog2(L1_FMAP_AREA)-1:0] r_ipt_cnt;  // feature map count  
  // layer 1
  reg [      L1_WEIGHT_ADDR-1:0] r_lyr1_wraddr;  // weight adress
  // layer 2
  reg [      L2_WEIGHT_ADDR-1:0] r_lyr2_wraddr;  // weight adress
  //
  reg [                     3:0] r_lp_cstat;  // current state
  reg [                     3:0] r_lp_nstat;  // next state 
  reg [       L1_INPUT_ADDR-1:0] r_imem_addr;  // input adress
  reg [      L1_OUTPUT_ADDR-1:0] r_omem_addr;  // output address 
  // ------------------------ assign ----------------------- 
  // 왜 -1? -> 레지스터 값 시작이 1부터 이므로 주소 오프셋 조정 
  assign o_imem_raddr = (o_imem_re) ? (r_imem_addr - 'd1) : 'd0;


  // ------------------------ always -----------------------  

  //  initialize and update state register
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_lp_cstat <= LP_IDLE;
    end else if (i_lyr1_rdy) begin
      r_lp_cstat <= r_lp_nstat;
    end
  end
  // compute next state 
  always @(*) begin
    r_lp_nstat = r_lp_cstat;
    case (r_lp_cstat)
      LP_IDLE: begin
        if (i_st) begin
          r_lp_nstat = LP_LOAD_WEIGHT;
        end
      end

      LP_LOAD_WEIGHT: begin
        if (i_lyr1_wrdn && i_lyr2_wrdn) r_lp_nstat = LP_LOAD_INPUT;
      end

      LP_LOAD_INPUT: begin
        if (L1_INPUT_AREA - 1 < r_ipt_cnt) begin
          r_lp_nstat = LP_DONE;
        end
      end
      LP_SLIDE_START: ;
      LP_STORE_OUTPUT: begin
      end
      LP_DONE: begin
        // r_lp_nstat = LP_LOAD_WEIGHT;
      end
      default: ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_ipt_cnt   <= 'd0;
      r_imem_addr <= 'd0;
      r_omem_addr <= 'd0;
      o_imem_re   <= 'd0;


    end else begin
      o_imem_re <= 'd0;
      case (r_lp_nstat)
        LP_IDLE: ;
        LP_LOAD_WEIGHT: ;
        LP_LOAD_INPUT: begin
          if (i_lyr1_rdy) begin
            r_ipt_cnt   <= r_ipt_cnt + 'd1;
            o_imem_re   <= 'd1;
            r_imem_addr <= r_imem_addr + 'd1;
          end else begin
            o_imem_re <= 'd0;  // 중복 읽기 방지 위해 내림
          end
        end
        LP_SLIDE_START: ;
        LP_DONE: ;
        default: ;
      endcase
    end
  end

  // ------------------------- module ---------------------- 



endmodule


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

`include "defines.vh"
// 로컬 컨트롤러는 가중치 주소만 쏴주는 역할, 가중치 버퍼에서 값은 PU로 바로 들어감
module local_ctl #(
    parameter WEIGHT_BITS     = 16,
    parameter L1_CHANNEL_NUM  = 1,
    parameter L1_FILTER_NUM   = 8,
    parameter L1_WEIGHT_DEPTH = 8 * 9,
    parameter L2_CHANNEL_NUM  = 8,
    parameter L2_FILTER_NUM   = 8,
    parameter L2_WEIGHT_DEPTH = 8 * 9,
    parameter L3_CHANNEL_NUM  = 8,
    parameter L3_FILTER_NUM   = 1,
    parameter L3_WEIGHT_DEPTH = 8 * 1,

    localparam MAX_FILTER = `MAX2(L1_FILTER_NUM, `MAX2(L2_FILTER_NUM, L3_FILTER_NUM)),
    localparam MAX_CHANNEL = `MAX2(L1_CHANNEL_NUM, `MAX2(L2_CHANNEL_NUM, L3_CHANNEL_NUM)),
    localparam MAX_WEIGHT_ADDR = $clog2(
        `MAX2(L1_WEIGHT_DEPTH, `MAX2(L2_WEIGHT_DEPTH, L3_WEIGHT_DEPTH))
    )
) (
    input                          i_clk,
    input                          i_rstn,
    // channel and filter
    output [$clog2(MAX_CHANNEL):0] o_ch_num,
    output [ $clog2(MAX_FILTER):0] o_filt_num,
    // line buffer 
    output [      MAX_CHANNEL-1:0] o_lbuf_st,
    // wgt
    input                          i_wgt_st,
    output [                  2:0] o_wgt_re,
    output [  MAX_WEIGHT_ADDR-1:0] o_wgt_raddr,    // weight adress   
    output                         o_wgt_rdn,
    //  ipt
    input                          i_ipt_vld,
    output [      MAX_CHANNEL-1:0] o_ipt_vld_sel,
    // bias
    output [                  2:0] o_bias_sel

);
  // ====================== parmeter ======================= 
-    
  localparam IDLE = 3'd0;
  localparam LOAD_WEIGHT1 = 3'd1;
  localparam PROCESS_LAYER1 = 3'd2;
  localparam LOAD_WEIGHT2 = 3'd3;
  localparam PROCESS_LAYER2 = 3'd4;
  localparam LOAD_WEIGHT3 = 3'd5;
  localparam PROCESS_LAYER3 = 3'd6;
  localparam DONE = 3'd7;
// ====================== wire ===========================

// ====================== reg ============================ 
  // FSM
  reg [                  2:0] r_cstat;
  reg [                  2:0] r_nstat;
  //
  reg [$clog2(MAX_CHANNEL):0] r_ch_num;
  reg [ $clog2(MAX_FILTER):0] r_filt_num;
  // line buffer 
  reg [      MAX_CHANNEL-1:0] r_lbuf_st;
  // wgt
  reg [                  2:0] r_wgt_re;
  reg [  MAX_WEIGHT_ADDR-1:0] r_wgt_raddr;
  reg                         r_wgt_rdn;
  // bias
  reg [                  2:0] r_bias_sel;
  // ====================== assign ========================= 
  assign o_ch_num = r_ch_num;
  assign o_filt_num = r_filt_num;
  // line buffer
  assign o_lbuf_st = r_lbuf_st;
  //   weight
  assign o_wgt_rdn = r_wgt_rdn;
  assign o_wgt_re = r_wgt_re;
  assign o_wgt_raddr = r_wgt_raddr;
  // bias
  assign o_bias_sel = r_bias_sel;
  // ipt         
  assign o_ipt_vld_sel = (i_ipt_vld) ? 
    (r_cstat == PROCESS_LAYER1) ? {{(MAX_CHANNEL-L1_CHANNEL_NUM){1'b0}}, {L1_CHANNEL_NUM{1'b1}}} :
    (r_cstat == PROCESS_LAYER2) ? {{(MAX_CHANNEL-L2_CHANNEL_NUM){1'b0}}, {L2_CHANNEL_NUM{1'b1}}} :
    (r_cstat == PROCESS_LAYER3) ? {{(MAX_CHANNEL-L3_CHANNEL_NUM){1'b0}}, {L3_CHANNEL_NUM{1'b1}}} :
     {MAX_CHANNEL{1'b0}} : {MAX_CHANNEL{1'b0}};
  // ====================== hand shake ===================== 
  // ====================== always ========================= 
// ====================== FSM ============================    

  //  initialize and update state register
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_cstat <= IDLE;
    end else begin
      r_cstat <= r_nstat;
    end
  end
  // compute next state 
  always @(*) begin
    r_nstat = r_cstat;
    case (r_cstat)
      IDLE:           if (i_wgt_st) r_nstat = LOAD_WEIGHT1;
      LOAD_WEIGHT1:   if (r_wgt_raddr == L1_WEIGHT_DEPTH - 1) r_nstat = PROCESS_LAYER1;
      PROCESS_LAYER1: if (i_wgt_st) r_nstat = LOAD_WEIGHT2;
      LOAD_WEIGHT2:   if (r_wgt_raddr == L2_WEIGHT_DEPTH - 1) r_nstat = PROCESS_LAYER2;
      PROCESS_LAYER2: if (i_wgt_st) r_nstat = LOAD_WEIGHT3;
      LOAD_WEIGHT3:   if (r_wgt_raddr == L3_WEIGHT_DEPTH - 1) r_nstat = PROCESS_LAYER3;
      PROCESS_LAYER3: ;  // TODO : 어떤 종료 조건? 
      DONE:           r_nstat = IDLE;
      default:        ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_ch_num    <= 'd0;
      r_filt_num  <= 'd0;
      r_lbuf_st   <= 'd0;
      r_wgt_rdn   <= 'b0;
      r_wgt_re    <= 'd0;
      r_wgt_raddr <= 'd0;
      r_bias_sel  <= 'd0;
    end else begin
      r_wgt_rdn <= 'b0;
      r_wgt_re  <= 'b000;
      r_lbuf_st <= 'd0;
      case (r_cstat)
        IDLE: begin
          if (i_wgt_st) begin
            r_wgt_re   <= 3'b001;
            r_ch_num   <= L1_CHANNEL_NUM;
            r_filt_num <= L1_FILTER_NUM;
          end
        end
        LOAD_WEIGHT1: begin
          if (r_wgt_raddr < L1_WEIGHT_DEPTH - 1) begin
            r_wgt_re    <= 3'b001;
            r_wgt_raddr <= r_wgt_raddr + 'd1;
          end
          if (r_wgt_raddr == L1_WEIGHT_DEPTH - 1) begin
            r_wgt_rdn <= 1'b1;
            r_lbuf_st <= {{(MAX_CHANNEL - L1_CHANNEL_NUM) {1'b0}}, {L1_CHANNEL_NUM{1'b1}}};
          end
        end
        PROCESS_LAYER1: begin
          r_wgt_raddr <= 'd0;
          r_bias_sel  <= 'b001;
          if (i_wgt_st) begin
            r_wgt_re   <= 'b010;
            r_ch_num   <= L2_CHANNEL_NUM;
            r_filt_num <= L2_FILTER_NUM;
          end
        end
        LOAD_WEIGHT2: begin
          if (r_wgt_raddr < L2_WEIGHT_DEPTH - 1) begin
            r_wgt_re    <= 'b010;
            r_wgt_raddr <= r_wgt_raddr + 'd1;
          end
          if (r_wgt_raddr == L2_WEIGHT_DEPTH - 1) begin
            r_lbuf_st <= {{(MAX_CHANNEL - L2_CHANNEL_NUM) {1'b0}}, {L2_CHANNEL_NUM{1'b1}}};
            r_wgt_rdn <= 'b1;
          end

        end
        PROCESS_LAYER2: begin
          r_wgt_raddr <= 'd0;
          r_bias_sel  <= 'b010;
          if (i_wgt_st) begin
            r_wgt_re   <= 'b100;
            r_ch_num   <= L3_CHANNEL_NUM;
            r_filt_num <= L3_FILTER_NUM;
          end
        end
        LOAD_WEIGHT3: begin
          if (r_wgt_raddr < L3_WEIGHT_DEPTH - 1) begin
            r_wgt_re    <= 'b100;
            r_wgt_raddr <= r_wgt_raddr + 'd1;
          end
          if (r_wgt_raddr == L3_WEIGHT_DEPTH - 1) begin
            r_lbuf_st <= {{(MAX_CHANNEL - L3_CHANNEL_NUM) {1'b0}}, {L3_CHANNEL_NUM{1'b1}}};
            r_wgt_rdn <= 'b1;
          end
        end
        PROCESS_LAYER3: begin
          r_wgt_raddr <= 'd0;
          r_bias_sel  <= 'b100;
        end
        DONE: begin
        end
        default: begin
          r_wgt_re <= 'd0;
        end
      endcase
    end
  end


  // ====================== module ========================= 



endmodule

`include "defines.vh"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/23 16:06:57
// Design Name: 
// Module Name: stline_global_ctrl
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


// 글로벌 컨트롤러는 입력 버퍼(이미지) 주소값을 쏴줌. 입력버퍼 데이터값은 바로 첫번째 레이어로 들어감 
module stline_global_ctrl #(
    parameter BITS         = 16,
    parameter IMAGE_NUM    = 1,
    parameter INPUT_DEPTH  = 150 * 150 * 3,
    parameter IMAGE_DEPTH  = 150 * 150,
    parameter OUTPUT_DEPTH = 150 * 150 * 3,

    localparam INPUT_ADDR  = $clog2(INPUT_DEPTH),
    localparam IMAGE_ADDR  = $clog2(IMAGE_DEPTH),
    localparam OUTPUT_ADDR = $clog2(OUTPUT_DEPTH)
) (
    input                    i_clk,
    input                    i_rstn,
    input                    i_st,
    output                   o_ctrl_rdy,
    output                   o_img_st,
    // layer 1 
    input                    i_lyr1_rdy,
    input                    i_lyr1_wrdn,
    // layer 2  
    input                    i_lyr2_wrdn,
    // layer 3
    input                    i_lyr3_wrdn,
    input                    i_lyr3_vld,
    input  [       BITS-1:0] i_lyr3_din,
    // input mem  
    output                   o_ibuf_re,
    output [ INPUT_ADDR-1:0] o_ibuf_raddr,
    // opt mem  
    output                   o_obuf_we,
    output [OUTPUT_ADDR-1:0] o_obuf_addr,
    output [         BITS:0] o_obuf_dout,
    output                   o_done
);
  // ====================== parmeter ======================= 
  localparam IDLE = 2'd0;
  localparam LOAD_WEIGHT = 2'd1;
  localparam COMPUTE_IMAGE = 2'd2;
  localparam DONE_IMAGE = 2'd3;
  // ====================== wire ===========================
  wire                   w_wgt_load_dn;
  wire                   w_img_dn;
  // ====================== reg ============================ 
  reg  [            1:0] r_lp_cstat;  // current state
  reg  [            1:0] r_lp_nstat;  // next state  
  // img
  reg  [    IMAGE_NUM:0] r_img_cnt;
  reg                    r_img_st;
  // ctroller
  reg                    r_ctrl_rdy;
  // wgt 
  // ipt 
  reg                    r_ibuf_re;
  reg  [ INPUT_ADDR-1:0] r_ibuf_rcnt;
  reg  [ INPUT_ADDR-1:0] r_ibuf_addr;
  // opt  
  reg                    r_obuf_we;
  reg  [OUTPUT_ADDR-1:0] r_obuf_addr;
  reg  [OUTPUT_ADDR-1:0] r_obuf_wcnt;
  reg  [         BITS:0] r_obuf_dat;
  reg                    r_o_done;

  // ====================== assign ========================= 
  // cotroller
  assign o_ctrl_rdy   = r_ctrl_rdy;
  assign o_img_st     = r_img_st;
  // wgt
  assign w_wgt_load_dn  = i_lyr1_wrdn && i_lyr2_wrdn && i_lyr3_wrdn;
  // ipt
  assign o_ibuf_re    = r_ibuf_re;
  assign o_ibuf_raddr = r_ibuf_addr;
  // opt 
  assign o_obuf_we    = r_obuf_we;
  assign o_obuf_addr  = r_obuf_addr;
  assign o_obuf_dout  = r_obuf_dat;
  assign o_done       = r_o_done;
  // img
  assign w_img_dn   = (r_obuf_wcnt == IMAGE_DEPTH) && r_obuf_we;
  // ====================== always ========================= 

  //  initialize and update state register
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_lp_cstat <= IDLE;
    end else begin
      r_lp_cstat <= r_lp_nstat;
    end
  end
  // compute next state 
  always @(*) begin
    r_lp_nstat = r_lp_cstat;
    case (r_lp_cstat)
      IDLE:          if (i_st) r_lp_nstat = LOAD_WEIGHT;
      LOAD_WEIGHT:   if (w_wgt_load_dn) r_lp_nstat = COMPUTE_IMAGE;
      COMPUTE_IMAGE: if (w_img_dn) r_lp_nstat = DONE_IMAGE;
      DONE_IMAGE:    r_lp_nstat = (r_img_cnt == IMAGE_NUM) ? IDLE : COMPUTE_IMAGE;
      default:       ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_ctrl_rdy  <= 'd1;
      r_img_st    <= 'd0;
      r_img_cnt   <= 'd0;
      r_ibuf_re   <= 'b0;
      r_ibuf_rcnt <= 'd0;
      r_ibuf_addr <= {INPUT_ADDR{1'b1}};
      r_obuf_we   <= 'd0;
      r_obuf_addr <= {OUTPUT_ADDR{1'b1}};
      r_obuf_wcnt <= 'd0;
      r_obuf_dat  <= 'd0;
      r_o_done    <= 'b0;
    end else begin
      r_ctrl_rdy <= 'd1;  // 일단 항상 받기 
      r_ibuf_re  <= 'b0;
      r_obuf_we  <= 'd0;
      r_o_done   <= 1'b0;
      case (r_lp_cstat)
        IDLE: begin
          r_obuf_addr <= {OUTPUT_ADDR{1'b1}};
          r_obuf_wcnt <= 'd0;
        end
        LOAD_WEIGHT: begin
          if (w_wgt_load_dn && i_lyr1_rdy) begin
            r_img_st <= 'b1;
          end
        end
        COMPUTE_IMAGE: begin
          r_img_st <= 'b0;
          // ipt 
          if (i_lyr1_rdy && (r_ibuf_rcnt < IMAGE_DEPTH)) begin
            r_ibuf_re   <= 'd1;
            r_ibuf_rcnt <= r_ibuf_rcnt + 'd1;
            r_ibuf_addr <= r_ibuf_addr + 'd1;
          end
          //opt
          if (i_lyr3_vld) begin
            r_obuf_we  <= 'd1;
            r_obuf_dat <= i_lyr3_din;
            if (r_obuf_wcnt < OUTPUT_DEPTH) begin
              r_obuf_addr <= r_obuf_addr + 'd1;
              r_obuf_wcnt <= r_obuf_wcnt + 'd1;
            end
          end
          if ((r_obuf_wcnt == IMAGE_DEPTH) && r_obuf_we) begin
            r_o_done  <= 1'b1;
            r_img_cnt <= r_img_cnt + 'd1;
          end
        end
        DONE_IMAGE: begin
          if (r_img_cnt < IMAGE_NUM) r_img_st <= 'b1;
          r_ibuf_rcnt <= 'd0;
          r_obuf_wcnt <= 'd0;
        end
        default: ;
      endcase
    end
  end

  // ====================== module ========================= 



endmodule

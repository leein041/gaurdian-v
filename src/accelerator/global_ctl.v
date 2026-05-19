`include "defines.vh"
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


// 글로벌 컨트롤러는 입력 버퍼(이미지) 주소값을 쏴줌. 입력버퍼 데이터값은 바로 첫번째 레이어로 들어감 
module global_ctl #(
    parameter BITS            = 16,
    // fist layer
    parameter L1_INPUT_DEPTH  = 150 * 150 * 3,
    // last layer
    parameter L3_OUTPUT_DEPTH = 150 * 150 * 3,

    localparam L1_INPUT_ADDR  = $clog2(L1_INPUT_DEPTH),
    localparam L3_OUTPUT_ADDR = $clog2(L3_OUTPUT_DEPTH)
) (
    input                       i_clk,
    input                       i_rstn,
    input                       i_st,
    // layer 1 
    input                       i_lyr1_rdy,
    input                       i_lyr1_wrdn,
    // layer 2  
    input                       i_lyr2_wrdn,
    // layer 3
    input                       i_lyr3_wrdn,
    input                       i_lyr3_vld,
    input  [          BITS-1:0] i_lyr3_din,
    // input mem  
    output                      o_ibuf_re,
    output [ L1_INPUT_ADDR-1:0] o_ibuf_raddr,
    // opt mem  
    output                      o_obuf_we,
    output [L3_OUTPUT_ADDR-1:0] o_obuf_addr,
    output [            BITS:0] o_obuf_dout,
    output                      o_done         // what is this
);
  // ------------------- parmeter -------------------  
  localparam IDLE = 2'd0;
  localparam LOAD_WEIGHT = 2'd1;
  localparam ACT = 2'd2;
  localparam DONE = 2'd3;
  // --------------------- wire --------------------- 
  wire                      w_all_wgtdn;
  // ------------------------- reg -------------------------        
  reg  [               1:0] r_lp_cstat;  // current state
  reg  [               1:0] r_lp_nstat;  // next state  
  // wgt
  reg                       r_lyr1_wgtdn;
  reg                       r_lyr2_wgtdn;
  reg                       r_lyr3_wgtdn;
  // ipt 
  reg                       r_ibuf_re;
  reg  [ L1_INPUT_ADDR-1:0] r_ibuf_addr;
  // opt  
  reg                       r_obuf_we;
  reg  [L3_OUTPUT_ADDR-1:0] r_obuf_addr;
  reg  [L3_OUTPUT_ADDR-1:0] r_obuf_addr_dly;
  reg  [            BITS:0] r_obuf_dat;
  reg                       r_o_done;

  // ------------------------ assign ----------------------- 
  // wgt
  assign w_all_wgtdn  = r_lyr1_wgtdn && r_lyr2_wgtdn && r_lyr3_wgtdn;
  // ipt
  assign o_ibuf_re    = r_ibuf_re;
  assign o_ibuf_raddr = r_ibuf_addr;
  // opt 
  assign o_obuf_we    = r_obuf_we;
  assign o_obuf_addr  = r_obuf_addr_dly;
  assign o_obuf_dout  = r_obuf_dat;
  assign o_done       = r_o_done;
  // ------------------------ always -----------------------  

  //  initialize and update state register
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_lp_cstat <= IDLE;
    end else if (i_lyr1_rdy) begin
      r_lp_cstat <= r_lp_nstat;
    end
  end
  // compute next state 
  always @(*) begin
    r_lp_nstat = r_lp_cstat;
    case (r_lp_cstat)
      IDLE: begin
        if (i_st) begin
          r_lp_nstat = LOAD_WEIGHT;
        end
      end

      LOAD_WEIGHT: begin
        // 각 레이어가 모두 가중치 로드를 마쳤으면 ACT로 천이
        if (w_all_wgtdn) r_lp_nstat = ACT;
      end

      ACT: begin
        // OUTPUT 버퍼 마지막 주소까지 채웠으면 DONE로 천이
        if (o_ibuf_re && (r_obuf_addr_dly == L3_OUTPUT_DEPTH - 1)) r_lp_nstat = DONE;
      end
      DONE: begin
        r_lp_nstat = IDLE;
      end
      default: ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_lyr1_wgtdn    <= 'b0;
      r_lyr2_wgtdn    <= 'b0;
      r_lyr3_wgtdn    <= 'b0;
      r_ibuf_re       <= 'b0;
      r_ibuf_addr     <= 'd0;
      r_obuf_we       <= 'd0;
      r_obuf_addr     <= 'd0;
      r_obuf_addr_dly <= 'd0;
      r_obuf_dat      <= 'd0;
      r_o_done        <= 'b0;
    end else begin
      r_ibuf_re <= 'b0;
      r_obuf_we <= 'd0;
      r_o_done  <= 1'b0;
      case (r_lp_cstat)
        IDLE: begin
          r_obuf_addr <= 'd0;
          r_obuf_addr_dly <= 'd0;
        end
        LOAD_WEIGHT: begin
          if (i_lyr1_wrdn) r_lyr1_wgtdn <= 1'b1;
          if (i_lyr2_wrdn) r_lyr2_wgtdn <= 1'b1;
          if (i_lyr3_wrdn) r_lyr3_wgtdn <= 1'b1;
          if (w_all_wgtdn && i_lyr1_rdy) begin
            r_ibuf_re <= 'b1;
          end
        end
        ACT: begin
          // ipt 
          if (i_lyr1_rdy && (r_ibuf_addr < L1_INPUT_DEPTH - 1)) begin
            r_ibuf_re   <= 'd1;
            r_ibuf_addr <= r_ibuf_addr + 'd1;
          end
          //opt
          if (i_lyr3_vld) begin
            r_obuf_we  <= 'd1;
            r_obuf_dat <= i_lyr3_din;
            if (r_obuf_addr_dly < L3_OUTPUT_DEPTH - 1) begin
              r_obuf_addr <= r_obuf_addr + 1'b1;
              r_obuf_addr_dly <= r_obuf_addr;
            end
          end
`ifdef DEBUG_MODE
          if ((r_obuf_addr_dly == 'd24) && r_obuf_we) r_o_done <= 1'b1;
          if ((r_obuf_addr_dly == 'd49) && r_obuf_we) r_o_done <= 1'b1;
          if ((r_obuf_addr_dly == 'd74) && r_obuf_we) r_o_done <= 1'b1;
`else
          if ((r_obuf_addr_dly == 'd22499) && r_obuf_we) r_o_done <= 1'b1;
          if ((r_obuf_addr_dly == 'd44999) && r_obuf_we) r_o_done <= 1'b1;
          if ((r_obuf_addr_dly == 'd67499) && r_obuf_we) r_o_done <= 1'b1;
`endif
        end
        DONE: begin
          r_lyr1_wgtdn <= 'b0;
          r_lyr2_wgtdn <= 'b0;
          r_lyr3_wgtdn <= 'b0;
          r_ibuf_addr  <= 'd0;
        end
        default: ;
      endcase
    end
  end

  // ------------------------- module ---------------------- 



endmodule


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


// 로컬 컨트롤러는 가중치 주소만 쏴주는 역할, 가중치 버퍼에서 값은 PU로 바로 들어감
module local_ctl #(
    parameter WEIGHT_BITS  = 16,
    parameter WEIGHT_DEPTH = 3,

    localparam WEIGHT_ADDR = $clog2(WEIGHT_DEPTH)
) (
    input                    i_clk,
    input                    i_rstn,
    input                    i_st,
    // wgt
    output                   o_wgt_re,
    output [WEIGHT_ADDR-1:0] o_wgt_raddr,  // weight adress   
    output                   o_wgt_rdn
);
  // ----------------------- parmeter ----------------------  
  localparam LP_IDLE = 2'd0;
  localparam LP_LOAD_WEIGHT1 = 2'd1;
  localparam LP_READ_INPUT1_WAIT = 2'd2;
  localparam LP_LOAD_WEIGHT2 = 2'd1;
  localparam LP_READ_INPUT2_WAIT = 2'd2;
  localparam LP_LOAD_WEIGHT3 = 2'd1;
  localparam LP_READ_INPUT3_WAIT = 2'd2;
  localparam LP_WAIT = 2'd3;
  // ------------------------- wire ------------------------ 
  // ------------------------- reg -------------------------  
  // FSM
  reg [            1:0] r_lp_cstat;  // current state
  reg [            1:0] r_lp_nstat;  // next state 
  // wgt
  reg                   r_wgt_re;
  reg [WEIGHT_ADDR-1:0] r_wgt_raddr;
  reg                   r_wgt_rdn;
  // bias
  reg                   r_bias_re;
  reg [WEIGHT_ADDR-1:0] r_bias_raddr;
  reg                   r_bias_rdn;
  // ------------------------ assign -----------------------    
  assign o_wgt_rdn   = r_wgt_rdn;
  assign o_wgt_re    = r_wgt_re;
  assign o_wgt_raddr = r_wgt_raddr;
  // ---------------------- hand shake --------------------- 
  // ------------------------ always ----------------------- 
  // ------------------------- FSM -------------------------    
  //  initialize and update state register
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_lp_cstat <= LP_IDLE;
    end else begin
      r_lp_cstat <= r_lp_nstat;
    end
  end
  // compute next state 
  always @(*) begin
    r_lp_nstat = r_lp_cstat;
    case (r_lp_cstat)
      LP_IDLE: begin
        if (i_st) r_lp_nstat = LP_LOAD_WEIGHT;
      end
      // 읽기 마쳤으면 WAIT으로 천이
      LP_LOAD_WEIGHT: if (r_wgt_re && (r_wgt_raddr == WEIGHT_DEPTH - 1)) r_lp_nstat = LP_LOAD_BIAS;

LP_LOAD_BIAS : if(r_bias_re && (r_bias_raddr == WEIGHT_DEPTH - 1)) r_lp_nstat = LP_LOAD_BIAS;

      LP_WAIT: r_lp_nstat = LP_IDLE;
      default: ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_wgt_rdn   <= 'b0;
      r_wgt_re    <= 'd0;
      r_wgt_raddr <= 'd0;
    end else begin
      case (r_lp_cstat)
        LP_IDLE: begin
          r_wgt_rdn   <= 'b0;
          r_wgt_raddr <= 'd0;
          if (i_st) begin
            r_wgt_re <= 'b1;
          end else begin
            r_wgt_re <= 'b0;
          end
        end
        LP_LOAD_WEIGHT: begin
          if (r_wgt_raddr < WEIGHT_DEPTH - 1) begin
            r_wgt_re    <= 'b1;
            r_wgt_raddr <= r_wgt_raddr + 'd1;
          end else begin
            r_wgt_re  <= 'b0;
            r_wgt_rdn <= 'b1;
          end
        end
        LP_WAIT: begin
          r_wgt_rdn   <= 'b0;
          r_wgt_re    <= 'd0;
          r_wgt_raddr <= 'd0;
        end
        default: begin
          r_wgt_rdn   <= 'b0;
          r_wgt_re    <= 'd0;
          r_wgt_raddr <= 'd0;
        end
      endcase
    end
  end


  // ------------------------- module ---------------------- 



endmodule

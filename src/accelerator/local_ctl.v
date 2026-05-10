
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



module local_ctl #(
    parameter FMAP_WIDTH    = 5,
    parameter FMAP_HEIGHT   = 5,
    parameter PADDING_EN    = 0,
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

    localparam WEIGHT_AREA = WEIGHT_WIDTH * WEIGHT_HEIGHT,
    localparam WEIGHT_ADDR = $clog2(WEIGHT_AREA),
    localparam INPUT_AREA  = INPUT_WIDTH * INPUT_HEIGHT,
    localparam INPUT_ADDR  = $clog2(INPUT_AREA),
    localparam OUTPUT_AREA = OUTPUT_WIDTH * OUTPUT_HEIGHT,
    localparam OUTPUT_ADDR = $clog2(OUTPUT_AREA),

    localparam FMAP_AREA  = FMAP_WIDTH * FMAP_HEIGHT,
    localparam LINE_AREA  = LINE_WIDTH * LINE_HEIGHT,
    localparam PATCH_AREA = PATCH_HEIGHT * PATCH_WIDTH,
    localparam PATCH_SIZE = INPUT_BITS * PATCH_AREA
) (
    input                        i_clk,
    input                        i_rstn,
    input                        i_st,
    // wgt
    output reg                   o_wgt_re,
    output     [WEIGHT_ADDR-1:0] o_wgt_raddr,  // weight adress   
    output                       o_wgt_rdn,
    // ipt 
    input                        i_ipt_vld,
    output                       o_ipt_rdy,
    output reg                   o_ipt_re,
    output     [ INPUT_ADDR-1:0] o_ipt_raddr,  // input adress  
    // opt
    input                        i_opt_rdy,
    output                       o_opt_vld
);
  // ------------------- parmeter ------------------- 

  localparam LP_IDLE = 4'd0;
  localparam LP_LOAD_WEIGHT = 4'd1;
  localparam LP_LOAD_INPUT = 4'd2;
  localparam LP_DONE = 4'd8;
  localparam LP_WAIT = 4'd9;
  // --------------------- wire --------------------- 
  wire                   w_is_pad;
  wire                   w_ipt_isrt;
  wire                   w_ptch_sld;
  wire                   w_act = o_ipt_rdy;
// ------------------------- reg -------------------------  
  // FSM
  reg  [            3:0] r_lp_cstat;  // current state
  reg  [            3:0] r_lp_nstat;  // next state 
  // wgt
  reg  [WEIGHT_ADDR-1:0] r_wgt_raddr;
  reg                    r_wgt_rdn;
  //ipt
  reg  [ INPUT_ADDR-1:0] r_ipt_raddr;
  reg                    r_ipt_rdn;
// ------------------------ assign -----------------------    
  assign o_wgt_rdn   = r_wgt_rdn;
  assign o_wgt_raddr = (r_wgt_raddr - 'd1);  // address offset
  assign o_ipt_raddr = (r_ipt_raddr - 'd1);  // address offset

  assign o_ipt_rdy   = i_opt_rdy || !o_opt_vld;
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
      LP_LOAD_WEIGHT: begin
        if (r_wgt_rdn) r_lp_nstat = LP_LOAD_INPUT;
      end

      LP_LOAD_INPUT: begin
        if (r_ipt_rdn) r_lp_nstat = LP_DONE;
      end

      LP_DONE: begin
        //
      end
      default: ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      o_wgt_re    <= 'd0;
      r_wgt_raddr <= 'd0;
      o_ipt_re    <= 'd0;
      r_ipt_raddr <= 'd0;
    end else begin 
      o_wgt_re  <= 'd0;
      o_ipt_re  <= 'd0;
      r_ipt_rdn <= 'd0;

      case (r_lp_nstat)
        LP_IDLE: begin
        end
        LP_LOAD_WEIGHT: begin
          if (r_wgt_raddr < WEIGHT_AREA) begin
            o_wgt_re    <= 'd1;
            r_wgt_raddr <= r_wgt_raddr + 'd1;
          end else begin
            r_wgt_rdn <= 'd1;
          end
        end

        LP_LOAD_INPUT: begin
          if (r_ipt_raddr < INPUT_AREA) begin
            o_ipt_re    <= 'd1;
            r_ipt_raddr <= r_ipt_raddr + 'd1;
          end else begin
            r_ipt_rdn   <= 'd1;
            r_ipt_raddr <= 'd0;
          end
        end
        default: ;
      endcase
    end
  end


  // ------------------------- module ---------------------- 



endmodule

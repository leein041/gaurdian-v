`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/29 13:08:08
// Design Name: 
// Module Name: mac
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

/* 
mac이 많아진다
-> 48비트 output register 가 많아진다
-> output register 는 타이밍 안정도를 높이기 위함임
-> 자원 제한적이면 output assign 으로 바로 출력  
-> delay 레지스터는 필수

*/

module mac #(
    parameter WEIGHT_BITS = 16,
    parameter INPUT_BITS  = 16,
    parameter OUTPUT_BITS = 32
) (
    input                             i_clk,
    input                             i_rstn,
    // wgt
    input  signed [WEIGHT_BITS - 1:0] i_wgt_din,
    // ipt
    output                            o_ipt_rdy,
    input                             i_ipt_vld,
    input  signed [ INPUT_BITS - 1:0] i_ipt_din,
    // opt
    input                             i_opt_rdy,
    output                            o_opt_vld,
    output signed [OUTPUT_BITS - 1:0] o_opt_dout
);
  // ----------------------- parmeter ---------------------- 
  localparam DSP_DLY = 1;
  // --------------------- wire ---------------------
  // debug 
  wire                            dbg_stv = o_ipt_rdy && (!i_ipt_vld);
  wire                            dbg_bpss = !i_opt_rdy && o_opt_vld;
  // ? 
  wire signed [OUTPUT_BITS - 1:0] w_dsp_opt;
  wire                            w_act = o_ipt_rdy && (i_ipt_vld);

// ------------------------- reg -------------------------   
  // opt
  reg                             r_opt_vld;
  reg                             r_opt_vld_dly;
  reg         [OUTPUT_BITS - 1:0] r_opt_dat;

  // ------------------ hand shake ------------------- 
// ------------------------ assign -----------------------  
  // opt
  assign o_opt_vld  = r_opt_vld_dly;
  assign o_opt_dout = r_opt_dat;
  // ipt
  assign o_ipt_rdy  = (i_opt_rdy || !o_opt_vld);  // 받을 준비 조건
  // ------------------------ always ----------------------- 
  // output
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_vld     <= 'd0;
      r_opt_vld_dly <= 'd0;
      r_opt_dat     <= 'd0;
    end else begin
      if (o_ipt_rdy) begin
        r_opt_vld     <= i_ipt_vld;  // 다음 입력이 있으면 유지(1), 없으면 해제(0)
        r_opt_vld_dly <= r_opt_vld;
        if (r_opt_vld) begin
          r_opt_dat <= w_dsp_opt;  // 새로운 데이터 캡처
        end
      end
    end
  end
  // ------------------------- module ----------------------  
  dsp_add_macro dsp (
      .CLK(i_clk),
      .CE (w_act),
      .A  (i_ipt_din),
      .B  (i_wgt_din),
      .P  (w_dsp_opt)
  );

endmodule

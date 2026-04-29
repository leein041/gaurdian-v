`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/29 12:59:59
// Design Name: 
// Module Name: adder_tree
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


module adder_tree #(
    parameter INPUT_SIZE   = 9,
    parameter OUTPUT_BITS = 48
) (
    input                                    i_clk,
    input                                    i_rstn,
    input                                    i_valid,
    input  [OUTPUT_BITS * INPUT_SIZE - 1:0] i_data,
    output [                 OUTPUT_BITS:0] o_data,
    output                                   o_valid
);
  localparam STAGES = $clog2(INPUT_SIZE);

  reg [OUTPUT_BITS-1:0] w_stage_data[0:STAGES][0:INPUT_SIZE-1];

  // 1. 스테이지 valid 판별
  reg [STAGES:0] r_valid_pipe;
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) r_valid_pipe <= 0;
    else r_valid_pipe <= {r_valid_pipe[STAGES-1:0], i_valid};
  end

  // 2. 0번 스테이지 초기화
  integer k;
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      for (k = 0; k < INPUT_SIZE; k = k + 1) w_stage_data[0][k] <= 0;
    end else if (i_valid) begin
      for (k = 0; k < INPUT_SIZE; k = k + 1)
      w_stage_data[0][k] <= i_data[k*OUTPUT_BITS+:OUTPUT_BITS];
    end
  end

  // 3. adder tree
  genvar s;
  integer j;
  generate
    for (s = 0; s < STAGES; s = s + 1) begin : STAGE_LOGIC
      localparam CUR_IN_SIZE = (s == 0) ? INPUT_SIZE : (((INPUT_SIZE - 1) >> (s - 1)) + 1);
      localparam CUR_OUT_SIZE = ((CUR_IN_SIZE - 1) >> 1) + 1;

      always @(posedge i_clk or negedge i_rstn) begin
        if (~i_rstn) begin
          for (k = 0; k < INPUT_SIZE; k = k + 1) w_stage_data[s+1][k] <= 0;
        end else if (r_valid_pipe[s]) begin  // 이전 단계 데이터가 유효할 때 연산
          for (j = 0; j < CUR_OUT_SIZE; j = j + 1) begin
            if (2 * j + 1 < CUR_IN_SIZE)
              w_stage_data[s+1][j] <= w_stage_data[s][2*j] + w_stage_data[s][2*j+1];
            else w_stage_data[s+1][j] <= w_stage_data[s][2*j];
          end
        end
      end
    end
  endgenerate

  // 4. Output
  assign o_data  = w_stage_data[STAGES][0];
  assign o_valid = r_valid_pipe[STAGES];
endmodule

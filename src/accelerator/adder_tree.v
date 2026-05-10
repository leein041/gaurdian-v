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
    parameter INPUT_NUM   = 9,
    parameter OUTPUT_BITS = 32
) (
    input                                             i_clk,
    input                                             i_rstn,
    // ipt
    input                                             o_ipt_rdy,
    input                                             i_ipt_vld,
    input             [OUTPUT_BITS * INPUT_NUM - 1:0] i_ipt_din,
    // opt
    input                                             i_opt_rdy,
    output reg                                        o_opt_vld,
    output reg signed [             OUTPUT_BITS -1:0] o_opt_dout
);
  // ------------------ hand shake -------------------
  assign o_ipt_rdy = i_opt_rdy || !o_opt_vld;
  assign w_act     = o_ipt_rdy && (i_ipt_vld);
  // ------------------- parmeter ------------------- 
  localparam STAGES = $clog2(INPUT_NUM);

  genvar s;
  integer                      j;
  integer                      k;
  // ------------------------- reg ------------------------- 
  // 연결되지 않은 레지스터는 합성되지 않음
  reg signed [OUTPUT_BITS-1:0] w_stg_dat [0:STAGES][0:INPUT_NUM-1];
  reg        [       STAGES:0] r_stg_vld;

  // ------------------------ always ----------------------- 



  // 3. adder tree
  generate
    if (0 < STAGES) begin
      always @(posedge i_clk or negedge i_rstn) begin
        if (~i_rstn) begin
          r_stg_vld <= 0;
          for (k = 0; k < INPUT_NUM; k = k + 1) w_stg_dat[0][k] <= 0;
        end else if (o_ipt_rdy) begin
          r_stg_vld <= {r_stg_vld[STAGES-1:0], i_ipt_vld};
          if (i_ipt_vld)  // act
            for (k = 0; k < INPUT_NUM; k = k + 1) begin
              w_stg_dat[0][k] <= i_ipt_din[k*OUTPUT_BITS+:OUTPUT_BITS];
            end
        end
      end
    end else begin
      always @(posedge i_clk or negedge i_rstn) begin
        if (~i_rstn) begin
          r_stg_vld <= 0;
          for (k = 0; k < INPUT_NUM; k = k + 1) w_stg_dat[0][k] <= 0;
        end else if (o_ipt_rdy) begin
          r_stg_vld <= i_ipt_vld;
          if (i_ipt_vld)  // act
            for (k = 0; k < INPUT_NUM; k = k + 1) begin
              w_stg_dat[0][k] <= i_ipt_din[k*OUTPUT_BITS+:OUTPUT_BITS];
            end
        end
      end
    end


    for (s = 0; s < STAGES; s = s + 1) begin : STAGE_LOGIC
      localparam CUR_IN_SIZE = (s == 0) ? INPUT_NUM : (((INPUT_NUM - 1) >> (s - 1)) + 1);
      localparam CUR_OUT_SIZE = ((CUR_IN_SIZE - 1) >> 1) + 1;  // 

      always @(posedge i_clk or negedge i_rstn) begin
        if (~i_rstn) begin
          for (k = 0; k < INPUT_NUM; k = k + 1) w_stg_dat[s+1][k] <= 0;
        end else begin
          if (o_ipt_rdy) begin
            if (r_stg_vld[s]) begin
              for (j = 0; j < CUR_OUT_SIZE; j = j + 1) begin  // 스테이지의 출력단 연결
                if (2 * j + 1 < CUR_IN_SIZE)
                  w_stg_dat[s+1][j] <= w_stg_dat[s][2*j] + w_stg_dat[s][2*j+1];
                else w_stg_dat[s+1][j] <= w_stg_dat[s][2*j];
              end
            end
          end
        end
      end
    end
  endgenerate

  // 4. Output
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      o_opt_vld  <= 'd0;
      o_opt_dout <= 'd0;
    end else begin
      if (o_ipt_rdy) begin
        o_opt_vld <= r_stg_vld[STAGES];
        if (r_stg_vld[STAGES]) begin
          o_opt_dout <= w_stg_dat[STAGES][0];
        end
      end
    end
  end
endmodule

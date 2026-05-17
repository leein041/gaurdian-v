`timescale 1ns / 1ps

module adder_tree #(
    parameter INPUT_NUM = 9,
    parameter BITS      = 32
) (
    input                                      i_clk,
    input                                      i_rstn,
    // ipt
    output                                     o_ipt_rdy,
    input                                      i_ipt_vld,
    input             [BITS * INPUT_NUM - 1:0] i_ipt_din,
    // opt
    input                                      i_opt_rdy,
    output reg                                 o_opt_vld,
    output reg signed [             BITS -1:0] o_opt_dout
);

  // ---------------------- hand shake ---------------------  
  assign o_ipt_rdy = i_opt_rdy || !o_opt_vld;
  // ----------------------- parmeter ---------------------- 
  localparam STAGES = $clog2(INPUT_NUM);
  genvar s;
  integer j, k;
  // ----------------------- function ---------------------- 
  function integer get_stg_size(input integer stage);
    integer i, size;
    begin
      size = INPUT_NUM;
      for (i = 0; i < stage; i = i + 1) begin
        size = ((size - 1) >> 1) + 1;
      end
      get_stg_size = size;
    end
  endfunction
  // ------------------------- reg -------------------------  
  reg signed [BITS-1:0] r_stg_dat [0:STAGES][0:INPUT_NUM-1]; // 스테이지 파이프라인(data)
  reg        [STAGES:0] r_stg_vld; // 스테이지 파이프라인(valid)
  // ------------------------ always ----------------------- 
  // stg0
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_stg_vld[0] <= 1'b0;
    end else if (o_ipt_rdy) begin
      r_stg_vld[0] <= i_ipt_vld;
      if (i_ipt_vld) begin
        for (k = 0; k < INPUT_NUM; k = k + 1) begin
          r_stg_dat[0][k] <= i_ipt_din[k*BITS+:BITS];
        end
      end
    end
  end
  // stg 1~
  generate
    for (s = 0; s < STAGES; s = s + 1) begin : STAGE_LOGIC
      localparam CUR_IN_SIZE = get_stg_size(s);
      localparam CUR_OUT_SIZE = get_stg_size(s + 1);

      always @(posedge i_clk or negedge i_rstn) begin
        if (~i_rstn) begin
          r_stg_vld[s+1] <= 1'b0;
        end else if (o_ipt_rdy) begin
          r_stg_vld[s+1] <= r_stg_vld[s];
          for (j = 0; j < CUR_OUT_SIZE; j = j + 1) begin
            if (2 * j + 1 < CUR_IN_SIZE) begin
              r_stg_dat[s+1][j] <= r_stg_dat[s][2*j] + r_stg_dat[s][2*j+1];
            end else begin
              r_stg_dat[s+1][j] <= r_stg_dat[s][2*j];
            end
          end
        end
      end
    end
  endgenerate
  // opt
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      o_opt_vld <= 1'b0;
    end else begin
      if (o_ipt_rdy) begin  // w_act 를 ipt_rdy 통일 -> LUT 자원 최소화(MUX 생성 제거)
        o_opt_vld  <= r_stg_vld[STAGES];
        o_opt_dout <= r_stg_dat[STAGES][0];
      end
    end
  end
endmodule

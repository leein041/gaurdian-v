`timescale 1ns / 1ps

module adder_tree #(
    parameter  INPUT_NUM  = 9,
    parameter  INPUT_BIT  = 16,
    localparam STAGES     = $clog2(INPUT_NUM),
    localparam OUTPUT_BIT = INPUT_BIT + STAGES
) (
    input                                       i_clk,
    input                                       i_rstn,
    // ipt
    output                                      o_ipt_rdy,
    input         [            INPUT_NUM - 1:0] i_ipt_vld,
    input         [INPUT_BIT * INPUT_NUM - 1:0] i_ipt_din,
    // opt
    input                                       i_opt_rdy,
    output                                      o_opt_vld,
    output signed [           OUTPUT_BIT - 1:0] o_opt_dout
);

  // ---------------------- hand shake ---------------------  
  assign o_ipt_rdy = i_opt_rdy || !o_opt_vld;

  // ----------------------- parameter ---------------------- 

  genvar s;
  integer                     j;

  // ------------------------- reg -------------------------  
  // 모든 스테이지 비트 폭 MAX_BITS
  reg signed [OUTPUT_BIT-1:0] r_stg_dat [0:STAGES] [0:INPUT_NUM-1];
  reg        [ INPUT_NUM-1:0] r_stg_vld [0:STAGES];
  reg                         r_opt_vld;
  reg signed [OUTPUT_BIT-1:0] r_opt_dat;

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

  // ------------------------ assign ----------------------- 
  assign o_opt_vld = r_opt_vld;
  assign o_opt_dout = r_opt_dat; // 정해진 출력 폭만큼 하위 비트가 할당됨 (자동 크롭)

  // ------------------------ Stage 0 ----------------------- 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_stg_vld[0] <= 'd0;
      for (j = 0; j < INPUT_NUM; j = j + 1) begin
        r_stg_dat[0][j] <= 'd0;
      end
    end else if (o_ipt_rdy) begin
      r_stg_vld[0] <= i_ipt_vld;
      for (j = 0; j < INPUT_NUM; j = j + 1) begin
        if (i_ipt_vld[j]) begin
          r_stg_dat[0][j] <= $signed(i_ipt_din[j*INPUT_BIT+:INPUT_BIT]);
        end else begin
          r_stg_dat[0][j] <= 'd0;
        end
      end
    end
  end

  // --------------------- Stage 1 ~ STAGES --------------------- 
  generate
    for (s = 0; s < STAGES; s = s + 1) begin : STAGE_LOGIC
      localparam CUR_IN_SIZE = get_stg_size(s);
      localparam CUR_OUT_SIZE = get_stg_size(s + 1);

      always @(posedge i_clk or negedge i_rstn) begin
        if (~i_rstn) begin
          r_stg_vld[s+1] <= 'd0;
          for (j = 0; j < CUR_OUT_SIZE; j = j + 1) begin
            r_stg_dat[s+1][j] <= 'd0;
          end
        end else if (o_ipt_rdy) begin
          for (j = 0; j < CUR_OUT_SIZE; j = j + 1) begin
            if (2 * j + 1 < CUR_IN_SIZE) begin
              r_stg_vld[s+1][j] <= r_stg_vld[s][2*j] || r_stg_vld[s][2*j+1];
              r_stg_dat[s+1][j] <= (r_stg_vld[s][2*j]   ? r_stg_dat[s][2*j]   : 'd0) + 
                                   (r_stg_vld[s][2*j+1] ? r_stg_dat[s][2*j+1] : 'd0);
            end else begin
              r_stg_vld[s+1][j] <= r_stg_vld[s][2*j];
              r_stg_dat[s+1][j] <= r_stg_vld[s][2*j] ? r_stg_dat[s][2*j] : 'd0;
            end
          end
        end
      end

    end
  endgenerate

  // ------------------------ Output ----------------------- 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_vld <= 1'b0;
      r_opt_dat <= 0;
    end else begin
      if (o_ipt_rdy) begin
        r_opt_vld <= r_stg_vld[STAGES][0];
        if (r_stg_vld[STAGES][0]) begin
          r_opt_dat <= r_stg_dat[STAGES][0];
        end
      end
    end
  end

endmodule

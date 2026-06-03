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

  // ----------------------- parameter ---------------------- 

  genvar s;
  integer                           j;

  // ====================== reg ============================  
  reg signed  [     OUTPUT_BIT-1:0] r_stg_dat     [     1:STAGES] [0:$clog2(INPUT_NUM)];
  reg         [$clog2(INPUT_NUM):0] r_stg_vld     [     1:STAGES];

  wire signed [      INPUT_BIT-1:0] w_ipt_dat_mask[0:INPUT_NUM-1];
  wire signed [     OUTPUT_BIT-1:0] w_stg0_dat    [0:INPUT_NUM-1];
  wire        [      INPUT_NUM-1:0] w_stg0_vld;
  // ====================== function ======================= 
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

  // ====================== assign =========================  

  generate

    if (INPUT_NUM == 1) begin  // bypass
      assign o_ipt_rdy  = i_opt_rdy;
      assign o_opt_vld  = i_ipt_vld;
      assign o_opt_dout = i_ipt_din;
    end else begin
      // masking non valid -> zero
      for (s = 0; s < INPUT_NUM; s = s + 1) begin
        assign w_stg0_vld[s]     = i_ipt_vld[s];
        assign w_ipt_dat_mask[s] = (i_ipt_vld[s]) ? i_ipt_din[s*INPUT_BIT+:INPUT_BIT] : 'd0;
        assign w_stg0_dat[s]     = $signed(w_ipt_dat_mask[s]);
      end
      assign o_ipt_rdy  = i_opt_rdy || !o_opt_vld;
      assign o_opt_vld  = r_stg_vld[STAGES][0];
      assign o_opt_dout = r_stg_dat[STAGES][0];
      for (s = 0; s < STAGES; s = s + 1) begin : STAGE_LOGIC
        localparam CUR_IN_SIZE = get_stg_size(s);
        localparam CUR_OUT_SIZE = get_stg_size(s + 1);
        if (s == 0)
          always @(posedge i_clk or negedge i_rstn) begin
            if (~i_rstn) begin
              r_stg_vld[s+1] <= 'd0;
            end else if (o_ipt_rdy) begin
              for (j = 0; j < CUR_OUT_SIZE; j = j + 1) begin
                if (2 * j + 1 < CUR_IN_SIZE) begin
                  r_stg_vld[s+1][j] <= i_ipt_vld[2*j] || i_ipt_vld[2*j+1];
                  r_stg_dat[s+1][j] <= w_stg0_dat[2*j] + w_stg0_dat[2*j+1];
                end else begin
                  r_stg_vld[s+1][j] <= i_ipt_vld[2*j];
                  r_stg_dat[s+1][j] <= w_stg0_dat[2*j];
                end
              end
            end
          end
        else
          always @(posedge i_clk or negedge i_rstn) begin
            if (~i_rstn) begin
              r_stg_vld[s+1] <= 'd0;
            end else if (o_ipt_rdy) begin
              for (j = 0; j < CUR_OUT_SIZE; j = j + 1) begin
                if (2 * j + 1 < CUR_IN_SIZE) begin
                  r_stg_vld[s+1][j] <= r_stg_vld[s][2*j] || r_stg_vld[s][2*j+1];
                  r_stg_dat[s+1][j] <= r_stg_dat[s][2*j] + r_stg_dat[s][2*j+1];
                end else begin
                  r_stg_vld[s+1][j] <= r_stg_vld[s][2*j];
                  r_stg_dat[s+1][j] <= r_stg_dat[s][2*j];
                end
              end
            end
          end
      end
    end
  endgenerate

  // ====================== output =========================
endmodule

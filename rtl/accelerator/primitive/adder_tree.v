`timescale 1ns / 1ps

module adder_tree #(
    parameter  IPT_NUM    = 9,
    parameter  IPT_BIT    = 16,
    localparam STAGES     = $clog2(IPT_NUM),
    localparam OUTPUT_BIT = IPT_BIT + STAGES
) (
    input                                   i_clk,
    input                                   i_rstn,
    // ipt
    output                                  o_ipt_rdy,
    input         [          IPT_NUM - 1:0] i_ipt_vld,
    input         [IPT_BIT * IPT_NUM - 1:0] i_ipt_din,
    // opt
    input                                   i_opt_rdy,
    output                                  o_opt_vld,
    output signed [       OUTPUT_BIT - 1:0] o_opt_dout
);
  // ====================== parmeter =======================  
  genvar s;
  integer                      j;
  // ====================== wire ===========================
  wire signed [OUTPUT_BIT-1:0] w_stg0_dat [0:IPT_NUM-1];
  wire        [   IPT_NUM-1:0] w_stg0_vld;

  // ====================== reg ============================  
  reg signed  [OUTPUT_BIT-1:0] r_stg_dat  [   1:STAGES] [0:IPT_NUM/2];
  reg                          r_stg_vld  [   1:STAGES];

  // ====================== function ======================= 
  function integer get_stg_size(input integer stage);
    integer i, size;
    begin
      size = IPT_NUM;
      for (i = 0; i < stage; i = i + 1) begin
        size = ((size - 1) >> 1) + 1;
      end
      get_stg_size = size;
    end
  endfunction

  // ====================== assign =========================  

  generate
    // bypass
    if (IPT_NUM == 1) begin
      assign o_ipt_rdy  = i_opt_rdy;
      assign o_opt_vld  = i_ipt_vld;
      assign o_opt_dout = i_ipt_din;

    end else begin
      assign o_ipt_rdy  = i_opt_rdy || !o_opt_vld;
      assign o_opt_vld  = r_stg_vld[STAGES];
      assign o_opt_dout = r_stg_dat[STAGES][0];

      // muxing 'input' or 'zero'
      assign w_stg0_vld = |i_ipt_vld;
      for (s = 0; s < IPT_NUM; s = s + 1) begin
        assign w_stg0_dat[s] = $signed((i_ipt_vld[s]) ? i_ipt_din[s*IPT_BIT+:IPT_BIT] : 'd0);
      end

      for (s = 0; s < STAGES; s = s + 1) begin : STAGE_LOGIC
        localparam CUR_IN_SIZE = get_stg_size(s);
        localparam CUR_OUT_SIZE = get_stg_size(s + 1);
        // stage 0    
        if (s == 0)
          always @(posedge i_clk or negedge i_rstn) begin
            if (~i_rstn) begin
              r_stg_vld[s+1] <= 'b0;
            end else if (o_ipt_rdy) begin
              r_stg_vld[s+1] <= w_stg0_vld;
              for (j = 0; j < CUR_OUT_SIZE; j = j + 1) begin
                if (2 * j + 1 < CUR_IN_SIZE) begin
                  r_stg_dat[s+1][j] <= w_stg0_dat[2*j] + w_stg0_dat[2*j+1];
                end else begin
                  r_stg_dat[s+1][j] <= w_stg0_dat[2*j];
                end
              end
            end
          end
        else
          // stage 1~
          always
            @(posedge i_clk or negedge i_rstn) begin
              if (~i_rstn) begin
                r_stg_vld[s+1] <= 'b0;
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
    end
  endgenerate

  // ====================== output =========================
endmodule

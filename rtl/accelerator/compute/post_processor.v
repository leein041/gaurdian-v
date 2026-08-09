
`include "defines.vh"
`include "network_config.vh"
module post_proccessor (
    input                                     i_clk,
    input                                     i_rstn,
    //
    input                                     i_relu,
    input                                     i_bias_swap,
    input                                     i_bias_vld,
    input  [ `IPT_BIT* `MAX_GROUP_FILTER-1:0] i_bias_din,
    //
    input  [`PSUM_BIT* `MAX_GROUP_FILTER-1:0] i_ipt_din,
    input                                     i_ipt_vld,
    //
    output                                    o_opt_vld,
    output [ `OPT_BIT* `MAX_GROUP_FILTER-1:0] o_opt_dout
);
  // ====================== parmeter =======================  
  integer i;
  genvar p;
  // ====================== reg ============================
  reg                                           r_sel;
  reg signed  [                   `IPT_BIT-1:0] r_bias_dat     [0:`MAX_GROUP_FILTER-1] [0:1];
  // ============F========== wire ===========================
  wire signed [                   `IPT_BIT-1:0] w_cur_bias     [0:`MAX_GROUP_FILTER-1];
  wire signed [                  `PSUM_BIT-1:0] w_bias_ex_dat  [0:`MAX_GROUP_FILTER-1];
  // adder 
  wire                                          w_adder_vld    [0:`MAX_GROUP_FILTER-1];
  wire signed [                  `PSUM_BIT-1:0] w_adder_dat    [0:`MAX_GROUP_FILTER-1];
  // slicer 
  wire                                          w_slicer_vld   [0:`MAX_GROUP_FILTER-1];
  wire        [                   `OPT_BIT-1:0] w_slicer_dat   [0:`MAX_GROUP_FILTER-1];
  // relu 
  wire                                          w_relu_vld     [0:`MAX_GROUP_FILTER-1];
  wire        [                   `OPT_BIT-1:0] w_relu_dat     [0:`MAX_GROUP_FILTER-1];
  wire        [ `MAX_GROUP_FILTER*`OPT_BIT-1:0] w_relu_dat_bus;
  //
  wire        [`PSUM_BIT*`MAX_GROUP_FILTER-1:0] w_sum;
  // ====================== assign =========================   
  generate
    for (p = 0; p < `MAX_GROUP_FILTER; p = p + 1) begin
      assign w_cur_bias[p] = (r_sel == 0) ? r_bias_dat[p][1] : r_bias_dat[p][0];
      assign w_relu_dat_bus[p*`OPT_BIT+:`OPT_BIT] = w_relu_dat[p];
    end
  endgenerate
  // ====================== always =========================  
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_sel <= 'b0;
    end else begin
      if (i_bias_swap) r_sel <= ~r_sel;
    end
  end
  // update bias data
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      for (i = 0; i < `MAX_GROUP_FILTER; i = i + 1) r_bias_dat[i][0] <= 'd0;
      for (i = 0; i < `MAX_GROUP_FILTER; i = i + 1) r_bias_dat[i][1] <= 'd0;

    end else if (i_bias_vld) begin
      if (r_sel == 0) begin
        for (i = 0; i < `MAX_GROUP_FILTER; i = i + 1) begin
          r_bias_dat[i][0] <= i_bias_din[i*`IPT_BIT+:`IPT_BIT];
        end
      end else begin
        for (i = 0; i < `MAX_GROUP_FILTER; i = i + 1) begin
          r_bias_dat[i][1] <= i_bias_din[i*`IPT_BIT+:`IPT_BIT];
        end
      end
    end
  end
  // ====================== module ========================= 
  for (p = 0; p < `MAX_GROUP_FILTER; p = p + 1) begin
    bit_extender #(
        .IPT_BIT(`IPT_BIT),
        .OPT_BIT(`PSUM_BIT),
        .LSB_PAD(8),
        .SIGNED (1)
    ) inst_bit_extender (
        .i_din (w_cur_bias[p]),
        .o_dout(w_bias_ex_dat[p])
    );
    // bias adder
    adder #(
        .BIT(`PSUM_BIT)
    ) inst_bias_adder (
        .i_clk     (i_clk),
        .i_rstn    (i_rstn),
        .o_ipt1_rdy(),
        .i_ipt1_vld(i_ipt_vld),
        .i_ipt1_din(i_ipt_din[p*`PSUM_BIT+:`PSUM_BIT]),
        .o_ipt2_rdy(),
        .i_ipt2_vld('b1),
        .i_ipt2_din(w_bias_ex_dat[p]),
        .i_opt_rdy ('b1),                                // TODO
        .o_opt_vld (w_adder_vld[p]),
        .o_opt_dout(w_adder_dat[p])
    );

    // bit slice
    bit_slicer #(
        .IPT_BIT(`PSUM_BIT),
        .OPT_BIT(`OPT_BIT)
    ) inst_bit_slicer (
        .i_clk     (i_clk),
        .i_rstn    (i_rstn),
        .i_ipt_din (w_adder_dat[p]),
        .i_ipt_vld (w_adder_vld[p]),
        .o_ipt_rdy (),
        .i_opt_rdy ('b1),
        .o_opt_vld (w_slicer_vld[p]),
        .o_opt_dout(w_slicer_dat[p])
    );

    // ReLU
    relu #(
        .BIT(`OPT_BIT)
    ) inst_relu (
        .i_clk     (i_clk),
        .i_rstn    (i_rstn),
        .i_relu_en (i_relu),           // TODO
        // ipt
        .i_ipt_din (w_slicer_dat[p]),
        .i_ipt_vld (w_slicer_vld[p]),
        .o_ipt_rdy (),
        // opt
        .i_opt_rdy ('b1),
        .o_opt_vld (w_relu_vld[p]),
        .o_opt_dout(w_relu_dat[p])
    );
  end
  // ====================== output ========================= 
  assign o_opt_vld  = w_relu_vld[0];
  assign o_opt_dout = w_relu_dat_bus;
endmodule

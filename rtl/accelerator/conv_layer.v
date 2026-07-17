
`include "defines.vh"
`include "network_config.vh"
module conv_layer (
    input                                   i_clk,
    input                                   i_rstn,
    input                                   i_clr,
    // bias
    input                                   i_bias_vld,
    input  [                  `IPT_BIT-1:0] i_bias_din,
    // wgt    
    input                                   i_wgt_vld,
    input  [                  `WGT_BIT-1:0] i_wgt_din,
    // ipt 
    output                                  o_ipt_rdy,
    input                                   i_ipt_vld,
    input  [`IPT_BIT*`MAX_GROUP_FILTER-1:0] i_ipt_din,
    // opt
    input                                   i_opt_rdy,
    output                                  o_opt_vld,
    output [      `IPT_BIT*`MAX_FILTER-1:0] o_opt_dout,
    // temp
    input                                   i_relu_en,
    input  [      $clog2(`MAX_TILE_SIDE):0] i_tile_side,
    input  [   $clog2(`MAX_GROUP_FILTER):0] i_ch_num,
    input  [         $clog2(`MAX_FILTER):0] i_pu_num,
    input  [        `MAX_GROUP_CHANNEL-1:0] i_ch_mask,
    input  [         `MAX_GROUP_FILTER-1:0] i_pu_mask
);
  // ====================== parmeter =======================   
  localparam LINE_HEIGHT = `CONV_3X3_SIDE;
  localparam PE_OPT_BIT = `IPT_BIT + `WGT_BIT;
  localparam PU_OPT_BIT = PE_OPT_BIT + $clog2(`CONV_3X3_AREA);
  localparam AT_OPT_BIT = PU_OPT_BIT + $clog2(`MAX_GROUP_FILTER);
  localparam AD_OPT_BIT = AT_OPT_BIT + 1;

  localparam LINEBUFFER_SIDE = `MAX_IPT_SIDE + 2;
  localparam LINEBUFFER_AREA = LINEBUFFER_SIDE * LINEBUFFER_SIDE;

  integer i, j;
  genvar l, c, p;
  // ====================== wire =========================== 
  // IO port 
  wire signed [`IPT_BIT-1:0] w_ipt_dat[0:`MAX_GROUP_FILTER-1];
  // line bufferS   
  wire w_lbuf_rdy;
  wire w_lbuf_vld;
  wire [`IPT_BIT* `MAX_GROUP_CHANNEL*LINE_HEIGHT-1:0] w_lbuf_dat_bus;
  wire [`IPT_BIT*LINE_HEIGHT-1:0] w_lbuf_dat[0:`MAX_GROUP_CHANNEL];
  // patch
  wire [`MAX_GROUP_FILTER-1:0] w_ptch_rdy;
  wire [`MAX_GROUP_FILTER-1:0] w_ptch_vld;
  wire [`IPT_BIT*`CONV_3X3_AREA-1:0] w_ptch_dat[0:`MAX_GROUP_FILTER-1];
  // pu
  wire w_pu_rdy[0:`MAX_FILTER-1][0:`MAX_GROUP_FILTER-1];
  wire w_pu_vld[0:`MAX_FILTER-1][0:`MAX_GROUP_FILTER-1];
  wire [`MAX_GROUP_FILTER-1:0] w_pu_vld_bus[0:`MAX_FILTER-1];
  wire signed [PU_OPT_BIT-1:0] w_pu_dat[0:`MAX_FILTER-1][0:`MAX_GROUP_FILTER-1];
  wire [`MAX_GROUP_FILTER*PU_OPT_BIT-1:0] w_pu_dat_bus[0:`MAX_FILTER-1];
  // channel adder tree 
  wire w_cat_rdy[0:`MAX_FILTER-1];
  wire w_cat_vld[0:`MAX_FILTER-1];
  wire signed [AT_OPT_BIT-1:0] w_cat_dat[0:`MAX_FILTER-1];
  // bias 
  wire signed [AT_OPT_BIT-1:0] w_bias_exdat[0:`MAX_FILTER-1];

  // adder
  wire w_adder_rdy1[0:`MAX_FILTER-1];
  wire w_adder_rdy2[0:`MAX_FILTER-1];
  wire w_adder_vld[0:`MAX_FILTER-1];
  wire signed [AD_OPT_BIT-1:0] w_adder_dat[0:`MAX_FILTER-1];
  // slicer
  wire w_slicer_rdy[0:`MAX_FILTER-1];
  wire w_slicer_vld[0:`MAX_FILTER-1];
  wire [`OPT_BIT-1:0] w_slicer_dat[0:`MAX_FILTER-1];
  // relu
  wire w_relu_rdy[0:`MAX_FILTER-1];
  wire w_relu_vld[0:`MAX_FILTER-1];
  wire [`OPT_BIT-1:0] w_relu_dat[0:`MAX_FILTER-1];
  wire [`MAX_FILTER*`IPT_BIT-1:0] w_relu_dat_bus;


  // ====================== reg ============================ 
  // interenal counter
  reg [$clog2(`MAX_FILTER):0] r_pu_idx;
  reg [$clog2(`MAX_GROUP_FILTER):0] r_ch_idx;
  reg [$clog2(`CONV_3X3_AREA):0] r_pe_idx;
  // line buffer    
  reg [`MAX_GROUP_FILTER-1:0] r_lbuf_st;  // for timing with below
  reg [$clog2(`MAX_TILE_SIDE+2):0] r_pad_tile_side;
  reg [$clog2(LINEBUFFER_AREA):0] r_tile_area;
  // pu
  reg signed [`WGT_BIT-1:0] r_pu_wdat;
  reg r_pu_wvld[0:`MAX_FILTER-1][0:`MAX_GROUP_FILTER-1];
  // bias 
  reg signed [`IPT_BIT-1:0] r_bias_dat[0:`MAX_FILTER-1];
  reg r_bias_vld;
  // adder
  reg [`MAX_FILTER-1:0] r_add_vld;
  // pipe line 1 : slice
  reg r_88_vld;
  reg signed [`IPT_BIT-1:0] r_88_dat[0:`MAX_FILTER-1];
  // pipe line 1 : relu
  reg r_relu_vld;
  reg signed [`IPT_BIT-1:0] r_relu_dat[0:`MAX_FILTER-1];

  // ====================== hand shake ===================== 

  // ====================== assign =========================   
  assign o_ipt_rdy = w_lbuf_rdy;
  generate
    for (c = 0; c < `MAX_GROUP_CHANNEL; c = c + 1) begin
      for (l = 0; l < LINE_HEIGHT; l = l + 1) begin
        assign w_lbuf_dat[c][`IPT_BIT*l+:`IPT_BIT] = w_lbuf_dat_bus[`IPT_BIT*(c + l*`MAX_GROUP_CHANNEL)+:`IPT_BIT];
      end
    end
  endgenerate

  generate
    for (c = 0; c < `MAX_GROUP_FILTER; c = c + 1) begin
      for (p = 0; p < `MAX_FILTER; p = p + 1) begin
        assign w_pu_vld_bus[p][c]                        = w_pu_vld[p][c];
        assign w_pu_dat_bus[p][c*PU_OPT_BIT+:PU_OPT_BIT] = w_pu_dat[p][c];
      end
    end

    for (p = 0; p < `MAX_FILTER; p = p + 1) begin
      assign w_bias_exdat[p] = $signed(r_bias_dat[p]) << 8;
      assign w_relu_dat_bus[p*`IPT_BIT+:`IPT_BIT] = w_relu_dat[p];
    end
  endgenerate
  // ====================== always ========================= 

  // comput line buffer size   
  always @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
      r_pad_tile_side <= 'd0;
      r_tile_area <= 'd0;
    end else begin
      if (i_clr) begin
        r_pad_tile_side <= i_tile_side + 2;
        r_tile_area     <= i_tile_side * i_tile_side;  // TODO :
      end
    end
  end

  // count internal index
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_pe_idx <= 'd0;
      r_pu_idx <= 'd0;
      r_ch_idx <= 'd0;
    end else if (i_wgt_vld) begin
      if (r_pe_idx < `CONV_3X3_AREA - 1) r_pe_idx <= r_pe_idx + 'd1;
      else begin
        r_pe_idx <= 'd0;
        if (r_ch_idx < i_ch_num - 1) r_ch_idx <= r_ch_idx + 'd1;
        else begin
          r_ch_idx <= 'd0;
          if (r_pu_idx < i_pu_num - 1) r_pu_idx <= r_pu_idx + 'd1;
          else r_pu_idx <= 'd0;
        end
      end
    end
  end

  // select PU for initializing weight data
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_pu_wdat <= 'd0;
      for (i = 0; i < `MAX_FILTER; i = i + 1)
      for (j = 0; j < `MAX_GROUP_FILTER; j = j + 1) r_pu_wvld[i][j] <= 'b0;

    end else begin
      for (i = 0; i < `MAX_FILTER; i = i + 1)
      for (j = 0; j < `MAX_GROUP_FILTER; j = j + 1) begin
        if (i_wgt_vld && (r_pu_idx == i) && (r_ch_idx == j)) begin
          r_pu_wvld[i][j] <= 1'b1;
          r_pu_wdat       <= i_wgt_din;
        end else r_pu_wvld[i][j] <= 1'b0;
      end
    end
  end

  // update bias data
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      for (i = 0; i < `MAX_FILTER; i = i + 1) r_bias_dat[i] <= 'd0;
      r_bias_vld <= 'd0;
    end else begin
      if (i_bias_vld) begin
        r_bias_vld                <= 'b1;
        r_bias_dat[`MAX_FILTER-1] <= i_bias_din;
        for (i = 0; i < `MAX_FILTER - 1; i = i + 1) r_bias_dat[i] <= r_bias_dat[i+1];
      end else r_bias_vld <= 'b0;
    end
  end

  // ====================== module =========================    
  line_buffer #(
      .LINE_BIT   (`IPT_BIT * `MAX_GROUP_CHANNEL),
      .LINE_HEIGHT(LINE_HEIGHT),
      .LINE_SIDE  (`MAX_TILE_SIDE + 2)              // padded
  ) inst_line_buffer (
      .i_clk      (i_clk),
      .i_rstn     (i_rstn),
      .i_clr      (i_clr),
      // ipt
      .o_ipt_rdy  (o_ipt_rdy),
      .i_ipt_din  (i_ipt_din),
      .i_ipt_vld  (i_ipt_vld),
      // opt
      .i_opt_rdy  (w_ptch_rdy[0]),
      .o_opt_vld  (w_lbuf_vld),
      .o_opt_dout (w_lbuf_dat_bus),
      // 
      .i_line_side(r_pad_tile_side),
      .i_line_area(r_tile_area)
  );
  generate
    for (c = 0; c < `MAX_GROUP_FILTER; c = c + 1) begin : LINE_BUFFER_ARRAY
      patch #(
          .STRIDE       (`CONV_3X3_STRIDE),
          .PATCH_SIDE   (`CONV_3X3_SIDE),
          .MAX_TILE_SIDE(`MAX_TILE_SIDE + 2)
      ) inst_conv_patch_buffer (
          .i_clk      (i_clk),
          .i_rstn     (i_rstn),
          .i_clr      (i_clr),
          // ipt
          .i_ipt_din  (w_lbuf_dat[c]),
          .i_ipt_vld  (w_lbuf_vld[c]),
          .o_ipt_rdy  (w_ptch_rdy[c]),
          // opt
          .i_opt_rdy  (w_pu_rdy[0][c]),
          .o_opt_vld  (w_ptch_vld[c]),
          .o_opt_dout (w_ptch_dat[c]),
          //
          .i_line_side(r_pad_tile_side)
      );
    end
  endgenerate

  generate
    for (p = 0; p < `MAX_GROUP_FILTER; p = p + 1) begin : pu_array
      for (c = 0; c < `MAX_GROUP_CHANNEL; c = c + 1) begin : ch_array
        // process unit
        pu #(
            .CONV_AREA(`CONV_3X3_SIDE * `CONV_3X3_SIDE)
        ) inst_pu (
            .i_clk     (i_clk),
            .i_rstn    (i_rstn),
            .i_clr     (i_clr),
            .i_wgt_vld (r_pu_wvld[p][c]),
            .i_wgt_din (r_pu_wdat),
            .o_ipt_rdy (w_pu_rdy[p][c]),
            .i_ipt_vld (w_ptch_vld[c] && i_ch_mask[c] && i_pu_mask[p]),
            .i_ipt_din (w_ptch_dat[c]),
            .i_opt_rdy (w_cat_rdy[p]),
            .o_opt_vld (w_pu_vld[p][c]),
            .o_opt_dout(w_pu_dat[p][c])
        );
      end

      // adder tree
      adder_tree #(
          .IPT_BIT(PU_OPT_BIT),
          .IPT_NUM(`MAX_GROUP_FILTER)
      ) inst_ch_at (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .o_ipt_rdy (w_cat_rdy[p]),
          .i_ipt_vld (w_pu_vld_bus[p]),
          .i_ipt_din (w_pu_dat_bus[p]),
          .i_opt_rdy (w_adder_rdy1[p]),
          .o_opt_vld (w_cat_vld[p]),
          .o_opt_dout(w_cat_dat[p])
      );

      // bias adder
      adder #(
          .IPT_BIT(AT_OPT_BIT)
      ) inst_bias_adder (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .o_ipt1_rdy(w_adder_rdy1[p]),
          .i_ipt1_vld(w_cat_vld[p]),
          .i_ipt1_din(w_cat_dat[p]),
          .o_ipt2_rdy(w_adder_rdy2[p]),
          .i_ipt2_vld('b1),
          .i_ipt2_din(w_bias_exdat[p]),
          .i_opt_rdy (w_slicer_rdy[p]),
          .o_opt_vld (w_adder_vld[p]),
          .o_opt_dout(w_adder_dat[p])
      );

      // bit slice
      bit_slicer #(
          .IPT_BIT(AD_OPT_BIT),
          .OPT_BIT(`OPT_BIT)
      ) inst_bit_slicer (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .i_ipt_din (w_adder_dat[p]),
          .i_ipt_vld (w_adder_vld[p]),
          .o_ipt_rdy (w_slicer_rdy[p]),
          .i_opt_rdy (w_relu_rdy[p]),
          .o_opt_vld (w_slicer_vld[p]),
          .o_opt_dout(w_slicer_dat[p])
      );

      // ReLU
      relu #(
          .BITS(`OPT_BIT)
      ) inst_relu (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .i_relu_en (i_relu_en),
          // ipt
          .i_ipt_din (w_slicer_dat[p]),
          .i_ipt_vld (w_slicer_vld[p]),
          .o_ipt_rdy (w_relu_rdy[p]),
          // opt
          .i_opt_rdy (i_opt_rdy),
          .o_opt_vld (w_relu_vld[p]),
          .o_opt_dout(w_relu_dat[p])
      );

    end
  endgenerate
  // ====================== output ========================= 
  assign o_opt_vld  = w_relu_vld[0];
  assign o_opt_dout = w_relu_dat_bus;

endmodule

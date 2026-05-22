//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/23 15:34:14
// Design Name: 
// Module Name: TOP_prac1
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
`include "defines.vh"
module rcursiv_layer #(
    parameter IMAGE_NUM           = 1,
    parameter PADDING_EN          = 1,
    parameter WEIGHT_BITS         = 16,
    parameter INPUT_BITS          = 16,
    parameter IMAGE_WIDTH         = 5,
    parameter IMAGE_HEIGHT        = 5,
    parameter OUTPUT_BITS         = 16,
    parameter PATCH_WIDTH         = 3,
    parameter PATCH_HEIGHT        = 3,
    // layer 1
    parameter L1_CHANNEL_NUM      = 1,
    parameter L1_FILTER_NUM       = 8,
    parameter L1_WEIGHT_DEPTH     = 8 * PATCH_WIDTH * PATCH_HEIGHT,
    parameter L1_WEIGHT_INIT_FILE = "",
    parameter L1_BIAS_INIT_FILE   = "",
    // layer 2
    parameter L2_CHANNEL_NUM      = 8,
    parameter L2_FILTER_NUM       = 8,
    parameter L2_WEIGHT_DEPTH     = 8 * PATCH_WIDTH * PATCH_HEIGHT,
    parameter L2_WEIGHT_INIT_FILE = "",
    parameter L2_BIAS_INIT_FILE   = "",
    // layer3
    parameter L3_CHANNEL_NUM      = 8,
    parameter L3_FILTER_NUM       = 1,
    parameter L3_WEIGHT_DEPTH     = 1 * PATCH_WIDTH * PATCH_HEIGHT,
    parameter L3_WEIGHT_INIT_FILE = "",
    parameter L3_BIAS_INIT_FILE   = "",

    localparam L1_WEIGHT_ADDR  = $clog2(L1_WEIGHT_DEPTH),
    localparam L2_WEIGHT_ADDR  = $clog2(L2_WEIGHT_DEPTH),
    localparam L3_WEIGHT_ADDR  = $clog2(L3_WEIGHT_DEPTH),
    localparam MAX_FILTER      = `MAX2(L1_FILTER_NUM, `MAX2(L2_FILTER_NUM, L3_FILTER_NUM)),
    localparam MAX_CHANNEL     = `MAX2(L1_CHANNEL_NUM, `MAX2(L2_CHANNEL_NUM, L3_CHANNEL_NUM)),
    localparam MAX_WEIGHT_ADDR = `MAX2(L1_WEIGHT_ADDR, `MAX2(L2_WEIGHT_ADDR, L3_WEIGHT_ADDR)),
    localparam PATCH_AREA      = PATCH_WIDTH * PATCH_HEIGHT,

    localparam LINE_WIDTH  = IMAGE_WIDTH + 2 * PADDING_EN,
    localparam LINE_HEIGHT = 3
) (
    input                                      i_clk,
    input                                      i_rstn,
    input                                      i_st,
    input                                      i_relu_en,
    // wgt 
    // ipt 
    output                                     o_ipt_rdy,
    input                                      i_ipt_vld,
    input         [INPUT_BITS*MAX_CHANNEL-1:0] i_ipt_din_pck,
    // opt
    input                                      i_opt_rdy,
    output                                     o_opt_vld,
    output signed [ INPUT_BITS*MAX_FILTER-1:0] o_opt_dout,
    // temp
    input         [     $clog2(MAX_CHANNEL):0] i_ch_num,
    input         [      $clog2(MAX_FILTER):0] i_filt_num,
    input         [           MAX_CHANNEL-1:0] i_lbuf_st,
    input         [                       2:0] i_wgt_re,
    input         [       MAX_WEIGHT_ADDR-1:0] i_wgt_raddr,
    input         [           MAX_CHANNEL-1:0] i_ipt_mask,
    input         [                       2:0] i_bias_sel
);
  // ------------------- parmeter -------------------  
  localparam FILTER_CNT_BITS = (MAX_FILTER <= 1) ? 1 : $clog2(MAX_FILTER);
  localparam CHANNEL_CNT_BITS = (MAX_CHANNEL <= 1) ? 1 : $clog2(MAX_CHANNEL);
  localparam PATCH_CNT_BITS = (PATCH_AREA <= 1) ? 1 : $clog2(PATCH_AREA);
  localparam PE_OUT_BITS = OUTPUT_BITS * 2;
  localparam PU_OUT_BITS = PE_OUT_BITS + $clog2(PATCH_AREA);
  localparam CAT_OUT_BITS = PU_OUT_BITS + $clog2(MAX_CHANNEL);
  localparam ADDER_OUT_BITS = CAT_OUT_BITS + 1;

  integer i, j;
  genvar c, p, g;
  // --------------------- wire ---------------------  
  // weight
  wire                                      w_wgt_vld      [              0:2];
  wire                                      w_wgt_svld;
  wire signed [            WEIGHT_BITS-1:0] w_wgt_dat      [              0:2];
  wire signed [            WEIGHT_BITS-1:0] w_wgt_sdat;
  // IO port 
  wire signed [             INPUT_BITS-1:0] w_ipt_dat      [  0:MAX_CHANNEL-1];
  // line bufferS  
  wire        [            MAX_CHANNEL-1:0] w_lbuf_rdy;
  wire        [            MAX_CHANNEL-1:0] w_lbuf_vld;
  wire        [            MAX_CHANNEL-1:0] w_lbuf_pu_vld  [   0:MAX_FILTER-1];
  wire        [            MAX_CHANNEL-1:0] w_lbuf_vld_pck;
  wire signed [INPUT_BITS*PATCH_HEIGHT-1:0] w_lbuf_dat     [  0:MAX_CHANNEL-1];
  // pu
  wire                                      w_pu_rdy       [   0:MAX_FILTER-1] [0:MAX_CHANNEL-1];
  wire        [             0:MAX_FILTER-1] w_pu_rdy_pck   [  0:MAX_CHANNEL-1];
  wire                                      w_pu_vld       [   0:MAX_FILTER-1] [0:MAX_CHANNEL-1];
  wire        [            MAX_CHANNEL-1:0] w_pu_vld_cpck  [   0:MAX_FILTER-1];
  wire signed [            PU_OUT_BITS-1:0] w_pu_dat       [   0:MAX_FILTER-1] [0:MAX_CHANNEL-1];
  wire        [MAX_CHANNEL*PU_OUT_BITS-1:0] w_pu_dat_cpck  [   0:MAX_FILTER-1];
  // channel adder tree 
  wire                                      w_cat_rdy      [   0:MAX_FILTER-1];
  wire                                      w_cat_vld      [   0:MAX_FILTER-1];
  wire signed [           CAT_OUT_BITS-1:0] w_cat_dat      [   0:MAX_FILTER-1];
  // bias 
  wire signed [           CAT_OUT_BITS-1:0] w_bias_exdat   [   0:MAX_FILTER-1];

  // adder
  wire                                      w_add_act      [   0:MAX_FILTER-1];
  wire                                      w_add_rdy;
  wire signed [         ADDER_OUT_BITS-1:0] w_add_dat      [   0:MAX_FILTER-1];
  wire signed [             INPUT_BITS-1:0] w_add_88dat    [   0:MAX_FILTER-1];
  wire        [  MAX_FILTER*INPUT_BITS-1:0] w_add_dat_pck;


  // ------------------------- reg -------------------------  
  // interenal counter
  reg         [        FILTER_CNT_BITS-1:0] r_pu_cnt;
  reg         [       CHANNEL_CNT_BITS-1:0] r_ch_cnt;
  reg         [         PATCH_CNT_BITS-1:0] r_ptch_cnt;
  // pu
  reg signed  [            WEIGHT_BITS-1:0] r_pu_wdat;
  reg                                       r_pu_wvld      [   0:MAX_FILTER-1] [0:MAX_CHANNEL-1];
  // bias
  reg signed  [             INPUT_BITS-1:0] r_bias1_dat    [0:L1_FILTER_NUM-1];
  reg signed  [             INPUT_BITS-1:0] r_bias2_dat    [0:L2_FILTER_NUM-1];
  reg signed  [             INPUT_BITS-1:0] r_bias3_dat    [0:L3_FILTER_NUM-1];
  reg signed  [             INPUT_BITS-1:0] r_bias_dat     [   0:MAX_FILTER-1];
  reg signed  [             MAX_FILTER-1:0] r_bias_vld;
  // adder
  reg         [             MAX_FILTER-1:0] r_add_vld;

  // init bias
  generate
    if (L1_BIAS_INIT_FILE != "" && L2_BIAS_INIT_FILE != "" && L3_BIAS_INIT_FILE != "") begin : init_bias
      initial begin
        $readmemh(L1_BIAS_INIT_FILE, r_bias1_dat);
        $readmemh(L2_BIAS_INIT_FILE, r_bias2_dat);
        $readmemh(L3_BIAS_INIT_FILE, r_bias3_dat);
      end
    end else begin
      initial begin
        for (i = 0; i < L1_FILTER_NUM; i = i + 1) r_bias1_dat[i] = {INPUT_BITS{1'b0}};
        for (i = 0; i < L2_FILTER_NUM; i = i + 1) r_bias2_dat[i] = {INPUT_BITS{1'b0}};
        for (i = 0; i < L3_FILTER_NUM; i = i + 1) r_bias3_dat[i] = {INPUT_BITS{1'b0}};
      end
    end

  endgenerate
  // ----------------------- function ----------------------  
  // 16.16 -> 8.8 saturation cliping function
  function signed [INPUT_BITS-1:0] sat_q16_16_to_q8_8;
    input signed [ADDER_OUT_BITS-1:0] din;
    begin
      if (!din[23] && |din[ADDER_OUT_BITS-1:24]) begin  // 양수 최댓값
        sat_q16_16_to_q8_8 = 16'sh7FFF;
      end else if (din[23] && !(&din[ADDER_OUT_BITS-1:24])) begin  // 음수 최솟값
        sat_q16_16_to_q8_8 = 16'sh8000;
      end else begin  // 8.8 비트슬라이싱
        sat_q16_16_to_q8_8 = din[23:8];
      end
    end
  endfunction
  // ---------------------- hand shake --------------------- 
  assign o_ipt_rdy = |w_lbuf_rdy;

  // ------------------------ assign -----------------------  
  // weight select
  assign w_wgt_sdat = (w_wgt_vld[0]) ? w_wgt_dat[0] : 
                      (w_wgt_vld[1]) ? w_wgt_dat[1] : 
                      (w_wgt_vld[2]) ? w_wgt_dat[2] : 'd0;
  assign w_wgt_svld = (w_wgt_vld[0] || w_wgt_vld[1] || w_wgt_vld[2]) ? 'b1 : 'b0;
  // line buffer
  generate
    for (p = 0; p < MAX_FILTER; p = p + 1) begin
      assign w_lbuf_pu_vld[p] = (p < i_filt_num) ? w_lbuf_vld : 'd0;
    end
  endgenerate
  // ------------------------ always ----------------------- 
  // select PU for initializing weight data
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_pu_wdat <= 'd0;
      for (i = 0; i < MAX_FILTER; i = i + 1) begin
        for (j = 0; j < MAX_CHANNEL; j = j + 1) begin
          r_pu_wvld[i][j] <= 1'b0;
        end
      end
    end else begin
      for (i = 0; i < MAX_FILTER; i = i + 1) begin
        for (j = 0; j < MAX_CHANNEL; j = j + 1) begin
          if (w_wgt_svld && (r_pu_cnt == i) && (r_ch_cnt == j)) begin
            r_pu_wvld[i][j] <= 1'b1;
          end else begin
            r_pu_wvld[i][j] <= 1'b0;
          end
        end
      end
      if (w_wgt_svld) r_pu_wdat <= w_wgt_sdat;
    end
  end
  // update interenal counter
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_pu_cnt   <= 'd0;
      r_ch_cnt   <= 'd0;
      r_ptch_cnt <= 'd0;
    end else if (w_wgt_svld) begin
      if (r_ptch_cnt < PATCH_AREA - 1) begin
        r_ptch_cnt <= r_ptch_cnt + 'd1;
      end else begin
        r_ptch_cnt <= 'd0;
        if (r_ch_cnt < i_ch_num - 1) begin
          r_ch_cnt <= r_ch_cnt + 'd1;
        end else begin
          r_ch_cnt <= 'd0;
          if (r_pu_cnt < i_filt_num - 1) begin
            r_pu_cnt <= r_pu_cnt + 'd1;
          end else begin
            r_pu_cnt <= 'd0;
          end
        end
      end
    end
  end
  // select bias
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_bias_vld <= 'd0;
      for (i = 0; i < MAX_FILTER; i = i + 1) begin
        r_bias_dat[i] <= 'd0;
      end
    end else begin
      r_bias_vld <= 'd0;
      if (i_bias_sel[0]) begin
        for (i = 0; i < L1_FILTER_NUM; i = i + 1) begin
          r_bias_dat[i] <= r_bias1_dat[i];
          r_bias_vld[i] <= 'b1;
        end
      end else if (i_bias_sel[1]) begin
        for (i = 0; i < L2_FILTER_NUM; i = i + 1) begin
          r_bias_dat[i] <= r_bias2_dat[i];
          r_bias_vld[i] <= 'b1;
        end
      end else if (i_bias_sel[2]) begin
        for (i = 0; i < L3_FILTER_NUM; i = i + 1) begin
          r_bias_dat[i] <= r_bias3_dat[i];
          r_bias_vld[i] <= 'b1;
        end
      end
    end
  end
  // update adder valid
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_add_vld <= 'd0;
    end else if (w_add_rdy) begin
      for (i = 0; i < MAX_FILTER; i = i + 1) begin
        r_add_vld[i] <= w_cat_vld[i] && r_bias_vld[i];  // 유효한 바이어스만
      end
    end
  end
  // ------------------- Unpack / Pack ------------------- 
  generate
    for (c = 0; c < MAX_CHANNEL; c = c + 1) begin
      // ipt
      assign w_ipt_dat[c] = i_ipt_din_pck[c*INPUT_BITS+:INPUT_BITS];
      // line buffer
      assign w_lbuf_vld_pck[c] = w_lbuf_vld[c];
      for (p = 0; p < MAX_FILTER; p = p + 1) begin
        assign w_pu_rdy_pck[c][p] = w_pu_rdy[p][c];
        assign w_pu_vld_cpck[p][c] = w_pu_vld[p][c];
        assign w_pu_dat_cpck[p][c*PU_OUT_BITS+:PU_OUT_BITS] = w_pu_dat[p][c];
      end
    end
    for (p = 0; p < MAX_FILTER; p = p + 1) begin
      // bias
      assign w_bias_exdat[p] = {
        {(CAT_OUT_BITS - OUTPUT_BITS + 8) {r_bias_dat[p][15]}}, r_bias_dat[p], 8'd0
      };
      // adder
      assign w_add_rdy = i_opt_rdy || !(|r_add_vld);
      assign w_add_act[p] = w_cat_vld[p] && w_add_rdy;
      assign w_add_88dat[p] = sat_q16_16_to_q8_8(w_add_dat[p]);
      assign w_add_dat_pck[p*INPUT_BITS+:INPUT_BITS] = (i_relu_en && w_add_88dat[p][15]) ? 16'd0 : w_add_88dat[p];
    end


  endgenerate

  // ------------------------- module ---------------------- 
  // weight buffer
  simple_dual_port_ram #(
      .WIDTH    (WEIGHT_BITS),
      .DEPTH    (L1_WEIGHT_DEPTH),
      .INIT_FILE(L1_WEIGHT_INIT_FILE)
  ) wgt_mem1 (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_re   (i_wgt_re[0]),
      .i_raddr(i_wgt_raddr[L1_WEIGHT_ADDR-1:0]),
      .i_we   (),
      .i_waddr(),
      .i_wdin (),
      .o_vld  (w_wgt_vld[0]),
      .o_dout (w_wgt_dat[0])
  );
  simple_dual_port_ram #(
      .WIDTH    (WEIGHT_BITS),
      .DEPTH    (L2_WEIGHT_DEPTH),
      .INIT_FILE(L2_WEIGHT_INIT_FILE)
  ) wgt_mem2 (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_re   (i_wgt_re[1]),
      .i_raddr(i_wgt_raddr[L2_WEIGHT_ADDR-1:0]),
      .i_we   (),
      .i_waddr(),
      .i_wdin (),
      .o_vld  (w_wgt_vld[1]),
      .o_dout (w_wgt_dat[1])
  );
  simple_dual_port_ram #(
      .WIDTH    (WEIGHT_BITS),
      .DEPTH    (L3_WEIGHT_DEPTH),
      .INIT_FILE(L3_WEIGHT_INIT_FILE)
  ) wgt_mem3 (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_re   (i_wgt_re[2]),
      .i_raddr(i_wgt_raddr[L3_WEIGHT_ADDR-1:0]),
      .i_we   (),
      .i_waddr(),
      .i_wdin (),
      .o_vld  (w_wgt_vld[2]),
      .o_dout (w_wgt_dat[2])
  );
  // line buffer
  generate
    for (c = 0; c < MAX_CHANNEL; c = c + 1) begin : LINE_BUFFER_ARRAY
      line_buffer #(
          .IMAGE_NUM   (IMAGE_NUM),
          .PADDING_EN  (PADDING_EN),
          .INPUT_BITS  (INPUT_BITS),
          .IMAGE_WIDTH (IMAGE_WIDTH),
          .IMAGE_HEIGHT(IMAGE_HEIGHT),
          .PATCH_WIDTH (PATCH_WIDTH),
          .PATCH_HEIGHT(PATCH_HEIGHT)
      ) inst_line_buffer (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .i_st      (i_lbuf_st[c]),
          // ipt
          .o_ipt_rdy (w_lbuf_rdy[c]),
          .i_ipt_din (w_ipt_dat[c]),
          .i_ipt_vld (i_ipt_mask[c] && i_ipt_vld),
          // opt
          .i_opt_rdy (&w_pu_rdy_pck[c]),            // TODO 
          .o_opt_vld (w_lbuf_vld[c]),
          .o_opt_dout(w_lbuf_dat[c])
      );
    end
  endgenerate

  generate
    for (p = 0; p < MAX_FILTER; p = p + 1) begin : pu_array
      for (c = 0; c < MAX_CHANNEL; c = c + 1) begin : ch_array
        pu #(
            .INPUT_BITS  (INPUT_BITS),
            .WEIGHT_BITS (WEIGHT_BITS),
            .OUTPUT_BITS (PU_OUT_BITS),
            .PATCH_WIDTH (PATCH_WIDTH),
            .PATCH_HEIGHT(PATCH_HEIGHT),
            .LINE_WIDTH  (LINE_WIDTH),
            .LINE_HEIGHT (LINE_HEIGHT)
        ) inst_pu (
            .i_clk     (i_clk),
            .i_rstn    (i_rstn),
            .i_clr     (i_lbuf_st[c]),
            // wgt 
            .i_wgt_vld (r_pu_wvld[p][c]),
            .i_wgt_din (r_pu_wdat),
            // ipt
            .o_ipt_rdy (w_pu_rdy[p][c]),
            .i_ipt_vld (w_lbuf_pu_vld[p][c]),
            .i_ipt_din (w_lbuf_dat[c]),
            // opt
            .i_opt_rdy (w_cat_rdy[p]),
            .o_opt_vld (w_pu_vld[p][c]),
            .o_opt_dout(w_pu_dat[p][c])
        );
      end
      adder_tree #(
          .INPUT_BIT(PU_OUT_BITS),
          .INPUT_NUM(MAX_CHANNEL)
      ) inst_ch_at (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          // ipt
          .o_ipt_rdy (w_cat_rdy[p]),
          .i_ipt_vld (w_pu_vld_cpck[p]),
          .i_ipt_din (w_pu_dat_cpck[p]),
          // opt
          .i_opt_rdy (w_add_rdy),
          .o_opt_vld (w_cat_vld[p]),
          .o_opt_dout(w_cat_dat[p])
      );
      adder #(
          .BITS(CAT_OUT_BITS)
      ) inst_adder (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .i_add_en  (w_add_act[p]),
          .i_ipt1_din(w_cat_dat[p]),
          .i_ipt2_din(w_bias_exdat[p]),
          .o_opt_dout(w_add_dat[p])      // 16 + 16 = 17 bit
      );

    end
  endgenerate

  // ------------------------- output ---------------------- 
  assign o_opt_vld  = |r_add_vld;
  assign o_opt_dout = w_add_dat_pck;
endmodule

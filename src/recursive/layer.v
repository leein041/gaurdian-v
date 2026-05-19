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
module layer #(
    parameter RELU_EN          = 0,
    parameter PADDING_EN       = 0,
    parameter INPUT_BITS       = 16,
    parameter INPUT_WIDTH      = 5,
    parameter INPUT_HEIGHT     = 5,
    parameter FMAP_WIDTH       = 5,
    parameter FMAP_HEIGHT      = 5,
    parameter FMAP_DEPTH       = 5,
    parameter WEIGHT_BITS      = 16,
    parameter WEIGHT_DEPTH     = 9,
    parameter OUTPUT_BITS      = 32,
    parameter LINE_WIDTH       = 5,
    parameter LINE_HEIGHT      = 3,
    parameter PATCH_WIDTH      = 3,
    parameter PATCH_HEIGHT     = 3,
    parameter CHANNEL_NUM      = 1,
    parameter FILTER_NUM       = 1,
    parameter WEIGHT_INIT_FILE = "",
    parameter BIAS_INIT_FILE   = "",

    localparam WEIGHT_ADDR = $clog2(WEIGHT_DEPTH),
    localparam PATCH_AREA  = PATCH_WIDTH * PATCH_HEIGHT
) (
    input                                      i_clk,
    input                                      i_rstn,
    input                                      i_st,
    // wgt
    output                                     o_wgt_rdn,
    // ipt 
    output                                     o_ipt_rdy,
    input                                      i_ipt_vld,
    input         [INPUT_BITS*CHANNEL_NUM-1:0] i_ipt_din_pck,
    // opt
    input                                      i_opt_rdy,
    output                                     o_opt_vld,
    output signed [ INPUT_BITS*FILTER_NUM-1:0] o_opt_dout
);
  // ------------------- parmeter -------------------  
  localparam FILTER_CNT_BITS = (FILTER_NUM <= 1) ? 1 : $clog2(FILTER_NUM);
  localparam CHANNEL_CNT_BITS = (CHANNEL_NUM <= 1) ? 1 : $clog2(CHANNEL_NUM);
  localparam PATCH_CNT_BITS = (PATCH_AREA <= 1) ? 1 : $clog2(PATCH_AREA);
  localparam PU_OUT_BITS = OUTPUT_BITS + $clog2(PATCH_AREA);
  localparam CAT_OUT_BITS = PU_OUT_BITS + $clog2(CHANNEL_NUM);
  localparam ADDER_OUT_BITS = CAT_OUT_BITS + 1;

  integer i;
  genvar c, p, g;
  // --------------------- wire --------------------- 
  // wgt
  wire                                        w_wgt_vld;
  wire signed [              WEIGHT_BITS-1:0] w_wgt_dat;
  wire                                        w_wgt_re;
  wire        [            WEIGHT_ADDR-1 : 0] w_wgt_raddr;
  // IO port 
  wire signed [             INPUT_BITS - 1:0] w_ipt_dat      [0:CHANNEL_NUM-1];
  // line bufferS 
  wire                                        w_lbuf_rdy     [0:CHANNEL_NUM-1];
  wire        [              CHANNEL_NUM-1:0] w_lbuf_rdy_pck;
  wire                                        w_lbuf_vld     [0:CHANNEL_NUM-1];
  wire        [              CHANNEL_NUM-1:0] w_lbuf_vld_pck;
  wire signed [INPUT_BITS*PATCH_HEIGHT - 1:0] w_lbuf_dat     [0:CHANNEL_NUM-1];
  // pu
  wire                                        w_pu_wvld      [ 0:FILTER_NUM-1] [0:CHANNEL_NUM-1];
  wire                                        w_pu_rdy       [ 0:FILTER_NUM-1] [0:CHANNEL_NUM-1];
  wire        [               0:FILTER_NUM-1] w_pu_rdy_pck   [0:CHANNEL_NUM-1];
  wire                                        w_pu_vld       [ 0:FILTER_NUM-1] [0:CHANNEL_NUM-1];
  wire        [              CHANNEL_NUM-1:0] w_pu_vld_cpck  [ 0:FILTER_NUM-1];
  wire signed [            PU_OUT_BITS - 1:0] w_pu_dat       [ 0:FILTER_NUM-1] [0:CHANNEL_NUM-1];
  wire        [  CHANNEL_NUM*PU_OUT_BITS-1:0] w_pu_dat_cpck  [ 0:FILTER_NUM-1];
  // channel adder tree 
  wire                                        w_cat_rdy      [ 0:FILTER_NUM-1];
  wire                                        w_cat_vld      [ 0:FILTER_NUM-1];
  wire signed [          CAT_OUT_BITS  - 1:0] w_cat_dat      [ 0:FILTER_NUM-1];
  // bias 
  wire signed [             CAT_OUT_BITS-1:0] w_bias_exdat   [ 0:FILTER_NUM-1];
  // bias dder
  wire                                        w_add_act      [ 0:FILTER_NUM-1];
  wire                                        w_add_rdy;
  wire signed [         ADDER_OUT_BITS - 1:0] w_add_dat      [ 0:FILTER_NUM-1];
  wire signed [             INPUT_BITS - 1:0] w_add_88dat    [ 0:FILTER_NUM-1];
  wire        [  FILTER_NUM*INPUT_BITS - 1:0] w_add_dat_pck;


  // ------------------------- reg -------------------------  
  reg         [          FILTER_CNT_BITS-1:0] r_pu_cnt;
  reg         [         CHANNEL_CNT_BITS-1:0] r_ch_cnt;
  reg         [           PATCH_CNT_BITS-1:0] r_ptch_cnt;
  reg         [               FILTER_NUM-1:0] r_add_vld;

  reg signed  [               INPUT_BITS-1:0] r_bias_dat     [ 0:FILTER_NUM-1];
  generate
    if (BIAS_INIT_FILE != "") begin : init_bias
      initial begin
        $readmemh(BIAS_INIT_FILE, r_bias_dat);
      end
    end else begin : init_to_zero
      integer i;
      initial begin
        for (i = 0; i < FILTER_NUM; i = i + 1) r_bias_dat[i] = {INPUT_BITS{1'b0}};
      end
    end
  endgenerate

  // ----------------------- function ----------------------  
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
  // ------------------------ assign -----------------------  
  assign o_ipt_rdy = &w_lbuf_rdy_pck;
  generate
    for (p = 0; p < FILTER_NUM; p = p + 1) begin
      for (c = 0; c < CHANNEL_NUM; c = c + 1) begin
        // 가중치 버퍼에서 어느 필터, 어느 채널에 꽂아줄지 선택하는 로직 
        assign w_pu_wvld[p][c] = (w_wgt_vld && (r_pu_cnt == p) && (r_ch_cnt == c)) ? 'b1 : 'b0;
      end
    end
  endgenerate
  // ------------------------ always ----------------------- 

  // 가중치 초기화 구간
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_pu_cnt   <= 'd0;
      r_ch_cnt   <= 'd0;
      r_ptch_cnt <= 'd0;
    end else if(w_wgt_vld) begin // 가중치는 처음에 넣는 과정이므로 별도 핸드셰이크 X  
      if (r_ptch_cnt < PATCH_AREA - 1) begin
        r_ptch_cnt <= r_ptch_cnt + 'd1;
      end else begin
        r_ptch_cnt <= 'd0;
        if (r_ch_cnt < CHANNEL_NUM - 1) begin
          r_ch_cnt <= r_ch_cnt + 'd1;
        end else begin
          r_ch_cnt <= 'd0;
          if (r_pu_cnt < FILTER_NUM - 1) begin
            r_pu_cnt <= r_pu_cnt + 'd1;
          end else begin
            r_pu_cnt <= 'd0;
          end
        end
      end
    end
  end
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_add_vld <= 'd0;
    end else if (w_add_rdy) begin
      for (i = 0; i < FILTER_NUM; i = i + 1) begin
        r_add_vld[i] <= w_cat_vld[i];
      end
    end
  end
  // ------------------- Unpack / Pack ------------------- 
  generate
    for (c = 0; c < CHANNEL_NUM; c = c + 1) begin
      // ipt
      assign w_ipt_dat[c] = i_ipt_din_pck[c*INPUT_BITS+:INPUT_BITS];
      // line buffer
      assign w_lbuf_vld_pck[c] = w_lbuf_vld[c];
      assign w_lbuf_rdy_pck[c] = w_lbuf_rdy[c];
      for (p = 0; p < FILTER_NUM; p = p + 1) begin
        assign w_pu_rdy_pck[c][p] = w_pu_rdy[p][c];
        assign w_pu_vld_cpck[p][c] = w_pu_vld[p][c];
        assign w_pu_dat_cpck[p][c*PU_OUT_BITS+:PU_OUT_BITS] = w_pu_dat[p][c];
      end
    end
    for (p = 0; p < FILTER_NUM; p = p + 1) begin
      assign w_bias_exdat[p] = {
        {(CAT_OUT_BITS - OUTPUT_BITS + 8) {r_bias_dat[p][15]}}, r_bias_dat[p], 8'd0
      };

      assign w_add_rdy = i_opt_rdy || !(&r_add_vld);
      assign w_add_act[p] = w_cat_vld[p] && w_add_rdy;
      assign w_add_88dat[p] = sat_q16_16_to_q8_8(w_add_dat[p]);
      assign w_add_dat_pck[p*INPUT_BITS+:INPUT_BITS] = (RELU_EN && w_add_88dat[p][15]) ? 16'd0 : w_add_88dat[p];
    end


  endgenerate

  // ------------------------- module ---------------------- 
  // weight buffer
  simple_dual_port_bram #(
      .WIDTH    (WEIGHT_BITS),
      .DEPTH    (WEIGHT_DEPTH),
      .INIT_FILE(WEIGHT_INIT_FILE)
  ) wgt_mem1 (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_re   (w_wgt_re),
      .i_raddr(w_wgt_raddr),
      .i_we   (),
      .i_waddr(),
      .i_wdin (),
      .o_vld  (w_wgt_vld),
      .o_dout (w_wgt_dat)
  );
  // local ctrl
  local_ctl #(
      .WEIGHT_BITS (WEIGHT_BITS),
      .WEIGHT_DEPTH(WEIGHT_DEPTH)
  ) inst_local_ctl (
      .i_clk      (i_clk),
      .i_rstn     (i_rstn),
      .i_st       (i_st),
      // wgt
      .o_wgt_re   (w_wgt_re),
      .o_wgt_raddr(w_wgt_raddr),
      .o_wgt_rdn  (o_wgt_rdn)
  );
  // line buffer
  generate
    for (c = 0; c < CHANNEL_NUM; c = c + 1) begin : LINE_BUFFER_ARRAY
      line_buffer #(
          .PADDING_EN  (PADDING_EN),
          .FMAP_WIDTH  (FMAP_WIDTH),
          .FMAP_HEIGHT (FMAP_HEIGHT),
          .INPUT_BITS  (INPUT_BITS),
          .INPUT_WIDTH (INPUT_WIDTH),
          .INPUT_HEIGHT(INPUT_HEIGHT),
          .LINE_WIDTH  (LINE_WIDTH),
          .LINE_HEIGHT (LINE_HEIGHT),
          .PATCH_WIDTH (PATCH_WIDTH),
          .PATCH_HEIGHT(PATCH_HEIGHT)
      ) inst_line_buffer (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          // ipt
          .o_ipt_rdy (w_lbuf_rdy[c]),
          .i_ipt_din (w_ipt_dat[c]),
          .i_ipt_vld (i_ipt_vld),
          // opt
          .i_opt_rdy (&w_pu_rdy_pck[c]),  // TODO 
          .o_opt_vld (w_lbuf_vld[c]),
          .o_opt_dout(w_lbuf_dat[c])
      );
    end
  endgenerate

  generate
    for (p = 0; p < FILTER_NUM; p = p + 1) begin : pu_array
      for (c = 0; c < CHANNEL_NUM; c = c + 1) begin : ch_array
        pu #(
            .CHANNEL_NUM (CHANNEL_NUM),
            .RELU_EN     (RELU_EN),
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
            // wgt 
            .i_wgt_vld (w_pu_wvld[p][c]),
            .i_wgt_din (w_wgt_dat),
            // ipt
            .o_ipt_rdy (w_pu_rdy[p][c]),
            .i_ipt_vld (w_lbuf_vld[c]),
            .i_ipt_din (w_lbuf_dat[c]),
            // opt
            .i_opt_rdy (w_cat_rdy[p]),
            .o_opt_vld (w_pu_vld[p][c]),
            .o_opt_dout(w_pu_dat[p][c])
        );
      end
      adder_tree #(
          .INPUT_BIT(PU_OUT_BITS),
          .INPUT_NUM(CHANNEL_NUM)
      ) inst_ch_at (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          // ipt
          .o_ipt_rdy (w_cat_rdy[p]),
          .i_ipt_vld (&w_pu_vld_cpck[p]),
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
  assign o_opt_vld  = &r_add_vld;
  assign o_opt_dout = w_add_dat_pck;
endmodule

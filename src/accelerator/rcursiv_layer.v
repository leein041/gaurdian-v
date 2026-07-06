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
    parameter L1_FILTER_GROUP_NUM = 2,
    parameter L1_CHANNEL_NUM      = 1,
    parameter L1_FILTER_NUM       = 8,
    parameter L1_WEIGHT_DEPTH     = 8 * PATCH_WIDTH * PATCH_HEIGHT, 
    parameter L1_BIAS_INIT_FILE   = "",
    // layer 2
    parameter L2_FILTER_GROUP_NUM = 2,
    parameter L2_CHANNEL_NUM      = 8,
    parameter L2_FILTER_NUM       = 8,
    parameter L2_WEIGHT_DEPTH     = 8 * PATCH_WIDTH * PATCH_HEIGHT, 
    parameter L2_BIAS_INIT_FILE   = "",
    // layer3

    parameter L3_FILTER_GROUP_NUM = 1,
    parameter L3_CHANNEL_NUM      = 8,
    parameter L3_FILTER_NUM       = 1,
    parameter L3_WEIGHT_DEPTH     = 1 * PATCH_WIDTH * PATCH_HEIGHT, 
    parameter L3_BIAS_INIT_FILE   = "",

 
    localparam MAX_FILTER_GROUP_NUM =
    `MAX2(L1_FILTER_GROUP_NUM, `MAX2(L2_FILTER_GROUP_NUM, L3_FILTER_GROUP_NUM)),
    localparam L1_REQ = L1_FILTER_NUM / L1_FILTER_GROUP_NUM,
    localparam L2_REQ = L2_FILTER_NUM / L2_FILTER_GROUP_NUM,
    localparam L3_REQ = L3_FILTER_NUM / L3_FILTER_GROUP_NUM,
    localparam MAX_FILTER = `MAX2(L1_REQ, `MAX2(L2_REQ, L3_REQ)),
    localparam MAX_CHANNEL = `MAX2(L1_CHANNEL_NUM, `MAX2(L2_CHANNEL_NUM, L3_CHANNEL_NUM)), 
    localparam PATCH_AREA = PATCH_WIDTH * PATCH_HEIGHT,

    localparam LINE_WIDTH  = IMAGE_WIDTH + 2 * PADDING_EN,
    localparam LINE_HEIGHT = 3
) (
    input                                     i_clk,
    input                                     i_rstn,
    // wgt    
    input                                     i_wgt_vld,
    input  [                 WEIGHT_BITS-1:0] i_wgt_din,
    // ipt 
    output                                    o_ipt_rdy,
    input                                     i_ipt_vld,
    input  [      INPUT_BITS*MAX_CHANNEL-1:0] i_ipt_din,
    // opt
    input                                     i_opt_rdy,
    output                                    o_opt_vld,
    output [       INPUT_BITS*MAX_FILTER-1:0] o_opt_dout,
    // temp
    input  [                 MAX_CHANNEL-1:0] i_lbuf_st,
    input                                     i_relu_en,
    input  [           $clog2(MAX_CHANNEL):0] i_ch_num,
    input  [            $clog2(MAX_FILTER):0] i_filt_num,
    input  [                             2:0] i_bias_sel,
    input  [$clog2(  MAX_FILTER_GROUP_NUM):0] i_grp_sel
);
  // ------------------- parmeter -------------------    
`ifdef RESOURCE
  localparam PE_OUT_BITS = INPUT_BITS + WEIGHT_BITS + $clog2(PATCH_AREA);
  localparam PU_OUT_BITS = PE_OUT_BITS;
  localparam CAT_OUT_BITS = PU_OUT_BITS + $clog2(MAX_CHANNEL);
  localparam ADDER_OUT_BITS = CAT_OUT_BITS + 1;
`elsif BALANCE
  localparam PE_OUT_BITS = INPUT_BITS + WEIGHT_BITS + $clog2(PATCH_HEIGHT);
  localparam PU_OUT_BITS = PE_OUT_BITS + $clog2(PATCH_WIDTH);
  localparam CAT_OUT_BITS = PU_OUT_BITS + $clog2(MAX_CHANNEL);
  localparam ADDER_OUT_BITS = CAT_OUT_BITS + 1;
`elsif PERFORMANCE
  localparam PE_OUT_BITS = INPUT_BITS + WEIGHT_BITS;
  localparam PU_OUT_BITS = PE_OUT_BITS + $clog2(PATCH_AREA);
  localparam CAT_OUT_BITS = PU_OUT_BITS + $clog2(MAX_CHANNEL);
  localparam ADDER_OUT_BITS = CAT_OUT_BITS + 1;
`endif
  integer i, j;
  genvar c, p;
  // --------------------- wire ---------------------   
  // IO port 
  wire signed [             INPUT_BITS-1:0] w_ipt_dat      [  0:MAX_CHANNEL-1];
  // line bufferS  
  wire        [            MAX_CHANNEL-1:0] w_lbuf_rdy;
  wire        [            MAX_CHANNEL-1:0] w_lbuf_vld; 
  wire        [INPUT_BITS*PATCH_HEIGHT-1:0] w_lbuf_dat     [  0:MAX_CHANNEL-1];
  // patch
  wire        [            MAX_CHANNEL-1:0] w_ptch_rdy;
  wire        [            MAX_CHANNEL-1:0] w_ptch_vld;
  wire        [  INPUT_BITS*PATCH_AREA-1:0] w_ptch_dat     [  0:MAX_CHANNEL-1];
  // pu
  wire                                      w_pu_rdy       [   0:MAX_FILTER-1] [0:MAX_CHANNEL-1];
  wire        [             0:MAX_FILTER-1] w_pu_rdy_bus   [  0:MAX_CHANNEL-1];
  wire                                      w_pu_vld       [   0:MAX_FILTER-1] [0:MAX_CHANNEL-1];
  wire        [            MAX_CHANNEL-1:0] w_pu_vld_bus   [   0:MAX_FILTER-1];
  wire signed [            PU_OUT_BITS-1:0] w_pu_dat       [   0:MAX_FILTER-1] [0:MAX_CHANNEL-1];
  wire        [MAX_CHANNEL*PU_OUT_BITS-1:0] w_pu_dat_bus   [   0:MAX_FILTER-1];
  // channel adder tree 
  wire                                      w_cat_rdy      [   0:MAX_FILTER-1];
  wire                                      w_cat_vld      [   0:MAX_FILTER-1];
  wire signed [           CAT_OUT_BITS-1:0] w_cat_dat      [   0:MAX_FILTER-1];
  // bias 
  wire signed [           CAT_OUT_BITS-1:0] w_bias_exdat   [   0:MAX_FILTER-1];

  // adder
  wire                                      w_adder_rdy1   [   0:MAX_FILTER-1];
  wire                                      w_adder_rdy2   [   0:MAX_FILTER-1];
  wire                                      w_adder_vld    [   0:MAX_FILTER-1];
  wire signed [         ADDER_OUT_BITS-1:0] w_adder_dat    [   0:MAX_FILTER-1];
  // slicer
  wire                                      w_slicer_rdy   [   0:MAX_FILTER-1];
  wire                                      w_slicer_vld   [   0:MAX_FILTER-1];
  wire        [            OUTPUT_BITS-1:0] w_slicer_dat   [   0:MAX_FILTER-1];
  // relu
  wire                                      w_relu_rdy     [   0:MAX_FILTER-1];
  wire                                      w_relu_vld     [   0:MAX_FILTER-1];
  wire        [            OUTPUT_BITS-1:0] w_relu_dat     [   0:MAX_FILTER-1];
  wire        [  MAX_FILTER*INPUT_BITS-1:0] w_relu_dat_bus;


  // ====================== reg ============================ 
  // interenal counter
  reg         [       $clog2(MAX_FILTER):0] r_pu_idx;
  reg         [      $clog2(MAX_CHANNEL):0] r_ch_idx;
  reg         [       $clog2(PATCH_AREA):0] r_pe_idx;
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
  // pipe line 1 : slice
  reg                                       r_88_vld;
  reg signed  [             INPUT_BITS-1:0] r_88_dat       [   0:MAX_FILTER-1];
  // pipe line 1 : relu
  reg                                       r_relu_vld;
  reg signed  [             INPUT_BITS-1:0] r_relu_dat     [   0:MAX_FILTER-1];

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

  // ====================== hand shake ===================== 

  // ====================== assign =========================  
  assign o_ipt_rdy = w_lbuf_rdy[0];  
  // ====================== always ========================= 

  // count internal index
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_pe_idx <= 'd0;
      r_pu_idx <= 'd0;
      r_ch_idx <= 'd0;
    end else if (i_wgt_vld) begin
      if (r_pe_idx < PATCH_AREA - 1) r_pe_idx <= r_pe_idx + 'd1;
      else begin
        r_pe_idx <= 'd0;
        if (r_ch_idx < i_ch_num - 1) r_ch_idx <= r_ch_idx + 'd1;
        else begin
          r_ch_idx <= 'd0;
          if (r_pu_idx < i_filt_num - 1) r_pu_idx <= r_pu_idx + 'd1;
          else r_pu_idx <= 'd0;
        end
      end
    end
  end

  // select PU for initializing weight data
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_pu_wdat <= 'd0;
      for (i = 0; i < MAX_FILTER; i = i + 1)
      for (j = 0; j < MAX_CHANNEL; j = j + 1) r_pu_wvld[i][j] <= 'b0;

    end else begin
      for (i = 0; i < MAX_FILTER; i = i + 1)
      for (j = 0; j < MAX_CHANNEL; j = j + 1) begin
        if (i_wgt_vld && (r_pu_idx == i) && (r_ch_idx == j)) begin
          r_pu_wvld[i][j] <= 1'b1;
          r_pu_wdat       <= i_wgt_din;
        end else r_pu_wvld[i][j] <= 1'b0;
      end
    end
  end


  // select bias 
  // TODO : 바이어스가 커지면 메모리에 넣고 MUX->Shift 수정
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_bias_vld <= 'd0;
      for (i = 0; i < MAX_FILTER; i = i + 1) r_bias_dat[i] <= 'd0;
    end else begin
      r_bias_vld <= 'd0;
      case (i_bias_sel)
        3'b001: begin
          for (i = 0; i < L1_FILTER_NUM / L1_FILTER_GROUP_NUM; i = i + 1) begin
            r_bias_dat[i] <= r_bias1_dat[i+(i_grp_sel*(L1_FILTER_NUM/L1_FILTER_GROUP_NUM))];
            r_bias_vld[i] <= 1'b1;
          end
        end
        3'b010: begin
          for (i = 0; i < L2_FILTER_NUM / L2_FILTER_GROUP_NUM; i = i + 1) begin
            r_bias_dat[i] <= r_bias2_dat[i+(i_grp_sel*(L2_FILTER_NUM/L2_FILTER_GROUP_NUM))];
            r_bias_vld[i] <= 1'b1;
          end
        end
        3'b100: begin
          for (i = 0; i < L3_FILTER_NUM / L3_FILTER_GROUP_NUM; i = i + 1) begin
            r_bias_dat[i] <= r_bias3_dat[i+(i_grp_sel*(L3_FILTER_NUM/L3_FILTER_GROUP_NUM))];
            r_bias_vld[i] <= 1'b1;
          end
        end
        default: ;
      endcase
    end
  end

  generate
    for (c = 0; c < MAX_CHANNEL; c = c + 1) begin
      for (p = 0; p < MAX_FILTER; p = p + 1) begin
        assign w_pu_rdy_bus[c][p]                          = w_pu_rdy[p][c];
        assign w_pu_vld_bus[p][c]                          = w_pu_vld[p][c];
        assign w_pu_dat_bus[p][c*PU_OUT_BITS+:PU_OUT_BITS] = w_pu_dat[p][c];
      end
    end

    for (c = 0; c < MAX_CHANNEL; c = c + 1) begin
      assign w_ipt_dat[c] = i_ipt_din[c*INPUT_BITS+:INPUT_BITS];
    end

    for (p = 0; p < MAX_FILTER; p = p + 1) begin
      assign w_bias_exdat[p] = $signed(r_bias_dat[p]) << 8;
      assign w_relu_dat_bus[p*INPUT_BITS+:INPUT_BITS] = w_relu_dat[p];
    end
  endgenerate

  // ====================== module ========================= 

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
          .o_ipt_rdy (w_lbuf_rdy[c]),
          .i_ipt_din (w_ipt_dat[c]),
          .i_ipt_vld (i_ipt_vld),
          .i_opt_rdy (w_ptch_rdy[c]),
          .o_opt_vld (w_lbuf_vld[c]),
          .o_opt_dout(w_lbuf_dat[c])
      );

      patch #(
          .INPUT_BITS  (INPUT_BITS),
          .PATCH_WIDTH (PATCH_WIDTH),
          .PATCH_HEIGHT(PATCH_HEIGHT),
          .LINE_WIDTH  (LINE_WIDTH),
          .LINE_HEIGHT (LINE_HEIGHT)
      ) inst_patch_perf (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .i_clr     (i_lbuf_st[c]),
          // ipt
          .i_ipt_din (w_lbuf_dat[c]),
          .i_ipt_vld (w_lbuf_vld[c]),
          .o_ipt_rdy (w_ptch_rdy[c]),
          // opt
          .i_opt_rdy (w_pu_rdy[0][c]),
          .o_opt_vld (w_ptch_vld[c]),
          .o_opt_dout(w_ptch_dat[c])
      );
    end
  endgenerate

  generate
    for (p = 0; p < MAX_FILTER; p = p + 1) begin : pu_array
      for (c = 0; c < MAX_CHANNEL; c = c + 1) begin : ch_array
        pu #(
            .INPUT_BITS  (INPUT_BITS),
            .WEIGHT_BITS (WEIGHT_BITS),
            .PATCH_WIDTH (PATCH_WIDTH),
            .PATCH_HEIGHT(PATCH_HEIGHT),
            .LINE_WIDTH  (LINE_WIDTH),
            .LINE_HEIGHT (LINE_HEIGHT)
        ) inst_pu (
            .i_clk     (i_clk),
            .i_rstn    (i_rstn),
            .i_clr     (i_lbuf_st[c]),
            .i_wgt_vld (r_pu_wvld[p][c]),
            .i_wgt_din (r_pu_wdat),
            .o_ipt_rdy (w_pu_rdy[p][c]),
            .i_ipt_vld (w_ptch_vld[c]),
            .i_ipt_din (w_ptch_dat[c]),
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
          .o_ipt_rdy (w_cat_rdy[p]),
          .i_ipt_vld (w_pu_vld_bus[p]),
          .i_ipt_din (w_pu_dat_bus[p]),
          .i_opt_rdy (w_adder_rdy1[p]),
          .o_opt_vld (w_cat_vld[p]),
          .o_opt_dout(w_cat_dat[p])
      );

      adder #(
          .BITS(CAT_OUT_BITS)
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

      bit_slicer #(
          .INPUT_BITS (ADDER_OUT_BITS),
          .OUTPUT_BITS(OUTPUT_BITS)
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
      relu #(
          .BITS(OUTPUT_BITS)
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

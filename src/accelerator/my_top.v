`include "defines.vh"
module my_top #(
    parameter INPUT_BITS = 16,
    parameter WEIGHT_BITS = 16,
    parameter OUTPUT_BITS = 32,
    parameter INPUT_INIT_FILE = "c:/DSD26_Termproject_Materials/03_Demo_Environment/input_image/input_text51_89_64.txt",
    // layer 1
    parameter L1_RELU_EN = 1,
    parameter L1_PADDING_EN = 1,
    parameter L1_INPUT_WIDTH = 150,
    parameter L1_INPUT_HEIGHT = 150,
    parameter L1_INPUT_DEPTH = 150 * 150 * 3,  // image x 3
    parameter L1_FMAP_WIDTH = L1_INPUT_WIDTH + (2 * L1_PADDING_EN),  // 7
    parameter L1_FMAP_HEIGHT = L1_INPUT_HEIGHT * 3 + (2 * L1_PADDING_EN),  // 7
    parameter L1_WEIGHT_DEPTH = 9 * 8 * 1,
    parameter L1_OUTPUT_WIDTH = 150,  // (3 + 2 * 1)
    parameter L1_OUTPUT_HEIGHT = 150,
    parameter L1_LINE_WIDTH = L1_INPUT_WIDTH + (2 * L1_PADDING_EN),  // (5 + 2 * 1)
    parameter L1_LINE_HEIGHT = 3,
    parameter L1_PATCH_WIDTH = 3,
    parameter L1_PATCH_HEIGHT = 3,
    parameter L1_CHANNEL_NUM = 1,
    parameter L1_FILTER_NUM = 8,
    parameter L1_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_4weight/fixed_point_W1_hex.txt",
    parameter L1_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_4bias/fixed_point_B1_hex.txt",

    // layer 2
    parameter L2_RELU_EN = 1,
    parameter L2_PADDING_EN = 1,
    parameter L2_INPUT_WIDTH = 150,
    parameter L2_INPUT_HEIGHT = 150,
    parameter L2_FMAP_WIDTH = L2_INPUT_WIDTH + (2 * L2_PADDING_EN),  // 7
    parameter L2_FMAP_HEIGHT = L2_INPUT_HEIGHT * 3 + (2 * L2_PADDING_EN),  // 7
    parameter L2_WEIGHT_DEPTH = 9 * 4 * 8,
    parameter L2_OUTPUT_WIDTH = 150,  // (3 + 2 * 1)
    parameter L2_OUTPUT_HEIGHT = 150,
    parameter L2_LINE_WIDTH = L2_INPUT_WIDTH + (2 * L2_PADDING_EN),  // (5 + 2 * 1)
    parameter L2_LINE_HEIGHT = 3,
    parameter L2_PATCH_WIDTH = 3,
    parameter L2_PATCH_HEIGHT = 3,
    parameter L2_CHANNEL_NUM = 8,
    parameter L2_FILTER_NUM = 4,
    parameter L2_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_4weight/fixed_point_W2_hex.txt",
    parameter L2_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_4bias/fixed_point_B2_hex.txt",
    // layer 1
    parameter L3_RELU_EN = 0,
    parameter L3_PADDING_EN = 1,
    parameter L3_INPUT_WIDTH = 150,
    parameter L3_INPUT_HEIGHT = 150,
    parameter L3_FMAP_WIDTH = L3_INPUT_WIDTH + (2 * L3_PADDING_EN),  // 7
    parameter L3_FMAP_HEIGHT = L3_INPUT_HEIGHT * 3 + (2 * L3_PADDING_EN),  // 7
    parameter L3_WEIGHT_DEPTH = 9 * 4 * 1,
    parameter L3_OUTPUT_WIDTH = 150,  // (3 + 2 * 1)
    parameter L3_OUTPUT_HEIGHT = 150,
    parameter L3_OUTPUT_DEPTH = 150 * 150 * 3,
    parameter L3_LINE_WIDTH = L3_INPUT_WIDTH + (2 * L3_PADDING_EN),  // (5 + 2 * 1)
    parameter L3_LINE_HEIGHT = 3,
    parameter L3_PATCH_WIDTH = 3,
    parameter L3_PATCH_HEIGHT = 3,
    parameter L3_CHANNEL_NUM = 4,
    parameter L3_FILTER_NUM = 1,
    parameter L3_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_4weight/fixed_point_W3_hex.txt",
    parameter L3_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_4bias/fixed_point_B3_hex.txt",
    //
    parameter L1_FMAP_DEPTH = 152 * 152 * 3,
    parameter L2_FMAP_DEPTH = 152 * 152 * 3,
    parameter L3_FMAP_DEPTH = 152 * 152 * 3,

    localparam L1_WEIGHT_ADDR = $clog2(L1_WEIGHT_DEPTH),
    localparam L1_INPUT_AREA  = L1_INPUT_WIDTH * L1_INPUT_HEIGHT,
    localparam L1_INPUT_ADDR  = $clog2(L1_INPUT_DEPTH),
    localparam L1_OUTPUT_AREA = L1_OUTPUT_WIDTH * L1_OUTPUT_HEIGHT,
    localparam L1_OUTPUT_ADDR = $clog2(L1_OUTPUT_AREA),

    localparam L2_WEIGHT_ADDR = $clog2(L2_WEIGHT_DEPTH),
    localparam L2_INPUT_AREA  = L2_INPUT_WIDTH * L2_INPUT_HEIGHT,
    localparam L2_OUTPUT_AREA = L2_OUTPUT_WIDTH * L2_OUTPUT_HEIGHT,
    localparam L2_OUTPUT_ADDR = $clog2(L2_OUTPUT_AREA)
) (
    input         i_clk,
    input         i_rstn,
    input         i_start,
`ifdef DEBUG_MODE
    input         i_rdy_test,
`endif
    output        output_bram_wen,
    output [16:0] output_bram_waddr,
    output [15:0] L3_p_out,
    output        o_done
);
  // ------------------- parmeter ------------------- 
  genvar g;
  // --------------------- wire --------------------- 
  wire                                 w_sbuf_rdy;
  wire [INPUT_BITS*L1_CHANNEL_NUM-1:0] w_sbuf_dat;
  wire                                 w_sbuf_vld;
  // layer 1 
  wire                                 w_lyr1_wrdn;
  wire                                 w_lyr1_rdy;
  wire                                 w_lyr1_vld;
  wire [ INPUT_BITS*L1_FILTER_NUM-1:0] w_lyr1_dat;
  // layer 1 - layer 2 skide buffer
  wire                                 w_lyr1_srdy;
  wire                                 w_lyr1_svld;
  wire [ INPUT_BITS*L1_FILTER_NUM-1:0] w_lyr1_sdat;
  // layer 2 
  wire                                 w_lyr2_wrdn;
  wire                                 w_lyr2_rdy;
  wire                                 w_lyr2_vld;
  wire [ INPUT_BITS*L2_FILTER_NUM-1:0] w_lyr2_dat;
  // layer 2 - layer 3 skid buffer
  wire                                 w_lyr2_srdy;
  wire                                 w_lyr2_svld;
  wire [ INPUT_BITS*L2_FILTER_NUM-1:0] w_lyr2_sdat;
  // layer 3 
  wire                                 w_lyr3_wrdn;
  wire                                 w_lyr3_rdy;
  wire                                 w_lyr3_vld;
  wire [ INPUT_BITS*L3_FILTER_NUM-1:0] w_lyr3_dat;
  // intput mem
  wire                                 w_ibuf_vld;
  wire [INPUT_BITS*L1_CHANNEL_NUM-1:0] w_ibuf_dat_cpck;
  wire                                 w_ibuf_re;
  wire [            L1_INPUT_ADDR-1:0] w_ibuf_raddr;
  // output mem
  wire [               INPUT_BITS-1:0] w_omem_wdat;
  wire                                 w_omem_we;
  wire [           L1_OUTPUT_ADDR-1:0] w_omem_addr;
  // ------------------------- reg ------------------------- 
  // ------------------------ assign ----------------------- 
  // ------------------------ always ----------------------- 
  // ------------------- Unpack / Pack -------------------  
  // ------------------------- module ---------------------- 


  global_ctl #(
      .L1_INPUT_WIDTH  (L1_INPUT_WIDTH),
      .L1_INPUT_HEIGHT (L1_INPUT_HEIGHT),
      .L1_INPUT_DEPTH  (L1_INPUT_DEPTH),
      .L1_OUTPUT_WIDTH (L1_OUTPUT_WIDTH),
      .L1_OUTPUT_HEIGHT(L1_OUTPUT_HEIGHT),
      .L2_INPUT_WIDTH  (L2_INPUT_WIDTH),
      .L2_INPUT_HEIGHT (L2_INPUT_HEIGHT),
      .L2_OUTPUT_WIDTH (L2_OUTPUT_WIDTH),
      .L2_OUTPUT_HEIGHT(L2_OUTPUT_HEIGHT),
      .L3_INPUT_WIDTH  (L3_INPUT_WIDTH),
      .L3_INPUT_HEIGHT (L3_INPUT_HEIGHT),
      .L3_OUTPUT_WIDTH (L3_OUTPUT_WIDTH),
      .L3_OUTPUT_HEIGHT(L3_OUTPUT_HEIGHT),
      .L3_OUTPUT_DEPTH (L3_OUTPUT_DEPTH)
  ) inst_global_ctl (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .i_st        (i_start),
      .i_lyr1_rdy  (w_sbuf_rdy),
      .i_lyr1_wrdn (w_lyr1_wrdn),
      .i_lyr2_wrdn (w_lyr2_wrdn),
      .i_lyr3_wrdn (w_lyr3_wrdn),
      .i_lyr3_vld  (w_lyr3_vld),
      .i_lyr3_din  (w_lyr3_dat),
      .o_ibuf_re   (w_ibuf_re),
      .o_ibuf_raddr(w_ibuf_raddr),

      .o_obuf_we  (output_bram_wen),
      .o_obuf_addr(output_bram_waddr),
      .o_obuf_dout(L3_p_out),
      .o_done     (o_done)
  );
  // INPUT mem
  simple_dual_port_bram #(
      .WIDTH    (INPUT_BITS * L1_CHANNEL_NUM),
      .DEPTH    (L1_INPUT_DEPTH),
      .INIT_FILE(INPUT_INIT_FILE)
  ) input_mem (
      .i_clk  ( i_clk),
      .i_rstn ( i_rstn),
      .i_re   (w_ibuf_re),
      .i_raddr(w_ibuf_raddr),
      .i_we   (),
      .i_waddr(),
      .i_wdin (),
      .o_vld  (w_ibuf_vld ),
      .o_dout ( w_ibuf_dat_cpck)
  );

  skid_buffer #(
      .BITS   (INPUT_BITS*L1_CHANNEL_NUM),
      .LATENCY(3),
      .MEM_SKID(1)
  ) inst_skid_buffer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_ipt_vld (w_ibuf_vld),
      .i_ipt_din (w_ibuf_dat_cpck),
      .o_ipt_rdy (w_sbuf_rdy),
      .i_opt_rdy (w_lyr1_rdy),
      .o_opt_dout(w_sbuf_dat),
      .o_opt_vld (w_sbuf_vld)
  );
  layer #(
      .PADDING_EN      (L1_PADDING_EN),
      .RELU_EN         (L1_RELU_EN),
      .FMAP_WIDTH      (L1_FMAP_WIDTH),
      .FMAP_HEIGHT     (L1_FMAP_HEIGHT),
      .INPUT_BITS      (INPUT_BITS),
      .INPUT_WIDTH     (L1_INPUT_WIDTH),
      .INPUT_HEIGHT    (L1_INPUT_HEIGHT),
      .WEIGHT_BITS     (WEIGHT_BITS),
      .WEIGHT_DEPTH    (L1_WEIGHT_DEPTH),
      .OUTPUT_BITS     (OUTPUT_BITS),
      .LINE_WIDTH      (L1_LINE_WIDTH),
      .LINE_HEIGHT     (L1_LINE_HEIGHT),
      .PATCH_WIDTH     (L1_PATCH_WIDTH),
      .PATCH_HEIGHT    (L1_PATCH_HEIGHT),
      .CHANNEL_NUM     (L1_CHANNEL_NUM),
      .FILTER_NUM      (L1_FILTER_NUM),
      .WEIGHT_INIT_FILE(L1_WEIGHT_INIT_FILE),
      .BIAS_INIT_FILE  (L1_BIAS_INIT_FILE)
  ) layer1 (
      .i_clk        (i_clk),
      .i_rstn       (i_rstn),
      .i_st         (i_start),
      // wgt 
      .o_wgt_rdn    (w_lyr1_wrdn),  // wgt read done
      // ipt 
      .o_ipt_rdy    (w_lyr1_rdy),
      .i_ipt_vld    (w_sbuf_vld),
      .i_ipt_din_pck(w_sbuf_dat),
      // opt
      .i_opt_rdy    (w_lyr1_srdy),  // for test
      .o_opt_vld    (w_lyr1_vld),
      .o_opt_dout   (w_lyr1_dat)
  );
  skid_buffer #(
      .BITS(INPUT_BITS * L1_FILTER_NUM),
      .LATENCY(6)
  ) inst_L1_skid_buffer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_ipt_vld (w_lyr1_vld),
      .i_ipt_din (w_lyr1_dat),
      .o_ipt_rdy (w_lyr1_srdy),
      .i_opt_rdy (w_lyr2_rdy),
      .o_opt_dout(w_lyr1_sdat),
      .o_opt_vld (w_lyr1_svld)
  );
  layer #(
      .PADDING_EN      (L2_PADDING_EN),
      .RELU_EN         (L2_RELU_EN),
      .FMAP_WIDTH      (L2_FMAP_WIDTH),
      .FMAP_HEIGHT     (L2_FMAP_HEIGHT),
      .INPUT_BITS      (INPUT_BITS),
      .INPUT_WIDTH     (L2_INPUT_WIDTH),
      .INPUT_HEIGHT    (L2_INPUT_HEIGHT),
      .WEIGHT_BITS     (WEIGHT_BITS),
      .WEIGHT_DEPTH    (L2_WEIGHT_DEPTH),
      .OUTPUT_BITS     (OUTPUT_BITS),
      .LINE_WIDTH      (L2_LINE_WIDTH),
      .LINE_HEIGHT     (L2_LINE_HEIGHT),
      .PATCH_WIDTH     (L2_PATCH_WIDTH),
      .PATCH_HEIGHT    (L2_PATCH_HEIGHT),
      .CHANNEL_NUM     (L2_CHANNEL_NUM),
      .FILTER_NUM      (L2_FILTER_NUM),
      .WEIGHT_INIT_FILE(L2_WEIGHT_INIT_FILE),
      .BIAS_INIT_FILE  ("")
  ) layer2 (
      .i_clk        (i_clk),
      .i_rstn       (i_rstn),
      .i_st         (i_start),
      // wgt 
      .o_wgt_rdn    (w_lyr2_wrdn),
      // ipt 
      .o_ipt_rdy    (w_lyr2_rdy),
      .i_ipt_vld    (w_lyr1_svld),
      .i_ipt_din_pck(w_lyr1_sdat),
      // opt
      .i_opt_rdy    (w_lyr2_srdy),  // for test
      .o_opt_vld    (w_lyr2_vld),
      .o_opt_dout   (w_lyr2_dat)
  );
  skid_buffer #(
      .BITS(INPUT_BITS * L1_FILTER_NUM),
      .LATENCY(6)
  ) inst_L2_skid_buffer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_ipt_vld (w_lyr2_vld),
      .i_ipt_din (w_lyr2_dat),
      .o_ipt_rdy (w_lyr2_srdy),
      .i_opt_rdy (w_lyr3_rdy),
      .o_opt_dout(w_lyr2_sdat),
      .o_opt_vld (w_lyr2_svld)
  );
  layer #(
      .PADDING_EN      (L3_PADDING_EN),
      .RELU_EN         (L3_RELU_EN),
      .FMAP_WIDTH      (L3_FMAP_WIDTH),
      .FMAP_HEIGHT     (L3_FMAP_HEIGHT),
      .INPUT_BITS      (INPUT_BITS),
      .INPUT_WIDTH     (L3_INPUT_WIDTH),
      .INPUT_HEIGHT    (L3_INPUT_HEIGHT),
      .WEIGHT_BITS     (WEIGHT_BITS),
      .WEIGHT_DEPTH    (L3_WEIGHT_DEPTH),
      .OUTPUT_BITS     (OUTPUT_BITS),
      .LINE_WIDTH      (L3_LINE_WIDTH),
      .LINE_HEIGHT     (L3_LINE_HEIGHT),
      .PATCH_WIDTH     (L3_PATCH_WIDTH),
      .PATCH_HEIGHT    (L3_PATCH_HEIGHT),
      .CHANNEL_NUM     (L3_CHANNEL_NUM),
      .FILTER_NUM      (L3_FILTER_NUM),
      .WEIGHT_INIT_FILE(L3_WEIGHT_INIT_FILE),
      .BIAS_INIT_FILE  ("")
  ) layer3 (
      .i_clk        (i_clk),
      .i_rstn       (i_rstn),
      .i_st         (i_start),
      // wgt 
      .o_wgt_rdn    (w_lyr3_wrdn),
      // ipt 
      .o_ipt_rdy    (w_lyr3_rdy),
      .i_ipt_vld    (w_lyr2_svld),
      .i_ipt_din_pck(w_lyr2_sdat),
      // opt
`ifdef DEBUG_MODE
      .i_opt_rdy    (i_rdy_test),   // for test
`else
      .i_opt_rdy    ('b1),
`endif
      .o_opt_vld    (w_lyr3_vld),
      .o_opt_dout   (w_lyr3_dat)
  );

endmodule

`include "defines.vh"
module my_top #(
    parameter INPUT_BITS = 16,
    parameter WEIGHT_BITS = 16,
    parameter OUTPUT_BITS = 32,
    parameter INPUT_INIT_FILE = "c:/DSD26_Termproject_Materials/03_Demo_Environment/input_image/input_text51_89_64.txt",
    // layer  
    parameter RELU_EN = 1,
    parameter PADDING_EN = 1,
    parameter INPUT_WIDTH = 150,
    parameter INPUT_HEIGHT = 150,
    parameter FMAP_WIDTH = INPUT_WIDTH + (2 * PADDING_EN),  // 7
    parameter FMAP_HEIGHT = INPUT_HEIGHT + (2 * PADDING_EN),  // 7
    parameter WEIGHT_DEPTH = 9 * 8 * 1,
    parameter OUTPUT_WIDTH = 150,  // (3 + 2 * 1)
    parameter OUTPUT_HEIGHT = 150,
    parameter LINE_WIDTH = INPUT_WIDTH + (2 * PADDING_EN),  // (5 + 2 * 1)
    parameter LINE_HEIGHT = 3,
    parameter PATCH_WIDTH = 3,
    parameter PATCH_HEIGHT = 3,
    parameter CHANNEL_NUM = 1,
    parameter FILTER_NUM = 8,
    parameter  WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_4weight/fixed_point_W1_hex.txt",
    parameter  BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_4bias/fixed_point_B1_hex.txt",


    localparam WEIGHT_ADDR = $clog2(L1_WEIGHT_DEPTH),
    localparam INPUT_AREA  = INPUT_WIDTH * INPUT_HEIGHT,
    localparam INPUT_ADDR  = $clog2(L1_INPUT_DEPTH),
    localparam OUTPUT_AREA = OUTPUT_WIDTH * OUTPUT_HEIGHT,
    localparam OUTPUT_ADDR = $clog2(L1_OUTPUT_AREA)
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
  wire                                 w_lyr_wrdn;
  wire                                 w_lyr_rdy;
  wire                                 w_lyr_vld;
  wire [ INPUT_BITS*L1_FILTER_NUM-1:0] w_lyr_dat;
  // layer 1 - layer 2 skide buffer
  wire                                 w_lyr_srdy;
  wire                                 w_lyr_svld;
  wire [ INPUT_BITS*L1_FILTER_NUM-1:0] w_lyr_sdat;
  // intput mem
  wire                                 w_act1_vld;
  wire [INPUT_BITS*L1_CHANNEL_NUM-1:0] w_act1_dat_cpck;
  wire                                 w_act1_re;
  wire [               INPUT_ADDR-1:0] w_act1_raddr;
  // output mem
  wire [               INPUT_BITS-1:0] w_act2_wdat;
  wire                                 w_act2_we;
  wire [              OUTPUT_ADDR-1:0] w_act2_addr;
  // ------------------------- reg ------------------------- 
  // ------------------------ assign ----------------------- 
  // ------------------------ always ----------------------- 
  // ------------------- Unpack / Pack -------------------  
  // ------------------------- module ---------------------- 


  global_ctl #(
      .INPUT_WIDTH  (INPUT_WIDTH),
      .INPUT_HEIGHT (INPUT_HEIGHT),
      .OUTPUT_WIDTH (OUTPUT_WIDTH),
      .OUTPUT_HEIGHT(OUTPUT_HEIGHT)
  ) inst_global_ctl (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .i_st        (i_start),
      .i_lyr_rdy   (w_sbuf_rdy),
      .i_lyr_wrdn  (w_lyr_wrdn),
      .o_act1_re   (w_act1_re),
      .o_act1_raddr(w_act1_raddr),

      .o_obuf_we  (output_bram_wen),
      .o_obuf_addr(output_bram_waddr),
      .o_obuf_dout(L3_p_out),
      .o_done     (o_done)
  );
  // act 1
  simple_dual_port_bram #(
      .WIDTH    (INPUT_BITS * CHANNEL_NUM),
      .DEPTH    (L1_INPUT_AREA),
      .INIT_FILE(INPUT_INIT_FILE)
  ) act_1 (
      .i_clk  ( i_clk),
      .i_rstn ( i_rstn),
      .i_re   (w_act1_re),
      .i_raddr(w_act1_raddr),
      .i_we   (),
      .i_waddr(),
      .i_wdin (),
      .o_vld  (w_act1_vld ),
      .o_dout ( w_act1_dat_cpck)
  );

  skid_buffer #(
      .BITS   (INPUT_BITS*L1_CHANNEL_NUM),
      .LATENCY(3),
      .MEM_SKID(1)
  ) inst_skid_1 (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_ipt_vld (w_act1_vld),
      .i_ipt_din (w_act1_dat_cpck),
      .o_ipt_rdy (w_sbuf_rdy),
      .i_opt_rdy (w_lyr_rdy),
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
  ) layer (
      .i_clk        (i_clk),
      .i_rstn       (i_rstn),
      .i_st         (i_start),
      // wgt 
      .o_wgt_rdn    (w_lyr_wrdn),  // wgt read done
      // ipt 
      .o_ipt_rdy    (w_lyr_rdy),
      .i_ipt_vld    (w_sbuf_vld),
      .i_ipt_din_pck(w_sbuf_dat),
      // opt
      .i_opt_rdy    (w_lyr_srdy),  // for test
      .o_opt_vld    (w_lyr_vld),
      .o_opt_dout   (w_lyr_dat)
  );
  skid_buffer #(
      .BITS(INPUT_BITS * FILTER_NUM),
      .LATENCY(4)
  ) inst_skid_2 (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_ipt_vld (w_lyr_vld),
      .i_ipt_din (w_lyr_dat),
      .o_ipt_rdy (w_lyr_srdy),
      .i_opt_rdy (w_lyr2_rdy),
      .o_opt_dout(w_lyr_sdat),
      .o_opt_vld (w_lyr_svld)
  );
  // act 2
  simple_dual_port_bram #(
      .WIDTH    (INPUT_BITS * CHANNEL_NUM),
      .DEPTH    (L1_INPUT_AREA),
      .INIT_FILE(INPUT_INIT_FILE)
  ) act_2 (
      .i_clk  ( i_clk),
      .i_rstn ( i_rstn),
      .i_re   (w_act1_re),
      .i_raddr(w_act1_raddr),
      .i_we   (),
      .i_waddr(),
      .i_wdin (),
      .o_vld  (w_act1_vld ),
      .o_dout ( w_act1_dat_cpck)
  );
endmodule

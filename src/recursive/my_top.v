`include "defines.vh"
module my_top #(
    parameter IMAGE_NUM = 1,  // important : when demo, must change 3
    parameter PADDING_EN = 1,
`ifdef RELEASE_4_2
    parameter L1_CHANNEL_NUM = 1,
    parameter L1_FILTER_NUM = 4,
    parameter L2_CHANNEL_NUM = 4,
    parameter L2_FILTER_NUM = 2,
    parameter L3_CHANNEL_NUM = 2,
    parameter L3_FILTER_NUM = 1,
`elsif RELEASE_8_8 
    parameter L1_CHANNEL_NUM = 1,
    parameter L1_FILTER_NUM = 8,
    parameter L2_CHANNEL_NUM = 8,
    parameter L2_FILTER_NUM = 8,
    parameter L3_CHANNEL_NUM = 8,
    parameter L3_FILTER_NUM = 1,
`endif

    localparam MAX_FILTER = `MAX2(L1_FILTER_NUM, `MAX2(L2_FILTER_NUM, L3_FILTER_NUM)),
    localparam MAX_CHANNEL = `MAX2(L1_CHANNEL_NUM, `MAX2(L2_CHANNEL_NUM, L3_CHANNEL_NUM)),
    parameter IMAGE_FILE = "c:/DSD26_Termproject_Materials/02_Provided_Data/input_Y_channel_only_hex/test_40_hex.txt",
    //
    parameter WEIGHT_BITS = 16,
    parameter INPUT_BITS = 16,
    parameter OUTPUT_BITS = 16,
    parameter INPUT_WIDTH = 150,
    parameter INPUT_HEIGHT = 150,
    parameter PATCH_WIDTH = 3,
    parameter PATCH_HEIGHT = 3,

    localparam ACT_DEPTH = INPUT_WIDTH * INPUT_HEIGHT,
    localparam ACT_ADDR = $clog2(ACT_DEPTH),
    localparam IMAGE_DEPTH = INPUT_WIDTH * INPUT_HEIGHT * IMAGE_NUM,
    localparam IMAGE_ADDR = $clog2(IMAGE_DEPTH),
    localparam OUTPUT_ADDR = $clog2(IMAGE_DEPTH),
    // layer 1
    parameter L1_WEIGHT_DEPTH = L1_CHANNEL_NUM * L1_FILTER_NUM * PATCH_WIDTH * PATCH_HEIGHT,
    parameter L1_BIAS_DEPTH = L1_FILTER_NUM,
    // layer 2 
    parameter L2_WEIGHT_DEPTH = L2_CHANNEL_NUM * L2_FILTER_NUM * PATCH_WIDTH * PATCH_HEIGHT,
    parameter L2_BIAS_DEPTH = L2_FILTER_NUM,
    // layer 3      
    parameter L3_WEIGHT_DEPTH = L3_CHANNEL_NUM * L3_FILTER_NUM * PATCH_WIDTH * PATCH_HEIGHT, 
    parameter L3_BIAS_DEPTH = L3_FILTER_NUM, 
`ifdef RELEASE_4_2 
    parameter L1_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_4_2weight/fixed_point_W1_hex.txt",
    parameter L1_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_4_2bias/fixed_point_B1_hex.txt",
    parameter L2_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_4_2weight/fixed_point_W2_hex.txt",
    parameter L2_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_4_2bias/fixed_point_B2_hex.txt",
    parameter L3_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_4_2weight/fixed_point_W3_hex.txt", 
    parameter L3_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_4_2bias/fixed_point_B3_hex.txt"  
`elsif RELEASE_8_8  
    parameter L1_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_8weight/fixed_point_W1_hex.txt",
    parameter L1_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_8bias/fixed_point_B1_hex.txt",
    parameter L2_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_8weight/fixed_point_W2_hex.txt",
    parameter L2_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_8bias/fixed_point_B2_hex.txt",
    parameter L3_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_8weight/fixed_point_W3_hex.txt", 
    parameter L3_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_8bias/fixed_point_B3_hex.txt" 
`endif
) (
`ifdef DEBUG
    input                           i_rdy_test,
`endif
    input                           i_clk,
    input                           i_rstn,
    input                           i_start,
    output                          output_bram_wen,
    output        [OUTPUT_ADDR-1:0] output_bram_waddr,
    output signed [ INPUT_BITS-1:0] L3_p_out,
    output                          o_done
);
  // ------------------- parmeter ------------------- 
  genvar g;
  // --------------------- wire ---------------------  
  // ctrl
  wire                              w_ctrl_rdy;
  // intput mem
  wire                              w_ibuf_vld;
  wire [            INPUT_BITS-1:0] w_ibuf_dat;
  wire                              w_ibuf_re;
  wire [            IMAGE_ADDR-1:0] w_ibuf_raddr;
  // act buffer
  wire                              w_abuf_we;
  wire [              ACT_ADDR-1:0] w_abuf_waddr;
  wire [INPUT_BITS*MAX_CHANNEL-1:0] w_abuf_wdat;
  wire                              w_abuf_re;
  wire [              ACT_ADDR-1:0] w_abuf_raddr;
  wire                              w_abuf_rvld;
  wire [INPUT_BITS*MAX_CHANNEL-1:0] w_abuf_rdat;
  // act/image buffer select
  wire                              w_sel_vld;
  wire [INPUT_BITS*MAX_CHANNEL-1:0] w_sel_dat;
  // skid
  wire                              w_skid_rdy;
  wire [INPUT_BITS*MAX_CHANNEL-1:0] w_skid_dat;
  wire                              w_skid_vld;
  // layer 
  wire                              w_lyr_wst;
  wire                              w_lyr_relu_en;
  wire                              w_lyr_wrdn;
  wire                              w_lyr_rdy;
  wire                              w_lyr_vld;
  wire [ INPUT_BITS*MAX_FILTER-1:0] w_lyr_dat;
  // ------------------------- reg ------------------------- 
  // ------------------------ assign ----------------------- 
  // act/image buffer select
  assign w_sel_dat  = (w_ibuf_vld) ? {{(INPUT_BITS*(MAX_CHANNEL-1)){1'b0}} ,w_ibuf_dat} : w_abuf_rdat;
  assign w_sel_vld = w_ibuf_vld || w_abuf_rvld;
  // ------------------------ always ----------------------- 
  // ------------------- Unpack / Pack -------------------  
  // ------------------------- module ----------------------  
  stline_global_ctrl #(
      .MAX_CHANNEL(MAX_CHANNEL),
      .BITS       (INPUT_BITS),
      .ACT_DEPTH  (ACT_DEPTH),
      .IMAGE_DEPTH(IMAGE_DEPTH)
  ) inst_global_ctl (
      .i_clk        (i_clk),
      .i_rstn       (i_rstn),
      .i_st         (i_start),
      .o_ctrl_rdy   (w_ctrl_rdy),
      // ipt mem
      .o_ibuf_re    (w_ibuf_re),
      .o_ibuf_raddr (w_ibuf_raddr),
      // act buffer
      .o_abuf_re    (w_abuf_re),
      .o_abuf_raddr (w_abuf_raddr),
      .o_abuf_we    (w_abuf_we),
      .o_abuf_waddr (w_abuf_waddr),
      .o_abuf_wdout (w_abuf_wdat),
      // skid
      .i_skid_rdy   (w_skid_rdy),
      // lyr 
      .i_lyr_wrdn   (w_lyr_wrdn),
      .i_lyr_vld    (w_lyr_vld),
      .i_lyr_din    (w_lyr_dat),
      .o_lyr_wst    (w_lyr_wst),
      .o_lyr_relu_en(w_lyr_relu_en),
      // opt mem
      .o_obuf_we    (output_bram_wen),
      .o_obuf_addr  (output_bram_waddr),
      .o_obuf_dout  (L3_p_out),
      .o_done       (o_done)

  );
  // image buffer
  simple_dual_port_bram #(
      .WIDTH    (INPUT_BITS),
      .DEPTH    (IMAGE_DEPTH),
      .INIT_FILE(IMAGE_FILE)
  ) image_buf (
      .i_clk  ( i_clk),
      .i_rstn ( i_rstn),
      .i_re   (w_ibuf_re),
      .i_raddr(w_ibuf_raddr),
      .i_we   (),
      .i_waddr(),
      .i_wdin (),
      .o_vld  (w_ibuf_vld),
      .o_dout (w_ibuf_dat)
  );
  // act Buffer
  simple_dual_port_bram #(
      .WIDTH(INPUT_BITS * MAX_FILTER),
      .DEPTH(ACT_DEPTH)
  ) act_buf (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_re   (w_abuf_re),
      .i_raddr(w_abuf_raddr),
      .i_we   (w_abuf_we),
      .i_waddr(w_abuf_waddr),
      .i_wdin (w_abuf_wdat),
      .o_vld  (w_abuf_rvld),
      .o_dout (w_abuf_rdat)
  );
  // image/act - layer skid buffer
  skid_buffer #(
      .BITS    (INPUT_BITS * MAX_FILTER),
      .LATENCY (4),
      .MEM_SKID(1)
  ) inst_skid_buffer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_ipt_vld (w_sel_vld),
      .i_ipt_din (w_sel_dat),
      .o_ipt_rdy (w_skid_rdy),
      .i_opt_rdy (w_lyr_rdy),
      .o_opt_dout(w_skid_dat),
      .o_opt_vld (w_skid_vld)
  );
  layer #(
      .IMAGE_NUM          (IMAGE_NUM),
      .PADDING_EN         (PADDING_EN),
      .WEIGHT_BITS        (WEIGHT_BITS),
      .INPUT_BITS         (INPUT_BITS),
      .INPUT_WIDTH        (INPUT_WIDTH),
      .INPUT_HEIGHT       (INPUT_HEIGHT),
      .OUTPUT_BITS        (OUTPUT_BITS),
      .PATCH_WIDTH        (PATCH_WIDTH),
      .PATCH_HEIGHT       (PATCH_HEIGHT),
      .L1_CHANNEL_NUM     (L1_CHANNEL_NUM),
      .L1_FILTER_NUM      (L1_FILTER_NUM),
      .L1_WEIGHT_DEPTH    (L1_WEIGHT_DEPTH),
      .L1_WEIGHT_INIT_FILE(L1_WEIGHT_INIT_FILE),
      .L1_BIAS_INIT_FILE  (L1_BIAS_INIT_FILE),
      .L2_CHANNEL_NUM     (L2_CHANNEL_NUM),
      .L2_FILTER_NUM      (L2_FILTER_NUM),
      .L2_WEIGHT_DEPTH    (L2_WEIGHT_DEPTH),
      .L2_WEIGHT_INIT_FILE(L2_WEIGHT_INIT_FILE),
      .L2_BIAS_INIT_FILE  (L2_BIAS_INIT_FILE),
      .L3_CHANNEL_NUM     (L3_CHANNEL_NUM),
      .L3_FILTER_NUM      (L3_FILTER_NUM),
      .L3_WEIGHT_DEPTH    (L3_WEIGHT_DEPTH),
      .L3_WEIGHT_INIT_FILE(L3_WEIGHT_INIT_FILE),
      .L3_BIAS_INIT_FILE  (L3_BIAS_INIT_FILE)
  ) layer (
      .i_clk        (i_clk),
      .i_rstn       (i_rstn),
      .i_st         (i_start),
      .i_relu_en    (w_lyr_relu_en),
      // wgt  
      .i_wgt_st     (w_lyr_wst),
      .o_wgt_rdn    (w_lyr_wrdn),
      // ipt 
      .o_ipt_rdy    (w_lyr_rdy),
      .i_ipt_vld    (w_skid_vld),
      .i_ipt_din_pck(w_skid_dat),
      // opt
`ifdef DEBUG
      .i_opt_rdy    (w_ctrl_rdy),     // for test
`else
      .i_opt_rdy    (w_ctrl_rdy),
`endif
      .o_opt_vld    (w_lyr_vld),
      .o_opt_dout   (w_lyr_dat)
  );

endmodule

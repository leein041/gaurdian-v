module top #(
    parameter LAYER_NUM        = 2,
    // layer 1
    parameter L1_PADDING_EN    = 1,
    parameter L1_RELU_EN       = 0,
    parameter INPUT_BITS       = 16,
    parameter WEIGHT_BITS      = 16,
    parameter OUTPUT_BITS      = 32,
    parameter L1_INPUT_WIDTH   = 5,
    parameter L1_INPUT_HEIGHT  = 5,
    parameter L1_FMAP_WIDTH    = L1_INPUT_WIDTH + (2 * L1_PADDING_EN),   // 7
    parameter L1_FMAP_HEIGHT   = L1_INPUT_HEIGHT + (2 * L1_PADDING_EN),  // 7
    parameter L1_WEIGHT_WIDTH  = 3,
    parameter L1_WEIGHT_HEIGHT = 3,
    parameter L1_OUTPUT_WIDTH  = 5,                                      // (3 + 2 * 1)
    parameter L1_OUTPUT_HEIGHT = 5,
    parameter L1_LINE_WIDTH    = L1_INPUT_WIDTH + (2 * L1_PADDING_EN),   // (5 + 2 * 1)
    parameter L1_LINE_HEIGHT   = 3,
    parameter L1_PATCH_WIDTH   = 3,
    parameter L1_PATCH_HEIGHT  = 3,
    parameter L1_CHANNEL_NUM   = 1,
    // layer 2
    parameter L2_PADDING_EN    = 1,
    parameter L2_RELU_EN       = 1,
    parameter L2_INPUT_WIDTH   = 5,
    parameter L2_INPUT_HEIGHT  = 5,
    parameter L2_FMAP_WIDTH    = L2_INPUT_WIDTH + (2 * L2_PADDING_EN),   // 7
    parameter L2_FMAP_HEIGHT   = L2_INPUT_HEIGHT + (2 * L2_PADDING_EN),  // 7
    parameter L2_WEIGHT_WIDTH  = 3,
    parameter L2_WEIGHT_HEIGHT = 3,
    parameter L2_OUTPUT_WIDTH  = 5,                                      // (3 + 2 * 1)
    parameter L2_OUTPUT_HEIGHT = 5,
    parameter L2_LINE_WIDTH    = L2_INPUT_WIDTH + (2 * L2_PADDING_EN),   // (5 + 2 * 1)
    parameter L2_LINE_HEIGHT   = 3,
    parameter L2_PATCH_WIDTH   = 3,
    parameter L2_PATCH_HEIGHT  = 3,
    parameter L2_CHANNEL_NUM   = 1,

    parameter INIT_INPUT_BRAM   = "",
    parameter INIT_WEIGHT_BRAM1 = "",
    parameter INIT_WEIGHT_BRAM2 = "",

    localparam L1_WEIGHT_AREA = L1_WEIGHT_WIDTH * L1_WEIGHT_HEIGHT,
    localparam L1_WEIGHT_ADDR = $clog2(L1_WEIGHT_AREA),
    localparam L1_INPUT_AREA  = L1_INPUT_WIDTH * L1_INPUT_HEIGHT,
    localparam L1_INPUT_ADDR  = $clog2(L1_INPUT_AREA),
    localparam L1_OUTPUT_AREA = L1_OUTPUT_WIDTH * L1_OUTPUT_HEIGHT,
    localparam L1_OUTPUT_ADDR = $clog2(L1_OUTPUT_AREA),

    localparam L2_WEIGHT_AREA = L2_WEIGHT_WIDTH * L2_WEIGHT_HEIGHT,
    localparam L2_WEIGHT_ADDR = $clog2(L2_WEIGHT_AREA),
    localparam L2_INPUT_AREA  = L2_INPUT_WIDTH * L2_INPUT_HEIGHT,
    localparam L2_INPUT_ADDR  = $clog2(L2_INPUT_AREA),
    localparam L2_OUTPUT_AREA = L2_OUTPUT_WIDTH * L2_OUTPUT_HEIGHT,
    localparam L2_OUTPUT_ADDR = $clog2(L2_OUTPUT_AREA)
) (
    input i_clk,
    input i_rstn,
    input i_st,

    output o_dn
);
  // ------------------- parmeter ------------------- 
  genvar g;
  // --------------------- wire --------------------- 
  
  wire [ INPUT_BITS*L1_CHANNEL_NUM-1:0] w_sbuf_dat;
  wire                                  w_sbuf_vld;
  // ayer 1
  wire                                  w_lyr1_wvld;
  wire [WEIGHT_BITS*L1_CHANNEL_NUM-1:0] w_lyr1_wdat_pck;
  wire                                  w_lyr1_wrdn;
  wire                                  w_lyr1_wre;
  wire [          L1_WEIGHT_ADDR-1 : 0] w_lyr1_wraddr;
  wire                                  w_lyr1_rdy;
  wire                                  w_lyr1_vld;
  wire [           OUTPUT_BITS   - 1:0] w_lyr1_dat;
  // layer 2
  wire                                  w_lyr2_wvld;
  wire [WEIGHT_BITS*L2_CHANNEL_NUM-1:0] w_lyr2_wdat_pck;
  wire                                  w_lyr2_wrdn;
  wire                                  w_lyr2_wre;
  wire [          L2_WEIGHT_ADDR-1 : 0] w_lyr2_wraddr;
  wire                                  w_lyr2_rdy;
  wire                                  w_lyr2_vld;
  wire [           OUTPUT_BITS   - 1:0] w_lyr2_dat;
  // intput mem
  wire                                  w_imem_vld;
  wire [ INPUT_BITS*L1_CHANNEL_NUM-1:0] w_imem_dat_cpck;
  wire                                  w_imem_re;
  wire [             L1_INPUT_ADDR-1:0] w_imem_raddr;
  // output mem
  wire [             OUTPUT_BITS - 1:0] w_omem_wdat;
  wire                                  w_omem_we;
  wire [            L1_OUTPUT_ADDR-1:0] w_omem_addr;
  // ------------------------- reg ------------------------- 
  // ------------------------ assign ----------------------- 
  // ------------------------ always ----------------------- 
  // ------------------- Unpack / Pack -------------------  
  // ------------------------- module ---------------------- 


  global_ctl #(
      .LAYER_NUM       (LAYER_NUM),
      .INPUT_BITS      (INPUT_BITS),
      .WEIGHT_BITS     (WEIGHT_BITS),
      .OUTPUT_BITS     (OUTPUT_BITS),
      .L1_PADDING_EN   (L1_PADDING_EN),
      .L1_INPUT_WIDTH  (L1_INPUT_WIDTH),
      .L1_INPUT_HEIGHT (L1_INPUT_HEIGHT),
      .L1_FMAP_WIDTH   (L1_FMAP_WIDTH),
      .L1_FMAP_HEIGHT  (L1_FMAP_HEIGHT),
      .L1_WEIGHT_WIDTH (L1_WEIGHT_WIDTH),
      .L1_WEIGHT_HEIGHT(L1_WEIGHT_HEIGHT),
      .L1_OUTPUT_WIDTH (L1_OUTPUT_WIDTH),
      .L1_OUTPUT_HEIGHT(L1_OUTPUT_HEIGHT),
      .L1_LINE_WIDTH   (L1_LINE_WIDTH),
      .L1_LINE_HEIGHT  (L1_LINE_HEIGHT),
      .L1_PATCH_WIDTH  (L1_PATCH_WIDTH),
      .L1_PATCH_HEIGHT (L1_PATCH_HEIGHT),
      .L1_CHANNEL_NUM  (L1_CHANNEL_NUM),
      .L2_PADDING_EN   (L2_PADDING_EN),
      .L2_INPUT_WIDTH  (L2_INPUT_WIDTH),
      .L2_INPUT_HEIGHT (L2_INPUT_HEIGHT),
      .L2_FMAP_WIDTH   (L2_FMAP_WIDTH),
      .L2_FMAP_HEIGHT  (L2_FMAP_HEIGHT),
      .L2_WEIGHT_WIDTH (L2_WEIGHT_WIDTH),
      .L2_WEIGHT_HEIGHT(L2_WEIGHT_HEIGHT),
      .L2_OUTPUT_WIDTH (L2_OUTPUT_WIDTH),
      .L2_OUTPUT_HEIGHT(L2_OUTPUT_HEIGHT),
      .L2_LINE_WIDTH   (L2_LINE_WIDTH),
      .L2_LINE_HEIGHT  (L2_LINE_HEIGHT),
      .L2_PATCH_WIDTH  (L2_PATCH_WIDTH),
      .L2_PATCH_HEIGHT (L2_PATCH_HEIGHT),
      .L2_CHANNEL_NUM  (L2_CHANNEL_NUM)
  ) inst_global_ctl (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .i_st        (i_st),
      .i_lyr1_rdy  (w_lyr1_rdy),
      .i_lyr1_wrdn (w_lyr1_wrdn),
      .i_lyr2_wrdn (w_lyr2_wrdn),
      .o_imem_re   (w_imem_re),
      .o_imem_raddr(w_imem_raddr)
  );
  // INPUT mem
  simple_dual_port_bram #(
      .WIDTH    (INPUT_BITS * L1_CHANNEL_NUM),
      .DEPTH    (L1_INPUT_AREA),
      .INIT_FILE(INIT_INPUT_BRAM)
  ) input_mem (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_re   (w_imem_re),
      .i_raddr(w_imem_raddr),
      .i_we   (),
      .i_waddr(),
      .i_wdin (),
      .o_vld  (w_imem_vld ),
      .o_dout ( w_imem_dat_cpck)
  );

  // weight
  simple_dual_port_bram #(
      .WIDTH    (WEIGHT_BITS * L1_CHANNEL_NUM),
      .DEPTH    (L1_WEIGHT_AREA),
      .INIT_FILE(INIT_WEIGHT_BRAM1)
  ) wgt_mem1 (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_re   (w_lyr1_wre),
      .i_raddr(w_lyr1_wraddr),
      .i_we   (0),
      .i_waddr(0),
      .i_wdin (0),
      .o_vld  (w_lyr1_wvld),
      .o_dout (w_lyr1_wdat_pck)
  );

  simple_dual_port_bram #(
      .WIDTH    (WEIGHT_BITS * L2_CHANNEL_NUM),
      .DEPTH    (L2_WEIGHT_WIDTH * L2_WEIGHT_HEIGHT),
      .INIT_FILE(INIT_WEIGHT_BRAM2)
  ) wgt_mem2 (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_re   (w_lyr2_wre),
      .i_raddr(w_lyr2_wraddr),
      .i_we   (0),
      .i_waddr(0),
      .i_wdin (0),
      .o_vld  (w_lyr2_wvld),
      .o_dout (w_lyr2_wdat_pck)
  );
  skid_buffer #(
      .INPUT_BITS (INPUT_BITS),
      .CHANNEL_NUM(L1_CHANNEL_NUM),
      .MEM_LATENCY(2)
  ) inst_skid_buffer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_ipt_vld (w_imem_vld),
      .i_ipt_din (w_imem_dat_cpck),
      .o_ipt_rdy (),
      .i_opt_rdy (w_lyr1_rdy),
      .o_opt_dout(w_sbuf_dat),
      .o_opt_vld (w_sbuf_vld)
  );
  layer #(
      .PADDING_EN   (L1_PADDING_EN),
      .RELU_EN      (L1_RELU_EN),
      .FMAP_WIDTH   (L1_FMAP_WIDTH),
      .FMAP_HEIGHT  (L1_FMAP_HEIGHT),
      .INPUT_BITS   (INPUT_BITS),
      .INPUT_WIDTH  (L1_INPUT_WIDTH),
      .INPUT_HEIGHT (L1_INPUT_HEIGHT),
      .WEIGHT_BITS  (WEIGHT_BITS),
      .WEIGHT_WIDTH (L1_WEIGHT_WIDTH),
      .WEIGHT_HEIGHT(L1_WEIGHT_HEIGHT),
      .OUTPUT_BITS  (OUTPUT_BITS),
      .OUTPUT_WIDTH (L1_OUTPUT_WIDTH),
      .OUTPUT_HEIGHT(L1_OUTPUT_HEIGHT),
      .LINE_WIDTH   (L1_LINE_WIDTH),
      .LINE_HEIGHT  (L1_LINE_HEIGHT),
      .PATCH_WIDTH  (L1_PATCH_WIDTH),
      .PATCH_HEIGHT (L1_PATCH_HEIGHT),
      .CHANNEL_NUM  (L1_CHANNEL_NUM)
  ) layer1 (
      .i_clk         (i_clk),
      .i_rstn        (i_rstn),
      .i_st          (i_st),
      // wgt
      .i_wgt_vld     (w_lyr1_wvld),
      .i_wgt_din_pck(w_lyr1_wdat_pck),
      .o_wgt_re      (w_lyr1_wre),
      .o_wgt_raddr   (w_lyr1_wraddr),
      .o_wgt_rdn     (w_lyr1_wrdn),      // wgt read done
      // ipt
      .o_ipt_re      (),
      .o_ipt_raddr   (),
      .o_ipt_rdy     (w_lyr1_rdy),
      .i_ipt_vld     (w_sbuf_vld),
      .i_ipt_din_pck(w_sbuf_dat),
      // opt
      .i_opt_rdy     (w_lyr2_rdy),       // for test
      .o_opt_vld     (w_lyr1_vld),
      .o_opt_dout    (w_lyr1_dat)
  );
  layer #(
      .PADDING_EN   (L2_PADDING_EN),
      .RELU_EN      (L2_RELU_EN),
      .FMAP_WIDTH   (L2_FMAP_WIDTH),
      .FMAP_HEIGHT  (L2_FMAP_HEIGHT),
      .INPUT_BITS   (INPUT_BITS),
      .INPUT_WIDTH  (L2_INPUT_WIDTH),
      .INPUT_HEIGHT (L2_INPUT_HEIGHT),
      .WEIGHT_BITS  (WEIGHT_BITS),
      .WEIGHT_WIDTH (L2_WEIGHT_WIDTH),
      .WEIGHT_HEIGHT(L2_WEIGHT_HEIGHT),
      .OUTPUT_BITS  (OUTPUT_BITS),
      .OUTPUT_WIDTH (L2_OUTPUT_WIDTH),
      .OUTPUT_HEIGHT(L2_OUTPUT_HEIGHT),
      .LINE_WIDTH   (L2_LINE_WIDTH),
      .LINE_HEIGHT  (L2_LINE_HEIGHT),
      .PATCH_WIDTH  (L2_PATCH_WIDTH),
      .PATCH_HEIGHT (L2_PATCH_HEIGHT),
      .CHANNEL_NUM  (L2_CHANNEL_NUM)
  ) layer2 (
      .i_clk         (i_clk),
      .i_rstn        (i_rstn),
      .i_st          (i_st),
      // wgt
      .i_wgt_vld     (w_lyr2_wvld),
      .i_wgt_din_pck(w_lyr2_wdat_pck),
      .o_wgt_re      (w_lyr2_wre),
      .o_wgt_raddr   (w_lyr2_wraddr),
      .o_wgt_rdn     (w_lyr2_wrdn),
      // ipt
      .o_ipt_re      (),
      .o_ipt_raddr   (),
      .o_ipt_rdy     (w_lyr2_rdy),
      .i_ipt_vld     (w_lyr1_vld),
      .i_ipt_din_pck(w_lyr1_dat),
      // opt
      .i_opt_rdy     ('d1),              // for test
      .o_opt_vld     (w_lyr2_vld),
      .o_opt_dout    (w_lyr2_dat)
  );


  // OUTPUT mem
  simple_dual_port_bram #(
      .WIDTH    (OUTPUT_BITS),
      .DEPTH    (L1_OUTPUT_WIDTH * L1_OUTPUT_HEIGHT),
      .INIT_FILE()
  ) output_mem (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_re   (),
      .i_raddr(),
      .i_we   (w_lyr2_vld),
      .i_waddr(0),
      .i_wdin (w_lyr2_dat),
      .o_vld  (),
      .o_dout ()
  );
endmodule

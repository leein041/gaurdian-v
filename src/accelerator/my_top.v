`include "defines.vh"
module my_top #(
    //
    parameter PADDING_EN    = 1,
    parameter WEIGHT_BITS   = 16,
    parameter INPUT_BITS    = 16,
    parameter OUTPUT_BITS   = 16,
    parameter INPUT_WIDTH   = 150,
    parameter INPUT_HEIGHT  = 150,
    parameter IMAGE_WIDTH   = 150,
    parameter IMAGE_HEIGHT  = 150,
    parameter OUTPUT_WIDTH  = 150,
    parameter OUTPUT_HEIGHT = 150,
    parameter PATCH_WIDTH   = 3,
    parameter PATCH_HEIGHT  = 3,
    parameter L1_RELU_EN    = 1,
    parameter L2_RELU_EN    = 1,
    parameter L3_RELU_EN    = 0,

    parameter L1_FILTER_GROUP_NUM = `L1_FILTER_GROUP_NUM,
    parameter L2_FILTER_GROUP_NUM = `L2_FILTER_GROUP_NUM,
    parameter L3_FILTER_GROUP_NUM = `L3_FILTER_GROUP_NUM,

`ifdef IMAGE_1
    parameter IMAGE_NUM = 1,
    parameter INPUT_INIT_FILE = "C:/DSD26_Termproject_Materials/02_Provided_Data/input_Y_channel_only_hex/test_51_hex.txt",
`elsif IMAGE_3
    parameter IMAGE_NUM = 3,
    parameter INPUT_INIT_FILE = "C:/DSD26_Termproject_Materials/03_Demo_Environment/input_image/input_text51_89_64.txt",
`endif

`ifdef RELEASE_4_2
    parameter L1_CHANNEL_NUM = 1,
    parameter L1_FILTER_NUM  = 4,
    parameter L2_CHANNEL_NUM = 4,
    parameter L2_FILTER_NUM  = 2,
    parameter L3_CHANNEL_NUM = 2,
    parameter L3_FILTER_NUM  = 1,
`elsif RELEASE_8_4
    parameter L1_CHANNEL_NUM = 1,
    parameter L1_FILTER_NUM  = 8,
    parameter L2_CHANNEL_NUM = 8,
    parameter L2_FILTER_NUM  = 4,
    parameter L3_CHANNEL_NUM = 4,
    parameter L3_FILTER_NUM  = 1,
`elsif RELEASE_8_8
    parameter L1_CHANNEL_NUM = 1,
    parameter L1_FILTER_NUM  = 8,
    parameter L2_CHANNEL_NUM = 8,
    parameter L2_FILTER_NUM  = 8,
    parameter L3_CHANNEL_NUM = 8,
    parameter L3_FILTER_NUM  = 1,
`elsif DEBUG
    parameter L1_CHANNEL_NUM = 1,
    parameter L2_CHANNEL_NUM = 2,
    parameter L3_CHANNEL_NUM = 2,

    parameter  L1_FILTER_NUM   = 2,
    parameter  L2_FILTER_NUM   = 2,
    parameter  L3_FILTER_NUM   = 1,
`endif
    // layer 1
    localparam L1_WEIGHT_DEPTH = PATCH_WIDTH * PATCH_HEIGHT * L1_CHANNEL_NUM * L1_FILTER_NUM,
    localparam L1_WEIGHT_ADDR  = $clog2(L1_WEIGHT_DEPTH),
    // layer 2
    localparam L2_WEIGHT_DEPTH = PATCH_WIDTH * PATCH_HEIGHT * L2_CHANNEL_NUM * L2_FILTER_NUM,
    localparam L2_WEIGHT_ADDR  = $clog2(L2_WEIGHT_DEPTH),
    // layer 3
    localparam L3_WEIGHT_DEPTH = PATCH_WIDTH * PATCH_HEIGHT * L3_CHANNEL_NUM * L3_FILTER_NUM,
    localparam L3_WEIGHT_ADDR  = $clog2(L3_WEIGHT_DEPTH),


    localparam INPUT_DEPTH  = INPUT_WIDTH * INPUT_HEIGHT * IMAGE_NUM,
    localparam INPUT_ADDR   = $clog2(INPUT_DEPTH),
    localparam IMAGE_DEPTH  = IMAGE_WIDTH * IMAGE_HEIGHT,
    localparam IMAGE_ADDR   = $clog2(IMAGE_DEPTH),
    localparam OUTPUT_DEPTH = OUTPUT_WIDTH * OUTPUT_HEIGHT * IMAGE_NUM,
    localparam OUTPUT_ADDR  = $clog2(OUTPUT_DEPTH),

    localparam L1_REQ = L1_FILTER_NUM / L1_FILTER_GROUP_NUM,
    localparam L2_REQ = L2_FILTER_NUM / L2_FILTER_GROUP_NUM,
    localparam L3_REQ = L3_FILTER_NUM / L3_FILTER_GROUP_NUM,
    localparam MAX_FILTER = `MAX2(L1_REQ, `MAX2(L2_REQ, L3_REQ)),
    localparam MAX_FILTER_GROUP_NUM =
    `MAX2(L1_FILTER_GROUP_NUM, `MAX2(L2_FILTER_GROUP_NUM, L3_FILTER_GROUP_NUM)),
    localparam MAX_CHANNEL = `MAX2(L1_CHANNEL_NUM, `MAX2(L2_CHANNEL_NUM, L3_CHANNEL_NUM)),
    localparam MAX_WEIGHT_ADDR = `MAX2(L1_WEIGHT_ADDR, `MAX2(L2_WEIGHT_ADDR, L3_WEIGHT_ADDR)),
    localparam LAYER_NUM = 3,


`ifdef RELEASE_4_2
    parameter L1_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_4_2weight/fixed_point_W1_hex.txt",
    parameter L1_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_4_2bias/fixed_point_B1_hex.txt",
    parameter L2_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_4_2weight/fixed_point_W2_hex.txt",
    parameter L2_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_4_2bias/fixed_point_B2_hex.txt",
    parameter L3_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_4_2weight/fixed_point_W3_hex.txt",
    parameter L3_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_4_2bias/fixed_point_B3_hex.txt",
`elsif RELEASE_8_4
    parameter L1_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_4weight/fixed_point_W1_hex.txt",
    parameter L1_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_4bias/fixed_point_B1_hex.txt",
    parameter L2_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_4weight/fixed_point_W2_hex.txt",
    parameter L2_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_4bias/fixed_point_B2_hex.txt",
    parameter L3_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_4weight/fixed_point_W3_hex.txt",
    parameter L3_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_4bias/fixed_point_B3_hex.txt",
`elsif RELEASE_8_8
    parameter L1_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_8weight/fixed_point_W1_hex.txt",
    parameter L1_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_8bias/fixed_point_B1_hex.txt",
    parameter L2_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_8weight/fixed_point_W2_hex.txt",
    parameter L2_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_8bias/fixed_point_B2_hex.txt",
    parameter L3_WEIGHT_INIT_FILE = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_8weight/fixed_point_W3_hex.txt",
    parameter L3_BIAS_INIT_FILE   = "c:/DSD26_Termproject_Materials/01_Reference_SW/q88_8_8bias/fixed_point_B3_hex.txt",
`elsif DEBUG  // 디버그는 테스트벤치에서 받음
    parameter L1_WEIGHT_INIT_FILE = "",
    parameter L1_BIAS_INIT_FILE = "",
    parameter L2_WEIGHT_INIT_FILE = "",
    parameter L2_BIAS_INIT_FILE = "",
    parameter L3_WEIGHT_INIT_FILE = "",
    parameter L3_BIAS_INIT_FILE = "",
`endif
    parameter PARAM_END_DUMMY = 0
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
  genvar g, f;
  integer i;

  //      ____ _____ ____  _____    _    __  __   _     ___ _   _ _____ 
  //     / ___|_   _|  _ \| ____|  / \  |  \/  | | |   |_ _| \ | | ____|
  //     \___ \ | | | |_) |  _|   / _ \ | |\/| | | |    | ||  \| |  _|  
  //      ___) || | |  _ <| |___ / ___ \| |  | | | |___ | || |\  | |___ 
  //     |____/ |_| |_| \_\_____/_/   \_\_|  |_| |_____|___|_| \_|_____|
  //                                                                    
`ifdef STREAMLINE

  // controller
  wire                                 w_ctrl_rdy;
  wire                                 w_img_st;
  // skide buffer
  wire                                 w_sbuf_rdy;
  wire [INPUT_BITS*L1_CHANNEL_NUM-1:0] w_sbuf_dat;
  wire                                 w_sbuf_vld;
  // layer 1 
  wire                                 w_lyr1_wrdn;
  wire                                 w_lyr1_rdy;
  wire                                 w_lyr1_vld;
  wire [ INPUT_BITS*L1_FILTER_NUM-1:0] w_lyr1_dat;
  // layer 2 
  wire                                 w_lyr2_wrdn;
  wire                                 w_lyr2_rdy;
  wire                                 w_lyr2_vld;
  wire [ INPUT_BITS*L2_FILTER_NUM-1:0] w_lyr2_dat;
  // layer 3 
  wire                                 w_lyr3_wrdn;
  wire                                 w_lyr3_rdy;
  wire                                 w_lyr3_vld;
  wire [ INPUT_BITS*L3_FILTER_NUM-1:0] w_lyr3_dat;
  // intput mem
  wire                                 w_ibuf_vld;
  wire [INPUT_BITS*L1_CHANNEL_NUM-1:0] w_ibuf_dat_cpck;
  wire                                 w_ibuf_re;
  wire [               INPUT_ADDR-1:0] w_ibuf_raddr;

  stline_global_ctrl #(
      .BITS        (INPUT_BITS),
      .IMAGE_NUM   (IMAGE_NUM),
      .INPUT_DEPTH (INPUT_DEPTH),
      .IMAGE_DEPTH (IMAGE_DEPTH),
      .OUTPUT_DEPTH(OUTPUT_DEPTH)
  ) streamline_global_ctl (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .i_st        (i_start),
      .o_ctrl_rdy  (w_ctrl_rdy),
      .o_img_st    (w_img_st),
      // layer
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
  simple_dual_port_ram #(
      .WIDTH    (INPUT_BITS * L1_CHANNEL_NUM),
      .DEPTH    (INPUT_DEPTH),
      .MEM_TYPE (`BRAM_TYPE),
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
      .LATENCY(2),
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
  stline_layer #(
      .IMAGE_NUM       (IMAGE_NUM),
      .PADDING_EN      (PADDING_EN),
      .RELU_EN         (L1_RELU_EN),
      .INPUT_BITS      (INPUT_BITS),
      .IMAGE_WIDTH     (IMAGE_WIDTH),
      .IMAGE_HEIGHT    (IMAGE_HEIGHT),
      .WEIGHT_BITS     (WEIGHT_BITS),
      .WEIGHT_DEPTH    (L1_WEIGHT_DEPTH),
      .OUTPUT_BITS     (OUTPUT_BITS),
      .PATCH_WIDTH     (PATCH_WIDTH),
      .PATCH_HEIGHT    (PATCH_HEIGHT),
      .CHANNEL_NUM     (L1_CHANNEL_NUM),
      .FILTER_NUM      (L1_FILTER_NUM),
      .WEIGHT_INIT_FILE(L1_WEIGHT_INIT_FILE),
      .BIAS_INIT_FILE  (L1_BIAS_INIT_FILE)
  ) layer1 (
      .i_clk        (i_clk),
      .i_rstn       (i_rstn),
      .i_wgt_st     (i_start),
      .i_img_st     (w_img_st),
      // wgt 
      .o_wgt_rdn    (w_lyr1_wrdn),  // wgt read done
      // ipt 
      .o_ipt_rdy    (w_lyr1_rdy),
      .i_ipt_vld    (w_sbuf_vld),
      .i_ipt_din_bus(w_sbuf_dat),
      // opt
      .i_opt_rdy    (w_lyr2_rdy),
      .o_opt_vld    (w_lyr1_vld),
      .o_opt_dout   (w_lyr1_dat)
  );
  stline_layer #(
      .IMAGE_NUM       (IMAGE_NUM),
      .PADDING_EN      (PADDING_EN),
      .RELU_EN         (L2_RELU_EN),
      .INPUT_BITS      (INPUT_BITS),
      .IMAGE_WIDTH     (IMAGE_WIDTH),
      .IMAGE_HEIGHT    (IMAGE_HEIGHT),
      .WEIGHT_BITS     (WEIGHT_BITS),
      .WEIGHT_DEPTH    (L2_WEIGHT_DEPTH),
      .OUTPUT_BITS     (OUTPUT_BITS),
      .PATCH_WIDTH     (PATCH_WIDTH),
      .PATCH_HEIGHT    (PATCH_HEIGHT),
      .CHANNEL_NUM     (L2_CHANNEL_NUM),
      .FILTER_NUM      (L2_FILTER_NUM),
      .WEIGHT_INIT_FILE(L2_WEIGHT_INIT_FILE),
      .BIAS_INIT_FILE  (L2_BIAS_INIT_FILE)
  ) layer2 (
      .i_clk        (i_clk),
      .i_rstn       (i_rstn),
      .i_wgt_st     (i_start),
      .i_img_st     (w_img_st),
      // wgt 
      .o_wgt_rdn    (w_lyr2_wrdn),
      // ipt 
      .o_ipt_rdy    (w_lyr2_rdy),
      .i_ipt_vld    (w_lyr1_vld),
      .i_ipt_din_bus(w_lyr1_dat),
      // opt
      .i_opt_rdy    (w_lyr3_rdy),
      .o_opt_vld    (w_lyr2_vld),
      .o_opt_dout   (w_lyr2_dat)
  );
  stline_layer #(
      .IMAGE_NUM       (IMAGE_NUM),
      .PADDING_EN      (PADDING_EN),
      .RELU_EN         (L3_RELU_EN),
      .INPUT_BITS      (INPUT_BITS),
      .IMAGE_WIDTH     (IMAGE_WIDTH),
      .IMAGE_HEIGHT    (IMAGE_HEIGHT),
      .WEIGHT_BITS     (WEIGHT_BITS),
      .WEIGHT_DEPTH    (L3_WEIGHT_DEPTH),
      .OUTPUT_BITS     (OUTPUT_BITS),
      .PATCH_WIDTH     (PATCH_WIDTH),
      .PATCH_HEIGHT    (PATCH_HEIGHT),
      .CHANNEL_NUM     (L3_CHANNEL_NUM),
      .FILTER_NUM      (L3_FILTER_NUM),
      .WEIGHT_INIT_FILE(L3_WEIGHT_INIT_FILE),
      .BIAS_INIT_FILE  (L3_BIAS_INIT_FILE)
  ) layer3 (
      .i_clk        (i_clk),
      .i_rstn       (i_rstn),
      .i_wgt_st     (i_start),
      .i_img_st     (w_img_st),
      // wgt 
      .o_wgt_rdn    (w_lyr3_wrdn),
      // ipt 
      .o_ipt_rdy    (w_lyr3_rdy),
      .i_ipt_vld    (w_lyr2_vld),
      .i_ipt_din_bus(w_lyr2_dat),
      // opt 
`ifdef DEBUG
      .i_opt_rdy    (w_ctrl_rdy),   // for hand shake test, change i_rdy_test
`else
      .i_opt_rdy    (w_ctrl_rdy),
`endif
      .o_opt_vld    (w_lyr3_vld),
      .o_opt_dout   (w_lyr3_dat)
  );
`endif  // STREAMLINE
  //      ____  _____ ____ _   _ ____  ____ _____     _______ 
  //     |  _ \| ____/ ___| | | |  _ \/ ___|_ _\ \   / / ____|
  //     | |_) |  _|| |   | | | | |_) \___ \| | \ \ / /|  _|  
  //     |  _ <| |__| |___| |_| |  _ < ___) | |  \ V / | |___ 
  //     |_| \_\_____\____|\___/|_| \_\____/___|  \_/  |_____|
  //                                                          
`ifdef RECURSIVE
  parameter URAM_WIDTH = (`MAX_FILTER_GROUP == 1) ?  INPUT_BITS * MAX_CHANNEL : INPUT_BITS * MAX_FILTER;
  wire                                  w_ctrl_rdy;
  // weight mem
  wire [                 LAYER_NUM-1:0] w_wgt_sel;
  wire                                  w_wgt_re;
  wire [           MAX_WEIGHT_ADDR-1:0] w_wgt_raddr;
  wire [                 LAYER_NUM-1:0] w_wgt_vld;
  wire [               WEIGHT_BITS-1:0] w_wgt_dat       [           0:LAYER_NUM-1];
  // intput mem
  wire                                  w_ibuf_vld;
  wire [                INPUT_BITS-1:0] w_ibuf_dat;
  wire                                  w_ibuf_re;
  wire [                INPUT_ADDR-1:0] w_ibuf_raddr;
  // act buffer
  wire                                  w_abuf_we;
  wire [                IMAGE_ADDR-1:0] w_abuf_waddr;
  wire [    INPUT_BITS*MAX_CHANNEL-1:0] w_abuf_wdat;
  wire                                  w_abuf_re;
  wire [                IMAGE_ADDR-1:0] w_abuf_raddr;
  wire [    INPUT_BITS*MAX_CHANNEL-1:0] w_abuf_rdat;
  // act/image buffer select
  wire                                  w_sel_vld;
  wire [    INPUT_BITS*MAX_CHANNEL-1:0] w_sel_dat;
  // skid
  wire                                  w_skid_rdy;
  wire [    INPUT_BITS*MAX_CHANNEL-1:0] w_skid_dat;
  wire                                  w_skid_vld;
  // layer  
  wire                                  w_lyr_relu_en;
  wire                                  w_lyr_rdy;
  wire                                  w_lyr_vld;
  wire [     INPUT_BITS*MAX_FILTER-1:0] w_lyr_dat;
  // temp
  wire [         $clog2(MAX_CHANNEL):0] w_ch_num;
  wire [          $clog2(MAX_FILTER):0] w_filt_num;
  wire [               MAX_CHANNEL-1:0] w_lbuf_st;
  wire [                           2:0] w_bias_sel;
  // group
  wire [$clog2(MAX_FILTER_GROUP_NUM):0] w_grp_sel;

  wire [  MAX_FILTER_GROUP_NUM - 1 : 0] w_ping_rvld_bus;
  wire [  MAX_FILTER_GROUP_NUM - 1 : 0] w_pong_rvld_bus;
  wire                                  w_abuf_sel;
  //
  wire [$clog2(MAX_FILTER_GROUP_NUM):0] w_vld_abuf;
  wire [          $clog2(MAX_FILTER):0] w_vld_ch;
  // ping-pong 
  wire [                URAM_WIDTH-1:0] w_ping_rdat_grp [0:MAX_FILTER_GROUP_NUM-1];
  wire [                URAM_WIDTH-1:0] w_pong_rdat_grp [0:MAX_FILTER_GROUP_NUM-1];
  wire [                URAM_WIDTH-1:0] w_rdat_raw_grp  [0:MAX_FILTER_GROUP_NUM-1];
  // ====================== reg ============================  
  reg                                   r_wgt_vld;
  reg  [               WEIGHT_BITS-1:0] r_wgt_dat;
  // ====================== assign =========================  
  assign w_sel_dat   = (w_ibuf_vld) ? {{(INPUT_BITS*(MAX_CHANNEL-1)){1'b0}} ,w_ibuf_dat} : w_abuf_rdat;
  generate
    if (MAX_FILTER_GROUP_NUM == 1) assign w_sel_vld = w_ibuf_vld || (|w_ping_rvld_bus);
    else assign w_sel_vld = w_ibuf_vld || (|w_ping_rvld_bus) || (|w_pong_rvld_bus);
  endgenerate
  generate
    // fiter group max : 1 
    if (MAX_FILTER_GROUP_NUM == 1) begin
`ifdef RELEASE_8_8
      assign w_abuf_rdat = w_rdat_raw_grp[0][URAM_WIDTH-1:0];
`elsif RELEASE_4_2
      assign w_abuf_rdat = w_rdat_raw_grp[0][URAM_WIDTH-1:0];
`elsif DEBUG
      assign w_abuf_rdat = w_rdat_raw_grp[0][URAM_WIDTH-1:0];
`endif
    end  // fiter group max : 2 
    else if (MAX_FILTER_GROUP_NUM == 2) begin
`ifdef RELEASE_8_8
      assign w_abuf_rdat =  
          (w_vld_abuf == 2 && w_vld_ch == 4) ? { w_rdat_raw_grp[1][63:0], w_rdat_raw_grp[0][63:0] } :  
                                                 w_rdat_raw_grp[0][URAM_WIDTH-1:0];
`elsif RELEASE_4_2
      assign w_abuf_rdat =  
          (w_vld_abuf == 2 && w_vld_ch == 2) ? { w_rdat_raw_grp[1][31:0], w_rdat_raw_grp[0][31:0] } :   
                                                 w_rdat_raw_grp[0][URAM_WIDTH-1:0];
`elsif DEBUG
      assign w_abuf_rdat =   
      (w_vld_abuf == 2 && w_vld_ch == 1) ? { 
                                              w_rdat_raw_grp[1][15:0], 
                                              w_rdat_raw_grp[0][15:0] 
                                            } :
      w_rdat_raw_grp[0][URAM_WIDTH-1:0];
`endif
      // fiter group max : 4 
    end else if (MAX_FILTER_GROUP_NUM == 4) begin
`ifdef RELEASE_8_8
      assign w_abuf_rdat =  
          (w_vld_abuf == 2 && w_vld_ch == 4) ? { w_rdat_raw_grp[1][63:0], w_rdat_raw_grp[0][63:0] } : 
          (w_vld_abuf == 4 && w_vld_ch == 2) ? { w_rdat_raw_grp[3][31:0], w_rdat_raw_grp[2][31:0], w_rdat_raw_grp[1][31:0], w_rdat_raw_grp[0][31:0] } :    
                                                 w_rdat_raw_grp[0][URAM_WIDTH-1:0];
`elsif RELEASE_4_2
      assign w_abuf_rdat =  
          (w_vld_abuf == 2 && w_vld_ch == 2) ? {   w_rdat_raw_grp[1][31:0], w_rdat_raw_grp[0][31:0] } : 
          (w_vld_abuf == 4 && w_vld_ch == 1) ? { w_rdat_raw_grp[3][15:0], w_rdat_raw_grp[2][15:0], w_rdat_raw_grp[1][15:0], w_rdat_raw_grp[0][15:0] } :      
                                                 w_rdat_raw_grp[0][URAM_WIDTH-1:0];
`elsif DEBUG
      assign w_abuf_rdat =   
      (w_vld_abuf == 2 && w_vld_ch == 1) ? { 
                                              w_rdat_raw_grp[1][15:0], 
                                              w_rdat_raw_grp[0][15:0] 
                                            } :
      w_rdat_raw_grp[0][URAM_WIDTH-1:0];
`endif
    end

    wire [URAM_WIDTH-1 : 0] w_masked_wdin = 
          (w_filt_num == 1) ? {{(URAM_WIDTH - INPUT_BITS){1'b0}}, w_abuf_wdat[INPUT_BITS-1 : 0]} : 
          (w_filt_num == 2) ? {{(URAM_WIDTH - INPUT_BITS*2){1'b0}}, w_abuf_wdat[INPUT_BITS*2-1 : 0]} : 
          w_abuf_wdat;
  endgenerate

  generate
    if (MAX_FILTER_GROUP_NUM == 1) assign w_rdat_raw_grp[0] = w_ping_rdat_grp[0];
    else begin
      for (g = 0; g < MAX_FILTER_GROUP_NUM; g = g + 1) begin
        assign w_rdat_raw_grp[g] = (w_abuf_sel == 1'b1) ? w_ping_rdat_grp[g] : w_pong_rdat_grp[g];
      end
    end
  endgenerate
  // ====================== always =========================  
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_wgt_vld <= 'b0;
      r_wgt_dat <= 'd0;
    end else begin
      if (|w_wgt_vld) begin
        r_wgt_vld <= 'b1;
        for (i = 0; i < LAYER_NUM; i = i + 1) begin
          if (w_wgt_vld[i]) begin
            r_wgt_dat <= w_wgt_dat[i];
          end
        end
      end else r_wgt_vld <= 'b0;

    end
  end
  // ====================== module ========================= 
  rcursiv_global_ctrl #(
      .IMAGE_NUM          (IMAGE_NUM),
      .BITS               (INPUT_BITS),
      .INPUT_DEPTH        (INPUT_DEPTH),
      .IMAGE_DEPTH        (IMAGE_DEPTH),
      .WEIGHT_BITS        (WEIGHT_BITS),
      .L1_CHANNEL_NUM     (L1_CHANNEL_NUM),
      .L1_FILTER_NUM      (L1_FILTER_NUM),
      .L1_WEIGHT_DEPTH    (L1_WEIGHT_DEPTH),
      .L2_CHANNEL_NUM     (L2_CHANNEL_NUM),
      .L2_FILTER_NUM      (L2_FILTER_NUM),
      .L2_WEIGHT_DEPTH    (L2_WEIGHT_DEPTH),
      .L3_CHANNEL_NUM     (L3_CHANNEL_NUM),
      .L3_FILTER_NUM      (L3_FILTER_NUM),
      .L3_WEIGHT_DEPTH    (L3_WEIGHT_DEPTH),
      .L1_FILTER_GROUP_NUM(L1_FILTER_GROUP_NUM),
      .L2_FILTER_GROUP_NUM(L2_FILTER_GROUP_NUM),
      .L3_FILTER_GROUP_NUM(L3_FILTER_GROUP_NUM)
  ) inst_global_ctl (
      .i_clk        (i_clk),
      .i_rstn       (i_rstn),
      .i_st         (i_start),
      .o_ctrl_rdy   (w_ctrl_rdy),
      // wgt
      .o_wgt_re     (w_wgt_re),
      .o_wgt_raddr  (w_wgt_raddr),
      .o_wgt_sel    (w_wgt_sel),
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
      .i_lyr_vld    (w_lyr_vld),
      .i_lyr_din    (w_lyr_dat),
      .o_lyr_relu_en(w_lyr_relu_en),
      // opt mem
      .o_obuf_we    (output_bram_wen),
      .o_obuf_addr  (output_bram_waddr),
      .o_obuf_dout  (L3_p_out),
      .o_done       (o_done),
      // temp
      .o_ch_num     (w_ch_num),
      .o_filt_num   (w_filt_num),
      .o_lbuf_st    (w_lbuf_st),
      .o_bias_sel   (w_bias_sel),
      // group
      .o_grp_sel    (w_grp_sel),
      .o_abuf_sel   (w_abuf_sel),
      //
      .o_vld_abuf   (w_vld_abuf),
      .o_vld_ch     (w_vld_ch)
  );
  // input buffer
  simple_dual_port_ram #(
      .WIDTH    (INPUT_BITS),
      .DEPTH    (INPUT_DEPTH),
      .INIT_FILE(INPUT_INIT_FILE)
  ) input_buf (
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
  generate
    // 필터 그룹화를 안했을때 ( 핑퐁 버퍼 피룡 x )
    if (MAX_FILTER_GROUP_NUM == 1) begin
      simple_dual_port_ram #(
          .WIDTH   (URAM_WIDTH),
          .DEPTH   (IMAGE_DEPTH),
          .MEM_TYPE(`URAM_TYPE)
      ) ping_grp (
          .i_clk  (i_clk),
          .i_rstn (i_rstn),
          .i_re   (w_abuf_re),
          .i_raddr(w_abuf_raddr),
          .i_we   (w_abuf_we),
          .i_waddr(w_abuf_waddr),
          .i_wdin (w_masked_wdin),
          .o_vld  (w_ping_rvld_bus[0]),
          .o_dout (w_ping_rdat_grp[0])
      );
    end else begin
      for (g = 0; g < MAX_FILTER_GROUP_NUM; g = g + 1) begin
        simple_dual_port_ram #(
            .WIDTH   (URAM_WIDTH),
            .DEPTH   (IMAGE_DEPTH),
            .MEM_TYPE(`URAM_TYPE)
        ) ping_grp (
            .i_clk  (i_clk),
            .i_rstn (i_rstn),
            .i_re   (w_abuf_re && (w_abuf_sel == 1'b1)),
            .i_raddr(w_abuf_raddr),
            .i_we   (w_abuf_we && (w_grp_sel == g) && (w_abuf_sel == 1'b0)),
            .i_waddr(w_abuf_waddr),
            .i_wdin (w_masked_wdin),
            .o_vld  (w_ping_rvld_bus[g]),
            .o_dout (w_ping_rdat_grp[g])
        );

        simple_dual_port_ram #(
            .WIDTH   (URAM_WIDTH),
            .DEPTH   (IMAGE_DEPTH),
            .MEM_TYPE(`URAM_TYPE)
        ) pong_grp (
            .i_clk  (i_clk),
            .i_rstn (i_rstn),
            .i_re   (w_abuf_re && (w_abuf_sel == 1'b0)),
            .i_raddr(w_abuf_raddr),
            .i_we   (w_abuf_we && (w_grp_sel == g) && (w_abuf_sel == 1'b1)),
            .i_waddr(w_abuf_waddr),
            .i_wdin (w_masked_wdin),
            .o_vld  (w_pong_rvld_bus[g]),
            .o_dout (w_pong_rdat_grp[g])
        );
      end
    end
  endgenerate
  // image/act - layer skid buffer
  skid_buffer #(
      .BITS    (INPUT_BITS * MAX_CHANNEL),
      .LATENCY (3),
      .MEM_SKID(1)
  ) inst_skid_buffer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // ipt
      .i_ipt_vld (w_sel_vld),
      .i_ipt_din (w_sel_dat),
      .o_ipt_rdy (w_skid_rdy),
      // opt
      .i_opt_rdy (w_lyr_rdy),
      .o_opt_dout(w_skid_dat),
      .o_opt_vld (w_skid_vld)
  );
  // weight buffer
  generate
    for (g = 0; g < LAYER_NUM; g = g + 1) begin : WEIGHT_BUFFER
      localparam TEMP_WEIGHT_DEPTH = (g == 0) ? L1_WEIGHT_DEPTH :
                                     (g == 1) ? L2_WEIGHT_DEPTH : 
                                     (g == 2) ? L3_WEIGHT_DEPTH : L3_WEIGHT_DEPTH;

      localparam TEMP_WEIGHT_ADDR = (g == 0) ? L1_WEIGHT_ADDR :
                                    (g == 1) ? L2_WEIGHT_ADDR : 
                                    (g == 2) ? L3_WEIGHT_ADDR : L3_WEIGHT_ADDR;

      localparam TEMP_WEIGHT_INIT = (g == 0) ? L1_WEIGHT_INIT_FILE :
                                    (g == 1) ? L2_WEIGHT_INIT_FILE : 
                                    (g == 2) ? L3_WEIGHT_INIT_FILE : "";
      simple_dual_port_ram #(
          .WIDTH    (WEIGHT_BITS),
          .DEPTH    (TEMP_WEIGHT_DEPTH),
          .INIT_FILE(TEMP_WEIGHT_INIT)
      ) wgt_buf (
          .i_clk  (i_clk),
          .i_rstn (i_rstn),
          .i_re   (w_wgt_re && w_wgt_sel[g]),
          .i_raddr(w_wgt_raddr[TEMP_WEIGHT_ADDR-1:0]),
          .i_we   (),
          .i_waddr(),
          .i_wdin (),
          .o_vld  (w_wgt_vld[g]),
          .o_dout (w_wgt_dat[g])
      );
    end
  endgenerate

  rcursiv_layer #(
      .L1_FILTER_GROUP_NUM(L1_FILTER_GROUP_NUM),
      .L2_FILTER_GROUP_NUM(L2_FILTER_GROUP_NUM),
      .L3_FILTER_GROUP_NUM(L3_FILTER_GROUP_NUM),
      .IMAGE_NUM          (IMAGE_NUM),
      .PADDING_EN         (PADDING_EN),
      .WEIGHT_BITS        (WEIGHT_BITS),
      .INPUT_BITS         (INPUT_BITS),
      .IMAGE_WIDTH        (IMAGE_WIDTH),
      .IMAGE_HEIGHT       (IMAGE_HEIGHT),
      .OUTPUT_BITS        (OUTPUT_BITS),
      .PATCH_WIDTH        (PATCH_WIDTH),
      .PATCH_HEIGHT       (PATCH_HEIGHT),
      .L1_CHANNEL_NUM     (L1_CHANNEL_NUM),
      .L1_FILTER_NUM      (L1_FILTER_NUM),
      .L1_WEIGHT_DEPTH    (L1_WEIGHT_DEPTH), 
      .L1_BIAS_INIT_FILE  (L1_BIAS_INIT_FILE),
      .L2_CHANNEL_NUM     (L2_CHANNEL_NUM),
      .L2_FILTER_NUM      (L2_FILTER_NUM),
      .L2_WEIGHT_DEPTH    (L2_WEIGHT_DEPTH), 
      .L2_BIAS_INIT_FILE  (L2_BIAS_INIT_FILE),
      .L3_CHANNEL_NUM     (L3_CHANNEL_NUM),
      .L3_FILTER_NUM      (L3_FILTER_NUM),
      .L3_WEIGHT_DEPTH    (L3_WEIGHT_DEPTH), 
      .L3_BIAS_INIT_FILE  (L3_BIAS_INIT_FILE)
  ) inst_rcursiv_layer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // wgt 
      .i_wgt_vld (r_wgt_vld),
      .i_wgt_din (r_wgt_dat),
      // ipt 
      .o_ipt_rdy (w_lyr_rdy),
      .i_ipt_vld (w_skid_vld),
      .i_ipt_din (w_skid_dat),
      // opt  
      .i_opt_rdy (w_ctrl_rdy),
      .o_opt_vld (w_lyr_vld),
      .o_opt_dout(w_lyr_dat),
      // temp
      .i_relu_en (w_lyr_relu_en),
      .i_ch_num  (w_ch_num),
      .i_filt_num(w_filt_num),
      .i_lbuf_st (w_lbuf_st),
      .i_bias_sel(w_bias_sel),
      .i_grp_sel (w_grp_sel)
  );
`endif  // RECURSIVE

endmodule

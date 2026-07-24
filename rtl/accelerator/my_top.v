
`include "defines.vh"
`include "network_config.vh"
module my_top #(
    parameter IMG_INIT_FILE     = "",
    parameter L1_WGT_INIT_FILE  = "",
    parameter L1_BIAS_INIT_FILE = "",
    parameter L2_WGT_INIT_FILE  = "",
    parameter L2_BIAS_INIT_FILE = "",
    parameter L3_WGT_INIT_FILE  = "",
    parameter L3_BIAS_INIT_FILE = "",


    parameter PARAM_END_DUMMY = 0
) (
`ifdef DEBUG
    input                                i_rdy_test,
    output        [$clog2(`LAYER_NUM):0] o_lyr_num,
    output                               o_lyr_vld,
    output signed [        `IPT_BIT-1:0] o_lyr_dat,
`endif
    input                                i_clk,
    input                                i_rstn,
    input                                i_start,
    output                               o_done
);
  // ====================== parmeter =======================  
  genvar g, f;
  integer i;

  localparam BIAS_ADDR = $clog2(`MAX_BIAS_DEPTH);
  localparam MAX_WGT_ADDR = $clog2(`MAX_WGT_DEPTH);
  localparam IPT_ADDR = $clog2(`MAX_IPT_AREA);
  localparam ACT_ADDR = $clog2(`MAX_IPT_AREA);

  localparam WGT_BANK_DEPTH = `MAX_CHANNEL * `CONV_3X3_AREA;
  localparam MAX_FBUF_DEPTH = `MAX_FILTER_GROUP_NUM * `MAX_IPT_AREA;

  wire                                                     gc_lyr_rdy;
  wire [                                   `LAYER_NUM-1:0] w_wbuf_vld;
  wire [                                     `WGT_BIT-1:0] w_wbuf_dat          [0:`LAYER_NUM-1];
  // bias buffer 
  wire [                                   `LAYER_NUM-1:0] w_bias_vld;
  wire [                                     `IPT_BIT-1:0] w_bias_dat          [0:`LAYER_NUM-1];
  // fmap buffer 
  wire                                                     fbuf_trc_vld;
  wire [             `OPT_BIT * `MAX_FILTER_GROUP_NUM-1:0] fbuf_trc_dat;
  // global controller (GC) 
  wire [                             $clog2(`LAYER_NUM):0] gc_lyr_idx;
  wire                                                     gc_fbuf_switch;
  wire                                                     gc_bl_st;
  wire                                                     gc_bl_bank_depth;
  wire [                      $clog2(`MAX_BIAS_DEPTH) : 0] gc_bl_req_len;
  wire [                      $clog2(`MAX_BIAS_DEPTH)-1:0] gc_bl_req_addr;
  wire [                    $clog2(`MAX_GROUP_FILTER) : 0] gc_br_read_len;
  wire [                    $clog2(`MAX_GROUP_FILTER)-1:0] gc_br_read_addr;
  wire                                                     gc_br_st;
  wire                                                     gc_wl_st;
  wire [          $clog2(`MAX_CHANNEL*`CONV_3X3_AREA) : 0] gc_wl_bank_depth;
  wire [                       $clog2(`MAX_WGT_DEPTH) : 0] gc_wl_req_len;
  wire [                       $clog2(`MAX_WGT_DEPTH)-1:0] gc_wl_req_addr;
  wire                                                     gc_wr_st;
  wire [                       $clog2(WGT_BANK_DEPTH) : 0] gc_wr_read_len;
  wire [                       $clog2(WGT_BANK_DEPTH)-1:0] gc_wr_read_addr;
  wire                                                     gc_tl_st;
  wire [                        $clog2(`MAX_IPT_SIDE) : 0] gc_tl_img_side;
  wire [                        $clog2(`MAX_IPT_SIDE) : 0] gc_tl_img_org_x;
  wire [                        $clog2(`MAX_IPT_SIDE) : 0] gc_tl_img_org_y;
  wire [                        $clog2(`MAX_IPT_AREA)-1:0] gc_tl_img_base_addr;
  wire                                                     gc_tr_st;
  wire [                   $clog2(`MAX_PAD_TILE_AREA) : 0] gc_tr_read_len;
  wire [                   $clog2(`MAX_PAD_TILE_AREA)-1:0] gc_tr_read_addr;
  wire [                       $clog2(`MAX_TILE_AREA) : 0] gc_lyr_opt_area;
  wire                                                     gc_lyr_relu;
  wire [                   $clog2(`MAX_PAD_TILE_SIDE) : 0] gc_lyr_line_width;
  wire [                    $clog2(`MAX_GROUP_FILTER) : 0] gc_lyr_ch;
  wire [                           `MAX_GROUP_CHANNEL-1:0] gc_lyr_ch_mask;
  wire [                          $clog2(`MAX_FILTER) : 0] gc_lyr_pu;
  wire [                            `MAX_GROUP_FILTER-1:0] gc_lyr_pu_mask;
  wire                                                     gc_lyr_clr;
  wire                                                     gc_psc_st;
  wire [`CLOG2_SAFE( `MAX_CHANNEL / `MAX_GROUP_CHANNEL):0] gc_psc_sum_cnt;
  wire                                                     gc_fbuf_we;
  wire [                  `OPT_BIT* `MAX_GROUP_FILTER-1:0] gc_fbuf_wdat;
  wire [                  `CLOG2_SAFE(MAX_FBUF_DEPTH)-1:0] gc_fbuf_waddr;
  // bias mem (DDR)
  reg                                                      bias_brc_vld;
  reg  [                                     `IPT_BIT-1:0] bias_brc_dat;
  // bias read controller (BRC)
  wire                                                     brc_bias_re;
  wire [                      $clog2(`MAX_BIAS_DEPTH)-1:0] brc_bias_raddr;
  wire                                                     brc_bl_req_dn;
  wire                                                     bias_rc_fifo_vld;
  wire [                                     `IPT_BIT-1:0] bias_rc_fifo_dat;
  // FIFO 
  wire                                                     fifo_bl_vld;
  wire [                                     `IPT_BIT-1:0] fifo_bl_dat;
  wire                                                     fifo_tl_vld;
  wire [                `IPT_BIT* `MAX_GROUP_CHANNEL -1:0] fifo_tl_dat;
  // bias loader (BL) 
  wire                                                     bl_gc_dn;
  wire [                      $clog2(`MAX_BIAS_DEPTH) : 0] bl_rc_req_len;
  wire                                                     bl_rc_req;
  wire [                      $clog2(`MAX_BIAS_DEPTH)-1:0] bl_rc_req_addr;
  wire                                                     bl_lyr_vld;
  wire [                                    `IPT_BIT -1:0] bl_lyr_dat;
  wire                                                     bl_fifo_rdy;
  wire [                      $clog2(`MAX_GROUP_FILTER):0] bl_bb_bank_idx;
  wire                                                     bl_bb_we;
  wire [                    $clog2(`MAX_GROUP_FILTER)-1:0] bl_bb_waddr;
  wire [                                     `IPT_BIT-1:0] bl_bb_wdat;
  // bias buffer (BB) 
  wire                                                     bb_br_vld;
  wire [                   `IPT_BIT*`MAX_GROUP_FILTER-1:0] bb_br_dat;
  // bias reader (BR) 
  wire                                                     br_gc_dn;
  wire                                                     br_bb_re;
  wire [                    $clog2(`MAX_GROUP_FILTER)-1:0] br_bb_raddr;
  wire                                                     br_psc_vld;
  wire [                   `IPT_BIT*`MAX_GROUP_FILTER-1:0] br_psc_dat;
  // weight (DDR)
  reg                                                      wbuf_wrc_vld;
  reg  [                                     `WGT_BIT-1:0] wbuf_wrc_dat;
  // weight read controller (WRC)
  wire                                                     wrc_wbuf_re;
  wire [                                 MAX_WGT_ADDR-1:0] wrc_wbuf_raddr;
  wire                                                     wrc_wl_req_dn;
  wire                                                     wrc_fifo_vld;
  wire [                                     `WGT_BIT-1:0] wrc_fifo_dat;
  // weight fifo (FIFO)
  wire                                                     fifo_wl_vld;
  wire [                                     `WGT_BIT-1:0] fifo_wl_dat;
  // weight loader (WL) 
  wire                                                     wl_gc_dn;
  wire [                       $clog2(`MAX_WGT_DEPTH) : 0] wl_rc_req_len;
  wire                                                     wl_rc_req;
  wire [                       $clog2(`MAX_WGT_DEPTH)-1:0] wl_rc_req_addr;
  wire                                                     wl_fifo_rdy;
  wire                                                     wl_wb_bank_idx;
  wire                                                     wl_wb_we;
  wire [                         $clog2(WGT_BANK_DEPTH):0] wl_wb_waddr;
  wire [                                     `WGT_BIT-1:0] wl_wb_wdat;
  // weight buffer (WB) 
  wire                                                     wb_wr_vld;
  wire [                 `WGT_BIT * `MAX_GROUP_FILTER-1:0] wb_wr_dat;
  // weight reader (WR) 
  wire                                                     wr_gc_dn;
  wire                                                     wr_wb_re;
  wire [                         $clog2(WGT_BANK_DEPTH):0] wr_wb_raddr;
  wire                                                     wr_lyr_vld;
  wire [                 `WGT_BIT * `MAX_GROUP_FILTER-1:0] wr_lyr_dat;
  // input mem (DDR)
  wire                                                     img_irc_vld;
  wire [                                     `IPT_BIT-1:0] img_irc_dat;
  // tile read controller (TRC) 
  wire                                                     trc_fbuf_re;
  wire [                  `CLOG2_SAFE(MAX_FBUF_DEPTH)-1:0] trc_fbuf_raddr;
  wire                                                     trc_fifo_vld;
  wire [                  `IPT_BIT*`MAX_GROUP_CHANNEL-1:0] trc_fifo_dat;
  // tile loader (TL) 
  wire                                                     trc_tl_req_dn;
  wire                                                     tl_gc_dn;
  wire [                        $clog2(`MAX_IPT_AREA) : 0] tl_trc_req_len;
  wire                                                     tl_trc_req;
  wire [                        $clog2(`MAX_IPT_AREA)-1:0] tl_trc_req_addr;
  wire                                                     tl_fifo_rdy;
  wire                                                     tl_tb_we;
  wire [                     $clog2(`MAX_PAD_TILE_AREA):0] tl_tb_waddr;
  wire [                `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] tl_tb_wdat;
  // tile buffer (TB) 
  wire                                                     tb_tr_vld;
  wire [                `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] tb_tr_dat;
  // tile reader (TR) 
  // weight reader (WR) 
  wire                                                     tr_gc_dn;
  wire                                                     tr_tb_re;
  wire [              `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] tr_tb_raddr;
  wire                                                     tr_lyr_vld;
  wire [                `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] tr_lyr_dat; 
  // skid
  wire                                                     w_skid_rdy;
  wire [                   `IPT_BIT*`MAX_GROUP_FILTER-1:0] w_skid_dat;
  wire                                                     w_skid_vld;
  // layer   
  wire                                                     clyr_gc_dn;
  wire                                                     w_lyr_pad_en;
  wire                                                     w_conv_lyr_rdy;
  wire                                                     clyr_psc_vld;
  wire [                  `PSUM_BIT*`MAX_GROUP_FILTER-1:0] clyr_psc_dat;
  wire                                                     w_pool_lyr_rdy;
  wire                                                     w_pool_lyr_vld;
  wire [                   `IPT_BIT*`MAX_GROUP_FILTER-1:0] w_pool_lyr_dat;
  // partial sum
  wire                                                     psc_psb_rdy;
  wire                                                     psc_psb_re;
  wire [                  `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] psc_psb_raddr;
  wire                                                     psc_psb_we;
  wire [                  `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] psc_psb_waddr;
  wire [                  `PSUM_BIT*`MAX_GROUP_FILTER-1:0] psc_psb_wdat;
  wire                                                     psc_gc_vld;
  wire [                  `OPT_BIT* `MAX_GROUP_FILTER-1:0] psc_gc_dat;
  wire                                                     psc_gc_dn;

  wire                                                     psb_psc_rdy;
  wire                                                     psb_psc_rvld;
  wire [                  `PSUM_BIT*`MAX_GROUP_FILTER-1:0] psb_psc_rdat;
  // temp
  wire [                        $clog2(`MAX_LAYER_TYPE):0] w_lyr_type; 
  // ====================== reg ============================  
  // ====================== assign =========================     
`ifdef DEBUG
  assign o_lyr_vld = clyr_psc_vld;
  assign o_lyr_dat = clyr_psc_dat;
  assign o_lyr_num = gc_lyr_idx;
`endif
  // ====================== always =========================  
  // select WGT data
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      wbuf_wrc_vld <= 'b0;
      wbuf_wrc_dat <= 'd0;
    end else begin
      if (|w_wbuf_vld) begin
        wbuf_wrc_vld <= 'b1;
        for (i = 0; i < `LAYER_NUM; i = i + 1) begin
          if (w_wbuf_vld[i]) begin
            wbuf_wrc_dat <= w_wbuf_dat[i];
          end
        end
      end else wbuf_wrc_vld <= 'b0;
    end
  end
  // select bias data
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      bias_brc_vld <= 'b0;
      bias_brc_dat <= 'd0;
    end else begin
      if (|w_bias_vld) begin
        bias_brc_vld <= 'b1;
        for (i = 0; i < `LAYER_NUM; i = i + 1) begin
          if (w_bias_vld[i]) begin
            bias_brc_dat <= w_bias_dat[i];
          end
        end
      end else bias_brc_vld <= 'b0;
    end
  end

  // WGT buffer
  generate
    for (g = 1; g <= `LAYER_NUM; g = g + 1) begin : WGT_BUFFER
      localparam TEMP_WGT_INIT =  (g == 1) ? L1_WGT_INIT_FILE :
                                     (g == 2) ? L2_WGT_INIT_FILE : 
                                     (g == 3) ? L3_WGT_INIT_FILE : "";
      simple_dual_port_ram #(
          .WIDTH    (`WGT_BIT),
          .DEPTH    (`MAX_WGT_DEPTH),
          .INIT_FILE(TEMP_WGT_INIT)
      ) wgt_buf (
          .i_clk  (i_clk),
          .i_rstn (i_rstn),
          .i_re   (wrc_wbuf_re && (gc_lyr_idx == g)),
          .i_raddr(wrc_wbuf_raddr),
          .i_we   (),
          .i_waddr(),
          .i_wdin (),
          .o_vld  (w_wbuf_vld[g-1]),
          .o_dout (w_wbuf_dat[g-1])
      );
    end
  endgenerate
  // bias buffer
  generate
    for (g = 1; g <= `LAYER_NUM; g = g + 1) begin : BIAS_BUFFER

      localparam TEMP_BIAS_INIT = (g == 1) ?  L1_BIAS_INIT_FILE :
                                    (g == 2)  ? L2_BIAS_INIT_FILE : 
                                    (g == 3)  ? L3_BIAS_INIT_FILE : "";
      simple_dual_port_ram #(
          .WIDTH    (`IPT_BIT),
          .DEPTH    (`MAX_BIAS_DEPTH),
          .INIT_FILE(TEMP_BIAS_INIT)
      ) bias_buf (
          .i_clk  (i_clk),
          .i_rstn (i_rstn),
          .i_re   (brc_bias_re && (gc_lyr_idx == g)),
          .i_raddr(brc_bias_raddr),
          .i_we   (),
          .i_waddr(),
          .i_wdin (),
          .o_vld  (w_bias_vld[g-1]),
          .o_dout (w_bias_dat[g-1])
      );
    end
  endgenerate

  featuremap_buffer #(
      .WIDTH        (`OPT_BIT * `MAX_FILTER_GROUP_NUM),
      .DEPTH        (MAX_FBUF_DEPTH),
      .MEM_TYPE     (`BRAM_TYPE),
      .IMG_INIT_FILE(IMG_INIT_FILE)
  ) inst_featuremap_buffer (
      .i_clk         (i_clk),
      .i_rstn        (i_rstn),
      .i_is_first_lyr(gc_lyr_idx == 1),
      .i_switch      (gc_fbuf_switch),
      .i_re          (trc_fbuf_re),
      .i_raddr       (trc_fbuf_raddr),
      .i_we          (gc_fbuf_we),
      .i_waddr       (gc_fbuf_waddr),
      .i_wdat        (gc_fbuf_wdat),
      .o_opt_vld     (fbuf_trc_vld),
      .o_opt_dout    (fbuf_trc_dat)
  );

  // partial sum buffer (on-chip)
  buffer #(
      .WIDTH     (`PSUM_BIT * `MAX_GROUP_FILTER),
      .BANK_DEPTH(`MAX_TILE_AREA),
      .MEM_TYPE  (`BRAM_TYPE),
      .BANK_NUM  (1)
  ) inst_partialsum_buf (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      //
      .i_re      (psc_psb_re),
      .i_raddr   (psc_psb_raddr),
      //
      .i_bank_idx(0),
      .i_we      (psc_psb_we),
      .i_waddr   (psc_psb_waddr),
      .i_wdat    (psc_psb_wdat),
      //
      .o_ipt_rdy (psb_psc_rdy),
      .i_opt_rdy (psc_psb_rdy),
      .o_opt_vld (psb_psc_rvld),
      .o_opt_dout(psb_psc_rdat)
  );
  // ====================== module =========================   
  //       ____ _       _           _    ____            _             _ _           
  //      / ___| | ___ | |__   __ _| |  / ___|___  _ __ | |_ _ __ ___ | | | ___ _ __ 
  //     | |  _| |/ _ \| '_ \ / _` | | | |   / _ \| '_ \| __| '__/ _ \| | |/ _ \ '__|
  //     | |_| | | (_) | |_) | (_| | | | |__| (_) | | | | |_| | | (_) | | |  __/ |   
  //      \____|_|\___/|_.__/ \__,_|_|  \____\___/|_| |_|\__|_|  \___/|_|_|\___|_|   
  //                                                                                 
  global_ctrl inst_global_ctl (
      .i_clk          (i_clk),
      .i_rstn         (i_rstn),
      .i_st           (i_start),
      .o_ctrl_rdy     (gc_lyr_rdy),
      // fmap
      .o_fbuf_switch  (gc_fbuf_switch),
      // bias loader (BL) 
      .o_bl_st        (gc_bl_st),
      .o_bl_bank_depth(gc_bl_bank_depth),
      .o_bl_req_len   (gc_bl_req_len),
      .o_bl_req_addr  (gc_bl_req_addr),
      .i_bl_dn        (bl_gc_dn),
      // bias reader
      .o_br_st        (gc_br_st),
      .o_br_read_len  (gc_br_read_len),
      .o_br_read_addr (gc_br_read_addr),
      .i_br_dn        (br_gc_dn),
      // weight loader (WL)
      .o_wl_st        (gc_wl_st),
      .o_wl_bank_depth(gc_wl_bank_depth),
      .o_wl_req_len   (gc_wl_req_len),
      .o_wl_req_addr  (gc_wl_req_addr),
      .i_wl_dn        (wl_gc_dn),
      // weight reader
      .o_wr_st        (gc_wr_st),
      .o_wr_read_len  (gc_wr_read_len),
      .o_wr_read_addr (gc_wr_read_addr),
      .i_wr_dn        (wr_gc_dn),
      // tile loader (TL) 
      .o_tl_st        (gc_tl_st),
      .o_img_org_x    (gc_tl_img_org_x),      // origin position
      .o_img_org_y    (gc_tl_img_org_y),
      .o_img_base_addr(gc_tl_img_base_addr),
      .i_tl_dn        (tl_gc_dn),
      // tile reader
      .o_tr_st        (gc_tr_st),
      .o_tr_read_len  (gc_tr_read_len),
      .o_tr_read_addr (gc_tr_read_addr),
      .i_tr_dn        (), 
      // skid
      .i_skid_rdy     (w_skid_rdy),
      // lyr  
      .i_lyr_dn       (clyr_gc_dn),
      .i_conv_lyr_vld (),
      .i_conv_lyr_din (),
      .i_pool_lyr_vld (w_pool_lyr_vld),
      .i_pool_lyr_din (w_pool_lyr_dat),
      .o_lyr_clr      (gc_lyr_clr),
      .o_lyr_relu_en  (gc_lyr_relu),
      .o_lyr_pad_en   (w_lyr_pad_en),
      .o_lyr_idx      (gc_lyr_idx),
      .o_lyr_opt_area (gc_lyr_opt_area),
      // PSC
      .o_psc_st       (gc_psc_st),
      .o_psc_sum_cnt  (gc_psc_sum_cnt),
      .i_psc_dn       (psc_gc_dn),
      .i_psc_vld      (psc_gc_vld),
      .i_psc_din      (psc_gc_dat),
      // 
      .o_done         (),
      .o_ddr_we       (gc_fbuf_we),
      .o_ddr_wdout    (gc_fbuf_wdat),
      .o_ddr_waddr    (gc_fbuf_waddr),
      // temp 
      .o_img_side     (gc_tl_img_side),
      .o_pad_tile_side(gc_lyr_line_width),
      .o_ch_num       (gc_lyr_ch),
      .o_pu_num       (gc_lyr_pu),
      .o_lyr_type     (w_lyr_type),
      // group  
      .o_ch_mask      (gc_lyr_ch_mask),
      .o_pu_mask      (gc_lyr_pu_mask)
  );

  //      ____  _           
  //     | __ )(_) __ _ ___ 
  //     |  _ \| |/ _` / __|
  //     | |_) | | (_| \__ \
  //     |____/|_|\__,_|___/
  //                     
  // bias read controller (BC)
  read_controller #(
      .WIDTH(`IPT_BIT),
      .DEPTH(`MAX_BIAS_DEPTH)
  ) inst_bias_rd_ctrl (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // WL 
      .i_req_len (bl_rc_req_len),
      .i_req     (bl_rc_req),
      .i_req_addr(bl_rc_req_addr),
      .o_req_dn  (brc_bl_req_dn),
      // DDR
      .o_re      (brc_bias_re),
      .o_raddr   (brc_bias_raddr),
      .i_rvld    (bias_brc_vld),
      .i_rdin    (bias_brc_dat),
      // opt
      .o_opt_vld (bias_rc_fifo_vld),
      .o_opt_dout(bias_rc_fifo_dat)
  );
  // fifo
  fifo #(
      .WIDTH(`IPT_BIT),
      .DEPTH(`MAX_BIAS_DEPTH)
  ) inst_bias_fifo (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // RC
      .o_ipt_rdy (),
      .i_ipt_vld (bias_rc_fifo_vld),
      .i_ipt_din (bias_rc_fifo_dat),
      // TL
      .i_opt_rdy (bl_fifo_rdy),
      .o_opt_vld (fifo_bl_vld),
      .o_opt_dout(fifo_bl_dat)
  );
  // bias loader (BL)
  loader #(
      .WIDTH    (`IPT_BIT),
      .IPT_DEPTH(`MAX_BIAS_DEPTH),
      .BUF_DEPTH(1)
  ) inst_bias_loader (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .i_clr       (),
      .i_st        (gc_bl_st),
      .o_dn        (bl_gc_dn),
      //
      .i_req_len   (gc_bl_req_len),
      .i_req_addr  (gc_bl_req_addr),
      .i_bank_depth(gc_bl_bank_depth),
      //
      .o_req_len   (bl_rc_req_len),
      .o_req       (bl_rc_req),
      .o_req_addr  (bl_rc_req_addr),
      .i_req_dn    (brc_bl_req_dn),
      //
      .o_ipt_rdy   (bl_fifo_rdy),
      .i_ipt_vld   (fifo_bl_vld),
      .i_ipt_din   (fifo_bl_dat),
      //
      .o_bank_idx  (bl_bb_bank_idx),
      .o_we        (bl_bb_we),
      .o_waddr     (bl_bb_waddr),
      .o_wdat      (bl_bb_wdat)
  );

  // bias buffer
  buffer #(
      .WIDTH     (`IPT_BIT),
      .BANK_DEPTH(1),
      .MEM_TYPE  (`LUT_TYPE),
      .BANK_NUM  (`MAX_GROUP_FILTER)
  ) inst_bias_buffer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_re      (br_bb_re),
      .i_raddr   (br_bb_raddr),
      .i_we      (bl_bb_we),
      .i_bank_idx(bl_bb_bank_idx),
      .i_waddr   (bl_bb_waddr),
      .i_wdat    (bl_bb_wdat),
      .i_opt_rdy ('b1),
      .o_opt_vld (bb_br_vld),
      .o_opt_dout(bb_br_dat)
  );
  // bias reader
  reader #(
      .WIDTH    (`IPT_BIT * `MAX_GROUP_FILTER),
      .BUF_DEPTH(`MAX_GROUP_FILTER)
  ) inst_bias_reader (
      .i_clk      (i_clk),
      .i_rstn     (i_rstn),
      .i_clr      (),
      // 
      .i_read_len (gc_br_read_len),
      .i_read_addr(gc_br_read_addr),
      .i_st       (gc_br_st),
      .o_dn       (br_gc_dn),
      ///
      .o_re       (br_bb_re),
      .o_raddr    (br_bb_raddr),
      //
      .o_ipt_rdy  (),
      .i_ipt_vld  (bb_br_vld),
      .i_ipt_din  (bb_br_dat),
      //
      .i_opt_rdy  ('b1),              // TODO
      .o_opt_vld  (br_psc_vld),
      .o_opt_dout (br_psc_dat)
  );
  //     __        __   _       _     _   
  //     \ \      / /__(_) __ _| |__ | |_ 
  //      \ \ /\ / / _ \ |/ _` | '_ \| __|
  //       \ V  V /  __/ | (_| | | | | |_ 
  //        \_/\_/ \___|_|\__, |_| |_|\__|
  //                      |___/           
  // weight read controller (WC)
  read_controller #(
      .WIDTH(`WGT_BIT),
      .DEPTH(`MAX_WGT_DEPTH)
  ) inst_wgt_rd_ctrl (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // WL 
      .i_req_len (wl_rc_req_len),
      .i_req     (wl_rc_req),
      .i_req_addr(wl_rc_req_addr),
      .o_req_dn  (wrc_wl_req_dn),
      // DDR
      .o_re      (wrc_wbuf_re),
      .o_raddr   (wrc_wbuf_raddr),
      .i_rvld    (wbuf_wrc_vld),
      .i_rdin    (wbuf_wrc_dat),
      // opt
      .o_opt_vld (wrc_fifo_vld),
      .o_opt_dout(wrc_fifo_dat)
  );
  // weight fifo (FIFO)
  fifo #(
      .WIDTH(`WGT_BIT),
      .DEPTH(`MAX_WGT_DEPTH)
  ) inst_wgt_fifo (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // RC
      .o_ipt_rdy (),
      .i_ipt_vld (wrc_fifo_vld),
      .i_ipt_din (wrc_fifo_dat),
      // TL
      .i_opt_rdy (wl_fifo_rdy),
      .o_opt_vld (fifo_wl_vld),
      .o_opt_dout(fifo_wl_dat)
  );

  // weight loader (WL)
  loader #(
      .WIDTH     (`WGT_BIT),
      .IPT_DEPTH (`MAX_WGT_DEPTH),
      .BUF_DEPTH (WGT_BANK_DEPTH),
      .BANK_NUM  (`MAX_GROUP_FILTER),
      .BANK_DEPTH(`MAX_CHANNEL * `CONV_3X3_AREA)
  ) inst_weight_loader (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .i_clr       (),
      .i_st        (gc_wl_st),
      .o_dn        (wl_gc_dn),
      //
      .i_req_len   (gc_wl_req_len),
      .i_req_addr  (gc_wl_req_addr),
      .i_bank_depth(gc_wl_bank_depth),
      //
      .o_req_len   (wl_rc_req_len),
      .o_req       (wl_rc_req),
      .o_req_addr  (wl_rc_req_addr),
      .i_req_dn    (wrc_wl_req_dn),
      //
      .o_ipt_rdy   (wl_fifo_rdy),
      .i_ipt_vld   (fifo_wl_vld),
      .i_ipt_din   (fifo_wl_dat),
      //
      .o_bank_idx  (wl_wb_bank_idx),
      .o_we        (wl_wb_we),
      .o_waddr     (wl_wb_waddr),
      .o_wdat      (wl_wb_wdat)
  );
  // weight buffer
  buffer #(
      .WIDTH     (`WGT_BIT),
      .BANK_DEPTH(WGT_BANK_DEPTH),
      .MEM_TYPE  (`BRAM_TYPE),
      .BANK_NUM  (`MAX_GROUP_FILTER)
  ) inst_weight_buffer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_re      (wr_wb_re),
      .i_raddr   (wr_wb_raddr),
      .i_we      (wl_wb_we),
      .i_bank_idx(wl_wb_bank_idx),
      .i_waddr   (wl_wb_waddr),
      .i_wdat    (wl_wb_wdat),
      .i_opt_rdy ('b1),
      .o_opt_vld (wb_wr_vld),
      .o_opt_dout(wb_wr_dat)
  );
  // weight reader
  reader #(
      .WIDTH    (`WGT_BIT * `MAX_GROUP_FILTER),
      .BUF_DEPTH(WGT_BANK_DEPTH)
  ) inst_wgt_reader (
      .i_clk      (i_clk),
      .i_rstn     (i_rstn),
      .i_clr      (),
      // 
      .i_read_len (gc_wr_read_len),
      .i_read_addr(gc_wr_read_addr),
      .i_st       (gc_wr_st),
      .o_dn       (wr_gc_dn),
      ///
      .o_re       (wr_wb_re),
      .o_raddr    (wr_wb_raddr),
      //
      .o_ipt_rdy  (),
      .i_ipt_vld  (wb_wr_vld),
      .i_ipt_din  (wb_wr_dat),
      //
      .i_opt_rdy  ('b1),              // TODO
      .o_opt_vld  (wr_lyr_vld),
      .o_opt_dout (wr_lyr_dat)
  );
  //      _____ _ _      
  //     |_   _(_) | ___ 
  //       | | | | |/ _ \
  //       | | | | |  __/
  //       |_| |_|_|\___|
  //        
  // image read controller (RC)
  read_controller #(
      .WIDTH(`IPT_BIT * `MAX_GROUP_CHANNEL),
      .DEPTH(`MAX_IPT_AREA)
  ) inst_img_rd_ctrl (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // TL
      .i_req_len (tl_trc_req_len),
      .i_req     (tl_trc_req),
      .i_req_addr(tl_trc_req_addr),
      .o_req_dn  (trc_tl_req_dn),
      // DDR
      .o_re      (trc_fbuf_re),
      .o_raddr   (trc_fbuf_raddr),
      .i_rvld    (fbuf_trc_vld),
      .i_rdin    (fbuf_trc_dat),
      // opt
      .o_opt_vld (trc_fifo_vld),
      .o_opt_dout(trc_fifo_dat)
  );

  // image fifo (FIFO)
  fifo #(
      .WIDTH(`IPT_BIT * `MAX_GROUP_CHANNEL),
      .DEPTH(`MAX_PAD_TILE_AREA)
  ) inst_img_fifo (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // RC
      .o_ipt_rdy (),
      .i_ipt_vld (trc_fifo_vld),
      .i_ipt_din (trc_fifo_dat),
      // TL
      .i_opt_rdy (tl_fifo_rdy),
      .o_opt_vld (fifo_tl_vld),
      .o_opt_dout(fifo_tl_dat)
  );

  // tile loader (TL)
  tile_loader #(
      .TILE_SIDE(`MAX_TILE_SIDE),
      .HALO     (1)
  ) inst_tile_loader (
      .i_clk           (i_clk),
      .i_rstn          (i_rstn),
      .i_st            (gc_tl_st),
      .o_dn            (tl_gc_dn),
      // GC
      .i_img_side      (gc_tl_img_side),
      .i_img_org_x     (gc_tl_img_org_x),
      .i_img_org_y     (gc_tl_img_org_y),
      .i_tile_base_addr(gc_tl_img_base_addr),
      // RC
      .o_req_len       (tl_trc_req_len),
      .o_req           (tl_trc_req),
      .o_req_addr      (tl_trc_req_addr),
      .i_req_dn        (trc_tl_req_dn),
      // FIFO
      .o_ipt_rdy       (tl_fifo_rdy),
      .i_ipt_vld       (fifo_tl_vld),
      .i_ipt_din       (fifo_tl_dat),
      // opt (layer)
      .o_we            (tl_tb_we),
      .o_waddr         (tl_tb_waddr),
      .o_wdat          (tl_tb_wdat)
  );
  // tile buffer
  buffer #(
      .WIDTH     (`IPT_BIT * `MAX_GROUP_CHANNEL),
      .BANK_DEPTH(`MAX_PAD_TILE_AREA),
      .MEM_TYPE  (`BRAM_TYPE),
      .BANK_NUM  (1)
  ) inst_tile_buffer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_re      (tr_tb_re),
      .i_raddr   (tr_tb_raddr),
      .i_we      (tl_tb_we),
      .i_bank_idx('d0),          // TODO
      .i_waddr   (tl_tb_waddr),
      .i_wdat    (tl_tb_wdat),
      .i_opt_rdy ('d1),          // TODO
      .o_opt_vld (tb_tr_vld),
      .o_opt_dout(tb_tr_dat)
  );
  // tile reader
  reader #(
      .WIDTH    (`IPT_BIT * `MAX_GROUP_CHANNEL),
      .BUF_DEPTH(`MAX_PAD_TILE_AREA)
  ) inst_tile_reader (
      .i_clk      (i_clk),
      .i_rstn     (i_rstn),
      .i_clr      (),
      // 
      .i_read_len (gc_tr_read_len),
      .i_read_addr(gc_tr_read_addr),
      .i_st       (gc_tr_st),
      .o_dn       (),
      ///
      .o_re       (tr_tb_re),
      .o_raddr    (tr_tb_raddr),
      //
      .o_ipt_rdy  (),
      .i_ipt_vld  (tb_tr_vld),
      .i_ipt_din  (tb_tr_dat),
      //
      .i_opt_rdy  ('b1),              // TODO
      .o_opt_vld  (tr_lyr_vld),
      .o_opt_dout (tr_lyr_dat)
  );


  //      _____     _____    ____                      _       _   _                    _                          
  //     |___ /_  _|___ /   / ___|___  _ ____   _____ | |_   _| |_(_) ___  _ __   | |    __ _ _   _  ___ _ __ 
  //       |_ \ \/ / |_ \  | |   / _ \| '_ \ \ / / _ \| | | | | __| |/ _ \| '_ \  | |   / _` | | | |/ _ \ '__|
  //      ___) >  < ___) | | |__| (_) | | | \ V / (_) | | |_| | |_| | (_) | | | | | |__| (_| | |_| |  __/ |   
  //     |____/_/\_\____/   \____\___/|_| |_|\_/ \___/|_|\__,_|\__|_|\___/|_| |_| |_____\__,_|\__, |\___|_|   
  //                                                                                          |___/           
  conv_layer inst_conv_layer (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .i_clr       (gc_lyr_clr),
      .o_dn        (clyr_gc_dn),
      // wgt 
      .i_wgt_vld   (wr_lyr_vld),
      .i_wgt_din   (wr_lyr_dat),
      // ipt 
      .o_ipt_rdy   (w_conv_lyr_rdy),
      .i_ipt_vld   (tr_lyr_vld),
      .i_ipt_din   (tr_lyr_dat),
      // opt  
      .i_opt_rdy   (gc_lyr_rdy),
      .o_opt_vld   (clyr_psc_vld),
      .o_opt_dout  (clyr_psc_dat),
      // temp
      .i_opt_area  (gc_lyr_opt_area),
      .i_line_width(gc_lyr_line_width),
      .i_relu_en   (gc_lyr_relu),
      .i_ch_num    (gc_lyr_ch),
      .i_pu_num    (gc_lyr_pu),
      .i_ch_mask   (gc_lyr_ch_mask),
      .i_pu_mask   (gc_lyr_pu_mask)
  );
  //      __  __              ____             _   _                          
  //     |  \/  | __ ___  __ |  _ \ ___   ___ | | | |    __ _ _   _  ___ _ __ 
  //     | |\/| |/ _` \ \/ / | |_) / _ \ / _ \| | | |   / _` | | | |/ _ \ '__|
  //     | |  | | (_| |>  <  |  __/ (_) | (_) | | | |__| (_| | |_| |  __/ |   
  //     |_|  |_|\__,_/_/\_\ |_|   \___/ \___/|_| |_____\__,_|\__, |\___|_|   
  //                                                          |___/           
  pool_layer inst_pool_layer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // ipt
      .o_ipt_rdy (w_pool_lyr_rdy),
      .i_ipt_vld (w_skid_vld),
      .i_ipt_din (w_skid_dat),
      // opt
      .i_opt_rdy (gc_lyr_rdy),
      .o_opt_vld (w_pool_lyr_vld),
      .o_opt_dout(w_pool_lyr_dat),
      //    
      .i_img_side(gc_lyr_line_width),
      .i_lbuf_st ((gc_lyr_clr & {`MAX_GROUP_FILTER{w_lyr_type == `LAYER_TYPE_MAXPOOL}}))
  );
  //      ____            _   _       _   ____                  
  //     |  _ \ __ _ _ __| |_(_) __ _| | / ___| _   _ _ __ ___  
  //     | |_) / _` | '__| __| |/ _` | | \___ \| | | | '_ ` _ \ 
  //     |  __/ (_| | |  | |_| | (_| | |  ___) | |_| | | | | | |
  //     |_|   \__,_|_|   \__|_|\__,_|_| |____/ \__,_|_| |_| |_|
  //                                                            
  partialsum_controller inst_partialsum_controller (
      .i_clk      (i_clk),
      .i_rstn     (i_rstn),
      .i_st       (gc_psc_st),
      .o_dn       (psc_gc_dn),
      .i_sum_cnt  (gc_psc_sum_cnt),
      //
      .i_bias_vld (br_psc_vld),
      .i_bias_din (br_psc_dat),
      //
      .i_psb_rdy  (psb_psc_rdy),
      .o_psb_re   (psc_psb_re),
      .o_psb_raddr(psc_psb_raddr),
      .i_psb_rvld (psb_psc_rvld),
      .i_psb_rdin (psb_psc_rdat),
      .o_psb_we   (psc_psb_we),
      .o_psb_waddr(psc_psb_waddr),
      .o_psb_wdout(psc_psb_wdat),
      .o_psc_rdy  (psc_psb_rdy),
      //
      .i_ipt_din  (clyr_psc_dat),
      .i_ipt_vld  (clyr_psc_vld),
      .o_ipt_rdy  (),
      //
      .i_opt_rdy  ('b1),
      .o_opt_vld  (psc_gc_vld),
      .o_opt_dout (psc_gc_dat)


  );
endmodule


`include "defines.vh"
`include "network_config.vh"
module my_top #(
    parameter IMG_INIT_FILE     = "",
    parameter L0_WGT_INIT_FILE  = "",
    parameter L0_BIAS_INIT_FILE = "",
    parameter L1_WGT_INIT_FILE  = "",
    parameter L1_BIAS_INIT_FILE = "",
    parameter L2_WGT_INIT_FILE  = "",
    parameter L2_BIAS_INIT_FILE = ""
) (
`ifdef DEBUG
    input                                     i_rdy_test,
    output        [`CLOG2_SAFE(`LAYER_NUM):0] o_lyr_num,
    output                                    o_lyr_vld,
    output signed [             `IPT_BIT-1:0] o_lyr_dat,
`endif
    input                                     i_clk,
    input                                     i_rstn,
    input                                     i_start,
    output                                    o_dn
);
  // ====================== parmeter =======================  
  genvar g, f;
  integer i;

  localparam MAX_WGT_BANK_DEPTH = `MAX_CHANNEL * `CONV_3X3_AREA;
  localparam FBUF_DEPTH = `MAX_FILTER_GROUP_NUM * `MAX_IPT_AREA;

  wire [                                   `LAYER_NUM-1:0] w_wbuf_vld;
  wire [                                     `WGT_BIT-1:0] w_wbuf_dat          [0:`LAYER_NUM-1];
  // bias buffer 
  wire [                                   `LAYER_NUM-1:0] w_bias_vld;
  wire [                                     `IPT_BIT-1:0] w_bias_dat          [0:`LAYER_NUM-1];
  // fmap buffer 
  wire                                                     fbuf_trc_vld;
  wire [                `OPT_BIT * `MAX_GROUP_FILTER -1:0] fbuf_trc_dat;
  // global controller (GC) 
  wire [                   `CLOG2_SAFE(`MAX_LAYER_TYPE):0] w_lyr_type;
  wire                                                     gc_dn;
  wire                                                     gc_lyr_rdy;
  wire [                      `CLOG2_SAFE(`LAYER_NUM)-1:0] gc_lyr_idx;
  wire                                                     gc_fbuf_switch;
  wire                                                     gc_bl_st;
  wire                                                     gc_bl_bank_depth;
  wire [                 `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] gc_bl_req_len;
  wire [                 `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] gc_bl_req_addr;
  wire [               `CLOG2_SAFE(`MAX_GROUP_FILTER) : 0] gc_br_read_len;
  wire [               `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] gc_br_read_addr;
  wire                                                     gc_br_st;
  wire                                                     gc_wl_st;
  wire [     `CLOG2_SAFE(`MAX_CHANNEL*`CONV_3X3_AREA) : 0] gc_wl_bank_depth;
  wire [                  `CLOG2_SAFE(`MAX_WGT_DEPTH) : 0] gc_wl_req_len;
  wire [                  `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] gc_wl_req_addr;
  wire                                                     gc_wr_st;
  wire [              `CLOG2_SAFE(MAX_WGT_BANK_DEPTH) : 0] gc_wr_read_len;
  wire [              `CLOG2_SAFE(MAX_WGT_BANK_DEPTH)-1:0] gc_wr_read_addr;
  wire                                                     gc_tl_st;
  wire [                   `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] gc_tl_img_side;
  wire [                   `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] gc_tl_img_org_x;
  wire [                   `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] gc_tl_img_org_y;
  wire [                      `CLOG2_SAFE(FBUF_DEPTH)-1:0] gc_tl_img_base_addr;
  wire                                                     gc_tr_st;
  wire [              `CLOG2_SAFE(`MAX_PAD_TILE_AREA) : 0] gc_tr_read_len;
  wire [              `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] gc_tr_read_addr;
  wire [                  `CLOG2_SAFE(`MAX_TILE_AREA) : 0] gc_lyr_opt_num;
  wire [              `CLOG2_SAFE(`MAX_PAD_TILE_SIDE) : 0] gc_lyr_line_width;
  wire [              `CLOG2_SAFE(`MAX_GROUP_CHANNEL) : 0] gc_lyr_in_ch;
  wire [                           `MAX_GROUP_CHANNEL-1:0] gc_lyr_ch_mask;
  wire [                     `CLOG2_SAFE(`MAX_FILTER) : 0] gc_lyr_out_ch;
  wire [                            `MAX_GROUP_FILTER-1:0] gc_lyr_pu_mask;
  wire                                                     gc_lyr_clr;
  wire                                                     gc_lyr_pad_en;
  wire                                                     gc_psc_st;
  wire                                                     gc_psc_relu;
  wire [`CLOG2_SAFE( `MAX_CHANNEL / `MAX_GROUP_CHANNEL):0] gc_psc_sum_cnt;
  wire                                                     gc_fbuf_we;
  wire [                  `OPT_BIT* `MAX_GROUP_FILTER-1:0] gc_fbuf_wdat;
  wire [                      `CLOG2_SAFE(FBUF_DEPTH)-1:0] gc_fbuf_waddr;
  // bias mem (DDR)
  wire                                                     storage_brc_vld;
  wire [                                     `IPT_BIT-1:0] storage_brc_dat;
  wire                                                     brc_fifo_vld;
  wire [                                     `IPT_BIT-1:0] brc_fifo_dat;
  // bias read controller (BRC)
  wire                                                     brc_storage_re;
  wire [                 `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] brc_storage_raddr;
  wire                                                     brc_bl_req_dn;
  // FIFO 
  wire                                                     fifo_bl_vld;
  wire [                                     `IPT_BIT-1:0] fifo_bl_dat;
  // bias loader (BL) 
  wire                                                     bl_gc_dn;
  wire [                 `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] bl_rc_req_len;
  wire                                                     bl_rc_req;
  wire [                 `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] bl_rc_req_addr;
  wire                                                     bl_lyr_vld;
  wire [                                    `IPT_BIT -1:0] bl_lyr_dat;
  wire                                                     bl_fifo_rdy;
  wire [               `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] bl_bb_bank_idx;
  wire                                                     bl_bb_we;
  wire [               `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] bl_bb_waddr;
  wire [                                     `IPT_BIT-1:0] bl_bb_wdat;
  // bias buffer (BB) 
  wire                                                     bb_br_vld;
  wire [                   `IPT_BIT*`MAX_GROUP_FILTER-1:0] bb_br_dat;
  // bias reader (BR) 
  wire                                                     br_gc_dn;
  wire                                                     br_bb_re;
  wire [               `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] br_bb_raddr;
  wire                                                     br_psc_vld;
  wire [                   `IPT_BIT*`MAX_GROUP_FILTER-1:0] br_psc_dat;
  // weight (DDR)
  wire                                                     storage_wrc_vld;
  wire [                                     `WGT_BIT-1:0] storage_wrc_dat;
  // weight read controller (WRC)
  wire                                                     wrc_storage_re;
  wire [                  `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] wrc_storage_raddr;
  wire                                                     wrc_wl_req_dn;
  wire                                                     wrc_fifo_vld;
  wire [                                     `WGT_BIT-1:0] wrc_fifo_dat;
  // weight   (FIFO)
  wire                                                     fifo_wl_vld;
  wire [                                     `WGT_BIT-1:0] fifo_wl_dat;
  // weight loader (WL) 
  wire                                                     wl_gc_dn;
  wire [                  `CLOG2_SAFE(`MAX_WGT_DEPTH) : 0] wl_rc_req_len;
  wire                                                     wl_rc_req;
  wire [                  `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] wl_rc_req_addr;
  wire                                                     wl_fifo_rdy;
  wire [               `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] wl_wb_bank_idx;
  wire                                                     wl_wb_we;
  wire [              `CLOG2_SAFE(MAX_WGT_BANK_DEPTH)-1:0] wl_wb_waddr;
  wire [                                     `WGT_BIT-1:0] wl_wb_wdat;
  // weight buffer (WB) 
  wire                                                     wb_wr_vld;
  wire [                 `WGT_BIT * `MAX_GROUP_FILTER-1:0] wb_wr_dat;
  // weight reader (WR) 
  wire                                                     wr_gc_dn;
  wire                                                     wr_wb_re;
  wire [              `CLOG2_SAFE(MAX_WGT_BANK_DEPTH)-1:0] wr_wb_raddr;
  wire                                                     wr_lyr_vld;
  wire [                 `WGT_BIT * `MAX_GROUP_FILTER-1:0] wr_lyr_dat;
  // input mem (DDR)
  wire                                                     img_irc_vld;
  wire [                                     `IPT_BIT-1:0] img_irc_dat;
  // tile read controller (TRC) 
  wire                                                     trc_fbuf_re;
  wire [                      `CLOG2_SAFE(FBUF_DEPTH)-1:0] trc_fbuf_raddr;
  wire                                                     trc_fifo_vld;
  wire [                  `IPT_BIT*`MAX_GROUP_CHANNEL-1:0] trc_fifo_dat;
  // FIFO  
  wire                                                     fifo_tl_vld;
  wire [                `IPT_BIT* `MAX_GROUP_CHANNEL -1:0] fifo_tl_dat;
  // tile loader (TL) 
  wire                                                     trc_tl_req_dn;
  wire                                                     tl_gc_dn;
  wire [                      `CLOG2_SAFE(FBUF_DEPTH) : 0] tl_trc_req_len;
  wire                                                     tl_trc_req;
  wire [                      `CLOG2_SAFE(FBUF_DEPTH)-1:0] tl_trc_req_addr;
  wire                                                     tl_fifo_rdy;
  wire                                                     tl_tb_we;
  wire [              `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] tl_tb_waddr;
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
  // layer   
  wire                                                     clyr_gc_dn;
  wire                                                     clyr_psc_vld;
  wire [                  `PSUM_BIT*`MAX_GROUP_FILTER-1:0] clyr_psc_dat;
  wire                                                     plyr_rdy;
  wire                                                     plyr_vld;
  wire [                   `IPT_BIT*`MAX_GROUP_FILTER-1:0] plyr_dat;
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
  //
  wire                                                     fifo_psb_rdy;
  wire                                                     psb_psc_vld;
  wire [                  `PSUM_BIT*`MAX_GROUP_FILTER-1:0] psb_psc_dat;
  //
  wire                                                     psb_psc_rdy;
  wire                                                     psb_fifo_rvld;
  wire [                  `PSUM_BIT*`MAX_GROUP_FILTER-1:0] psb_fifo_rdat;
  wire                                                     psb_fifo_rdy;
  // ====================== reg ============================   
  // bias storage
  storage #(
      .WIDTH     (`IPT_BIT),
      .DEPTH     (`MAX_BIAS_DEPTH),
      .INIT_FILE0(L0_BIAS_INIT_FILE),
      .INIT_FILE1(L1_BIAS_INIT_FILE),
      .INIT_FILE2(L2_BIAS_INIT_FILE)
  ) isnt_bias_storage (
      .i_clk    (i_clk),
      .i_rstn   (i_rstn),
      //
      .i_re     (brc_storage_re),
      .i_raddr  (brc_storage_raddr),
      .o_rvld   (storage_brc_vld),
      .o_rdout  (storage_brc_dat),
      //
      .i_we     (),
      .i_waddr  (),
      .i_wdin   (),
      //
      .i_lyr_idx(gc_lyr_idx)
  );

  // weight storage
  storage #(
      .WIDTH     (`WGT_BIT),
      .DEPTH     (`MAX_WGT_DEPTH),
      .INIT_FILE0(L0_WGT_INIT_FILE),
      .INIT_FILE1(L1_WGT_INIT_FILE),
      .INIT_FILE2(L2_WGT_INIT_FILE)
  ) isnt_weight_storage (
      .i_clk    (i_clk),
      .i_rstn   (i_rstn),
      //
      .i_re     (wrc_storage_re),
      .i_raddr  (wrc_storage_raddr),
      .o_rvld   (storage_wrc_vld),
      .o_rdout  (storage_wrc_dat),
      //
      .i_we     (),
      .i_waddr  (),
      .i_wdin   (),
      //
      .i_lyr_idx(gc_lyr_idx)
  );

  featuremap_buffer #(
      .WIDTH        (`OPT_BIT * `MAX_GROUP_FILTER),
      .DEPTH        (FBUF_DEPTH),
      .MEM_TYPE     (`BRAM_TYPE),
      .IMG_INIT_FILE(IMG_INIT_FILE)
  ) inst_fbuf (
      .i_clk    (i_clk),
      .i_rstn   (i_rstn),
      //
      .i_re     (trc_fbuf_re),
      .i_raddr  (trc_fbuf_raddr),
      .o_rvld   (fbuf_trc_vld),
      .o_rdout  (fbuf_trc_dat),
      //        
      .i_we     (gc_fbuf_we),
      .i_waddr  (gc_fbuf_waddr),
      .i_wdin   (gc_fbuf_wdat),
      //
      .i_lyr_idx(gc_lyr_idx),
      .i_switch (gc_fbuf_switch)
  );
  partialsum_buffer #(
      .WIDTH   (`PSUM_BIT * `MAX_GROUP_FILTER),
      .DEPTH   (`MAX_TILE_AREA),
      .MEM_TYPE(`BRAM_TYPE)
  ) inst_partialsum_buffer (
      .i_clk    (i_clk),
      .i_rstn   (i_rstn),
      //
      .i_re     (psc_psb_re),
      .i_raddr  (psc_psb_raddr),
      .o_rvld   (psb_psc_vld),
      .o_rdout  (psb_psc_dat),
      //
      .i_we     (psc_psb_we),
      .i_waddr  (psc_psb_waddr),
      .i_wdin   (psc_psb_wdat),
      //
      .o_ipt_rdy(psb_psc_rdy),
      .i_opt_rdy(psc_psb_rdy)
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
      .o_dn           (gc_dn),
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
      // lyr  
      .i_lyr_dn       (clyr_gc_dn),
      .i_conv_lyr_vld (),
      .i_conv_lyr_din (),
      .i_pool_lyr_vld (plyr_vld),
      .i_pool_lyr_din (plyr_dat),
      .o_lyr_clr      (gc_lyr_clr),
      .o_lyr_relu_en  (gc_psc_relu),
      .o_lyr_pad_en   (gc_lyr_pad_en),
      .o_lyr_idx      (gc_lyr_idx),
      .o_lyr_opt_num  (gc_lyr_opt_num),
      // PSC
      .o_psc_st       (gc_psc_st),
      .o_psc_sum_cnt  (gc_psc_sum_cnt),
      .i_psc_dn       (psc_gc_dn),
      .i_psc_vld      (psc_gc_vld),
      .i_psc_din      (psc_gc_dat),
      //  
      .o_ddr_we       (gc_fbuf_we),
      .o_ddr_wdout    (gc_fbuf_wdat),
      .o_ddr_waddr    (gc_fbuf_waddr),
      // temp 
      .o_img_side     (gc_tl_img_side),
      .o_pad_tile_side(gc_lyr_line_width),
      .o_in_ch        (gc_lyr_in_ch),
      .o_out_ch       (gc_lyr_out_ch),
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
      .o_re      (brc_storage_re),
      .o_raddr   (brc_storage_raddr),
      .i_rvld    (storage_brc_vld),
      .i_rdin    (storage_brc_dat),
      // opt
      .o_opt_vld (brc_fifo_vld),
      .o_opt_dout(brc_fifo_dat)
  );
  //  bias
  fifo_buffer #(
      .WIDTH   (`IPT_BIT),
      .DEPTH   (`MAX_BIAS_DEPTH),
      .MEM_TYPE(`BRAM_TYPE)
  ) inst_bias_fifo (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // RC
      .o_ipt_rdy (),
      .i_ipt_vld (brc_fifo_vld),
      .i_ipt_din (brc_fifo_dat),
      // TL
      .i_opt_rdy (bl_fifo_rdy),
      .o_opt_vld (fifo_bl_vld),
      .o_opt_dout(fifo_bl_dat)
  );
  // bias loader (BL)
  loader #(
      .WIDTH     (`IPT_BIT),
      .IPT_DEPTH (`MAX_BIAS_DEPTH),
      .BUF_DEPTH (1),
      .BANK_NUM  (`MAX_GROUP_FILTER),
      .BANK_DEPTH(1)
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
  bank_buffer #(
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
      .i_wdin    (bl_bb_wdat),
      .i_opt_rdy ('b1),
      .o_rvld    (bb_br_vld),
      .o_rdout   (bb_br_dat)
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
      .o_re      (wrc_storage_re),
      .o_raddr   (wrc_storage_raddr),
      .i_rvld    (storage_wrc_vld),
      .i_rdin    (storage_wrc_dat),
      // opt
      .o_opt_vld (wrc_fifo_vld),
      .o_opt_dout(wrc_fifo_dat)
  );
  // weight fifo (FIFO)
  fifo_buffer #(
      .WIDTH   (`WGT_BIT),
      .DEPTH   (`MAX_WGT_DEPTH),
      .MEM_TYPE(`BRAM_TYPE)
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
      .BUF_DEPTH (MAX_WGT_BANK_DEPTH),
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
  bank_buffer #(
      .WIDTH     (`WGT_BIT),
      .BANK_DEPTH(MAX_WGT_BANK_DEPTH),
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
      .i_wdin    (wl_wb_wdat),
      .i_opt_rdy ('b1),
      .o_rvld    (wb_wr_vld),
      .o_rdout   (wb_wr_dat)
  );
  // weight reader
  reader #(
      .WIDTH    (`WGT_BIT * `MAX_GROUP_FILTER),
      .BUF_DEPTH(MAX_WGT_BANK_DEPTH)
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
      .DEPTH(FBUF_DEPTH)
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

  // image   (FIFO)
  fifo_buffer #(
      .WIDTH   (`IPT_BIT * `MAX_GROUP_CHANNEL),
      .DEPTH   (`MAX_PAD_TILE_AREA),
      .MEM_TYPE(`BRAM_TYPE)
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
      .TILE_SIDE (`MAX_TILE_SIDE),
      .FBUF_DEPTH(FBUF_DEPTH),
      .HALO      (1)
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
  bank_buffer #(
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
      .i_wdin    (tl_tb_wdat),
      .i_opt_rdy ('d1),          // TODO
      .o_rvld    (tb_tr_vld),
      .o_rdout   (tb_tr_dat)
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
      .o_ipt_rdy   (),
      .i_ipt_vld   (tr_lyr_vld),
      .i_ipt_din   (tr_lyr_dat),
      // opt  
      .i_opt_rdy   (gc_lyr_rdy),
      .o_opt_vld   (clyr_psc_vld),
      .o_opt_dout  (clyr_psc_dat),
      // temp
      .i_opt_num   (gc_lyr_opt_num),
      .i_line_width(gc_lyr_line_width),
      .i_relu_en   (),
      .i_in_ch     (gc_lyr_in_ch),
      .i_out_ch    (gc_lyr_out_ch),
      .i_ch_mask   (gc_lyr_ch_mask),
      .i_filt_mask (gc_lyr_pu_mask)
  );
  //      __  __              ____             _   _                          
  //     |  \/  | __ ___  __ |  _ \ ___   ___ | | | |    __ _ _   _  ___ _ __ 
  //     | |\/| |/ _` \ \/ / | |_) / _ \ / _ \| | | |   / _` | | | |/ _ \ '__|
  //     | |  | | (_| |>  <  |  __/ (_) | (_) | | | |__| (_| | |_| |  __/ |   
  //     |_|  |_|\__,_/_/\_\ |_|   \___/ \___/|_| |_____\__,_|\__, |\___|_|   
  //                                                          |___/           
  //   pool_layer inst_pool_layer (
  //       .i_clk     (i_clk),
  //       .i_rstn    (i_rstn),
  //       // ipt
  //       .o_ipt_rdy (plyr_rdy),
  //       .i_ipt_vld (),
  //       .i_ipt_din (),
  //       // opt
  //       .i_opt_rdy (gc_lyr_rdy),
  //       .o_opt_vld (plyr_vld),
  //       .o_opt_dout(plyr_dat),
  //       //    
  //       .i_img_side(gc_lyr_line_width),
  //       .i_lbuf_st ((gc_lyr_clr & {`MAX_GROUP_FILTER{w_lyr_type == `LAYER_TYPE_MAXPOOL}}))
  //   );
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
      .i_relu     (gc_psc_relu),
      //
      .i_bias_vld (br_psc_vld),
      .i_bias_din (br_psc_dat),
      //
      .i_psb_rdy  (psb_psc_rdy),
      .o_psb_re   (psc_psb_re),
      .o_psb_raddr(psc_psb_raddr),
      .i_psb_rvld (psb_psc_vld),
      .i_psb_rdin (psb_psc_dat),
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

  assign o_dn = gc_dn;
endmodule

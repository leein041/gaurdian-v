
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

  localparam WGT_BANK_DEPTH = `MAX_CHANNEL * `CONV_3X3_AREA;
  localparam FBUF_DEPTH = `MAX_FILTER_GROUP_NUM * `MAX_IPT_AREA;

  wire [                               `LAYER_NUM-1:0] w_wbuf_vld;
  wire [                                 `WGT_BIT-1:0] w_wbuf_dat             [0:`LAYER_NUM-1];
  // bias buffer 
  wire [                               `LAYER_NUM-1:0] w_bias_vld;
  wire [                                 `IPT_BIT-1:0] w_bias_dat             [0:`LAYER_NUM-1];
  // fmap buffer 
  wire                                                 fbuf_trc_vld;
  wire [            `OPT_BIT * `MAX_GROUP_FILTER -1:0] fbuf_trc_dat;
  // global controller 
  wire                                                 gc_sched_st;
  //
  wire [             `CLOG2_SAFE(`MAX_LAYER_TYPE)-1:0] cfg_lyr_type;
  wire                                                 cfg_pad;
  wire                                                 cfg_relu;
  wire [                   `CLOG2_SAFE(`MAX_FILTER):0] cfg_filt;
  wire [ `CLOG2_SAFE(`MAX_FILTER/`MAX_GROUP_FILTER):0] cfg_filt_grp_num;
  wire [                 `CLOG2_SAFE(`MAX_TILE_NUM):0] cfg_tile_num;
  wire [`CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] cfg_tile_num_x;
  wire [`CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] cfg_tile_num_y;
  wire [                  `CLOG2_SAFE(`MAX_CHANNEL):0] cfg_ch;
  wire [        `CLOG2_SAFE(`MAX_CHANNEL_GROUP_NUM):0] cfg_ch_grp_num;
  wire [                 `CLOG2_SAFE(`MAX_IPT_SIDE):0] cfg_img_side;
  wire [                 `CLOG2_SAFE(`MAX_IPT_AREA):0] cfg_img_area;
  wire [                 `CLOG2_SAFE(`MAX_OPT_SIDE):0] cfg_opt_side;
  wire [                 `CLOG2_SAFE(`MAX_OPT_AREA):0] cfg_opt_area;
  wire [                `CLOG2_SAFE(`MAX_TILE_SIDE):0] cfg_tile_side;
  wire [                `CLOG2_SAFE(`MAX_TILE_AREA):0] cfg_lyr_opt_area;

  wire [             `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] cfg_bl_filt_grp_stride;
  wire [             `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] cfg_br_filt_grp_stride;
  wire [ `CLOG2_SAFE(`MAX_CHANNEL*`CONV_3X3_AREA) : 0] cfg_wl_filt_grp_stride;
  wire [              `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] cfg_wr_ch_grp_stride;
  wire [               `CLOG2_SAFE(`MAX_IPT_AREA) : 0] cfg_tl_row_stride;
  wire [               `CLOG2_SAFE(`MAX_IPT_AREA) : 0] cfg_tl_col_stride;
  wire [               `CLOG2_SAFE(`MAX_IPT_AREA) : 0] cfg_tl_ch_grp_stride;
  wire [               `CLOG2_SAFE(`MAX_IPT_AREA) : 0] cfg_ts_row_stride;
  wire [               `CLOG2_SAFE(`MAX_IPT_AREA) : 0] cfg_ts_col_stride;
  wire [               `CLOG2_SAFE(`MAX_IPT_AREA) : 0] cfg_ts_ch_grp_stride;
  wire [               `CLOG2_SAFE(`MAX_BIAS_DEPTH):0] cfg_bl_req_len;
  wire [           `CLOG2_SAFE(`MAX_GROUP_FILTER) : 0] cfg_br_read_len;
  wire [                `CLOG2_SAFE(`MAX_WGT_DEPTH):0] cfg_wl_req_len;
  wire [              `CLOG2_SAFE(WGT_BANK_DEPTH) : 0] cfg_wr_read_len;
  wire [          `CLOG2_SAFE(`MAX_PAD_TILE_AREA) : 0] cfg_tr_read_len;
  wire                                                 cfg_bl_bank_depth;
  wire [              `CLOG2_SAFE(WGT_BANK_DEPTH) : 0] cfg_wl_bank_depth;
  // scheduler (sched)  
  wire                                                 sched_gc_dn;
  wire                                                 sched_lyr_rdy;
  wire [                  `CLOG2_SAFE(`LAYER_NUM)-1:0] sched_lyr_idx;
  wire                                                 sched_nxt_lyr;
  wire                                                 sched_nxt_filt_grp;
  wire                                                 sched_nxt_tile_col;
  wire                                                 sched_nxt_tile_row;
  wire                                                 sched_nxt_ch_grp;
  wire                                                 sched_fbuf_switch;
  wire                                                 sched_bl_st;
  wire                                                 sched_bl_bank_depth;
  wire [             `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] sched_bl_req_len;
  wire [             `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] sched_bl_req_addr;
  wire [           `CLOG2_SAFE(`MAX_GROUP_FILTER) : 0] sched_br_read_len;
  wire [           `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] sched_br_read_addr;
  wire                                                 sched_br_st;
  wire                                                 sched_wl_st;
  wire [ `CLOG2_SAFE(`MAX_CHANNEL*`CONV_3X3_AREA) : 0] sched_wl_bank_depth;
  wire [              `CLOG2_SAFE(`MAX_WGT_DEPTH) : 0] sched_wl_req_len;
  wire [              `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] sched_wl_req_addr;
  wire                                                 sched_wr_st;
  wire [              `CLOG2_SAFE(WGT_BANK_DEPTH) : 0] sched_wr_read_len;
  wire [              `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] sched_wr_read_addr;
  wire                                                 sched_tl_st;
  wire [               `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] sched_tl_img_org_x;
  wire [               `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] sched_tl_img_org_y;
  wire [                  `CLOG2_SAFE(FBUF_DEPTH)-1:0] sched_tl_img_base_addr;
  wire                                                 sched_tr_st;
  wire [          `CLOG2_SAFE(`MAX_PAD_TILE_AREA) : 0] sched_tr_read_len;
  wire [          `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] sched_tr_read_addr;
  wire [              `CLOG2_SAFE(`MAX_TILE_AREA) : 0] sched_lyr_opt_num;
  wire [          `CLOG2_SAFE(`MAX_GROUP_CHANNEL) : 0] sched_lyr_in_ch;
  wire [                       `MAX_GROUP_CHANNEL-1:0] sched_lyr_ch_mask;
  wire [                        `MAX_GROUP_FILTER-1:0] sched_lyr_filt_mask;
  wire                                                 sched_lyr_clr;
  wire                                                 sched_psc_st;
  wire                                                 sched_ts_st;
  wire                                                 ts_fbuf_we;
  wire [              `OPT_BIT* `MAX_GROUP_FILTER-1:0] ts_fbuf_wdat;
  wire [                  `CLOG2_SAFE(FBUF_DEPTH)-1:0] ts_fbuf_waddr;
  // 
  wire [             `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] ag_bl_addr;
  wire [           `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] ag_br_addr;
  wire [              `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] ag_wl_addr;
  wire [              `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] ag_wr_addr;
  wire [                  `CLOG2_SAFE(FBUF_DEPTH)-1:0] ag_tl_addr;
  wire [          `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] ag_tr_addr;
  wire [                  `CLOG2_SAFE(FBUF_DEPTH)-1:0] ag_ts_addr;
  // bias mem (DDR)
  wire                                                 storage_brc_vld;
  wire [                                 `IPT_BIT-1:0] storage_brc_dat;
  wire                                                 brc_fifo_vld;
  wire [                                 `IPT_BIT-1:0] brc_fifo_dat;
  // bias read controller (BRC)
  wire                                                 brc_storage_re;
  wire [             `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] brc_storage_raddr;
  wire                                                 brc_bl_req_dn;
  // FIFO 
  wire                                                 fifo_bl_vld;
  wire [                                 `IPT_BIT-1:0] fifo_bl_dat;
  // bias loader (BL) 
  wire                                                 bl_sched_dn;
  wire [             `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] bl_rc_req_len;
  wire                                                 bl_rc_req;
  wire [             `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] bl_rc_req_addr;
  wire                                                 bl_lyr_vld;
  wire [                                `IPT_BIT -1:0] bl_lyr_dat;
  wire                                                 bl_fifo_rdy;
  wire [           `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] bl_bb_bank_idx;
  wire                                                 bl_bb_we;
  wire [           `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] bl_bb_waddr;
  wire [                                 `IPT_BIT-1:0] bl_bb_wdat;
  // bias buffer (BB) 
  wire                                                 bb_br_vld;
  wire [               `IPT_BIT*`MAX_GROUP_FILTER-1:0] bb_br_dat;
  // bias reader (BR) 
  wire                                                 br_sched_dn;
  wire                                                 br_bb_re;
  wire [           `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] br_bb_raddr;
  wire                                                 br_pp_vld;
  wire [               `IPT_BIT*`MAX_GROUP_FILTER-1:0] br_pp_dat;
  // weight (DDR)
  wire                                                 storage_wrc_vld;
  wire [                                 `WGT_BIT-1:0] storage_wrc_dat;
  // weight read controller (WRC)
  wire                                                 wrc_storage_re;
  wire [              `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] wrc_storage_raddr;
  wire                                                 wrc_wl_req_dn;
  wire                                                 wrc_fifo_vld;
  wire [                                 `WGT_BIT-1:0] wrc_fifo_dat;
  // weight   (FIFO)
  wire                                                 fifo_wl_vld;
  wire [                                 `WGT_BIT-1:0] fifo_wl_dat;
  // weight loader (WL) 
  wire                                                 wl_sched_dn;
  wire [              `CLOG2_SAFE(`MAX_WGT_DEPTH) : 0] wl_rc_req_len;
  wire                                                 wl_rc_req;
  wire [              `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] wl_rc_req_addr;
  wire                                                 wl_fifo_rdy;
  wire [           `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] wl_wb_bank_idx;
  wire                                                 wl_wb_we;
  wire [              `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] wl_wb_waddr;
  wire [                                 `WGT_BIT-1:0] wl_wb_wdat;
  // weight buffer (WB) 
  wire                                                 wb_wr_vld;
  wire [             `WGT_BIT * `MAX_GROUP_FILTER-1:0] wb_wr_dat;
  // weight reader (WR) 
  wire                                                 wr_sched_dn;
  wire                                                 wr_wb_re;
  wire [              `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] wr_wb_raddr;
  wire                                                 wr_lyr_vld;
  wire [             `WGT_BIT * `MAX_GROUP_FILTER-1:0] wr_lyr_dat;
  // input mem (DDR)
  wire                                                 img_irc_vld;
  wire [                                 `IPT_BIT-1:0] img_irc_dat;
  // tile read controller (TRC) 
  wire                                                 trc_fbuf_re;
  wire [                  `CLOG2_SAFE(FBUF_DEPTH)-1:0] trc_fbuf_raddr;
  wire                                                 trc_fifo_vld;
  wire [              `IPT_BIT*`MAX_GROUP_CHANNEL-1:0] trc_fifo_dat;
  // FIFO  
  wire                                                 fifo_tl_vld;
  wire [            `IPT_BIT* `MAX_GROUP_CHANNEL -1:0] fifo_tl_dat;
  // tile loader (TL) 
  wire                                                 trc_tl_req_dn;
  wire                                                 tl_sched_dn;
  wire [                  `CLOG2_SAFE(FBUF_DEPTH) : 0] tl_trc_req_len;
  wire                                                 tl_trc_req;
  wire [                  `CLOG2_SAFE(FBUF_DEPTH)-1:0] tl_trc_req_addr;
  wire                                                 tl_fifo_rdy;
  wire                                                 tl_tb_we;
  wire [          `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] tl_tb_waddr;
  wire [            `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] tl_tb_wdat;
  // tile buffer (TB) 
  wire                                                 tb_tr_vld;
  wire [            `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] tb_tr_dat;
  // tile reader (TR) 
  // weight reader (WR) 
  wire                                                 tr_sched_dn;
  wire                                                 tr_tb_re;
  wire [          `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] tr_tb_raddr;
  wire                                                 tr_lyr_vld;
  wire [            `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] tr_lyr_dat;
  // layer   
  wire                                                 clyr_sched_dn;
  wire                                                 clyr_psc_vld;
  wire [              `PSUM_BIT*`MAX_GROUP_FILTER-1:0] clyr_psc_dat;
  wire                                                 plyr_rdy;
  wire                                                 plyr_vld;
  wire [               `IPT_BIT*`MAX_GROUP_FILTER-1:0] plyr_dat;
  // partial sum
  wire                                                 psc_psb_rdy;
  wire                                                 psc_psb_re;
  wire [              `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] psc_psb_raddr;
  wire                                                 psc_psb_we;
  wire [              `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] psc_psb_waddr;
  wire [              `PSUM_BIT*`MAX_GROUP_FILTER-1:0] psc_psb_wdat;
  wire                                                 psc_pp_vld;
  wire [              `PSUM_BIT*`MAX_GROUP_FILTER-1:0] psc_pp_dat;
  wire                                                 psc_sched_dn;
  // 
  wire                                                 pp_ts_vld;
  wire [              `OPT_BIT* `MAX_GROUP_FILTER-1:0] pp_ts_dat;
  //
  wire                                                 ts_sched_dn;
  //
  wire                                                 fifo_psb_rdy;
  wire                                                 psb_psc_vld;
  wire [              `PSUM_BIT*`MAX_GROUP_FILTER-1:0] psb_psc_dat;
  //
  wire                                                 psb_psc_rdy;
  wire                                                 psb_fifo_rvld;
  wire [              `PSUM_BIT*`MAX_GROUP_FILTER-1:0] psb_fifo_rdat;
  wire                                                 psb_fifo_rdy;
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
      .i_lyr_idx(sched_lyr_idx)
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
      .i_lyr_idx(sched_lyr_idx)
  );
  // feature map buffer
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
      .i_we     (ts_fbuf_we),
      .i_waddr  (ts_fbuf_waddr),
      .i_wdin   (ts_fbuf_wdat),
      //
      .i_lyr_idx(sched_lyr_idx),
      .i_switch (sched_fbuf_switch)
  );
  // parital sum buffer
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
  global_ctrl inst_global_ctrl (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_st      (i_start),
      .o_dn      (o_dn),
      .o_sched_st(gc_sched_st),
      .i_sched_dn(sched_gc_dn)
  );
  scheduler inst_scheduler (
      .i_clk         (i_clk),
      .i_rstn        (i_rstn),
      .i_st          (gc_sched_st),
      .o_ctrl_rdy    (sched_lyr_rdy),
      .o_dn          (sched_gc_dn),
      //
      .o_lyr_idx     (sched_lyr_idx),
      .i_lyr_type    (cfg_lyr_type),
      .i_filt        (cfg_filt),
      .i_filt_grp_num(cfg_filt_grp_num),
      .i_tile_num    (cfg_tile_num),
      .i_tile_num_x  (cfg_tile_num_x),
      .i_tile_num_y  (cfg_tile_num_y),
      .i_ch          (cfg_ch),
      .i_ch_grp_num  (cfg_ch_grp_num),
      .i_tile_side   (cfg_tile_side),
      .i_lyr_opt_area(cfg_lyr_opt_area),
      //
      .o_nxt_lyr     (sched_nxt_lyr),
      .o_nxt_filt_grp(sched_nxt_filt_grp),
      .o_nxt_tile_col(sched_nxt_tile_col),
      .o_nxt_tile_row(sched_nxt_tile_row),
      .o_nxt_ch_grp  (sched_nxt_ch_grp),
      // fmap
      .o_fbuf_switch (sched_fbuf_switch),
      // bias loader (BL) 
      .o_bl_st       (sched_bl_st),
      .i_bl_dn       (bl_sched_dn),
      // bias reader
      .o_br_st       (sched_br_st),
      .i_br_dn       (br_sched_dn),
      // weight loader (WL)
      .o_wl_st       (sched_wl_st),
      .i_wl_dn       (wl_sched_dn),
      // weight reader
      .o_wr_st       (sched_wr_st),
      .i_wr_dn       (wr_sched_dn),
      // tile loader (TL) 
      .o_tl_st       (sched_tl_st),
      .o_img_org_x   (sched_tl_img_org_x),  // origin position
      .o_img_org_y   (sched_tl_img_org_y),
      .i_tl_dn       (tl_sched_dn),
      // tile reader
      .o_tr_st       (sched_tr_st),
      .i_tr_dn       (tr_sched_dn),
      // lyr  
      .i_lyr_dn      (clyr_sched_dn),
      .o_lyr_clr     (sched_lyr_clr),
      .o_lyr_opt_num (sched_lyr_opt_num),
      // PSC
      .o_psc_st      (sched_psc_st),
      //
      .o_ts_st       (sched_ts_st),
      .i_ts_dn       (ts_sched_dn),
      // temp   
      .o_in_ch       (sched_lyr_in_ch),
      // group  
      .o_ch_mask     (sched_lyr_ch_mask),
      .o_filt_mask   (sched_lyr_filt_mask)
  );

  layer_config inst_layer_config (
      .i_lyr_idx           (sched_lyr_idx),
      //
      .o_lyr_type          (cfg_lyr_type),
      .o_pad               (cfg_pad),
      .o_relu              (cfg_relu),
      .o_filt              (cfg_filt),
      .o_filt_grp_num      (cfg_filt_grp_num),
      .o_tile_num          (cfg_tile_num),
      .o_tile_num_x        (cfg_tile_num_x),
      .o_tile_num_y        (cfg_tile_num_y),
      .o_ch                (cfg_ch),
      .o_ch_grp_num        (cfg_ch_grp_num),
      .o_img_side          (cfg_img_side),
      .o_img_area          (cfg_img_area),
      .o_opt_side          (cfg_opt_side),
      .o_opt_area          (cfg_opt_area),
      .o_tile_side         (cfg_tile_side),
      .o_lyr_opt_area      (cfg_lyr_opt_area),
      //
      .o_bl_filt_grp_stride(cfg_bl_filt_grp_stride),
      .o_br_filt_grp_stride(cfg_br_filt_grp_stride),
      .o_wl_filt_grp_stride(cfg_wl_filt_grp_stride),
      .o_wr_ch_grp_stride  (cfg_wr_ch_grp_stride),
      .o_tl_row_stride     (cfg_tl_row_stride),
      .o_tl_col_stride     (cfg_tl_col_stride),
      .o_tl_ch_grp_stride  (cfg_tl_ch_grp_stride),
      .o_ts_col_stride     (cfg_ts_col_stride),
      .o_ts_row_stride     (cfg_ts_row_stride),
      .o_ts_ch_grp_stride  (cfg_ts_ch_grp_stride),
      //
      .o_bl_req_len        (cfg_bl_req_len),
      .o_br_read_len       (cfg_br_read_len),
      .o_wl_req_len        (cfg_wl_req_len),
      .o_wr_read_len       (cfg_wr_read_len),
      .o_tr_read_len       (cfg_tr_read_len),
      .o_bl_bank_depth     (cfg_bl_bank_depth),
      .o_wl_bank_depth     (cfg_wl_bank_depth)
  );
  address_generater inst_address_generater (
      .i_clk               (i_clk),
      .i_rstn              (i_rstn),
      //
      .i_nxt_lyr           (sched_nxt_lyr),
      .i_nxt_filt_grp      (sched_nxt_filt_grp),
      .i_nxt_tile_col      (sched_nxt_tile_col),
      .i_nxt_tile_row      (sched_nxt_tile_row),
      .i_nxt_ch_grp        (sched_nxt_ch_grp),
      .i_bl_filt_grp_stride(cfg_bl_filt_grp_stride),
      .i_br_filt_grp_stride(cfg_br_filt_grp_stride),
      .i_wl_filt_grp_stride(cfg_wl_filt_grp_stride),
      .i_wr_ch_grp_stride  (cfg_wr_ch_grp_stride),
      .i_tl_row_stride     (cfg_tl_row_stride),
      .i_tl_col_stride     (cfg_tl_col_stride),
      .i_tl_ch_grp_stride  (cfg_tl_ch_grp_stride),
      .i_ts_row_stride     (cfg_ts_row_stride),
      .i_ts_col_stride     (cfg_ts_col_stride),
      .i_ts_ch_grp_stride  (cfg_ts_ch_grp_stride),
      //
      .o_bl_addr           (ag_bl_addr),
      .o_br_addr           (ag_br_addr),
      .o_wl_addr           (ag_wl_addr),
      .o_wr_addr           (ag_wr_addr),
      .o_tl_addr           (ag_tl_addr),
      .o_tr_addr           (ag_tr_addr),
      .o_ts_addr           (ag_ts_addr)
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
      .i_st        (sched_bl_st),
      .o_dn        (bl_sched_dn),
      //
      .i_req_len   (cfg_bl_req_len),
      .i_req_addr  (ag_bl_addr),
      .i_bank_depth(cfg_bl_bank_depth),
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
      .i_read_len (cfg_br_read_len),
      .i_read_addr(ag_br_addr),
      .i_st       (sched_br_st),
      .o_dn       (br_sched_dn),
      ///
      .o_re       (br_bb_re),
      .o_raddr    (br_bb_raddr),
      //
      .o_ipt_rdy  (),
      .i_ipt_vld  (bb_br_vld),
      .i_ipt_din  (bb_br_dat),
      //
      .i_opt_rdy  ('b1),              // TODO
      .o_opt_vld  (br_pp_vld),
      .o_opt_dout (br_pp_dat)
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
      .BUF_DEPTH (WGT_BANK_DEPTH),
      .BANK_NUM  (`MAX_GROUP_FILTER),
      .BANK_DEPTH(`MAX_CHANNEL * `CONV_3X3_AREA)
  ) inst_weight_loader (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .i_clr       (),
      .i_st        (sched_wl_st),
      .o_dn        (wl_sched_dn),
      //
      .i_req_len   (cfg_wl_req_len),
      .i_req_addr  (ag_wl_addr),
      .i_bank_depth(cfg_wl_bank_depth),
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
      .i_wdin    (wl_wb_wdat),
      .i_opt_rdy ('b1),
      .o_rvld    (wb_wr_vld),
      .o_rdout   (wb_wr_dat)
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
      .i_read_len (cfg_wr_read_len),
      .i_read_addr(ag_wr_addr),
      .i_st       (sched_wr_st),
      .o_dn       (wr_sched_dn),
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
      .i_clk        (i_clk),
      .i_rstn       (i_rstn),
      .i_st         (sched_tl_st),
      .o_dn         (tl_sched_dn),
      // sched
      .i_img_side   (cfg_img_side),
      .i_img_org_x  (sched_tl_img_org_x),
      .i_img_org_y  (sched_tl_img_org_y),
      .i_tl_req_addr(ag_tl_addr),
      // RC
      .o_req_len    (tl_trc_req_len),
      .o_req        (tl_trc_req),
      .o_req_addr   (tl_trc_req_addr),
      .i_req_dn     (trc_tl_req_dn),
      // FIFO
      .o_ipt_rdy    (tl_fifo_rdy),
      .i_ipt_vld    (fifo_tl_vld),
      .i_ipt_din    (fifo_tl_dat),
      // opt (layer)
      .o_we         (tl_tb_we),
      .o_waddr      (tl_tb_waddr),
      .o_wdat       (tl_tb_wdat)
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
      .i_read_len (cfg_tr_read_len),
      .i_read_addr(ag_tr_addr),
      .i_st       (sched_tr_st),
      .o_dn       (tr_sched_dn),
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
      .i_clk      (i_clk),
      .i_rstn     (i_rstn),
      .i_clr      (sched_lyr_clr),
      .o_dn       (clyr_sched_dn),
      // wgt 
      .i_wgt_vld  (wr_lyr_vld),
      .i_wgt_din  (wr_lyr_dat),
      // ipt 
      .o_ipt_rdy  (),
      .i_ipt_vld  (tr_lyr_vld),
      .i_ipt_din  (tr_lyr_dat),
      // opt  
      .i_opt_rdy  (sched_lyr_rdy),
      .o_opt_vld  (clyr_psc_vld),
      .o_opt_dout (clyr_psc_dat),
      // temp
      .i_opt_area (sched_lyr_opt_num),
      .i_relu_en  (),
      .i_in_ch    (sched_lyr_in_ch),
      .i_ch_mask  (sched_lyr_ch_mask),
      .i_filt_mask(sched_lyr_filt_mask)
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
  //       .i_opt_rdy (sched_lyr_rdy),
  //       .o_opt_vld (plyr_vld),
  //       .o_opt_dout(plyr_dat),
  //       //    
  //       .i_img_side(sched_lyr_line_width),
  //       .i_lbuf_st ((sched_lyr_clr & {`MAX_GROUP_FILTER{w_lyr_type == `LAYER_TYPE_MAXPOOL}}))
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
      .i_st       (sched_psc_st),
      .o_dn       (psc_sched_dn),
      .i_sum_cnt  (cfg_ch_grp_num),
      .i_relu     (cfg_relu),
      //
      .i_bias_vld (br_pp_vld),
      .i_bias_din (br_pp_dat),
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
      .o_opt_vld  (psc_pp_vld),
      .o_opt_dout (psc_pp_dat)
  );
  post_proccessor inst_post_proccessor (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      //
      .i_relu    (cfg_relu),
      .i_bias_vld(br_pp_vld),
      .i_bias_din(br_pp_dat),
      //
      .i_ipt_vld (psc_pp_vld),
      .i_ipt_din (psc_pp_dat),
      //
      .o_opt_vld (pp_ts_vld),
      .o_opt_dout(pp_ts_dat)
  );
  tile_scatter inst_tile_scatter (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .i_st        (sched_ts_st),
      .o_dn        (ts_sched_dn),
      //
      .i_img_side  (cfg_img_side),
      .i_base_addr (ag_ts_addr),
      //
      .i_vld       (pp_ts_vld),
      .i_din       (pp_ts_dat),
      //
      .o_obuf_we   (ts_fbuf_we),
      .o_obuf_wdout(ts_fbuf_wdat),
      .o_obuf_waddr(ts_fbuf_waddr)
  );
endmodule


`include "defines.vh"
`include "network_config.vh"
module my_top #(
    parameter IMG_INIT_FILE     = "",
    parameter L0_WGT_INIT_FILE  = "",
    parameter L0_BIAS_INIT_FILE = "",
    parameter L1_WGT_INIT_FILE  = "",
    parameter L1_BIAS_INIT_FILE = "",
    parameter L2_WGT_INIT_FILE  = "",
    parameter L2_BIAS_INIT_FILE = "",
    parameter L3_WGT_INIT_FILE  = "",
    parameter L3_BIAS_INIT_FILE = "",
    parameter L4_WGT_INIT_FILE  = "",
    parameter L4_BIAS_INIT_FILE = "",
    parameter L5_WGT_INIT_FILE  = "",
    parameter L5_BIAS_INIT_FILE = ""
) (
`ifdef DEBUG
    input                                          i_rdy_test,
    output        [`CLOG2_SAFE(`CONV_LAYER_NUM):0] o_lyr_num,
    output                                         o_lyr_vld,
    output signed [                  `IPT_BIT-1:0] o_lyr_dat,
`endif
    input                                          i_clk,
    input                                          i_rstn,
    input                                          i_start,
    output                                         o_dn
);
  // ====================== parmeter =======================  
  genvar g, f;
  integer i;

  localparam MAX_WGT_BANK_DEPTH = `MAX_CHANNEL * `CONV_3X3_AREA;
  localparam MAX_WGT_BANK_NUM = `MAX_GROUP_FILTER;
  localparam FBUF_DEPTH = `MAX_FILTER_GROUP_NUM * `MAX_IPT_AREA * `CONV_LAYER_NUM;
  localparam WGT_DESC_BIT = `CLOG2_SAFE(MAX_WGT_BANK_DEPTH) + `CLOG2_SAFE(MAX_WGT_BANK_NUM) + 2;
  localparam BIAS_DESC_BIT =
  `CLOG2_SAFE(`MAX_FILTER_GROUP_NUM)
  +
  `CLOG2_SAFE(`MAX_GROUP_FILTER)
  + 2;


  // fmap buffer 
  wire                                                     fbuf_trc_vld;
  wire [                `OPT_BIT * `MAX_GROUP_FILTER -1:0] fbuf_trc_dat;
  // global controller 
  wire                                                     gc_sched_st;
  // 
  wire                                                     cfg_pad;
  wire                                                     cfg_relu;
  wire [                       `CLOG2_SAFE(`MAX_FILTER):0] cfg_filt;
  wire [                                              1:0] cfg_kernel_stride;
  wire [     `CLOG2_SAFE(`MAX_FILTER/`MAX_GROUP_FILTER):0] cfg_filt_grp_num;
  wire [                     `CLOG2_SAFE(`MAX_TILE_NUM):0] cfg_tile_num;
  wire [    `CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] cfg_tile_num_x;
  wire [    `CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] cfg_tile_num_y;
  wire [                      `CLOG2_SAFE(`MAX_CHANNEL):0] cfg_ch;
  wire [            `CLOG2_SAFE(`MAX_CHANNEL_GROUP_NUM):0] cfg_ch_grp_num;
  wire [                     `CLOG2_SAFE(`MAX_IPT_SIDE):0] cfg_img_side;
  wire [                     `CLOG2_SAFE(`MAX_OPT_SIDE):0] cfg_opt_side;
  wire [                     `CLOG2_SAFE(`MAX_OPT_AREA):0] cfg_opt_area;
  wire [                    `CLOG2_SAFE(`MAX_TILE_SIDE):0] cfg_tile_ipt_side;
  wire [                    `CLOG2_SAFE(`MAX_TILE_SIDE):0] cfg_tile_opt_side;
  wire [                    `CLOG2_SAFE(`MAX_TILE_AREA):0] cfg_tile_opt_area;

  wire [                 `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] cfg_bl_filt_grp_stride;
  wire [                 `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] cfg_br_filt_grp_stride;
  wire [     `CLOG2_SAFE(`MAX_CHANNEL*`CONV_3X3_AREA) : 0] cfg_wl_filt_grp_stride;
  wire [              `CLOG2_SAFE(MAX_WGT_BANK_DEPTH)-1:0] cfg_wr_ch_grp_stride;
  wire [                      `CLOG2_SAFE(`DDR_DEPTH)-1:0] cfg_tl_src0_base_addr;
  wire [                      `CLOG2_SAFE(`DDR_DEPTH)-1:0] cfg_tl_src1_base_addr;
  wire [          `CLOG2_SAFE(`MAX_CHANNEL_GROUP_NUM) : 0] cfg_tl_ch_grp_split;
  wire [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] cfg_tl_row_stride;
  wire [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] cfg_tl_col_stride;
  wire [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] cfg_tl_ch_grp_stride;
  wire [                      `CLOG2_SAFE(`DDR_DEPTH) : 0] cfg_ts_base_addr;
  wire [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] cfg_ts_row_stride;
  wire [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] cfg_ts_col_stride;
  wire [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] cfg_ts_ch_grp_stride;
  wire [                   `CLOG2_SAFE(`MAX_BIAS_DEPTH):0] cfg_brg_req_len;
  wire [           `CLOG2_SAFE(`MAX_FILTER_GROUP_NUM) : 0] cfg_br_read_len;
  wire [                    `CLOG2_SAFE(`MAX_WGT_DEPTH):0] cfg_wrg_req_len;
  wire [              `CLOG2_SAFE(MAX_WGT_BANK_DEPTH) : 0] cfg_wr_read_len;
  wire [              `CLOG2_SAFE(`MAX_PAD_TILE_AREA) : 0] cfg_tr_read_len;
  wire [           `CLOG2_SAFE(`MAX_FILTER_GROUP_NUM) : 0] cfg_brg_bank_depth;
  wire [              `CLOG2_SAFE(MAX_WGT_BANK_DEPTH) : 0] cfg_wrg_bank_depth;
  // scheduler (sched)  
  wire                                                     sched_gc_dn;
  wire                                                     sched_lyr_rdy;
  wire [                 `CLOG2_SAFE(`CONV_LAYER_NUM)-1:0] sched_lyr_idx;
  wire                                                     sched_bl_nxt_lyr;
  wire                                                     sched_bl_nxt_filt_grp;
  wire                                                     sched_wl_nxt_lyr;
  wire                                                     sched_wl_nxt_filt_grp;
  wire                                                     sched_nxt_lyr;
  wire                                                     sched_nxt_filt_grp;
  wire                                                     sched_nxt_tile_col;
  wire                                                     sched_nxt_tile_row;
  wire                                                     sched_nxt_ch_grp;
  wire                                                     sched_wr_nxt_lyr;
  wire                                                     sched_wr_nxt_filt_grp;
  wire                                                     sched_wr_nxt_tile;
  wire                                                     sched_wr_nxt_tile_row;
  wire                                                     sched_wr_nxt_ch_grp;
  wire                                                     sched_tr_nxt_lyr;
  wire                                                     sched_tr_nxt_filt_grp;
  wire                                                     sched_tr_nxt_tile_col;
  wire                                                     sched_tr_nxt_tile_row;
  wire                                                     sched_tr_nxt_ch_grp;
  wire                                                     sched_fbuf_wr_swap;
  wire                                                     sched_fbuf_rd_swap;
  wire                                                     sched_bl_st;
  wire                                                     sched_br_st;
  wire                                                     sched_wrg_st;
  wire                                                     sched_wb_wr_swap;
  wire                                                     sched_wb_rd_swap;
  wire                                                     sched_wr_st;
  wire                                                     sched_trg_st;
  wire [                   `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] sched_trg_tl_org_x;
  wire [                   `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] sched_trg_tl_org_y;
  wire                                                     sched_ag_commit_addr;
  wire                                                     sched_tr_st;
  wire [              `CLOG2_SAFE(`MAX_GROUP_CHANNEL) : 0] sched_lyr_in_ch;
  wire [              `CLOG2_SAFE(`MAX_GROUP_CHANNEL) : 0] sched_out_ch;
  wire [                           `MAX_GROUP_CHANNEL-1:0] sched_lyr_ch_mask;
  wire [                            `MAX_GROUP_FILTER-1:0] sched_lyr_filt_mask;
  wire                                                     sched_lyr_clr;
  wire                                                     sched_lyr_ws_swap;
  wire                                                     sched_psc_st;
  wire                                                     sched_pp_bias_swap;
  wire                                                     sched_ts_st;
  wire [                      `CLOG2_SAFE(`DDR_DEPTH)-1:0] sched_tl_base_addr;
  //
  wire                                                     ts_fbuf_we;
  wire [                  `OPT_BIT* `MAX_GROUP_FILTER-1:0] ts_fbuf_wdat;
  wire [                      `CLOG2_SAFE(`DDR_DEPTH)-1:0] ts_fbuf_waddr;
  // 
  wire [                 `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] ag_brg_addr;
  wire [           `CLOG2_SAFE(`MAX_FILTER_GROUP_NUM)-1:0] ag_br_addr;
  wire [                  `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] ag_wrg_addr;
  wire [              `CLOG2_SAFE(MAX_WGT_BANK_DEPTH)-1:0] ag_wr_addr;
  wire [                      `CLOG2_SAFE(`DDR_DEPTH)-1:0] ag_trg_req_addr;
  wire [              `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] ag_tr_addr;
  wire [                      `CLOG2_SAFE(`DDR_DEPTH)-1:0] ag_ts_addr;
  // bias mem (DDR)
  wire                                                     storage_brc_vld;
  wire [                                     `IPT_BIT-1:0] storage_brc_dat;
  wire                                                     brc_bf_vld;
  wire [                                     `IPT_BIT-1:0] brc_bf_dat;
  // bias request generator
  wire                                                     brg_bdf_vld;
  wire [                                BIAS_DESC_BIT-1:0] brg_bdf_dat;
  // bias request que
  wire                                                     bq_brg_que_full;
  wire                                                     bq_brc_que_empty;
  wire [`CLOG2_SAFE(FBUF_DEPTH)+`CLOG2_SAFE(FBUF_DEPTH):0] bq_brc_que_dat;
  // bias read controller (TRC) 
  wire                                                     brc_bq_que_pop;
  // bias read controller (BRC)
  wire                                                     brc_storage_re;
  wire [                 `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] brc_storage_raddr;
  // bias FIFO 
  wire                                                     bf_brc_rdy;
  wire                                                     bf_bw_vld;
  wire [                                     `IPT_BIT-1:0] bf_bw_dat;
  // desc FIFO 
  wire                                                     bdf_bw_vld;
  wire [                                BIAS_DESC_BIT-1:0] bdf_bw_dat;
  // bias tl (BL) 
  wire                                                     bl_sched_dn;
  wire [                 `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] brg_brc_req_len;
  wire                                                     brg_brc_req;
  wire [                 `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] brg_brc_req_addr;
  //
  wire                                                     bw_dn;
  wire                                                     bw_bf_rdy;
  wire                                                     bw_bdf_rdy;
  wire [               `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] bw_bb_bank_idx;
  wire                                                     bw_bb_we;
  wire [           `CLOG2_SAFE(`MAX_FILTER_GROUP_NUM)-1:0] bw_bb_waddr;
  wire [                                     `IPT_BIT-1:0] bw_bb_wrat;
  // bias buffer (BB) 
  wire                                                     bb_br_vld;
  wire [                   `IPT_BIT*`MAX_GROUP_FILTER-1:0] bb_br_dat;
  wire                                                     bb_wr_rdy;
  wire                                                     bb_rd_rdy;
  // bias reader (BR) 
  wire                                                     br_sched_dn;
  wire                                                     br_bb_re;
  wire [           `CLOG2_SAFE(`MAX_FILTER_GROUP_NUM)-1:0] br_bb_raddr;
  wire                                                     br_pp_vld;
  wire [                   `IPT_BIT*`MAX_GROUP_FILTER-1:0] br_pp_dat;
  // weight (DDR)
  wire                                                     storage_wrc_vld;
  wire [                                     `WGT_BIT-1:0] storage_wrc_dat;
  // weight
  wire                                                     wrg_wdf_desc_vld;
  wire [                                 WGT_DESC_BIT-1:0] wrg_wdf_desc_dat;  // {side,x,y} 
  // weight request que
  wire                                                     wq_wrc_que_empty;
  wire                                                     wq_wrg_que_full;
  wire [`CLOG2_SAFE(FBUF_DEPTH)+`CLOG2_SAFE(FBUF_DEPTH):0] wq_wrc_que_dat;
  // weight read controller (TRC) 
  wire                                                     wrc_wq_que_pop;
  // weight read controller (WRC)
  wire                                                     wrc_storage_re;
  wire [                  `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] wrc_storage_raddr;
  wire                                                     wrc_wf_vld;
  wire [                                     `WGT_BIT-1:0] wrc_wf_dat;
  // weight   (FIFO)
  wire                                                     wf_wrc_rdy;
  wire                                                     wf_ww_vld;
  wire [                                     `WGT_BIT-1:0] wf_ww_dat;
  // weight   (FIFO)
  wire                                                     wdf_ww_vld;
  wire [                                 WGT_DESC_BIT-1:0] wdf_ww_dat;
  // weight tl (WL) 
  wire                                                     wrg_sched_dn;
  wire [                  `CLOG2_SAFE(`MAX_WGT_DEPTH) : 0] wrg_wrc_req_len;
  wire                                                     wrg_wrc_req;
  wire [                  `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] wrg_wrc_req_addr;
  // weight writer
  wire                                                     ww_dn;
  wire                                                     ww_wf_rdy;
  wire [               `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] ww_wb_bank_idx;
  wire                                                     ww_wb_we;
  wire [              `CLOG2_SAFE(MAX_WGT_BANK_DEPTH)-1:0] ww_wb_waddr;
  wire [                                     `WGT_BIT-1:0] ww_wb_wdat;
  // weight writer
  wire                                                     ww_wdf_rdy;
  // weight buffer (WB) 
  wire                                                     wb_wr_rvld;
  wire [                 `WGT_BIT * `MAX_GROUP_FILTER-1:0] wb_wr_rdat;
  wire                                                     wb_ww_wr_rdy;
  wire                                                     wb_wr_rd_rdy;
  // weight reader (WR) 
  wire                                                     wr_sched_dn;
  wire                                                     wr_wb_re;
  wire [              `CLOG2_SAFE(MAX_WGT_BANK_DEPTH)-1:0] wr_wb_raddr;
  wire                                                     wr_lyr_vld;
  wire [                 `WGT_BIT * `MAX_GROUP_FILTER-1:0] wr_lyr_dat;
  //
  wire                                                     ws_wr_rdy;
  wire                                                     ws_rd_rdy;
  //
  wire                                                     trg_trg_desc_rdy;
  wire                                                     trg_tdf_desc_vld;
  wire [             3*(`CLOG2_SAFE(`MAX_IPT_SIDE)+1)-1:0] trg_tdf_desc_dout;  // {side,x,y}
  // tile request que
  wire                                                     tq_trg_que_full;
  wire                                                     tq_trc_que_empty;
  wire [`CLOG2_SAFE(FBUF_DEPTH)+`CLOG2_SAFE(`DDR_DEPTH):0] tq_trc_que_dat;
  // tile read controller (TRC) 
  wire                                                     trc_tq_que_pop;
  wire                                                     trc_fbuf_re;
  wire [                      `CLOG2_SAFE(`DDR_DEPTH)-1:0] trc_fbuf_raddr;
  wire                                                     trc_tf_vld;
  wire [                  `IPT_BIT*`MAX_GROUP_CHANNEL-1:0] trc_tf_dat;
  // tile pixel FIFO
  wire                                                     tpf_trc_rdy;
  wire                                                     tpf_tw_vld;
  wire [                `IPT_BIT* `MAX_GROUP_CHANNEL -1:0] tpf_tw_dat;
  // tile descript FIFO
  wire                                                     tdf_tw_vld;
  wire [             3*(`CLOG2_SAFE(`MAX_IPT_SIDE)+1)-1:0] tdf_tw_dat;
  // tile buffer writer
  wire                                                     tw_tdf_rdy;
  wire                                                     tw_tb_wr_dn;
  // tile tl (TL)  
  wire                                                     trg_sched_dn;
  wire [                      `CLOG2_SAFE(FBUF_DEPTH) : 0] trg_trc_req_len;
  wire                                                     trg_trc_req;
  wire [                      `CLOG2_SAFE(`DDR_DEPTH)-1:0] trg_trc_req_addr;
  wire                                                     tw_tpf_rdy;
  wire                                                     tw_tb_we;
  wire [              `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] tw_tb_waddr;
  wire [                `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] tw_tb_wdat;
  // tile buffer (TB) 
  wire                                                     tb_tr_vld;
  wire [                `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] tb_tr_dat;
  wire                                                     tb_tw_wr_rdy;
  wire                                                     tb_tr_rd_rdy;
  // tile reader (TR)  
  wire                                                     tr_dn;
  wire                                                     tr_tb_re;
  wire [              `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] tr_tb_raddr;
  wire                                                     tr_lyr_vld;
  wire [                `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] tr_lyr_dat;
  // layer   
  wire                                                     clyr_sched_dn;
  wire                                                     clyr_psc_vld;
  wire [                  `PSUM_BIT*`MAX_GROUP_FILTER-1:0] clyr_psc_dat;
  wire                                                     plyr_rdy;
  wire                                                     plyr_vld;
  wire [                   `IPT_BIT*`MAX_GROUP_FILTER-1:0] plyr_dat;
  // partial sum
  wire                                                     psc_sched_dn;
  wire                                                     psc_psb_rdy;
  wire                                                     psc_psb_re;
  wire [                  `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] psc_psb_raddr;
  wire                                                     psc_psb_we;
  wire [                  `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] psc_psb_waddr;
  wire [                  `PSUM_BIT*`MAX_GROUP_FILTER-1:0] psc_psb_wdat;
  wire                                                     psc_pp_vld;
  wire [                  `PSUM_BIT*`MAX_GROUP_FILTER-1:0] psc_pp_dat;
  // 
  wire                                                     pp_br_bs_wr_rdy;
  wire                                                     pp_bs_rd_rdy;
  wire                                                     pp_ts_vld;
  wire [                  `OPT_BIT* `MAX_GROUP_FILTER-1:0] pp_ts_dat;
  //  
  wire                                                     pool_ts_vld;
  wire [                  `OPT_BIT* `MAX_GROUP_FILTER-1:0] pool_ts_dat;
  //
  wire                                                     ts_sched_dn;
  // 
  wire                                                     psb_psc_vld;
  wire [                  `PSUM_BIT*`MAX_GROUP_FILTER-1:0] psb_psc_dat;
  //
  wire                                                     psb_psc_rdy;
  // ====================== reg ============================   
  // bias storage
  storage #(
      .WIDTH     (`IPT_BIT),
      .DEPTH     (`MAX_BIAS_DEPTH),
      .INIT_FILE0(L0_BIAS_INIT_FILE),
      .INIT_FILE1(L1_BIAS_INIT_FILE),
      .INIT_FILE2(L2_BIAS_INIT_FILE),
      .INIT_FILE3(L3_BIAS_INIT_FILE),
      .INIT_FILE4(L4_BIAS_INIT_FILE),
      .INIT_FILE5(L5_BIAS_INIT_FILE)
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
      .INIT_FILE2(L2_WGT_INIT_FILE),
      .INIT_FILE3(L3_WGT_INIT_FILE),
      .INIT_FILE4(L4_WGT_INIT_FILE),
      .INIT_FILE5(L5_WGT_INIT_FILE)
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
      .DEPTH        (`DDR_DEPTH),
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
      .i_wr_dn  (sched_fbuf_wr_swap),
      .i_rd_dn  (sched_fbuf_rd_swap)
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
  global_ctrl inst_global_ctrl (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_st      (i_start),
      .o_dn      (o_dn),
      .o_sched_st(gc_sched_st),
      .i_sched_dn(sched_gc_dn)
  );
  scheduler inst_scheduler (
      .i_clk              (i_clk),
      .i_rstn             (i_rstn),
      .i_st               (gc_sched_st),
      .o_ctrl_rdy         (sched_lyr_rdy),
      .o_dn               (sched_gc_dn),
      //
      .o_lyr_idx          (sched_lyr_idx),
      .i_filt             (cfg_filt),
      .i_filt_grp_num     (cfg_filt_grp_num),
      .i_tile_num         (cfg_tile_num),
      .i_tile_num_x       (cfg_tile_num_x),
      .i_tile_num_y       (cfg_tile_num_y),
      .i_ch               (cfg_ch),
      .i_ch_grp_num       (cfg_ch_grp_num),
      .i_tile_ipt_side    (cfg_tile_ipt_side),
      //
      .o_bl_nxt_lyr       (sched_bl_nxt_lyr),
      .o_bl_nxt_filt_grp  (sched_bl_nxt_filt_grp),
      // 
      .o_wl_nxt_lyr       (sched_wl_nxt_lyr),
      .o_wl_nxt_filt_grp  (sched_wl_nxt_filt_grp),
      //
      .o_tl_nxt_lyr       (sched_nxt_lyr),
      .o_tl_nxt_filt_grp  (sched_nxt_filt_grp),
      .o_tl_nxt_tile_col  (sched_nxt_tile_col),
      .o_tl_nxt_tile_row  (sched_nxt_tile_row),
      .o_tl_nxt_ch_grp    (sched_nxt_ch_grp),
      //
      .o_wr_nxt_lyr       (sched_wr_nxt_lyr),
      .o_wr_nxt_filt_grp  (sched_wr_nxt_filt_grp),
      .o_wr_nxt_tile      (sched_wr_nxt_tile),
      .o_wr_nxt_ch_grp    (sched_wr_nxt_ch_grp),
      //
      .o_tr_nxt_lyr       (sched_tr_nxt_lyr),
      .o_tr_nxt_filt_grp  (sched_tr_nxt_filt_grp),
      .o_tr_nxt_tile_col  (sched_tr_nxt_tile_col),
      .o_tr_nxt_tile_row  (sched_tr_nxt_tile_row),
      .o_tr_nxt_ch_grp    (sched_tr_nxt_ch_grp),
      // fmap 
      .o_bl_st            (sched_bl_st),
      .o_br_st            (sched_br_st),
      .o_wl_st            (sched_wrg_st),
      .o_wr_st            (sched_wr_st),
      .o_tl_st            (sched_trg_st),
      .o_tr_st            (sched_tr_st),
      .o_psc_st           (sched_psc_st),
      .o_ts_st            (sched_ts_st),
      //
      .i_bl_dn            (bl_sched_dn),
      .i_br_dn            (br_sched_dn),
      .i_wl_dn            (wrg_sched_dn),
      .i_wr_dn            (wr_sched_dn),
      .i_tl_dn            (trg_sched_dn),
      .i_tr_dn            (tr_dn),
      .i_lyr_dn           (clyr_sched_dn),
      .i_psc_dn           (psc_sched_dn),
      .i_ts_dn            (ts_sched_dn),
      //
      .i_bs_rdy           (pp_bs_rd_rdy),
      .i_ws_rdy           (ws_rd_rdy),
      // tile tl (TL) 
      .i_tl_src0_base_addr(cfg_tl_src0_base_addr),
      .o_tl_org_x         (sched_trg_tl_org_x),     // origin position
      .o_tl_org_y         (sched_trg_tl_org_y),
      .o_tl_base_addr     (sched_tl_base_addr),
      // lyr  
      .o_lyr_clr          (sched_lyr_clr),
      // switch
      .o_fbuf_wr_swap     (sched_fbuf_wr_swap),
      .o_fbuf_rd_swap     (sched_fbuf_rd_swap),
      .o_wb_rd_swap       (sched_wb_rd_swap),
      .o_ws_swap          (sched_lyr_ws_swap),
      .o_bs_swap          (sched_pp_bias_swap),
      // group  
      .o_in_ch            (sched_lyr_in_ch),
      .o_out_ch           (sched_out_ch),
      .o_ch_mask          (sched_lyr_ch_mask),
      .o_filt_mask        (sched_lyr_filt_mask)
  );
  layer_config inst_layer_config (
      .i_lyr_idx           (sched_lyr_idx),
      // 
      .o_pad               (cfg_pad),
      .o_relu              (cfg_relu),
      .o_filt              (cfg_filt),
      .o_kernel_stride     (cfg_kernel_stride),
      .o_filt_grp_num      (cfg_filt_grp_num),
      .o_tile_num          (cfg_tile_num),
      .o_tile_num_x        (cfg_tile_num_x),
      .o_tile_num_y        (cfg_tile_num_y),
      .o_ch                (cfg_ch),
      .o_ch_grp_num        (cfg_ch_grp_num),
      .o_img_side          (cfg_img_side),
      .o_opt_side          (cfg_opt_side),
      .o_opt_area          (cfg_opt_area),
      .o_tile_ipt_side     (cfg_tile_ipt_side),
      .o_tile_opt_side     (cfg_tile_opt_side),
      .o_tile_opt_area     (cfg_tile_opt_area),
      //
      .o_bl_filt_grp_stride(cfg_bl_filt_grp_stride),
      .o_br_filt_grp_stride(cfg_br_filt_grp_stride),
      .o_wl_filt_grp_stride(cfg_wl_filt_grp_stride),
      .o_wr_ch_grp_stride  (cfg_wr_ch_grp_stride),
      .o_tl_src0_base_addr (cfg_tl_src0_base_addr),
      .o_tl_src1_base_addr (cfg_tl_src1_base_addr),
      .o_tl_ch_grp_split   (cfg_tl_ch_grp_split),
      .o_tl_row_stride     (cfg_tl_row_stride),
      .o_tl_col_stride     (cfg_tl_col_stride),
      .o_tl_ch_grp_stride  (cfg_tl_ch_grp_stride),
      .o_ts_base_addr      (cfg_ts_base_addr),
      .o_ts_col_stride     (cfg_ts_col_stride),
      .o_ts_row_stride     (cfg_ts_row_stride),
      .o_ts_ch_grp_stride  (cfg_ts_ch_grp_stride),
      //
      .o_bl_req_len        (cfg_brg_req_len),
      .o_br_read_len       (cfg_br_read_len),
      .o_wl_req_len        (cfg_wrg_req_len),
      .o_wr_read_len       (cfg_wr_read_len),
      .o_tr_read_len       (cfg_tr_read_len),
      .o_bl_bank_depth     (cfg_brg_bank_depth),
      .o_wl_bank_depth     (cfg_wrg_bank_depth)
  );
  loader_addr_gen inst_loader_addr_gen (
      .i_clk               (i_clk),
      .i_rstn              (i_rstn),
      //
      .i_bl_nxt_lyr        (sched_bl_nxt_lyr),
      .i_bl_nxt_filt_grp   (sched_bl_nxt_filt_grp),
      //
      .i_wl_nxt_lyr        (sched_wl_nxt_lyr),
      .i_wl_nxt_filt_grp   (sched_wl_nxt_filt_grp),
      //
      .i_nxt_lyr           (sched_nxt_lyr),
      .i_nxt_filt_grp      (sched_nxt_filt_grp),
      .i_nxt_tile_col      (sched_nxt_tile_col),
      .i_nxt_tile_row      (sched_nxt_tile_row),
      .i_nxt_ch_grp        (sched_nxt_ch_grp),
      .i_bl_filt_grp_stride(cfg_bl_filt_grp_stride),
      .i_wl_filt_grp_stride(cfg_wl_filt_grp_stride),
      .i_tl_row_stride     (cfg_tl_row_stride),
      .i_tl_col_stride     (cfg_tl_col_stride),
      .i_tl_ch_grp_stride  (cfg_tl_ch_grp_stride),
      .i_tl_src0_base_addr (cfg_tl_src0_base_addr),
      .i_tl_src1_base_addr (cfg_tl_src1_base_addr),
      .i_tl_ch_grp_split   (cfg_tl_ch_grp_split),
      //
      .o_bl_addr           (ag_brg_addr),
      .o_wl_addr           (ag_wrg_addr),
      .o_tl_addr           (ag_trg_req_addr)
  );
  wr_addr_gen #() inst_wr_addr_gen (
      .i_clk             (i_clk),
      .i_rstn            (i_rstn),
      //
      .i_nxt_lyr         (sched_wr_nxt_lyr),
      .i_nxt_filt_grp    (sched_wr_nxt_filt_grp),
      .i_nxt_tile        (sched_wr_nxt_tile),
      .i_nxt_ch_grp      (sched_wr_nxt_ch_grp),
      // 
      .i_wr_ch_grp_stride(cfg_wr_ch_grp_stride),
      .o_br_addr         (ag_br_addr),
      .o_wr_addr         (ag_wr_addr)
  );
  reader_addr_gen inst_reader_addr_gen (
      .i_clk             (i_clk),
      .i_rstn            (i_rstn),
      //
      .i_nxt_lyr         (sched_tr_nxt_lyr),
      .i_nxt_filt_grp    (sched_tr_nxt_filt_grp),
      .i_nxt_tile_col    (sched_tr_nxt_tile_col),
      .i_nxt_tile_row    (sched_tr_nxt_tile_row),
      .i_nxt_ch_grp      (sched_tr_nxt_ch_grp),
      .i_ts_base_addr    (cfg_ts_base_addr),
      .i_ts_row_stride   (cfg_ts_row_stride),
      .i_ts_col_stride   (cfg_ts_col_stride),
      .i_ts_ch_grp_stride(cfg_ts_ch_grp_stride),
      //  
      .o_tr_addr         (ag_tr_addr),
      .o_ts_addr         (ag_ts_addr)
  );
  //      ____  _           
  //     | __ )(_) __ _ ___ 
  //     |  _ \| |/ _` / __|
  //     | |_) | | (_| \__ \
  //     |____/|_|\__,_|___/
  //
  bias_req_gen #(
      .BIAS_BUF_DEPTH     (`MAX_BIAS_DEPTH),
      .MAX_BIAS_BANK_DEPTH(`MAX_FILTER_GROUP_NUM),
      .MAX_BIAS_BANK_NUM  (`MAX_GROUP_FILTER)
  ) inst_bias_req_gen (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .i_st        (sched_bl_st),
      .o_dn        (bl_sched_dn),
      //
      .i_que_full  (bq_brg_que_full),
      .i_bank_depth(cfg_brg_bank_depth),
      .i_bank_num  (sched_out_ch),        // TEST
      //
      .i_req_len   (cfg_brg_req_len),
      .i_req_addr  (ag_brg_addr),
      .o_req       (brg_brc_req),
      .o_req_len   (brg_brc_req_len),
      .o_req_addr  (brg_brc_req_addr),
      //
      .o_desc_vld  (brg_bdf_vld),
      .o_desc_dout (brg_bdf_dat)
  );
  queue #(
      // len + addr
      .WIDTH(`CLOG2_SAFE(`MAX_BIAS_DEPTH) + 1 + `CLOG2_SAFE(`MAX_BIAS_DEPTH)),
      .DEPTH(2)  // test
  ) inst_bl_queue (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // 
      .i_push    (brg_brc_req),
      .i_pop     (brc_bq_que_pop),
      .o_full    (bq_brg_que_full),
      .o_empty   (bq_brc_que_empty),
      //
      .i_ipt_din ({brg_brc_req_len, brg_brc_req_addr}),
      // 
      .o_opt_dout(bq_brc_que_dat)
  );
  read_controller #(
      .WIDTH       (`IPT_BIT),
      .DEPTH       (`MAX_BIAS_DEPTH),
      .REQ_LEN_BIT (`CLOG2_SAFE(`MAX_BIAS_DEPTH) + 1),
      .REQ_ADDR_BIT(`CLOG2_SAFE(`MAX_BIAS_DEPTH))
  ) inst_bias_rd_ctrl (
      .i_clk      (i_clk),
      .i_rstn     (i_rstn),
      // WL 
      .i_que_empty(bq_brc_que_empty),
      .i_que_din  (bq_brc_que_dat),
      .o_que_pop  (brc_bq_que_pop),
      // DDR
      .o_re       (brc_storage_re),
      .o_raddr    (brc_storage_raddr),
      .i_rvld     (storage_brc_vld),
      .i_rdin     (storage_brc_dat),
      // opt
      .i_opt_rdy  (bf_brc_rdy),
      .o_opt_vld  (brc_bf_vld),
      .o_opt_dout (brc_bf_dat)
  );
  fifo_buffer #(
      .WIDTH   (`IPT_BIT),
      .DEPTH   (`MAX_BIAS_DEPTH),
      .MEM_TYPE(`BRAM_TYPE)
  ) inst_bias_fifo (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // RC
      .o_ipt_rdy (bf_brc_rdy),
      .i_ipt_vld (brc_bf_vld),
      .i_ipt_din (brc_bf_dat),
      // TL
      .i_opt_rdy (bw_bf_rdy),
      .o_opt_vld (bf_bw_vld),
      .o_opt_dout(bf_bw_dat)
  );
  fifo_buffer #(
      .WIDTH   (BIAS_DESC_BIT),
      .DEPTH   (10), // TEST
      .MEM_TYPE(`LUT_TYPE)
  ) inst_bias_desc_fifo (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // RC
      .o_ipt_rdy (),
      .i_ipt_vld (brg_bdf_vld),
      .i_ipt_din (brg_bdf_dat),
      // TL
      .i_opt_rdy (bw_bdf_rdy),
      .o_opt_vld (bdf_bw_vld),
      .o_opt_dout(bdf_bw_dat)
  );
  bias_buf_writer #(
      .MAX_BIAS_BANK_DEPTH(`MAX_FILTER_GROUP_NUM),
      .MAX_BIAS_BANK_NUM  (`MAX_GROUP_FILTER)
  ) inst_bias_buf_writer (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .o_dn        (bw_dn),
      //
      .o_desc_rdy  (bw_bdf_rdy),
      .i_desc_vld  (bdf_bw_vld),
      .i_desc_din  (bdf_bw_dat),
      //
      .o_ipt_rdy   (bw_bf_rdy),
      .i_ipt_vld   (bf_bw_vld),
      .i_ipt_din   (bf_bw_dat),
      //
      .i_buf_wr_rdy(bb_wr_rdy),       // TEST
      .o_bank_idx  (bw_bb_bank_idx),
      .o_we        (bw_bb_we),
      .o_waddr     (bw_bb_waddr),
      .o_wdat      (bw_bb_wrat)
  );

  double_bank_mem #(
      .WIDTH   (`IPT_BIT),
      .DEPTH   (`MAX_FILTER_GROUP_NUM),
      .MEM_TYPE(`REG_TYPE),
      .BANK_NUM(`MAX_GROUP_FILTER)
  ) inst_bias_buffer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      //
      .i_wr_dn   (bw_dn),
      .i_rd_dn   (br_sched_dn),
      .o_wr_rdy  (bb_wr_rdy),
      .o_rd_rdy  (bb_rd_rdy),
      //
      .i_re      (br_bb_re),
      .i_raddr   (br_bb_raddr),
      .o_rvld    (bb_br_vld),
      .o_rdout   (bb_br_dat),
      // 
      .i_bank_idx(bw_bb_bank_idx),
      .i_we      (bw_bb_we),
      .i_waddr   (bw_bb_waddr),
      .i_wdin    (bw_bb_wrat)


  );
  bias_reader #(
      .WIDTH    (`IPT_BIT * `MAX_GROUP_FILTER),
      .BUF_DEPTH(`MAX_FILTER_GROUP_NUM)
  ) inst_bias_reader (
      .i_clk      (i_clk),
      .i_rstn     (i_rstn),
      .i_clr      (),
      .i_st       (sched_br_st),
      .o_dn       (br_sched_dn),
      .i_br_rd_rdy(bb_rd_rdy),
      .i_bs_wr_rdy(pp_br_bs_wr_rdy),
      // 
      .i_read_len (cfg_br_read_len),
      .i_read_addr(ag_br_addr),
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
  weight_req_gen #(
      .WBUF_DEPTH        (`MAX_WGT_DEPTH),
      .MAX_WGT_BANK_DEPTH(MAX_WGT_BANK_DEPTH),
      .MAX_WGT_BANK_NUM  (MAX_WGT_BANK_NUM)
  ) inst_weight_req_gen (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .i_st        (sched_wrg_st),
      .o_dn        (wrg_sched_dn),
      //
      .i_que_full  (wq_wrg_que_full),
      .i_bank_depth(cfg_wrg_bank_depth),
      .i_bank_num  (sched_out_ch),
      //
      .i_req_len   (cfg_wrg_req_len),
      .i_req_addr  (ag_wrg_addr),
      //
      .o_req_len   (wrg_wrc_req_len),
      .o_req       (wrg_wrc_req),
      .o_req_addr  (wrg_wrc_req_addr),
      .o_desc_vld  (wrg_wdf_desc_vld),
      .o_desc_dout (wrg_wdf_desc_dat)

  );
  queue #(
      // len + addr
      .WIDTH(`CLOG2_SAFE(`MAX_WGT_DEPTH) + 1 + `CLOG2_SAFE(`MAX_WGT_DEPTH)),
      .DEPTH(2)
  ) inst_wl_queue (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // 
      .i_push    (wrg_wrc_req),
      .i_pop     (wrc_wq_que_pop),
      .o_full    (wq_wrg_que_full),
      .o_empty   (wq_wrc_que_empty),
      //
      .i_ipt_din ({wrg_wrc_req_len, wrg_wrc_req_addr}),
      // 
      .o_opt_dout(wq_wrc_que_dat)
  );
  read_controller #(
      .WIDTH       (`WGT_BIT),
      .DEPTH       (`MAX_WGT_DEPTH),
      .REQ_LEN_BIT (`CLOG2_SAFE(`MAX_WGT_DEPTH) + 1),
      .REQ_ADDR_BIT(`CLOG2_SAFE(`MAX_WGT_DEPTH))
  ) inst_wgt_rd_ctrl (
      .i_clk      (i_clk),
      .i_rstn     (i_rstn),
      // WL 
      .i_que_empty(wq_wrc_que_empty),
      .i_que_din  (wq_wrc_que_dat),
      .o_que_pop  (wrc_wq_que_pop),
      // DDR
      .o_re       (wrc_storage_re),
      .o_raddr    (wrc_storage_raddr),
      .i_rvld     (storage_wrc_vld),
      .i_rdin     (storage_wrc_dat),
      // opt
      .i_opt_rdy  (wf_wrc_rdy),
      .o_opt_vld  (wrc_wf_vld),
      .o_opt_dout (wrc_wf_dat)
  );
  fifo_buffer #(
      .WIDTH   (`WGT_BIT),
      .DEPTH   (`MAX_WGT_DEPTH),
      .MEM_TYPE(`BRAM_TYPE)
  ) inst_wgt_fifo (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // RC
      .o_ipt_rdy (wf_wrc_rdy),
      .i_ipt_vld (wrc_wf_vld),
      .i_ipt_din (wrc_wf_dat),
      // TL
      .i_opt_rdy (ww_wf_rdy),
      .o_opt_vld (wf_ww_vld),
      .o_opt_dout(wf_ww_dat)
  );
  fifo_buffer #(
      .WIDTH   (WGT_DESC_BIT),
      .DEPTH   (10), // test
      .MEM_TYPE(`BRAM_TYPE)
  ) inst_wgt_desc_fifo (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // RC
      .o_ipt_rdy (),
      .i_ipt_vld (wrg_wdf_desc_vld),
      .i_ipt_din (wrg_wdf_desc_dat),
      // TL
      .i_opt_rdy (ww_wdf_rdy),
      .o_opt_vld (wdf_ww_vld),
      .o_opt_dout(wdf_ww_dat)
  );

  weight_buf_writer #(
      .MAX_WGT_BANK_DEPTH(MAX_WGT_BANK_DEPTH),
      .MAX_WGT_BANK_NUM  (MAX_WGT_BANK_NUM)
  ) inst_weight_buf_writer (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .o_dn        (ww_dn),
      //
      .o_desc_rdy  (ww_wdf_rdy),
      .i_desc_vld  (wdf_ww_vld),
      .i_desc_din  (wdf_ww_dat),
      //
      .o_ipt_rdy   (ww_wf_rdy),
      .i_ipt_vld   (wf_ww_vld),
      .i_ipt_din   (wf_ww_dat),
      //
      .i_buf_wr_rdy(wb_ww_wr_rdy),
      .o_bank_idx  (ww_wb_bank_idx),
      .o_we        (ww_wb_we),
      .o_waddr     (ww_wb_waddr),
      .o_wdat      (ww_wb_wdat)
  );
  double_bank_mem #(
      .WIDTH   (`WGT_BIT),
      .DEPTH   (MAX_WGT_BANK_DEPTH),
      .MEM_TYPE(`BRAM_TYPE),
      .BANK_NUM(`MAX_GROUP_FILTER)
  ) inst_weight_buffer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      //
      .i_wr_dn   (ww_dn),
      .i_rd_dn   (sched_wb_rd_swap),
      .o_wr_rdy  (wb_ww_wr_rdy),
      .o_rd_rdy  (wb_wr_rd_rdy),
      .i_bank_idx(ww_wb_bank_idx),
      //
      .i_re      (wr_wb_re),
      .i_raddr   (wr_wb_raddr),
      .o_rvld    (wb_wr_rvld),
      .o_rdout   (wb_wr_rdat),
      .i_we      (ww_wb_we),
      .i_waddr   (ww_wb_waddr),
      .i_wdin    (ww_wb_wdat)
  );
  weight_reader #(
      .WIDTH    (`WGT_BIT * `MAX_GROUP_FILTER),
      .BUF_DEPTH(MAX_WGT_BANK_DEPTH)
  ) inst_wgt_reader (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .i_clr       (),
      .i_st        (sched_wr_st),
      .o_dn        (wr_sched_dn),
      .i_ws_wr_rdy (ws_wr_rdy),
      // 
      .i_read_len  (cfg_wr_read_len),
      .i_read_addr (ag_wr_addr),
      ///
      .i_buf_rd_rdy(wb_wr_rd_rdy),
      .o_re        (wr_wb_re),
      .o_raddr     (wr_wb_raddr),
      //
      .o_ipt_rdy   (),
      .i_ipt_vld   (wb_wr_rvld),
      .i_ipt_din   (wb_wr_rdat),
      //
      .i_opt_rdy   ('b1),              // TODO
      .o_opt_vld   (wr_lyr_vld),
      .o_opt_dout  (wr_lyr_dat)

  );
  //      _____ _ _      
  //     |_   _(_) | ___ 
  //       | | | | |/ _ \
  //       | | | | |  __/
  //       |_| |_|_|\___|
  //         
  tile_req_gen #(
      .TILE_SIDE (`MAX_TILE_SIDE),
      .FBUF_DEPTH(FBUF_DEPTH),
      .HALO      (1)
  ) inst_tile_req_gen (
      .i_clk        (i_clk),
      .i_rstn       (i_rstn),
      .i_st         (sched_trg_st),
      .o_dn         (trg_sched_dn),
      .i_que_full   (tq_trg_que_full),
      //
      .i_img_side   (cfg_img_side),
      .i_tl_org_x   (sched_trg_tl_org_x),
      .i_tl_org_y   (sched_trg_tl_org_y),
      .i_tl_req_addr(ag_trg_req_addr),
      //
      .o_req_len    (trg_trc_req_len),
      .o_req        (trg_trc_req),
      .o_req_addr   (trg_trc_req_addr),
      //
      .o_desc_rdy   (trg_trg_desc_rdy),
      .o_desc_vld   (trg_tdf_desc_vld),
      .o_desc_dout  (trg_tdf_desc_dout)    // {side,x,y}
  );
  queue #(
      // len + addr
      .WIDTH(`CLOG2_SAFE(FBUF_DEPTH) + 1 + `CLOG2_SAFE(`DDR_DEPTH)),
      .DEPTH(`MAX_TILE_SIDE + 2)
  ) inst_tl_queue (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // 
      .i_push    (trg_trc_req),
      .i_pop     (trc_tq_que_pop),
      .o_full    (tq_trg_que_full),
      .o_empty   (tq_trc_que_empty),
      //
      .i_ipt_din ({trg_trc_req_len, trg_trc_req_addr}),
      // 
      .o_opt_dout(tq_trc_que_dat)
  );
  read_controller #(
      .WIDTH       (`IPT_BIT * `MAX_GROUP_CHANNEL),
      .DEPTH       (FBUF_DEPTH),
      .REQ_LEN_BIT (`CLOG2_SAFE(FBUF_DEPTH) + 1),
      .REQ_ADDR_BIT(`CLOG2_SAFE(`DDR_DEPTH))
  ) inst_img_rd_ctrl (
      .i_clk      (i_clk),
      .i_rstn     (i_rstn),
      // TL
      .i_que_empty(tq_trc_que_empty),
      .i_que_din  (tq_trc_que_dat),
      .o_que_pop  (trc_tq_que_pop),
      // DDR
      .o_re       (trc_fbuf_re),
      .o_raddr    (trc_fbuf_raddr),
      .i_rvld     (fbuf_trc_vld),
      .i_rdin     (fbuf_trc_dat),
      // opt
      .i_opt_rdy  (tpf_trc_rdy),
      .o_opt_vld  (trc_tf_vld),
      .o_opt_dout (trc_tf_dat)
  );
  fifo_buffer #(
      .WIDTH   (`IPT_BIT * `MAX_GROUP_CHANNEL),
      .DEPTH   (3*(`MAX_PAD_TILE_AREA)), // TEST
      .MEM_TYPE(`BRAM_TYPE)
  ) inst_pixel_fifo (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // RC
      .o_ipt_rdy (tpf_trc_rdy),
      .i_ipt_vld (trc_tf_vld),
      .i_ipt_din (trc_tf_dat),
      // TL
      .i_opt_rdy (tw_tpf_rdy),
      .o_opt_vld (tpf_tw_vld),
      .o_opt_dout(tpf_tw_dat)
  );
  fifo_buffer #(
      .WIDTH   (3 * (`CLOG2_SAFE(`MAX_IPT_SIDE) + 1)),
      .DEPTH   (10),                                    // TEST
      .MEM_TYPE(`REG_TYPE)
  ) inst_desc_fifo (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // RC
      .o_ipt_rdy (trg_trg_desc_rdy),
      .i_ipt_vld (trg_tdf_desc_vld),
      .i_ipt_din (trg_tdf_desc_dout),
      // TL
      .i_opt_rdy (tw_tdf_rdy),
      .o_opt_vld (tdf_tw_vld),
      .o_opt_dout(tdf_tw_dat)
  );
  tile_buf_writer #(
      .TILE_SIDE(`MAX_TILE_SIDE),
      .HALO     (1)
  ) inst_tile_buf_writer (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .i_st        (),
      .o_dn        (tw_tb_wr_dn),
      //
      .o_desc_rdy  (tw_tdf_rdy),
      .i_desc_vld  (tdf_tw_vld),
      .i_desc_din  (tdf_tw_dat),
      //
      .o_ipt_rdy   (tw_tpf_rdy),
      .i_ipt_vld   (tpf_tw_vld),
      .i_ipt_din   (tpf_tw_dat),
      //
      .i_buf_wr_rdy(tb_tw_wr_rdy),
      .o_we        (tw_tb_we),
      .o_waddr     (tw_tb_waddr),
      .o_wdat      (tw_tb_wdat)
  );
  double_buffer #(
      .WIDTH   (`IPT_BIT * `MAX_GROUP_CHANNEL),
      .DEPTH   (`MAX_PAD_TILE_AREA),
      .MEM_TYPE(`BRAM_TYPE)
  ) inst_tile_buffer (
      .i_clk   (i_clk),
      .i_rstn  (i_rstn),
      //
      .i_wr_dn (tw_tb_wr_dn),
      .i_rd_dn (tr_dn),
      .o_wr_rdy(tb_tw_wr_rdy),
      .o_rd_rdy(tb_tr_rd_rdy),
      //        
      .i_re    (tr_tb_re),
      .i_raddr (tr_tb_raddr),
      .o_rvld  (tb_tr_vld),
      .o_rdout (tb_tr_dat),
      //
      .i_we    (tw_tb_we),
      .i_waddr (tw_tb_waddr),
      .i_wdin  (tw_tb_wdat)
  );
  tile_reader #(
      .WIDTH    (`IPT_BIT * `MAX_GROUP_CHANNEL),
      .BUF_DEPTH(`MAX_PAD_TILE_AREA)
  ) inst_tile_reader (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .i_clr       (),
      // 
      .i_read_len  (cfg_tr_read_len),
      .i_read_addr (ag_tr_addr),
      .i_st        (sched_tr_st),
      .o_dn        (tr_dn),
      ///
      .i_buf_rd_rdy(tb_tr_rd_rdy),
      .o_re        (tr_tb_re),
      .o_raddr     (tr_tb_raddr),
      //
      .o_ipt_rdy   (),
      .i_ipt_vld   (tb_tr_vld),
      .i_ipt_din   (tb_tr_dat),
      //
      .i_opt_rdy   (),                 // TODO
      .o_opt_vld   (tr_lyr_vld),
      .o_opt_dout  (tr_lyr_dat)
  );
  //      _____     _____    ____                      _       _   _                    _                          
  //     |___ /_  _|___ /   / ___|___  _ ____   _____ | |_   _| |_(_) ___  _ __   | |    __ _ _   _  ___ _ __ 
  //       |_ \ \/ / |_ \  | |   / _ \| '_ \ \ / / _ \| | | | | __| |/ _ \| '_ \  | |   / _` | | | |/ _ \ '__|
  //      ___) >  < ___) | | |__| (_) | | | \ V / (_) | | |_| | |_| | (_) | | | | | |__| (_| | |_| |  __/ |   
  //     |____/_/\_\____/   \____\___/|_| |_|\_/ \___/|_|\__,_|\__|_|\___/|_| |_| |_____\__,_|\__, |\___|_|   
  //                                                                                          |___/           
  conv_layer inst_conv_layer (
      .i_clk          (i_clk),
      .i_rstn         (i_rstn),
      .i_clr          (sched_lyr_clr),
      .o_dn           (clyr_sched_dn),
      // wgt 
      .i_wr_dn        (wr_sched_dn),
      .i_wgt_vld      (wr_lyr_vld),
      .i_wgt_din      (wr_lyr_dat),
      .o_ws_wr_rdy    (ws_wr_rdy),
      .o_ws_rd_rdy    (ws_rd_rdy),
      // ipt 
      .o_ipt_rdy      (),
      .i_ipt_vld      (tr_lyr_vld),
      .i_ipt_din      (tr_lyr_dat),
      // opt  
      .i_opt_rdy      (sched_lyr_rdy),
      .o_opt_vld      (clyr_psc_vld),
      .o_opt_dout     (clyr_psc_dat),
      // temp
      .i_kernel_stride(cfg_kernel_stride),
      .i_opt_area     (cfg_tile_opt_area),
      .i_in_ch        (sched_lyr_in_ch),
      .i_ch_mask      (sched_lyr_ch_mask),
      .i_filt_mask    (sched_lyr_filt_mask)
  );
  //      ____            _   _       _   ____                  
  //     |  _ \ __ _ _ __| |_(_) __ _| | / ___| _   _ _ __ ___  
  //     | |_) / _` | '__| __| |/ _` | | \___ \| | | | '_ ` _ \ 
  //     |  __/ (_| | |  | |_| | (_| | |  ___) | |_| | | | | | |
  //     |_|   \__,_|_|   \__|_|\__,_|_| |____/ \__,_|_| |_| |_|
  //                                                            
  partialsum_controller inst_partialsum_controller (
      .i_clk          (i_clk),
      .i_rstn         (i_rstn),
      .i_st           (sched_psc_st),
      .o_dn           (psc_sched_dn),
      //
      .i_sum_cnt      (cfg_ch_grp_num),
      .i_tile_opt_area(cfg_tile_opt_area),
      //
      .i_bias_vld     (br_pp_vld),
      .i_bias_din     (br_pp_dat),
      //
      .i_psb_rdy      (psb_psc_rdy),
      .o_psb_re       (psc_psb_re),
      .o_psb_raddr    (psc_psb_raddr),
      .i_psb_rvld     (psb_psc_vld),
      .i_psb_rdin     (psb_psc_dat),
      .o_psb_we       (psc_psb_we),
      .o_psb_waddr    (psc_psb_waddr),
      .o_psb_wdout    (psc_psb_wdat),
      .o_psc_rdy      (psc_psb_rdy),
      //
      .i_ipt_din      (clyr_psc_dat),
      .i_ipt_vld      (clyr_psc_vld),
      .o_ipt_rdy      (),
      //
      .i_opt_rdy      ('b1),
      .o_opt_vld      (psc_pp_vld),
      .o_opt_dout     (psc_pp_dat)
  );
  post_proccessor inst_post_proccessor (
      .i_clk      (i_clk),
      .i_rstn     (i_rstn),
      .o_bs_wr_rdy(pp_br_bs_wr_rdy),
      .o_bs_rd_rdy(pp_bs_rd_rdy),
      .i_br_dn    (br_sched_dn),
      .i_ts_dn    (sched_pp_bias_swap),
      //
      .i_relu     (cfg_relu),
      .i_bias_vld (br_pp_vld),
      .i_bias_din (br_pp_dat),
      //
      .i_ipt_vld  (psc_pp_vld),
      .i_ipt_din  (psc_pp_dat),
      //
      .o_opt_vld  (pp_ts_vld),
      .o_opt_dout (pp_ts_dat)
  );
  pool_layer inst_pool_layer (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .i_clr       (sched_lyr_clr),
      .i_maxpool_en('b0),            // TODO   
      //
      .o_ipt_rdy   (),
      .i_ipt_vld   (pp_ts_vld),
      .i_ipt_din   (pp_ts_dat),
      //
      .i_opt_rdy   ('b1),
      .o_opt_vld   (pool_ts_vld),
      .o_opt_dout  (pool_ts_dat)
  );
  tile_scatter inst_tile_scatter (
      .i_clk          (i_clk),
      .i_rstn         (i_rstn),
      .i_st           (sched_ts_st),
      .o_dn           (ts_sched_dn),
      //
      .i_img_side     (cfg_opt_side),
      .i_tile_opt_side(cfg_tile_opt_side),
      .i_tile_opt_area(cfg_tile_opt_area),
      .i_base_addr    (ag_ts_addr),
      //
      .i_vld          (pool_ts_vld),
      .i_din          (pool_ts_dat),
      //
      .o_obuf_we      (ts_fbuf_we),
      .o_obuf_wdout   (ts_fbuf_wdat),
      .o_obuf_waddr   (ts_fbuf_waddr)
  );
endmodule

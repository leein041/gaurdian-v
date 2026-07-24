

`include "defines.vh"
`include "network_config.vh"
module global_ctrl #(
    localparam MAX_BIAS_ADDR  = `CLOG2_SAFE(`MAX_BIAS_DEPTH),
    localparam MAX_WGT_ADDR   = `CLOG2_SAFE(`MAX_WGT_DEPTH),
    localparam MAX_IPT_ADDR   = `CLOG2_SAFE(`MAX_IPT_AREA),
    localparam MAX_TILE_ADDR  = `CLOG2_SAFE(`MAX_TILE_AREA), 
    localparam MAX_DDR_ADDR   = `CLOG2_SAFE(`MAX_FILTER_GROUP_NUM * `MAX_IPT_AREA),
    localparam WGT_BANK_DEPTH = `MAX_CHANNEL * `CONV_3X3_AREA
) (
    input                                                      i_clk,
    input                                                      i_rstn,
    input                                                      i_st,
    output                                                     o_ctrl_rdy,
    output                                                     o_done,
    // famp buffer
    output                                                     o_fbuf_switch,
    // bias loader
    output                                                     o_bl_st,
    output                                                     o_bl_bank_depth,
    output [                 `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] o_bl_req_len,
    output [                 `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] o_bl_req_addr,
    input                                                      i_bl_dn,
    // bias reader
    output                                                     o_br_st,
    output [               `CLOG2_SAFE(`MAX_GROUP_FILTER) : 0] o_br_read_len,
    output [               `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] o_br_read_addr,
    input                                                      i_br_dn,
    // weight loader
    output                                                     o_wl_st,
    output [     `CLOG2_SAFE(`MAX_CHANNEL*`CONV_3X3_AREA) : 0] o_wl_bank_depth,
    output [                  `CLOG2_SAFE(`MAX_WGT_DEPTH) : 0] o_wl_req_len,
    output [                  `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] o_wl_req_addr,
    input                                                      i_wl_dn,
    // weight reader
    output                                                     o_wr_st,
    output [                  `CLOG2_SAFE(WGT_BANK_DEPTH) : 0] o_wr_read_len,
    output [                  `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] o_wr_read_addr,
    input                                                      i_wr_dn,
    // tile loader 
    output                                                     o_tl_st,
    output [                   `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] o_img_org_x,      // origin position
    output [                   `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] o_img_org_y,
    output [                   `CLOG2_SAFE(`MAX_IPT_AREA)-1:0] o_img_base_addr,
    input                                                      i_tl_dn,
    // tile reader
    output                                                     o_tr_st,
    output [              `CLOG2_SAFE(`MAX_PAD_TILE_AREA) : 0] o_tr_read_len,
    output [              `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] o_tr_read_addr,
    input                                                      i_tr_dn, 
    // skid
    input                                                      i_skid_rdy,
    // layer    
    input                                                      i_lyr_dn,
    input                                                      i_conv_lyr_vld,
    input  [                   `OPT_BIT*`MAX_GROUP_FILTER-1:0] i_conv_lyr_din,
    input                                                      i_pool_lyr_vld,
    input  [                   `OPT_BIT*`MAX_GROUP_FILTER-1:0] i_pool_lyr_din,
    output                                                     o_lyr_clr,
    output [                   `CLOG2_SAFE(`MAX_LAYER_TYPE):0] o_lyr_type,
    output                                                     o_lyr_relu_en,
    output                                                     o_lyr_pad_en,
    output [                       `CLOG2_SAFE( `LAYER_NUM):0] o_lyr_idx,
    output [                    `CLOG2_SAFE(`MAX_TILE_AREA):0] o_lyr_opt_area,
    // PSC
    output                                                     o_psc_st,
    output [`CLOG2_SAFE( `MAX_CHANNEL / `MAX_GROUP_CHANNEL):0] o_psc_sum_cnt,
    input                                                      i_psc_dn,
    input                                                      i_psc_vld,
    input  [                  `OPT_BIT* `MAX_GROUP_FILTER-1:0] i_psc_din,
    // DDR
    output                                                     o_ddr_we,
    output [                  `OPT_BIT* `MAX_GROUP_FILTER-1:0] o_ddr_wdout,
    output [                                 MAX_DDR_ADDR-1:0] o_ddr_waddr,
    // tile
    output [                `CLOG2_SAFE(`MAX_PAD_TILE_SIDE):0] o_pad_tile_side,
    output [                    `CLOG2_SAFE(`MAX_TILE_AREA):0] o_tile_ipt_area,
    output [                     `CLOG2_SAFE(`MAX_IPT_SIDE):0] o_img_side,
    output [                 `CLOG2_SAFE(`MAX_GROUP_FILTER):0] o_ch_num,
    output [                       `CLOG2_SAFE(`MAX_FILTER):0] o_pu_num,
    output [                           `MAX_GROUP_CHANNEL-1:0] o_ch_mask,
    output [                            `MAX_GROUP_FILTER-1:0] o_pu_mask
);
  // ====================== parmeter ======================= 
  localparam IDLE = 1;
  // bias
  localparam LOAD_BIAS = 2;
  localparam WAIT_LOAD_BIAS = 3;
  localparam READ_BIAS = 8;
  localparam WAIT_READ_BIAS = 9;

  // weight
  localparam LOAD_WGT = 4;
  localparam WAIT_LOAD_WGT = 5;
  localparam READ_WGT = 10;
  localparam WAIT_READ_WGT = 11;

  // tile
  localparam LOAD_TILE = 6;
  localparam WAIT_LOAD_TILE = 7;
  localparam START = 12;
  localparam RUN = 13;

  //store
  localparam WAIT_PSC = 14;
  localparam STORE = 15;

  localparam NEXT_FILTER_GRP = 16;
  localparam NEXT_TILE = 17;
  localparam NEXT_CHANNEL_GRP = 18;

  localparam STATE_END = 19;


  integer                                                     i;
  // ====================== wire =========================== 
  wire                                                        w_lyr_vld;
  wire    [                   `OPT_BIT*`MAX_GROUP_FILTER-1:0] w_lyr_dat;
  // ====================== reg ============================ 
  reg     [                       `CLOG2_SAFE(STATE_END)-1:0] r_cstat;  // current state
  reg     [                       `CLOG2_SAFE(STATE_END)-1:0] r_nstat;  // next state   
  reg                                                         r_load_wgt;
  reg                                                         r_load_tile;
  reg                                                         r_load_bias;
  // ctrl
  reg                                                         r_ctrl_rdy;
  // fmap buffer
  reg                                                         r_fbuf_switch;
  // bias loader (BL)
  reg     [                                  MAX_BIAS_ADDR:0] r_bias_depth;
  reg     [                                  MAX_BIAS_ADDR:0] r_bl_req_len;
  reg                                                         r_bl_st;
  reg                                                         r_bl_bank_depth;
  reg     [                                MAX_BIAS_ADDR-1:0] r_bl_base_addr;
  reg     [                                MAX_BIAS_ADDR-1:0] r_bl_req_addr;
  // bias reader (BR)
  reg                                                         r_br_st;
  reg     [               `CLOG2_SAFE(`MAX_GROUP_FILTER) : 0] r_br_read_len;
  reg     [               `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] r_br_base_addr;
  reg     [               `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] r_br_read_addr;
  // weight loader (WL)
  reg     [                                   MAX_WGT_ADDR:0] r_wgt_depth;
  reg     [                                   MAX_WGT_ADDR:0] r_wl_req_len;
  reg                                                         r_wl_st;
  reg     [   `CLOG2_SAFE(`MAX_WGT_DEPTH*`CONV_3X3_AREA) : 0] r_wl_bank_depth;
  reg     [     `CLOG2_SAFE(`MAX_CHANNEL*`CONV_3X3_AREA) : 0] r_wl_addr_stride;
  reg     [                                 MAX_WGT_ADDR-1:0] r_wl_base_addr;
  reg     [                                 MAX_WGT_ADDR-1:0] r_wl_req_addr;
  // weight reader (WR)
  reg                                                         r_wr_st;
  reg     [                  `CLOG2_SAFE(WGT_BANK_DEPTH) : 0] r_wr_read_len;
  reg     [                  `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] r_wr_base_addr;
  reg     [                  `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] r_wr_read_addr;
  // tile loader (TL)
  reg     [                   `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] r_img_org_x;
  reg     [                   `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] r_img_org_y;
  reg     [                   `CLOG2_SAFE(`MAX_IPT_AREA)-1:0] r_tl_base_addr;
  reg     [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_tl_row_base_addr;
  reg     [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_tl_row_stride;
  reg     [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_tl_ch_base_addr;
  reg     [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_tr_col_stride;
  reg     [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_tl_ch_stride;
  reg     [                   `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] r_nxt_org_x;
  reg     [                   `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] r_nxt_org_y;
  reg                                                         r_tl_st;
  // tile reader (TR)
  reg                                                         r_tr_st;
  reg     [              `CLOG2_SAFE(`MAX_PAD_TILE_AREA) : 0] r_tr_read_len;
  reg     [              `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] r_tr_read_addr;
  // ipt  
  reg                                                         r_ibuf_vld;
  reg     [                                       `IPT_BIT:0] r_ibuf_rdat;
  reg     [                     `CLOG2_SAFE(`MAX_IPT_SIDE):0] r_img_side;
  reg     [                     `CLOG2_SAFE(`MAX_IPT_AREA):0] r_ipt_area; 
  // opt  
  reg     [                     `CLOG2_SAFE(`MAX_OPT_SIDE):0] r_opt_side;
  reg     [                     `CLOG2_SAFE(`MAX_OPT_AREA):0] r_opt_area;
  reg                                                         r_o_done;
  // layer
  reg     [                   `CLOG2_SAFE(`MAX_LAYER_TYPE):0] r_lyr_type;
  reg     [                        `CLOG2_SAFE(`LAYER_NUM):0] r_lyr_idx;
  reg                                                         r_lyr_clr;
  reg                                                         r_pad;
  reg                                                         r_relu;
  //  channel
  reg     [                      `CLOG2_SAFE(`MAX_CHANNEL):0] r_ch;
  reg     [                `CLOG2_SAFE(`MAX_GROUP_CHANNEL):0] r_grp_ch;
  reg     [ `CLOG2_SAFE(`MAX_CHANNEL / `MAX_GROUP_CHANNEL):0] r_ch_grp_num;
  reg     [                      `CLOG2_SAFE(`MAX_CHANNEL):0] r_ch_idx;
  reg     [ `CLOG2_SAFE(`MAX_CHANNEL / `MAX_GROUP_CHANNEL):0] r_ch_grp_idx;
  reg     [                      `CLOG2_SAFE(`MAX_CHANNEL):0] r_ch_left;
  reg     [                           `MAX_GROUP_CHANNEL-1:0] r_ch_mask;
  // filter
  reg     [                       `CLOG2_SAFE(`MAX_FILTER):0] r_filt;
  reg     [     `CLOG2_SAFE(`MAX_FILTER/`MAX_GROUP_FILTER):0] r_filt_grp_num;
  reg     [                 `CLOG2_SAFE(`MAX_GROUP_FILTER):0] r_filt_idx;
  reg     [     `CLOG2_SAFE(`MAX_FILTER/`MAX_GROUP_FILTER):0] r_filt_grp_idx;
  reg     [                       `CLOG2_SAFE(`MAX_FILTER):0] r_filt_left;
  reg     [                            `MAX_GROUP_FILTER-1:0] r_filt_mask;
  // tile
  reg     [    `CLOG2_SAFE(`MAX_IPT_AREA / `MAX_TILE_AREA):0] r_tile_num;
  reg     [    `CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] r_tile_num_x;
  reg     [    `CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] r_tile_num_y;
  reg     [    `CLOG2_SAFE(`MAX_IPT_AREA / `MAX_TILE_AREA):0] r_tile_idx;
  reg     [    `CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] r_tile_x_cnt;
  reg     [    `CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] r_tile_y_cnt;
  reg     [                    `CLOG2_SAFE(`MAX_TILE_SIDE):0] r_tile_side;
  reg     [                    `CLOG2_SAFE(`MAX_TILE_AREA):0] r_tile_ipt_area;
  reg     [                    `CLOG2_SAFE(`MAX_TILE_SIDE):0] r_tile_opt_side;
  reg     [                    `CLOG2_SAFE(`MAX_TILE_AREA):0] r_tile_opt_area;
  // partial sum controller (PSC)
  reg                                                         r_psc_st;
  reg     [`CLOG2_SAFE( `MAX_CHANNEL / `MAX_GROUP_CHANNEL):0] r_psc_sum_cnt;
  // DDR
  reg                                                         r_ddr_we;
  reg     [                  `OPT_BIT* `MAX_GROUP_FILTER-1:0] r_ddr_wdat;
  reg     [                    `CLOG2_SAFE(`MAX_TILE_AREA):0] r_ddr_pix_col;
  reg     [                                 MAX_DDR_ADDR : 0] r_ddr_pix_row;
  reg     [                                 MAX_DDR_ADDR : 0] r_ddr_tile_addr_stride;
  reg     [                                 MAX_DDR_ADDR : 0] r_ddr_org_y;
  reg     [                                 MAX_DDR_ADDR : 0] r_ddr_org_x;
  reg     [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_ddr_row_stride;
  reg     [                                 MAX_DDR_ADDR : 0] r_ddr_filt_addr_stride;
  reg     [                                 MAX_DDR_ADDR : 0] r_ddr_ch_base_addr;
  reg     [                                 MAX_DDR_ADDR : 0] r_ddr_ch_stride;
  reg     [                                 MAX_DDR_ADDR-1:0] r_ddr_waddr;
  // ====================== assign ========================= 
  assign o_ctrl_rdy      = r_ctrl_rdy;
  assign o_lyr_idx       = r_lyr_idx;
  assign o_lyr_clr       = r_lyr_clr;
  assign o_lyr_type      = r_lyr_type;
  assign o_lyr_relu_en   = r_relu;
  assign o_lyr_pad_en    = r_pad;
  assign o_pad_tile_side = r_tile_side + 2;
  assign o_tile_ipt_area = r_tile_ipt_area;
  assign o_img_side      = r_img_side;
  assign o_fbuf_switch   = r_fbuf_switch;
  assign o_bl_st         = r_bl_st;
  assign o_bl_bank_depth = r_bl_bank_depth;
  assign o_bl_req_len    = r_bl_req_len;
  assign o_bl_req_addr   = r_bl_req_addr;
  assign o_br_st         = r_br_st;
  assign o_br_read_len   = r_br_read_len;
  assign o_br_read_addr  = r_br_read_addr;
  assign o_wl_st         = r_wl_st;
  assign o_wl_bank_depth = r_wl_bank_depth;
  assign o_wl_req_len    = r_wl_req_len;
  assign o_wl_req_addr   = r_wl_req_addr;
  assign o_wr_st         = r_wr_st;
  assign o_wr_read_len   = r_wr_read_len;
  assign o_wr_read_addr  = r_wr_read_addr;
  assign o_tl_st         = r_tl_st;
  assign o_tr_st         = r_tr_st;
  assign o_tr_read_len   = r_tr_read_len;
  assign o_tr_read_addr  = r_tr_read_addr;
  assign o_img_org_x     = r_img_org_x;
  assign o_img_org_y     = r_img_org_y;
  assign o_img_base_addr = r_tl_base_addr; 
  assign o_done          = r_o_done;
  assign o_ch_num        = r_ch;
  assign o_pu_num        = r_filt;
  assign o_ch_mask       = r_ch_mask;
  assign o_pu_mask       = r_filt_mask;
  assign o_lyr_opt_area  = r_tile_opt_area;
  assign o_psc_st        = r_psc_st;
  assign o_psc_sum_cnt   = r_psc_sum_cnt;

  assign w_lyr_vld       = (r_lyr_type == `LAYER_TYPE_CONV) ? i_conv_lyr_vld : i_pool_lyr_vld;
  assign w_lyr_dat       = (r_lyr_type == `LAYER_TYPE_CONV) ? i_conv_lyr_din : i_pool_lyr_din;

  assign o_ddr_we        = r_ddr_we;
  assign o_ddr_wdout     = r_ddr_wdat;
  assign o_ddr_waddr     = r_ddr_waddr;
  // ====================== FSM ============================ 
  //  initialize and update state register    
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_cstat <= IDLE;
    end else begin
      r_cstat <= r_nstat;
    end
  end
  //

  always @(*) begin
    case (r_lyr_idx)
      1: begin
        r_lyr_type = `L1_TYPE;
        r_ch = `L1_CHANNEL;
        r_grp_ch = (`L1_CHANNEL < `MAX_GROUP_CHANNEL) ? `L1_CHANNEL : `MAX_GROUP_CHANNEL;
        r_ch_grp_num = (`L1_CHANNEL + `MAX_GROUP_CHANNEL - 1) / `MAX_GROUP_CHANNEL;
        r_filt = `L1_FILTER;
        r_filt_grp_num = (`L1_FILTER + `MAX_GROUP_FILTER - 1) / `MAX_GROUP_FILTER;
        r_relu = `L1_RELU;
        r_pad = `L1_PAD;
        r_img_side = `L1_IPT_SIDE;
        r_ipt_area = `L1_IPT_AREA;
        r_tile_side = `MAX_TILE_SIDE;
        r_tile_ipt_area = `MAX_TILE_AREA;
        r_tile_opt_side = `L1_TILE_OPT_SIDE;
        r_tile_opt_area = `L1_TILE_OPT_AREA;
        r_tile_num = `L1_IPT_AREA / `MAX_TILE_AREA;
        r_tile_num_x = `L1_IPT_SIDE / `MAX_TILE_SIDE;
        r_tile_num_y = `L1_IPT_SIDE / `MAX_TILE_SIDE;
        r_opt_side = `L1_OPT_SIDE;
        r_opt_area = `L1_OPT_SIDE * `L1_OPT_SIDE;
        r_wgt_depth = `L1_WGT_DEPTH;
        r_bias_depth = `L1_BIAS_DEPTH;
        r_bl_req_len = `L1_BIAS_DEPTH / `L1_FILTER_GROUP_NUM;
        r_bl_bank_depth = 'b1;
        r_br_read_len = 'd1;  // TODO
        r_wl_req_len = `L1_WGT_DEPTH / `L1_FILTER_GROUP_NUM;
        r_wl_bank_depth = `L1_CHANNEL * `CONV_3X3_AREA;
        r_wl_addr_stride = `MAX_GROUP_FILTER * `L1_CHANNEL * `CONV_3X3_AREA;
        r_wr_read_len = r_grp_ch * `CONV_3X3_AREA;
        r_tr_read_len = `MAX_PAD_TILE_AREA;
        r_tl_row_stride = `L1_IPT_SIDE * `MAX_TILE_SIDE;
        r_tr_col_stride = `MAX_TILE_SIDE;
        r_tl_ch_stride = `L1_IPT_AREA;
        r_psc_sum_cnt = r_ch_grp_num;
        r_ddr_tile_addr_stride = `L1_FILTER_GROUP_NUM * `MAX_TILE_AREA;
        r_ddr_filt_addr_stride = `MAX_TILE_AREA;
        r_ddr_row_stride = `L1_OPT_SIDE * `MAX_TILE_SIDE;
        r_ddr_ch_stride = `L1_OPT_AREA;
      end
      // Layer 2
      2: begin
        r_lyr_type      = `L2_TYPE;
        r_ch            = `L2_CHANNEL;
        r_ch_grp_num    = `L2_CHANNEL / `MAX_GROUP_CHANNEL;
        r_filt          = `L2_FILTER;
        r_filt_grp_num  = `L2_FILTER / `MAX_GROUP_FILTER;
        r_relu          = `L2_RELU;
        r_pad           = `L2_PAD;
        r_img_side      = `L2_IPT_SIDE;
        r_ipt_area      = `L2_IPT_AREA;
        r_tile_side     = `MAX_TILE_SIDE;
        r_tile_ipt_area = `MAX_TILE_AREA;
        r_tile_opt_side = `L2_TILE_OPT_SIDE;
        r_tile_opt_area = `L2_TILE_OPT_AREA;
        r_tile_num      = `L2_IPT_AREA / `MAX_TILE_AREA;
        r_opt_side      = `L2_OPT_SIDE;
        r_opt_area      = `L2_OPT_SIDE * `L2_OPT_SIDE;
        r_wgt_depth     = `L2_WGT_DEPTH;
        r_bias_depth    = `L2_BIAS_DEPTH;
        r_bl_req_len    = `L2_BIAS_DEPTH / `L2_FILTER_GROUP_NUM;
        r_bl_bank_depth = 'b1;
        r_br_read_len   = `L2_BIAS_DEPTH / `L2_FILTER_GROUP_NUM;
        r_wl_req_len    = `L2_WGT_DEPTH / `L2_FILTER_GROUP_NUM;
        r_wl_bank_depth = `L2_CHANNEL * `CONV_3X3_AREA;
        r_wr_read_len   = `MAX_GROUP_CHANNEL * `CONV_3X3_AREA;
        r_tr_read_len   = `MAX_PAD_TILE_AREA;
        r_tl_row_stride = `L2_IPT_SIDE * `MAX_TILE_SIDE;
      end
      3: begin
        r_lyr_type      = `L3_TYPE;
        r_ch            = `L3_CHANNEL;
        r_ch_grp_num    = `L3_CHANNEL / `MAX_GROUP_CHANNEL;
        r_filt          = `L3_FILTER;
        r_filt_grp_num  = `L3_FILTER / `MAX_GROUP_FILTER;
        r_relu          = `L3_RELU;
        r_pad           = `L3_PAD;
        r_img_side      = `L3_IPT_SIDE;
        r_ipt_area      = `L3_IPT_AREA;
        r_tile_side     = `MAX_TILE_SIDE;
        r_tile_ipt_area = `MAX_TILE_AREA;
        r_tile_opt_side = `L3_TILE_OPT_SIDE;
        r_tile_opt_area = `L3_TILE_OPT_AREA;
        r_tile_num      = `L3_IPT_AREA / `MAX_TILE_AREA;
        r_opt_side      = `L3_OPT_SIDE;
        r_opt_area      = `L3_OPT_SIDE * `L3_OPT_SIDE;
        r_wgt_depth     = `L3_WGT_DEPTH;
        r_bias_depth    = `L3_BIAS_DEPTH;
        r_bl_req_len    = `L3_BIAS_DEPTH / `L3_FILTER_GROUP_NUM;
        r_bl_bank_depth = 'b1;
        r_br_read_len   = `L3_BIAS_DEPTH / `L3_FILTER_GROUP_NUM;
        r_wl_req_len    = `L3_WGT_DEPTH / `L3_FILTER_GROUP_NUM;
        r_wl_bank_depth = `L3_CHANNEL * `CONV_3X3_AREA;
        r_wr_read_len   = `MAX_GROUP_CHANNEL * `CONV_3X3_AREA;
        r_tr_read_len   = `MAX_PAD_TILE_AREA;
        r_tl_row_stride = `L3_IPT_SIDE * `MAX_TILE_SIDE;
      end
      default: ;
    endcase
    r_ch_left   = r_ch - r_ch_idx;
    r_filt_left = r_filt - r_filt_idx;
    for (i = 0; i < `MAX_GROUP_CHANNEL; i = i + 1) r_ch_mask[i] = (i < r_ch_left);
    for (i = 0; i < `MAX_GROUP_FILTER; i = i + 1) r_filt_mask[i] = (i < r_filt_left);
  end
  // compute next state 
  always @(*) begin
    r_nstat = r_cstat;
    case (r_cstat)

      IDLE: begin
        if (i_st) r_nstat = LOAD_BIAS;
      end

      LOAD_BIAS: begin
        r_nstat = WAIT_LOAD_BIAS;
      end

      WAIT_LOAD_BIAS: begin
        if (i_bl_dn) r_nstat = READ_BIAS;
      end

      READ_BIAS: begin
        r_nstat = WAIT_READ_BIAS;
      end

      WAIT_READ_BIAS: begin
        if (i_br_dn) r_nstat = LOAD_WGT;
      end

      LOAD_WGT: begin
        r_nstat = WAIT_LOAD_WGT;
      end

      WAIT_LOAD_WGT: begin
        if (i_wl_dn) r_nstat = READ_WGT;
      end

      READ_WGT: begin
        r_nstat = WAIT_READ_WGT;
      end

      WAIT_READ_WGT: begin
        if (i_wr_dn) r_nstat = LOAD_TILE;
      end

      LOAD_TILE: begin
        r_nstat = WAIT_LOAD_TILE;
      end

      WAIT_LOAD_TILE: begin
        if (i_tl_dn) r_nstat = START;
      end

      START: begin
        r_nstat = RUN;
      end

      RUN: begin

        if (
        (r_ch_grp_idx == r_ch_grp_num - 1 && i_psc_dn) ||
        (r_ch_grp_idx != r_ch_grp_num - 1 && i_lyr_dn)
    ) begin

          if (r_ch_grp_idx != r_ch_grp_num - 1) r_nstat = NEXT_CHANNEL_GRP;
          else if (r_tile_idx != r_tile_num - 1) r_nstat = NEXT_TILE;
          else if (r_filt_grp_idx != r_filt_grp_num - 1) r_nstat = NEXT_FILTER_GRP;
          else r_nstat = IDLE;

        end
      end

      WAIT_PSC: begin
        if (i_psc_dn) begin
        end
      end

      NEXT_FILTER_GRP: begin
        r_nstat = LOAD_BIAS;
      end

      NEXT_TILE: begin
        r_nstat = NEXT_CHANNEL_GRP;
      end

      NEXT_CHANNEL_GRP: begin
        r_nstat = READ_WGT;
      end

      default: ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_fbuf_switch      <= 'b0;
      r_load_wgt         <= 'b0;
      r_load_tile        <= 'b0;
      r_load_bias        <= 'b0;
      r_ctrl_rdy         <= 'b0;
      r_lyr_clr          <= 'b0;
      r_lyr_idx          <= 'd0;
      r_bl_st            <= 'b0;
      r_bl_base_addr     <= 'd0;
      r_bl_req_addr      <= 'd0;
      r_br_base_addr     <= 'd0;
      r_br_st            <= 'b0;
      r_br_read_addr     <= 'd0;
      r_wl_st            <= 'b0;
      r_wl_base_addr     <= 'd0;
      r_wl_req_addr      <= 'd0;
      r_wr_st            <= 'b0;
      r_wr_base_addr     <= 'd0;
      r_wr_read_addr     <= 'd0;
      r_tl_base_addr     <= 'd0;
      r_tl_st            <= 'b0;
      r_tr_st            <= 'b0;
      r_tr_read_addr     <= 'd0;
      r_psc_st           <= 'b0; 
      r_o_done           <= 'd0;
      // local ctrl  
      r_filt_grp_idx     <= 'd0;
      r_filt_idx         <= 'd0;
      r_ch_grp_idx       <= 'd0;
      r_ch_idx           <= 'd0;
      r_tile_idx         <= 'd0;
      r_tile_x_cnt       <= 'd0;
      r_tile_y_cnt       <= 'd0;
      //
      r_img_org_x        <= 'd0;
      r_img_org_y        <= 'd0;
      r_tl_row_base_addr <= 'd0;
      r_tl_ch_base_addr  <= 'd0;
      r_nxt_org_x        <= 'd0;
      r_nxt_org_y        <= 'd0;
      //
      r_ddr_we           <= 'd0;
      r_ddr_wdat         <= 'd0;
      r_ddr_pix_col      <= 'd0;
      r_ddr_pix_row      <= 'd0;
      r_ddr_org_y        <= 'd0;
      r_ddr_org_x        <= 'd0;
      r_ddr_ch_base_addr <= 'd0;
      r_ddr_waddr        <= 'd0;
    end else begin
      r_ctrl_rdy <= 'b1;  // 일단 항상 받기    
      r_lyr_clr  <= 'b0;
      case (r_cstat)
        IDLE: begin
          if (i_st) begin
            r_lyr_idx     <= r_lyr_idx + 'd1;
            r_fbuf_switch <= 'b1;
          end
        end

        LOAD_BIAS: begin
          r_fbuf_switch <= 'b0;
          r_bl_st       <= 'b1;
          r_bl_req_addr <= r_bl_base_addr;
        end

        WAIT_LOAD_BIAS: begin
          r_bl_st <= 'b0;
        end

        READ_BIAS: begin
          r_br_st        <= 'b1;
          r_br_read_addr <= r_br_base_addr;
        end

        WAIT_READ_BIAS: begin
          r_br_st <= 'b0;
        end

        LOAD_WGT: begin
          r_wl_st       <= 'b1;
          r_wl_req_addr <= r_wl_base_addr;
        end

        WAIT_LOAD_WGT: begin
          r_wl_st <= 'b0;
        end

        READ_WGT: begin
          r_wr_st        <= 'b1;
          r_wr_read_addr <= r_wr_base_addr;
        end

        WAIT_READ_WGT: begin
          r_wr_st <= 'b0;
        end

        LOAD_TILE: begin
          r_psc_st       <= 'b1;
          r_tl_st        <= 'b1;
          r_tl_base_addr <= r_tl_row_base_addr + r_tl_ch_base_addr;
          r_img_org_x    <= r_nxt_org_x;
          r_img_org_y    <= r_nxt_org_y;
        end

        WAIT_LOAD_TILE: begin
          r_psc_st <= 'b0;
          r_tl_st  <= 'b0;
        end

        START: begin
          r_tr_st        <= 'b1;
          r_tr_read_addr <= 'd0;
        end

        RUN: begin
          r_tr_st <= 'b0;
          if (i_psc_vld) begin
            r_ddr_we   <= 'b1;
            r_ddr_wdat <= i_psc_din;
            if (r_ddr_pix_col < `MAX_TILE_SIDE - 1) begin
              r_ddr_pix_col <= r_ddr_pix_col + 'd1;
            end else begin
              r_ddr_pix_row <= r_ddr_pix_row + r_img_side;
              r_ddr_pix_col <= 'd0;
            end
            r_ddr_waddr <= r_ddr_pix_col + r_ddr_pix_row + r_ddr_org_x + r_ddr_org_y + r_ddr_ch_base_addr;
          end else begin
            r_ddr_we <= 'b0;
          end
        end

        NEXT_FILTER_GRP: begin
          // init
          r_nxt_org_x        <= 'd0;
          r_nxt_org_y        <= 'd0;
          r_tile_x_cnt       <= 'd0;
          r_tile_y_cnt       <= 'd0;
          r_tl_row_base_addr <= 'd0;
          r_tile_idx         <= 'd0;
          r_ddr_org_x        <= 'd0;
          r_ddr_pix_row      <= 'd0;
          r_ddr_org_y        <= 'd0;
          //
          r_lyr_clr          <= 'b1;
          r_ddr_ch_base_addr <= r_ddr_ch_base_addr + r_ddr_ch_stride;
          if (r_filt_grp_idx < r_filt_grp_num - 1) begin
            r_bl_base_addr <= r_bl_base_addr + `MAX_GROUP_FILTER;
            r_wl_base_addr <= r_wl_base_addr + r_wl_addr_stride;
            r_filt_grp_idx <= r_filt_grp_idx + 'd1;
            r_filt_idx     <= r_filt_idx + `MAX_GROUP_FILTER;
          end else begin
            r_bl_base_addr <= 'd0;
            r_filt_grp_idx <= 'd0;
            r_filt_idx     <= 'd0;
          end
        end

        NEXT_TILE: begin
          // init
          r_ch_grp_idx      <= 'd0;
          r_ch_idx          <= 'd0;
          r_wr_base_addr    <= 'd0;
          r_tl_ch_base_addr <= 'd0;
          //
          r_lyr_clr         <= 'b1;
          r_tile_idx        <= r_tile_idx + 'd1;
          // update tile origin
          if (r_tile_x_cnt < r_tile_num_x - 1) begin
            r_tile_x_cnt <= r_tile_x_cnt + 'd1;
            r_nxt_org_x  <= r_nxt_org_x + r_tile_side;
            r_ddr_org_x  <= r_ddr_org_x + r_tile_side;
          end else begin
            r_tile_x_cnt <= 'd0;
            r_nxt_org_x  <= 0;
            r_ddr_org_x  <= 0;
            if (r_tile_y_cnt < r_tile_num_y - 1) begin
              r_tile_y_cnt       <= r_tile_y_cnt + 'd1;
              r_nxt_org_y        <= r_nxt_org_y + r_tile_side;
              r_ddr_org_y        <= r_ddr_org_y + r_ddr_row_stride;
              r_tl_row_base_addr <= r_tl_row_base_addr + r_tl_row_stride;
            end else begin
              r_tile_y_cnt       <= 'd0;
              r_nxt_org_y        <= 'd0;
              r_ddr_org_y        <= 'd0;
              r_tl_row_base_addr <= 'd0;
            end
          end
        end

        NEXT_CHANNEL_GRP: begin
          r_lyr_clr     <= 'b1;
          r_ddr_pix_row <= 'd0;
          if (r_ch_grp_idx < r_ch_grp_num - 1) begin
            r_ch_grp_idx      <= r_ch_grp_idx + 'd1;
            r_ch_idx          <= r_ch_idx + `MAX_GROUP_CHANNEL;
            r_wr_base_addr    <= r_wr_base_addr + `MAX_GROUP_CHANNEL * `CONV_3X3_AREA;
            r_tl_ch_base_addr <= r_tl_ch_base_addr + r_tl_ch_stride;
          end
        end

        default: ;
      endcase
    end
  end

  // ====================== module ========================= 
endmodule

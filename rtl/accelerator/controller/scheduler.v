

`include "defines.vh"
`include "network_config.vh"
module scheduler #(
    localparam FBUF_DEPTH = `MAX_FILTER_GROUP_NUM * `MAX_IPT_AREA,
    localparam WGT_BANK_DEPTH = `MAX_CHANNEL * `CONV_3X3_AREA
) (
    input                                                      i_clk,
    input                                                      i_rstn,
    input                                                      i_st,
    output                                                     o_ctrl_rdy,
    output                                                     o_dn,
    // 
    output [                     `CLOG2_SAFE( `LAYER_NUM)-1:0] o_lyr_idx,
    input  [                 `CLOG2_SAFE(`MAX_LAYER_TYPE)-1:0] i_lyr_type,
    input                                                      i_pad,
    input  [                       `CLOG2_SAFE(`MAX_FILTER):0] i_filt,
    input  [             `CLOG2_SAFE(`MAX_FILTER_GROUP_NUM):0] i_filt_grp_num,
    input  [                     `CLOG2_SAFE(`MAX_TILE_NUM):0] i_tile_num,
    input  [    `CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] i_tile_num_x,
    input  [    `CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] i_tile_num_y,
    input  [                      `CLOG2_SAFE(`MAX_CHANNEL):0] i_ch,
    input  [            `CLOG2_SAFE(`MAX_CHANNEL_GROUP_NUM):0] i_ch_grp_num,
    input  [                     `CLOG2_SAFE(`MAX_IPT_SIDE):0] i_img_side,
    input  [                     `CLOG2_SAFE(`MAX_IPT_AREA):0] i_img_area,
    input  [                     `CLOG2_SAFE(`MAX_OPT_SIDE):0] i_opt_side,
    input  [                     `CLOG2_SAFE(`MAX_OPT_AREA):0] i_opt_area,
    input  [                    `CLOG2_SAFE(`MAX_TILE_SIDE):0] i_tile_side,
    input  [                    `CLOG2_SAFE(`MAX_TILE_AREA):0] i_lyr_opt_area,
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
    output [                      `CLOG2_SAFE(FBUF_DEPTH)-1:0] o_img_base_addr,
    input                                                      i_tl_dn,
    // tile reader
    output                                                     o_tr_st,
    output [              `CLOG2_SAFE(`MAX_PAD_TILE_AREA) : 0] o_tr_read_len,
    output [              `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] o_tr_read_addr,
    input                                                      i_tr_dn,
    // layer    
    input                                                      i_lyr_dn,
    input                                                      i_conv_lyr_vld,
    input  [                   `OPT_BIT*`MAX_GROUP_FILTER-1:0] i_conv_lyr_din,
    input                                                      i_pool_lyr_vld,
    input  [                   `OPT_BIT*`MAX_GROUP_FILTER-1:0] i_pool_lyr_din,
    output                                                     o_lyr_clr,
    output                                                     o_lyr_pad_en,
    output [                    `CLOG2_SAFE(`MAX_TILE_AREA):0] o_lyr_opt_num,
    // PSC
    output                                                     o_psc_st,
    output [`CLOG2_SAFE( `MAX_CHANNEL / `MAX_GROUP_CHANNEL):0] o_psc_sum_cnt,
    input                                                      i_psc_dn,
    input                                                      i_psc_vld,
    input  [                  `OPT_BIT* `MAX_GROUP_FILTER-1:0] i_psc_din,
    // DDR
    output                                                     o_obuf_we,
    output [                  `OPT_BIT* `MAX_GROUP_FILTER-1:0] o_obuf_wdout,
    output [                      `CLOG2_SAFE(FBUF_DEPTH)-1:0] o_obuf_waddr,
    // tile  
    output [                 `CLOG2_SAFE(`MAX_GROUP_FILTER):0] o_in_ch,
    output [                       `CLOG2_SAFE(`MAX_FILTER):0] o_out_ch,
    output [                           `MAX_GROUP_CHANNEL-1:0] o_ch_mask,
    output [                            `MAX_GROUP_FILTER-1:0] o_pu_mask
);
  // ====================== parmeter ======================= 
  localparam IDLE = 1;
  // bias
  localparam LOAD_BIAS = 2;
  localparam WAIT_LOAD_BIAS = 3;
  localparam READ_BIAS = 4;
  localparam WAIT_READ_BIAS = 5;

  // weight
  localparam LOAD_WGT = 6;
  localparam WAIT_LOAD_WGT = 7;
  localparam READ_WGT = 8;
  localparam WAIT_READ_WGT = 9;

  // tile
  localparam LOAD_TILE = 10;
  localparam WAIT_LOAD_TILE = 11;
  localparam START = 12;
  localparam RUN = 13;

  localparam NEXT_FILTER_GRP = 14;
  localparam NEXT_TILE = 15;
  localparam NEXT_CHANNEL_GRP = 16;
  localparam NEXT_LAYER = 17;

  localparam DONE = 18;

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
  reg                                                         r_dn;
  // fmap buffer
  reg                                                         r_fbuf_switch;
  // bias loader (BL)
  reg     [                   `CLOG2_SAFE(`MAX_BIAS_DEPTH):0] r_bias_depth;
  reg     [                   `CLOG2_SAFE(`MAX_BIAS_DEPTH):0] r_bl_req_len;
  reg                                                         r_bl_st;
  reg                                                         r_bl_bank_depth;
  reg     [                 `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] r_bl_base_addr;
  reg     [                 `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] r_bl_req_addr;
  // bias reader (BR)
  reg                                                         r_br_st;
  reg     [               `CLOG2_SAFE(`MAX_GROUP_FILTER) : 0] r_br_read_len;
  reg     [               `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] r_br_base_addr;
  reg     [               `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] r_br_read_addr;
  // weight loader (WL)
  reg     [                    `CLOG2_SAFE(`MAX_WGT_DEPTH):0] r_wgt_depth;
  reg     [                    `CLOG2_SAFE(`MAX_WGT_DEPTH):0] r_wl_req_len;
  reg                                                         r_wl_st;
  reg     [   `CLOG2_SAFE(`MAX_WGT_DEPTH*`CONV_3X3_AREA) : 0] r_wl_bank_depth;
  reg     [     `CLOG2_SAFE(`MAX_CHANNEL*`CONV_3X3_AREA) : 0] r_wl_addr_stride;
  reg     [                  `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] r_wl_base_addr;
  reg     [                  `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] r_wl_req_addr;
  // weight reader (WR)
  reg                                                         r_wr_st;
  reg     [                  `CLOG2_SAFE(WGT_BANK_DEPTH) : 0] r_wr_read_len;
  reg     [                  `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] r_wr_base_addr;
  reg     [                  `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] r_wr_read_addr;
  // tile loader (TL)
  reg     [                   `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] r_img_org_x;
  reg     [                   `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] r_img_org_y;
  reg     [                      `CLOG2_SAFE(FBUF_DEPTH)-1:0] r_tl_base_addr;
  reg     [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_tl_col_base_addr;
  reg     [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_tl_row_base_addr;
  reg     [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_tl_row_stride;
  reg     [                      `CLOG2_SAFE(FBUF_DEPTH) : 0] r_tl_ch_base_addr;
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
  // layer 
  reg     [                      `CLOG2_SAFE(`LAYER_NUM)-1:0] r_lyr_idx;
  reg                                                         r_lyr_clr; 
  //  channel 
  reg     [                `CLOG2_SAFE(`MAX_GROUP_CHANNEL):0] r_grp_ch;
  reg     [                      `CLOG2_SAFE(`MAX_CHANNEL):0] r_ch_idx;
  reg     [ `CLOG2_SAFE(`MAX_CHANNEL / `MAX_GROUP_CHANNEL):0] r_ch_grp_idx;
  reg     [                      `CLOG2_SAFE(`MAX_CHANNEL):0] r_ch_left;
  reg     [                `CLOG2_SAFE(`MAX_GROUP_CHANNEL):0] r_in_ch;
  reg     [                           `MAX_GROUP_CHANNEL-1:0] r_ch_mask;
  // filter  
  reg     [                 `CLOG2_SAFE(`MAX_GROUP_FILTER):0] r_filt_idx;
  reg     [     `CLOG2_SAFE(`MAX_FILTER/`MAX_GROUP_FILTER):0] r_filt_grp_idx;
  reg     [                       `CLOG2_SAFE(`MAX_FILTER):0] r_filt_left;
  reg     [                            `MAX_GROUP_FILTER-1:0] r_filt_mask;
  // tile   
  reg     [    `CLOG2_SAFE(`MAX_IPT_AREA / `MAX_TILE_AREA):0] r_tile_idx;
  reg     [    `CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] r_tile_x_cnt;
  reg     [    `CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] r_tile_y_cnt; 
  // partial sum controller (PSC)
  reg                                                         r_psc_st;
  reg     [`CLOG2_SAFE( `MAX_CHANNEL / `MAX_GROUP_CHANNEL):0] r_psc_sum_cnt;
  // DDR
  reg                                                         r_obuf_we;
  reg     [                  `OPT_BIT* `MAX_GROUP_FILTER-1:0] r_obuf_wdat;
  reg     [                    `CLOG2_SAFE(`MAX_TILE_AREA):0] r_obuf_pix_col;
  reg     [                      `CLOG2_SAFE(FBUF_DEPTH) : 0] r_obuf_pix_row;
  reg     [                      `CLOG2_SAFE(FBUF_DEPTH) : 0] r_obuf_tile_row;
  reg     [                      `CLOG2_SAFE(FBUF_DEPTH) : 0] r_obuf_tile_col;
  reg     [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_obuf_tile_row_stride;
  reg     [                      `CLOG2_SAFE(FBUF_DEPTH) : 0] r_obuf_ch_base_addr;
  reg     [                      `CLOG2_SAFE(FBUF_DEPTH) : 0] r_obuf_ch_stride;
  reg     [                      `CLOG2_SAFE(FBUF_DEPTH)-1:0] r_obuf_waddr;
  // ====================== assign ========================= 
  assign o_dn            = r_dn;
  assign o_ctrl_rdy      = r_ctrl_rdy;
  assign o_lyr_idx       = r_lyr_idx;
  assign o_lyr_clr       = r_lyr_clr;
  assign o_lyr_pad_en    = i_pad; 
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
  assign o_in_ch         = r_in_ch;
  assign o_ch_mask       = r_ch_mask;
  assign o_pu_mask       = r_filt_mask;
  assign o_lyr_opt_num   = i_lyr_opt_area;
  assign o_psc_st        = r_psc_st;
  assign o_psc_sum_cnt   = r_psc_sum_cnt;

  assign w_lyr_vld       = (i_lyr_type == `LAYER_TYPE_CONV) ? i_conv_lyr_vld : i_pool_lyr_vld;
  assign w_lyr_dat       = (i_lyr_type == `LAYER_TYPE_CONV) ? i_conv_lyr_din : i_pool_lyr_din;

  assign o_obuf_we       = r_obuf_we;
  assign o_obuf_wdout    = r_obuf_wdat;
  assign o_obuf_waddr    = r_obuf_waddr;
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
      0: begin    
        r_bl_req_len           = `L0_BL_REQ_LEN;
        r_br_read_len          = `L0_BR_READ_LEN;  // TODO
        r_wl_req_len           = `L0_WL_REQ_LEN;
        r_wr_read_len          = `L0_WR_READ_LEN;
        r_tr_read_len          = `L0_TR_READ_LEN;
        r_wgt_depth            = `L0_WGT_DEPTH;
        r_bias_depth           = `L0_BIAS_DEPTH;
        r_bl_bank_depth        = `L0_BL_BANK_DEPTH;
        r_wl_bank_depth        = `L0_WL_BANK_DEPTH;
        r_wl_addr_stride       = `L0_WL_ADDR_STRIDE;
        r_tl_row_stride        = `L0_TL_ROW_STRIDE;
        r_tl_ch_stride         = `L0_TL_CH_STRIDE;
        r_obuf_tile_row_stride = `L0_OBUF_TILE_ROW_STRIDE;
        r_obuf_ch_stride       = `L0_OBUF_TILE_CH_STRIDE;
        r_psc_sum_cnt          = `L0_PSC_SUM_NUM;
      end
      // Layer 2
      1: begin 
        r_wgt_depth            = `L1_WGT_DEPTH;
        r_bias_depth           = `L1_BIAS_DEPTH;
        r_bl_req_len           = `L1_BL_REQ_LEN;
        r_bl_bank_depth        = `L1_BL_BANK_DEPTH;
        r_br_read_len          = `L1_BR_READ_LEN;  // TODO
        r_wl_req_len           = `L1_WL_REQ_LEN;
        r_wl_bank_depth        = `L1_WL_BANK_DEPTH;
        r_wr_read_len          = `L1_WR_READ_LEN;
        r_tr_read_len          = `L1_TR_READ_LEN;
        r_wl_addr_stride       = `L1_WL_ADDR_STRIDE;
        r_tl_row_stride        = `L1_TL_ROW_STRIDE;
        r_tl_ch_stride         = `L1_TL_CH_STRIDE;
        r_psc_sum_cnt          = `L1_PSC_SUM_NUM;
        r_obuf_tile_row_stride = `L1_OBUF_TILE_ROW_STRIDE;
        r_obuf_ch_stride       = `L1_OBUF_TILE_CH_STRIDE;
      end
      2: begin    
        r_wgt_depth            = `L2_WGT_DEPTH;
        r_bias_depth           = `L2_BIAS_DEPTH;
        r_bl_req_len           = `L2_BL_REQ_LEN;
        r_bl_bank_depth        = `L2_BL_BANK_DEPTH;
        r_br_read_len          = `L2_BR_READ_LEN;  // TODO
        r_wl_req_len           = `L2_WL_REQ_LEN;
        r_wl_bank_depth        = `L2_WL_BANK_DEPTH;
        r_wr_read_len          = `L2_WR_READ_LEN;
        r_tr_read_len          = `L2_TR_READ_LEN;
        r_wl_addr_stride       = `L2_WL_ADDR_STRIDE;
        r_tl_row_stride        = `L2_TL_ROW_STRIDE;
        r_tl_ch_stride         = `L2_TL_CH_STRIDE;
        r_psc_sum_cnt          = `L2_PSC_SUM_NUM;
        r_obuf_tile_row_stride = `L2_OBUF_TILE_ROW_STRIDE;
        r_obuf_ch_stride       = `L2_OBUF_TILE_CH_STRIDE;
      end
      default: ;
    endcase
    r_ch_left   = i_ch - r_ch_idx;
    r_filt_left = i_filt - r_filt_idx;
    for (i = 0; i < `MAX_GROUP_CHANNEL; i = i + 1) r_ch_mask[i] = (i < r_ch_left);
    for (i = 0; i < `MAX_GROUP_FILTER; i = i + 1) r_filt_mask[i] = (i < r_filt_left);
    if (r_ch_left > `MAX_GROUP_CHANNEL) r_in_ch = `MAX_GROUP_CHANNEL;
    else r_in_ch = r_ch_left;
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
        (r_ch_grp_idx == i_ch_grp_num - 1 && i_psc_dn) ||
        (r_ch_grp_idx != i_ch_grp_num - 1 && i_lyr_dn)
    ) begin

          if (r_ch_grp_idx != i_ch_grp_num - 1) r_nstat = NEXT_CHANNEL_GRP;
          else if (r_tile_idx != i_tile_num - 1) r_nstat = NEXT_TILE;
          else if (r_filt_grp_idx != i_filt_grp_num - 1) r_nstat = NEXT_FILTER_GRP;
          else r_nstat = NEXT_LAYER;

        end
      end

      NEXT_FILTER_GRP: begin
        r_nstat = LOAD_BIAS;
      end

      NEXT_TILE: begin
        r_nstat = READ_WGT;
      end

      NEXT_CHANNEL_GRP: begin
        r_nstat = READ_WGT;
      end

      NEXT_LAYER: begin
        if (r_lyr_idx != `LAYER_NUM - 1) begin
          r_nstat = LOAD_BIAS;
        end else begin
          r_nstat = DONE;
        end
      end

      DONE: begin
        r_nstat = IDLE;
      end

      default: ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_dn                <= 'd0;
      r_fbuf_switch       <= 'b0;
      r_load_wgt          <= 'b0;
      r_load_tile         <= 'b0;
      r_load_bias         <= 'b0;
      r_ctrl_rdy          <= 'b0;
      r_lyr_clr           <= 'b0;
      r_lyr_idx           <= 'd0;
      r_bl_st             <= 'b0;
      r_bl_base_addr      <= 'd0;
      r_bl_req_addr       <= 'd0;
      r_br_base_addr      <= 'd0;
      r_br_st             <= 'b0;
      r_br_read_addr      <= 'd0;
      r_wl_st             <= 'b0;
      r_wl_base_addr      <= 'd0;
      r_wl_req_addr       <= 'd0;
      r_wr_st             <= 'b0;
      r_wr_base_addr      <= 'd0;
      r_wr_read_addr      <= 'd0;
      r_tl_base_addr      <= 'd0;
      r_tl_st             <= 'b0;
      r_tr_st             <= 'b0;
      r_tr_read_addr      <= 'd0;
      r_psc_st            <= 'b0;
      // local ctrl  
      r_filt_grp_idx      <= 'd0;
      r_filt_idx          <= 'd0;
      r_ch_grp_idx        <= 'd0;
      r_ch_idx            <= 'd0;
      r_tile_idx          <= 'd0;
      r_tile_x_cnt        <= 'd0;
      r_tile_y_cnt        <= 'd0;
      //
      r_img_org_x         <= 'd0;
      r_img_org_y         <= 'd0;
      r_tl_row_base_addr  <= 'd0;
      r_tl_col_base_addr  <= 'd0;
      r_tl_ch_base_addr   <= 'd0;
      r_nxt_org_x         <= 'd0;
      r_nxt_org_y         <= 'd0;
      //
      r_obuf_we           <= 'd0;
      r_obuf_wdat         <= 'd0;
      r_obuf_pix_col      <= 'd0;
      r_obuf_pix_row      <= 'd0;
      r_obuf_tile_row     <= 'd0;
      r_obuf_tile_col     <= 'd0;
      r_obuf_ch_base_addr <= 'd0;
      r_obuf_waddr        <= 'd0;
    end else begin
      r_ctrl_rdy <= 'b1;  // 일단 항상 받기    
      r_lyr_clr  <= 'b0;
      case (r_cstat)
        IDLE: begin
          r_dn <= 'b0;
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
          r_obuf_pix_row <= 'd0;
        end

        WAIT_READ_WGT: begin
          r_wr_st <= 'b0;
        end

        LOAD_TILE: begin
          r_psc_st       <= 'b1;
          r_tl_st        <= 'b1;
          r_tl_base_addr <= r_tl_col_base_addr + r_tl_row_base_addr + r_tl_ch_base_addr;
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
            r_obuf_we   <= 'b1;
            r_obuf_wdat <= i_psc_din;
            if (r_obuf_pix_col < `MAX_TILE_SIDE - 1) begin
              r_obuf_pix_col <= r_obuf_pix_col + 'd1;
            end else begin
              r_obuf_pix_row <= r_obuf_pix_row + i_img_side;
              r_obuf_pix_col <= 'd0;
            end
            r_obuf_waddr <= r_obuf_pix_col + r_obuf_pix_row + r_obuf_tile_col + r_obuf_tile_row + r_obuf_ch_base_addr;
          end else begin
            r_obuf_we <= 'b0;
          end
        end

        NEXT_FILTER_GRP: begin
          r_lyr_clr           <= 'b1;
          // init ddr
          r_obuf_pix_row      <= 'd0;
          r_obuf_pix_col      <= 'd0;
          r_obuf_tile_col     <= 'd0;
          r_obuf_tile_row     <= 'd0;
          // init tile
          r_nxt_org_x         <= 'd0;
          r_nxt_org_y         <= 'd0;
          r_tile_x_cnt        <= 'd0;
          r_tile_y_cnt        <= 'd0;
          r_tl_row_base_addr  <= 'd0;
          r_tl_col_base_addr  <= 'd0;
          r_tile_idx          <= 'd0;
          // init ch
          r_wr_base_addr      <= 'd0;
          r_tl_ch_base_addr   <= 'd0;
          r_ch_grp_idx        <= 'd0;
          r_ch_idx            <= 'd0;
          // update ddr
          r_obuf_ch_base_addr <= r_obuf_ch_base_addr + r_obuf_ch_stride;
          if (r_filt_grp_idx < i_filt_grp_num - 1) begin
            r_filt_grp_idx <= r_filt_grp_idx + 'd1;
            r_filt_idx     <= r_filt_idx + `MAX_GROUP_FILTER;
            r_bl_base_addr <= r_bl_base_addr + `MAX_GROUP_FILTER;
            r_wl_base_addr <= r_wl_base_addr + r_wl_addr_stride;
          end
        end

        NEXT_TILE: begin
          r_lyr_clr         <= 'b1;
          // ddr
          r_obuf_pix_row    <= 'd0;
          // init ch
          r_ch_grp_idx      <= 'd0;
          r_ch_idx          <= 'd0;
          r_wr_base_addr    <= 'd0;
          r_tl_ch_base_addr <= 'd0;
          // update tile 
          r_tile_idx        <= r_tile_idx + 'd1;

          if (r_tile_x_cnt < i_tile_num_x - 1) begin
            r_tl_col_base_addr <= r_tl_col_base_addr + `MAX_TILE_SIDE;
            r_tile_x_cnt       <= r_tile_x_cnt + 'd1;
            r_nxt_org_x        <= r_nxt_org_x + i_tile_side;
            r_obuf_tile_col    <= r_obuf_tile_col + i_tile_side;
          end else begin
            r_tl_col_base_addr <= 'd0;
            r_tile_x_cnt       <= 'd0;
            r_nxt_org_x        <= 0;
            r_obuf_tile_col    <= 0;
            if (r_tile_y_cnt < i_tile_num_y - 1) begin
              r_tile_y_cnt       <= r_tile_y_cnt + 'd1;
              r_nxt_org_y        <= r_nxt_org_y + i_tile_side;
              r_obuf_tile_row    <= r_obuf_tile_row + r_obuf_tile_row_stride;
              r_tl_row_base_addr <= r_tl_row_base_addr + r_tl_row_stride;
            end
          end
        end

        NEXT_CHANNEL_GRP: begin
          r_lyr_clr <= 'b1;
          if (r_ch_grp_idx < i_ch_grp_num - 1) begin
            r_ch_grp_idx      <= r_ch_grp_idx + 'd1;
            r_ch_idx          <= r_ch_idx + `MAX_GROUP_CHANNEL;
            r_wr_base_addr    <= r_wr_base_addr + `MAX_GROUP_CHANNEL * `CONV_3X3_AREA;
            r_tl_ch_base_addr <= r_tl_ch_base_addr + r_tl_ch_stride;
          end
        end

        NEXT_LAYER: begin
          if (r_lyr_idx != `LAYER_NUM - 1) begin
            r_lyr_idx           <= r_lyr_idx + 'd1;
            r_lyr_clr           <= 'b1;
            r_fbuf_switch       <= 'b1;
            // init filt 
            r_filt_grp_idx      <= 'd0;
            r_filt_idx          <= 'd0;
            r_bl_base_addr      <= 'd0;
            r_wl_base_addr      <= 'd0;
            // init ddr
            r_obuf_ch_base_addr <= 'd0;
            r_obuf_pix_row      <= 'd0;
            r_obuf_pix_col      <= 'd0;
            r_obuf_tile_col     <= 'd0;
            r_obuf_tile_row     <= 'd0;
            // init tile
            r_nxt_org_x         <= 'd0;
            r_nxt_org_y         <= 'd0;
            r_tile_x_cnt        <= 'd0;
            r_tile_y_cnt        <= 'd0;
            r_tl_row_base_addr  <= 'd0;
            r_tl_col_base_addr  <= 'd0;
            r_tile_idx          <= 'd0;
            // init ch
            r_wr_base_addr      <= 'd0;
            r_tl_ch_base_addr   <= 'd0;
            r_ch_grp_idx        <= 'd0;
            r_ch_idx            <= 'd0;
          end
        end

        DONE: begin
          r_dn <= 'b1;
        end

        default: ;
      endcase
    end
  end

  // ====================== module ========================= 
endmodule

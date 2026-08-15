

`include "defines.vh"
`include "network_config.vh"
module layer_config #(
    localparam FBUF_DEPTH = `MAX_FILTER_GROUP_NUM * `MAX_IPT_AREA,
    localparam WGT_BANK_DEPTH = `MAX_CHANNEL * `CONV_3X3_AREA
) (
    input      [                 `CLOG2_SAFE( `LAYER_NUM)-1:0] i_lyr_idx,
    // scheduler
    output reg [             `CLOG2_SAFE(`MAX_LAYER_TYPE)-1:0] o_lyr_type,
    output reg                                                 o_pad,
    output reg                                                 o_relu,
    output reg [                   `CLOG2_SAFE(`MAX_FILTER):0] o_filt,
    output reg [ `CLOG2_SAFE(`MAX_FILTER/`MAX_GROUP_FILTER):0] o_filt_grp_num,
    output reg [                 `CLOG2_SAFE(`MAX_TILE_NUM):0] o_tile_num,
    output reg [`CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] o_tile_num_x,
    output reg [`CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] o_tile_num_y,
    output reg [                  `CLOG2_SAFE(`MAX_CHANNEL):0] o_ch,
    output reg [        `CLOG2_SAFE(`MAX_CHANNEL_GROUP_NUM):0] o_ch_grp_num,
    output reg [                 `CLOG2_SAFE(`MAX_IPT_SIDE):0] o_img_side,
    output reg [                 `CLOG2_SAFE(`MAX_IPT_AREA):0] o_img_area,
    output reg [                 `CLOG2_SAFE(`MAX_OPT_SIDE):0] o_opt_side,
    output reg [                 `CLOG2_SAFE(`MAX_OPT_AREA):0] o_opt_area,
    output reg [                `CLOG2_SAFE(`MAX_TILE_SIDE):0] o_tile_side,
    output reg [                `CLOG2_SAFE(`MAX_TILE_AREA):0] o_lyr_opt_area,
    // loader
    output reg [             `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] o_bl_filt_grp_stride,
    output reg [             `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] o_br_filt_grp_stride,
    output reg [              `CLOG2_SAFE(WGT_BANK_DEPTH) : 0] o_wl_filt_grp_stride,
    output reg [              `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] o_wr_ch_grp_stride,
    output reg [               `CLOG2_SAFE(`MAX_IPT_AREA) : 0] o_tl_row_stride,
    output reg [               `CLOG2_SAFE(`MAX_IPT_AREA) : 0] o_tl_col_stride,
    output reg [               `CLOG2_SAFE(`MAX_IPT_AREA) : 0] o_tl_ch_grp_stride,
    output reg [               `CLOG2_SAFE(`MAX_IPT_AREA) : 0] o_ts_row_stride,
    output reg [               `CLOG2_SAFE(`MAX_IPT_AREA) : 0] o_ts_col_stride,
    output reg [               `CLOG2_SAFE(`MAX_IPT_AREA) : 0] o_ts_ch_grp_stride,
    output reg [               `CLOG2_SAFE(`MAX_BIAS_DEPTH):0] o_bl_req_len,
    output reg [       `CLOG2_SAFE(`MAX_FILTER_GROUP_NUM) : 0] o_br_read_len,
    output reg [                `CLOG2_SAFE(`MAX_WGT_DEPTH):0] o_wl_req_len,
    output reg [              `CLOG2_SAFE(WGT_BANK_DEPTH) : 0] o_wr_read_len,
    output reg [          `CLOG2_SAFE(`MAX_PAD_TILE_AREA) : 0] o_tr_read_len,
    output reg [       `CLOG2_SAFE(`MAX_FILTER_GROUP_NUM) : 0] o_bl_bank_depth,
    output reg [              `CLOG2_SAFE(WGT_BANK_DEPTH) : 0] o_wl_bank_depth
);
  // ====================== parmeter =======================   
  integer                                                     i;
  // ====================== reg ============================      
  reg     [                   `CLOG2_SAFE(`MAX_BIAS_DEPTH):0] r_bias_depth;
  reg     [                    `CLOG2_SAFE(`MAX_WGT_DEPTH):0] r_wgt_depth;
  // partial sum controller (PSC) 
  reg     [`CLOG2_SAFE( `MAX_CHANNEL / `MAX_GROUP_CHANNEL):0] r_psc_sum_cnt;
  // DDR 
  reg     [                   `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_obuf_tile_row_stride;
  reg     [                      `CLOG2_SAFE(FBUF_DEPTH) : 0] r_obuf_ch_stride;
  // ====================== always =========================

  always @(*) begin
    case (i_lyr_idx)
      0: begin
        // scheduler
        o_lyr_type             = `L0_TYPE;
        o_pad                  = `L0_PAD;
        o_relu                 = `L0_RELU;
        o_filt                 = `L0_FILTER;
        o_filt_grp_num         = `L0_FILTER_GROUP_NUM;
        o_tile_num             = `L0_TILE_NUM;
        o_tile_num_x           = `L0_TILE_NUM_X;
        o_tile_num_y           = `L0_TILE_NUM_Y;
        o_ch                   = `L0_CHANNEL;
        o_ch_grp_num           = `L0_CHANNEL_GROUP_NUM;
        o_img_side             = `L0_IPT_SIDE;
        o_img_area             = `L0_IPT_AREA;
        o_opt_side             = `L0_OPT_SIDE;
        o_opt_area             = `L0_OPT_AREA;
        o_tile_side            = `L0_TILE_IPT_SIDE;
        o_lyr_opt_area         = `L0_TILE_OPT_AREA;
        // address generator
        o_bl_filt_grp_stride   = `L0_BL_STRIDE;
        o_br_filt_grp_stride   = `L0_BR_STRIDE;
        o_wl_filt_grp_stride   = `L0_WL_FILT_GRP_STRIDE;
        o_wr_ch_grp_stride     = `L0_WR_CH_GRP_STRIDE;
        o_tl_col_stride        = `L0_TL_COL_STRIDE;
        o_tl_row_stride        = `L0_TL_ROW_STRIDE;
        o_tl_ch_grp_stride     = `L0_TL_CH_GRP_STRIDE;
        o_ts_col_stride        = `L0_TS_COL_STRIDE;
        o_ts_row_stride        = `L0_TS_ROW_STRIDE;
        o_ts_ch_grp_stride     = `L0_TS_CH_GRP_STRIDE;
        o_bl_req_len           = `L0_BL_REQ_LEN;
        o_br_read_len          = `L0_BR_READ_LEN;  // TODO
        o_wl_req_len           = `L0_WL_REQ_LEN;
        o_wr_read_len          = `L0_WR_READ_LEN;
        o_tr_read_len          = `L0_TR_READ_LEN;
        o_bl_bank_depth        = `L0_BL_BANK_DEPTH;
        o_wl_bank_depth        = `L0_WL_BANK_DEPTH;
        // loader
        r_bias_depth           = `L0_BIAS_DEPTH;
        r_wgt_depth            = `L0_WGT_DEPTH;
        // psc
        r_psc_sum_cnt          = `L0_PSC_SUM_NUM;
        // ??
        r_obuf_tile_row_stride = `L0_OBUF_TILE_ROW_STRIDE;
        r_obuf_ch_stride       = `L0_OBUF_TILE_CH_STRIDE;
      end
      // Layer 2
      1: begin
        // scheduler
        o_lyr_type             = `L1_TYPE;
        o_pad                  = `L1_PAD;
        o_relu                 = `L1_RELU;
        o_filt                 = `L1_FILTER;
        o_filt_grp_num         = `L1_FILTER_GROUP_NUM;
        o_tile_num             = `L1_TILE_NUM;
        o_tile_num_x           = `L1_TILE_NUM_X;
        o_tile_num_y           = `L1_TILE_NUM_Y;
        o_ch                   = `L1_CHANNEL;
        o_ch_grp_num           = `L1_CHANNEL_GROUP_NUM;
        o_img_side             = `L1_IPT_SIDE;
        o_img_area             = `L1_IPT_AREA;
        o_opt_side             = `L1_OPT_SIDE;
        o_opt_area             = `L1_OPT_AREA;
        o_tile_side            = `L1_TILE_IPT_SIDE;
        o_lyr_opt_area         = `L1_TILE_OPT_AREA;
        // address generator
        o_bl_filt_grp_stride   = `L1_BL_STRIDE;
        o_br_filt_grp_stride   = `L1_BR_STRIDE;
        o_wl_filt_grp_stride   = `L1_WL_FILT_GRP_STRIDE;
        o_wr_ch_grp_stride     = `L1_WR_CH_GRP_STRIDE;
        o_tl_col_stride        = `L1_TL_COL_STRIDE;
        o_tl_row_stride        = `L1_TL_ROW_STRIDE;
        o_tl_ch_grp_stride     = `L1_TL_CH_GRP_STRIDE;
        o_ts_col_stride        = `L1_TS_COL_STRIDE;
        o_ts_row_stride        = `L1_TS_ROW_STRIDE;
        o_ts_ch_grp_stride     = `L1_TS_CH_GRP_STRIDE;
        o_bl_req_len           = `L1_BL_REQ_LEN;
        o_br_read_len          = `L1_BR_READ_LEN;  // TODO
        o_wl_req_len           = `L1_WL_REQ_LEN;
        o_wr_read_len          = `L1_WR_READ_LEN;
        o_tr_read_len          = `L1_TR_READ_LEN;
        // loader
        r_wgt_depth            = `L1_WGT_DEPTH;
        r_bias_depth           = `L1_BIAS_DEPTH;
        o_bl_bank_depth        = `L1_BL_BANK_DEPTH;
        o_wl_bank_depth        = `L1_WL_BANK_DEPTH;
        // psc
        r_psc_sum_cnt          = `L1_PSC_SUM_NUM;
        // ??
        r_obuf_tile_row_stride = `L1_OBUF_TILE_ROW_STRIDE;
        r_obuf_ch_stride       = `L1_OBUF_TILE_CH_STRIDE;
      end
      2: begin
        // scheduler
        o_lyr_type             = `L2_TYPE;
        o_pad                  = `L2_PAD;
        o_relu                 = `L2_RELU;
        o_filt                 = `L2_FILTER;
        o_filt_grp_num         = `L2_FILTER_GROUP_NUM;
        o_tile_num             = `L2_TILE_NUM;
        o_tile_num_x           = `L2_TILE_NUM_X;
        o_tile_num_y           = `L2_TILE_NUM_Y;
        o_ch                   = `L2_CHANNEL;
        o_ch_grp_num           = `L2_CHANNEL_GROUP_NUM;
        o_img_side             = `L2_IPT_SIDE;
        o_img_area             = `L2_IPT_AREA;
        o_opt_side             = `L2_OPT_SIDE;
        o_opt_area             = `L2_OPT_AREA;
        o_tile_side            = `L2_TILE_IPT_SIDE;
        o_lyr_opt_area         = `L2_TILE_OPT_AREA;
        // address generator
        o_bl_filt_grp_stride   = `L2_BL_STRIDE;
        o_br_filt_grp_stride   = `L2_BR_STRIDE;
        o_wl_filt_grp_stride   = `L2_WL_FILT_GRP_STRIDE;
        o_wr_ch_grp_stride     = `L2_WR_CH_GRP_STRIDE;
        o_tl_col_stride        = `L2_TL_COL_STRIDE;
        o_tl_row_stride        = `L2_TL_ROW_STRIDE;
        o_tl_ch_grp_stride     = `L2_TL_CH_GRP_STRIDE;
        o_ts_col_stride        = `L2_TS_COL_STRIDE;
        o_ts_row_stride        = `L2_TS_ROW_STRIDE;
        o_ts_ch_grp_stride     = `L2_TS_CH_GRP_STRIDE;
        o_bl_req_len           = `L2_BL_REQ_LEN;
        o_br_read_len          = `L2_BR_READ_LEN;  // TODO
        o_wl_req_len           = `L2_WL_REQ_LEN;
        o_wr_read_len          = `L2_WR_READ_LEN;
        o_tr_read_len          = `L2_TR_READ_LEN;
        // loader
        r_wgt_depth            = `L2_WGT_DEPTH;
        r_bias_depth           = `L2_BIAS_DEPTH;
        o_bl_bank_depth        = `L2_BL_BANK_DEPTH;
        o_wl_bank_depth        = `L2_WL_BANK_DEPTH;
        // psc
        r_psc_sum_cnt          = `L2_PSC_SUM_NUM;
        // ??
        r_obuf_tile_row_stride = `L2_OBUF_TILE_ROW_STRIDE;
        r_obuf_ch_stride       = `L2_OBUF_TILE_CH_STRIDE;
      end
      default: ;
    endcase
  end
endmodule

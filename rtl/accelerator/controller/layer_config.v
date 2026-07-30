

`include "defines.vh"
`include "network_config.vh"
module layer_config #(
    localparam FBUF_DEPTH = `MAX_FILTER_GROUP_NUM * `MAX_IPT_AREA,
    localparam WGT_BANK_DEPTH = `MAX_CHANNEL * `CONV_3X3_AREA
) (
    input      [                 `CLOG2_SAFE( `LAYER_NUM)-1:0] i_lyr_idx,
    //  
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
    output reg [                `CLOG2_SAFE(`MAX_TILE_AREA):0] o_lyr_opt_area
);
  // ====================== parmeter =======================   
  integer                                                     i;
  // ====================== reg ============================     
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
  reg     [                     `CLOG2_SAFE(`MAX_IPT_SIDE):0] r_img_side;
  reg     [                     `CLOG2_SAFE(`MAX_IPT_AREA):0] r_img_area;
  // opt  
  reg     [                     `CLOG2_SAFE(`MAX_OPT_SIDE):0] r_opt_side;
  reg     [                     `CLOG2_SAFE(`MAX_OPT_AREA):0] r_opt_area;
  // layer 
  reg     [                      `CLOG2_SAFE(`LAYER_NUM)-1:0] r_lyr_idx;
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
  reg     [                `CLOG2_SAFE(`MAX_GROUP_CHANNEL):0] r_in_ch;
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
  reg     [                    `CLOG2_SAFE(`MAX_TILE_AREA):0] r_lyr_opt_area;
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
        o_tile_side            = `MAX_TILE_SIDE;
        o_lyr_opt_area         = `L0_TILE_OPT_AREA;
        // address generator
        r_wl_addr_stride       = `L0_WL_ADDR_STRIDE;
        r_tl_row_stride        = `L0_TL_ROW_STRIDE;
        r_tl_ch_stride         = `L0_TL_CH_STRIDE;
        r_obuf_tile_row_stride = `L0_OBUF_TILE_ROW_STRIDE;
        r_obuf_ch_stride       = `L0_OBUF_TILE_CH_STRIDE;

        // loader
        r_wgt_depth            = `L0_WGT_DEPTH;
        r_bias_depth           = `L0_BIAS_DEPTH;
        r_bl_req_len           = `L0_BL_REQ_LEN;
        r_bl_bank_depth        = `L0_BL_BANK_DEPTH;
        r_br_read_len          = `L0_BR_READ_LEN;  // TODO
        r_wl_req_len           = `L0_WL_REQ_LEN;
        r_wl_bank_depth        = `L0_WL_BANK_DEPTH;
        r_wr_read_len          = `L0_WR_READ_LEN;
        r_tr_read_len          = `L0_TR_READ_LEN;

        // psc
        r_psc_sum_cnt          = `L0_PSC_SUM_NUM;
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
        o_tile_side            = `MAX_TILE_SIDE;
        o_lyr_opt_area         = `L1_TILE_OPT_AREA;
        // address generator
        r_wl_addr_stride       = `L1_WL_ADDR_STRIDE;
        r_tl_row_stride        = `L1_TL_ROW_STRIDE;
        r_tl_ch_stride         = `L1_TL_CH_STRIDE;
        r_obuf_tile_row_stride = `L1_OBUF_TILE_ROW_STRIDE;
        r_obuf_ch_stride       = `L1_OBUF_TILE_CH_STRIDE;

        // loader
        r_wgt_depth            = `L1_WGT_DEPTH;
        r_bias_depth           = `L1_BIAS_DEPTH;
        r_bl_req_len           = `L1_BL_REQ_LEN;
        r_bl_bank_depth        = `L1_BL_BANK_DEPTH;
        r_br_read_len          = `L1_BR_READ_LEN;  // TODO
        r_wl_req_len           = `L1_WL_REQ_LEN;
        r_wl_bank_depth        = `L1_WL_BANK_DEPTH;
        r_wr_read_len          = `L1_WR_READ_LEN;
        r_tr_read_len          = `L1_TR_READ_LEN;

        // psc
        r_psc_sum_cnt          = `L1_PSC_SUM_NUM; 
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
        o_tile_side            = `MAX_TILE_SIDE;
        o_lyr_opt_area         = `L2_TILE_OPT_AREA;
        // address generator
        r_wl_addr_stride       = `L2_WL_ADDR_STRIDE;
        r_tl_row_stride        = `L2_TL_ROW_STRIDE;
        r_tl_ch_stride         = `L2_TL_CH_STRIDE;
        r_obuf_tile_row_stride = `L2_OBUF_TILE_ROW_STRIDE;
        r_obuf_ch_stride       = `L2_OBUF_TILE_CH_STRIDE;

        // loader
        r_wgt_depth            = `L2_WGT_DEPTH;
        r_bias_depth           = `L2_BIAS_DEPTH;
        r_bl_req_len           = `L2_BL_REQ_LEN;
        r_bl_bank_depth        = `L2_BL_BANK_DEPTH;
        r_br_read_len          = `L2_BR_READ_LEN;  // TODO
        r_wl_req_len           = `L2_WL_REQ_LEN;
        r_wl_bank_depth        = `L2_WL_BANK_DEPTH;
        r_wr_read_len          = `L2_WR_READ_LEN;
        r_tr_read_len          = `L2_TR_READ_LEN;

        // psc
        r_psc_sum_cnt          = `L2_PSC_SUM_NUM; 
      end
      default: ;
    endcase
    r_ch_left   = r_ch - r_ch_idx;
    r_filt_left = r_filt - r_filt_idx;
    for (i = 0; i < `MAX_GROUP_CHANNEL; i = i + 1) r_ch_mask[i] = (i < r_ch_left);
    for (i = 0; i < `MAX_GROUP_FILTER; i = i + 1) r_filt_mask[i] = (i < r_filt_left);
    if (r_ch_left > `MAX_GROUP_CHANNEL) r_in_ch = `MAX_GROUP_CHANNEL;
    else r_in_ch = r_ch_left;
  end
endmodule

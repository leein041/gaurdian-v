

`include "defines.vh"
`include "network_config.vh"
module layer_config #(
    localparam FBUF_DEPTH = `MAX_FILTER_GROUP_NUM * `MAX_IPT_AREA * `CONV_LAYER_NUM,
    localparam WGT_BANK_DEPTH = `MAX_CHANNEL * `CONV_3X3_AREA
) (
    input      [            `CLOG2_SAFE( `CONV_LAYER_NUM)-1:0] i_lyr_idx,
    // scheduler 
    output reg                                                 o_pad,
    output reg                                                 o_relu,
    output reg [                                          1:0] o_kernel_stride,
    output reg [                   `CLOG2_SAFE(`MAX_FILTER):0] o_filt,
    output reg [ `CLOG2_SAFE(`MAX_FILTER/`MAX_GROUP_FILTER):0] o_filt_grp_num,
    output reg [                 `CLOG2_SAFE(`MAX_TILE_NUM):0] o_tile_num,
    output reg [`CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] o_tile_num_x,
    output reg [`CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] o_tile_num_y,
    output reg [                  `CLOG2_SAFE(`MAX_CHANNEL):0] o_ch,
    output reg [        `CLOG2_SAFE(`MAX_CHANNEL_GROUP_NUM):0] o_ch_grp_num,
    //
    output reg [                 `CLOG2_SAFE(`MAX_IPT_SIDE):0] o_img_side,
    output reg [                 `CLOG2_SAFE(`MAX_OPT_SIDE):0] o_opt_side,
    output reg [                 `CLOG2_SAFE(`MAX_OPT_AREA):0] o_opt_area,
    output reg [                `CLOG2_SAFE(`MAX_TILE_SIDE):0] o_tile_ipt_side,
    output reg [                `CLOG2_SAFE(`MAX_TILE_SIDE):0] o_tile_opt_side,
    output reg [                `CLOG2_SAFE(`MAX_TILE_AREA):0] o_tile_opt_area,
    // loader
    output reg [             `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] o_bl_filt_grp_stride,
    output reg [             `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] o_br_filt_grp_stride,
    output reg [              `CLOG2_SAFE(WGT_BANK_DEPTH) : 0] o_wl_filt_grp_stride,
    output reg [              `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] o_wr_ch_grp_stride,
    output reg [                  `CLOG2_SAFE(`DDR_DEPTH)-1:0] o_tl_src0_base_addr,
    output reg [                  `CLOG2_SAFE(`DDR_DEPTH)-1:0] o_tl_src1_base_addr,
    output reg [                `CLOG2_SAFE(`MAX_CHANNEL) : 0] o_tl_ch_grp_split,
    output reg [               `CLOG2_SAFE(`MAX_IPT_AREA) : 0] o_tl_row_stride,
    output reg [               `CLOG2_SAFE(`MAX_IPT_AREA) : 0] o_tl_col_stride,
    output reg [               `CLOG2_SAFE(`MAX_IPT_AREA) : 0] o_tl_ch_grp_stride,
    output reg [                  `CLOG2_SAFE(`DDR_DEPTH) : 0] o_ts_base_addr,
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
  // ====================== always =========================

  always @(*) begin
    case (i_lyr_idx)
      0: begin
        o_tl_src0_base_addr    = 'h00_0000;
        o_ts_base_addr         = 'h00_0000;
        o_tl_ch_grp_split      = `L0_CHANNEL_GROUP_NUM;
        o_pad                  = `L0_PAD;
        o_relu                 = `L0_RELU;
        o_kernel_stride        = `L0_KERNEL_STRIDE;
        o_filt                 = `L0_FILTER;
        o_filt_grp_num         = `L0_FILTER_GROUP_NUM;
        o_tile_num             = `L0_TILE_NUM;
        o_tile_num_x           = `L0_TILE_NUM_X;
        o_tile_num_y           = `L0_TILE_NUM_Y;
        o_ch                   = `L0_CHANNEL;
        o_ch_grp_num           = `L0_CHANNEL_GROUP_NUM;
        o_img_side             = `L0_IPT_SIDE;
        o_opt_side             = `L0_OPT_SIDE;
        o_opt_area             = `L0_OPT_AREA;
        o_tile_ipt_side        = `L0_TILE_IPT_SIDE;
        o_tile_opt_side        = `L0_TILE_OPT_SIDE;
        o_tile_opt_area        = `L0_TILE_OPT_AREA;
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
      end
      // Layer 2
      1: begin
        o_tl_src0_base_addr    = 'h00_0000;
        o_ts_base_addr         = 'h10_0000;
        o_tl_ch_grp_split      = `L1_CHANNEL_GROUP_NUM;
        o_pad                  = `L1_PAD;
        o_relu                 = `L1_RELU;
        o_kernel_stride        = `L1_KERNEL_STRIDE;
        o_filt                 = `L1_FILTER;
        o_filt_grp_num         = `L1_FILTER_GROUP_NUM;
        o_tile_num             = `L1_TILE_NUM;
        o_tile_num_x           = `L1_TILE_NUM_X;
        o_tile_num_y           = `L1_TILE_NUM_Y;
        o_ch                   = `L1_CHANNEL;
        o_ch_grp_num           = `L1_CHANNEL_GROUP_NUM;
        o_img_side             = `L1_IPT_SIDE;
        o_opt_side             = `L1_OPT_SIDE;
        o_opt_area             = `L1_OPT_AREA;
        o_tile_ipt_side        = `L1_TILE_IPT_SIDE;
        o_tile_opt_side        = `L1_TILE_OPT_SIDE;
        o_tile_opt_area        = `L1_TILE_OPT_AREA;
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
        o_bl_bank_depth        = `L1_BL_BANK_DEPTH;
        o_wl_bank_depth        = `L1_WL_BANK_DEPTH;
      end
      2: begin
        o_tl_src0_base_addr    = 'h10_0000;
        o_ts_base_addr         = 'h20_0000;
        o_tl_ch_grp_split      = `L2_CHANNEL_GROUP_NUM;
        o_pad                  = `L2_PAD;
        o_relu                 = `L2_RELU;
        o_kernel_stride        = `L2_KERNEL_STRIDE;
        o_filt                 = `L2_FILTER;
        o_filt_grp_num         = `L2_FILTER_GROUP_NUM;
        o_tile_num             = `L2_TILE_NUM;
        o_tile_num_x           = `L2_TILE_NUM_X;
        o_tile_num_y           = `L2_TILE_NUM_Y;
        o_ch                   = `L2_CHANNEL;
        o_ch_grp_num           = `L2_CHANNEL_GROUP_NUM;
        o_img_side             = `L2_IPT_SIDE;
        o_opt_side             = `L2_OPT_SIDE;
        o_opt_area             = `L2_OPT_AREA;
        o_tile_ipt_side        = `L2_TILE_IPT_SIDE;
        o_tile_opt_side        = `L2_TILE_OPT_SIDE;
        o_tile_opt_area        = `L2_TILE_OPT_AREA;
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
        o_br_read_len          = `L2_BR_READ_LEN;
        o_wl_req_len           = `L2_WL_REQ_LEN;
        o_wr_read_len          = `L2_WR_READ_LEN;
        o_tr_read_len          = `L2_TR_READ_LEN; 
        o_bl_bank_depth        = `L2_BL_BANK_DEPTH;
        o_wl_bank_depth        = `L2_WL_BANK_DEPTH; 
      end
      // PCB Stage 1
      3: begin
        o_tl_src0_base_addr    = 'h20_0000;
        o_ts_base_addr         = 'h30_0000;
        o_tl_ch_grp_split      = `L3_CHANNEL_GROUP_NUM;
        o_pad                  = `L3_PAD;
        o_relu                 = `L3_RELU;
        o_kernel_stride        = `L3_KERNEL_STRIDE;
        o_filt                 = `L3_FILTER;
        o_filt_grp_num         = `L3_FILTER_GROUP_NUM;
        o_tile_num             = `L3_TILE_NUM;
        o_tile_num_x           = `L3_TILE_NUM_X;
        o_tile_num_y           = `L3_TILE_NUM_Y;
        o_ch                   = `L3_CHANNEL;
        o_ch_grp_num           = `L3_CHANNEL_GROUP_NUM;
        o_img_side             = `L3_IPT_SIDE;
        o_opt_side             = `L3_OPT_SIDE;
        o_opt_area             = `L3_OPT_AREA;
        o_tile_ipt_side        = `L3_TILE_IPT_SIDE;
        o_tile_opt_side        = `L3_TILE_OPT_SIDE;
        o_tile_opt_area        = `L3_TILE_OPT_AREA;
        o_bl_filt_grp_stride   = `L3_BL_STRIDE;
        o_br_filt_grp_stride   = `L3_BR_STRIDE;
        o_wl_filt_grp_stride   = `L3_WL_FILT_GRP_STRIDE;
        o_wr_ch_grp_stride     = `L3_WR_CH_GRP_STRIDE;
        o_tl_col_stride        = `L3_TL_COL_STRIDE;
        o_tl_row_stride        = `L3_TL_ROW_STRIDE;
        o_tl_ch_grp_stride     = `L3_TL_CH_GRP_STRIDE;
        o_ts_col_stride        = `L3_TS_COL_STRIDE;
        o_ts_row_stride        = `L3_TS_ROW_STRIDE;
        o_ts_ch_grp_stride     = `L3_TS_CH_GRP_STRIDE;
        o_bl_req_len           = `L3_BL_REQ_LEN;
        o_br_read_len          = `L3_BR_READ_LEN;
        o_wl_req_len           = `L3_WL_REQ_LEN;
        o_wr_read_len          = `L3_WR_READ_LEN;
        o_tr_read_len          = `L3_TR_READ_LEN; 
        o_bl_bank_depth        = `L3_BL_BANK_DEPTH;
        o_wl_bank_depth        = `L3_WL_BANK_DEPTH; 
      end
      4: begin
        o_tl_src0_base_addr    = 'h30_0000;
        o_ts_base_addr         = 'h40_0000;
        o_tl_ch_grp_split      = `L4_CHANNEL_GROUP_NUM;
        o_pad                  = `L4_PAD;
        o_relu                 = `L4_RELU;
        o_kernel_stride        = `L4_KERNEL_STRIDE;
        o_filt                 = `L4_FILTER;
        o_filt_grp_num         = `L4_FILTER_GROUP_NUM;
        o_tile_num             = `L4_TILE_NUM;
        o_tile_num_x           = `L4_TILE_NUM_X;
        o_tile_num_y           = `L4_TILE_NUM_Y;
        o_ch                   = `L4_CHANNEL;
        o_ch_grp_num           = `L4_CHANNEL_GROUP_NUM;
        o_img_side             = `L4_IPT_SIDE;
        o_opt_side             = `L4_OPT_SIDE;
        o_opt_area             = `L4_OPT_AREA;
        o_tile_ipt_side        = `L4_TILE_IPT_SIDE;
        o_tile_opt_side        = `L4_TILE_OPT_SIDE;
        o_tile_opt_area        = `L4_TILE_OPT_AREA;
        o_bl_filt_grp_stride   = `L4_BL_STRIDE;
        o_br_filt_grp_stride   = `L4_BR_STRIDE;
        o_wl_filt_grp_stride   = `L4_WL_FILT_GRP_STRIDE;
        o_wr_ch_grp_stride     = `L4_WR_CH_GRP_STRIDE;
        o_tl_col_stride        = `L4_TL_COL_STRIDE;
        o_tl_row_stride        = `L4_TL_ROW_STRIDE;
        o_tl_ch_grp_stride     = `L4_TL_CH_GRP_STRIDE;
        o_ts_col_stride        = `L4_TS_COL_STRIDE;
        o_ts_row_stride        = `L4_TS_ROW_STRIDE;
        o_ts_ch_grp_stride     = `L4_TS_CH_GRP_STRIDE;
        o_bl_req_len           = `L4_BL_REQ_LEN;
        o_br_read_len          = `L4_BR_READ_LEN;
        o_wl_req_len           = `L4_WL_REQ_LEN;
        o_wr_read_len          = `L4_WR_READ_LEN;
        o_tr_read_len          = `L4_TR_READ_LEN; 
        o_bl_bank_depth        = `L4_BL_BANK_DEPTH;
        o_wl_bank_depth        = `L4_WL_BANK_DEPTH; 
      end
      5: begin
        o_tl_src0_base_addr    = 'h40_0000;
        o_tl_src1_base_addr    = 'h30_0000;
        o_tl_ch_grp_split      = `L4_FILTER_GROUP_NUM; // 8-8 group  구조라 가능한데 개선 필요
        o_ts_base_addr         = 'h50_0000;
        o_pad                  = `L5_PAD;
        o_relu                 = `L5_RELU;
        o_kernel_stride        = `L5_KERNEL_STRIDE;
        o_filt                 = `L5_FILTER;
        o_filt_grp_num         = `L5_FILTER_GROUP_NUM;
        o_tile_num             = `L5_TILE_NUM;
        o_tile_num_x           = `L5_TILE_NUM_X;
        o_tile_num_y           = `L5_TILE_NUM_Y;
        o_ch                   = `L5_CHANNEL;
        o_ch_grp_num           = `L5_CHANNEL_GROUP_NUM;
        o_img_side             = `L5_IPT_SIDE;
        o_opt_side             = `L5_OPT_SIDE;
        o_opt_area             = `L5_OPT_AREA;
        o_tile_ipt_side        = `L5_TILE_IPT_SIDE;
        o_tile_opt_side        = `L5_TILE_OPT_SIDE;
        o_tile_opt_area        = `L5_TILE_OPT_AREA;
        o_bl_filt_grp_stride   = `L5_BL_STRIDE;
        o_br_filt_grp_stride   = `L5_BR_STRIDE;
        o_wl_filt_grp_stride   = `L5_WL_FILT_GRP_STRIDE;
        o_wr_ch_grp_stride     = `L5_WR_CH_GRP_STRIDE;
        o_tl_col_stride        = `L5_TL_COL_STRIDE;
        o_tl_row_stride        = `L5_TL_ROW_STRIDE;
        o_tl_ch_grp_stride     = `L5_TL_CH_GRP_STRIDE;
        o_ts_col_stride        = `L5_TS_COL_STRIDE;
        o_ts_row_stride        = `L5_TS_ROW_STRIDE;
        o_ts_ch_grp_stride     = `L5_TS_CH_GRP_STRIDE;
        o_bl_req_len           = `L5_BL_REQ_LEN;
        o_br_read_len          = `L5_BR_READ_LEN;
        o_wl_req_len           = `L5_WL_REQ_LEN;
        o_wr_read_len          = `L5_WR_READ_LEN;
        o_tr_read_len          = `L5_TR_READ_LEN; 
        o_bl_bank_depth        = `L5_BL_BANK_DEPTH;
        o_wl_bank_depth        = `L5_WL_BANK_DEPTH; 
      end
      default: ;
    endcase
  end
endmodule

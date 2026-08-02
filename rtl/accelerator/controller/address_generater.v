

`include "defines.vh"
`include "network_config.vh"
module address_generater #(
    localparam FBUF_DEPTH     = `MAX_FILTER_GROUP_NUM * `MAX_IPT_AREA,
    localparam WGT_BANK_DEPTH = `MAX_CHANNEL * `CONV_3X3_AREA
) (
    input                                            i_clk,
    input                                            i_rstn,
    // scheduler
    input                                            i_nxt_lyr,
    input                                            i_nxt_filt_grp,
    input                                            i_nxt_tile_col,
    input                                            i_nxt_tile_row,
    input                                            i_nxt_ch_grp,
    //
    input      [   `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] i_bl_filt_grp_stride,
    input      [   `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] i_br_filt_grp_stride,
    input      [    `CLOG2_SAFE(WGT_BANK_DEPTH) : 0] i_wl_filt_grp_stride,
    input      [    `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] i_wr_ch_grp_stride,
    input      [     `CLOG2_SAFE(`MAX_IPT_AREA) : 0] i_tl_row_stride,
    input      [     `CLOG2_SAFE(`MAX_IPT_AREA) : 0] i_tl_col_stride,
    input      [     `CLOG2_SAFE(`MAX_IPT_AREA) : 0] i_tl_ch_grp_stride,
    input      [     `CLOG2_SAFE(`MAX_IPT_AREA) : 0] i_ts_row_stride,
    input      [     `CLOG2_SAFE(`MAX_IPT_AREA) : 0] i_ts_col_stride,
    input      [     `CLOG2_SAFE(`MAX_IPT_AREA) : 0] i_ts_ch_grp_stride,
    // 
    output reg [   `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] o_bl_addr,
    output reg [ `CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] o_br_addr,
    output reg [    `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] o_wl_addr,
    output reg [    `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] o_wr_addr,
    output reg [        `CLOG2_SAFE(FBUF_DEPTH)-1:0] o_tl_addr,
    output reg [`CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] o_tr_addr,
    output reg [        `CLOG2_SAFE(FBUF_DEPTH)-1:0] o_ts_addr
);
  // ====================== parmeter =======================   
  integer                                      i;
  // ====================== wire =========================== 
  wire                                         w_lyr_vld;
  wire    [    `OPT_BIT*`MAX_GROUP_FILTER-1:0] w_lyr_dat;
  // ====================== reg ============================    
  reg     [  `CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] r_bl_offset;
  reg     [`CLOG2_SAFE(`MAX_GROUP_FILTER)-1:0] r_br_offset;
  reg     [   `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] r_wl_offset;
  reg     [   `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] r_wr_offset;
  reg     [    `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_tl_row_offset;
  reg     [    `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_tl_col_offset;
  reg     [       `CLOG2_SAFE(FBUF_DEPTH) : 0] r_tl_ch_offset;
  // DDR
  reg                                          r_obuf_we;
  reg     [   `OPT_BIT* `MAX_GROUP_FILTER-1:0] r_obuf_wdat;
  reg     [       `CLOG2_SAFE(FBUF_DEPTH) : 0] r_ts_row_offset;
  reg     [       `CLOG2_SAFE(FBUF_DEPTH) : 0] r_ts_col_offset;
  reg     [    `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_obuf_tile_row_stride;
  reg     [       `CLOG2_SAFE(FBUF_DEPTH) : 0] r_ts_ch_offset;
  reg     [       `CLOG2_SAFE(FBUF_DEPTH) : 0] r_obuf_ch_stride;
  reg     [       `CLOG2_SAFE(FBUF_DEPTH)-1:0] r_obuf_waddr;
  // ====================== assign =========================     
  always @(*) begin
    o_bl_addr = r_bl_offset;
    o_br_addr = r_br_offset;
    o_wl_addr = r_wl_offset;
    o_wr_addr = r_wr_offset;
    o_tl_addr = r_tl_col_offset + r_tl_row_offset + r_tl_ch_offset;
    o_tr_addr = 'd0;
    o_ts_addr = r_ts_col_offset + r_ts_row_offset + r_ts_ch_offset;
  end

  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_bl_offset     <= 'd0;
      r_br_offset     <= 'd0;
      r_wl_offset     <= 'd0;
      r_wr_offset     <= 'd0;
      r_tl_row_offset <= 'd0;
      r_tl_col_offset <= 'd0;
      r_tl_ch_offset  <= 'd0;
      r_ts_col_offset <= 'd0;
      r_ts_row_offset <= 'd0;
      r_ts_ch_offset  <= 'd0;
    end else begin
      if (i_nxt_lyr) begin
        r_bl_offset     <= 'd0;
        r_br_offset     <= 'd0;
        r_wl_offset     <= 'd0;
        r_wr_offset     <= 'd0;
        r_tl_row_offset <= 'd0;
        r_tl_col_offset <= 'd0;
        r_tl_ch_offset  <= 'd0;
        r_ts_col_offset <= 'd0;
        r_ts_row_offset <= 'd0;
        r_ts_ch_offset  <= 'd0;
      end else if (i_nxt_filt_grp) begin
        r_bl_offset     <= r_bl_offset + i_bl_filt_grp_stride;
        r_wl_offset     <= r_wl_offset + i_wl_filt_grp_stride;
        r_wr_offset     <= 'd0;
        r_tl_row_offset <= 'd0;
        r_tl_col_offset <= 'd0;
        r_tl_ch_offset  <= 'd0;
        r_ts_col_offset <= 'd0;
        r_ts_row_offset <= 'd0;
        r_ts_ch_offset  <= r_ts_ch_offset + i_ts_ch_grp_stride;
      end else if (i_nxt_tile_col || i_nxt_tile_row) begin
        r_wr_offset <= 'd0;
        r_tl_ch_offset <= 'd0;
        // update tile  
        if (i_nxt_tile_col) begin
          r_tl_col_offset <= r_tl_col_offset + i_tl_col_stride;
          r_ts_col_offset <= r_ts_col_offset + i_ts_col_stride;
        end else if (i_nxt_tile_row) begin
          r_tl_col_offset <= 'd0;
          r_ts_col_offset <= 'd0;
          r_tl_row_offset <= r_tl_row_offset + i_tl_row_stride;
          r_ts_row_offset <= r_ts_row_offset + i_ts_row_stride;
        end
      end else if (i_nxt_ch_grp) begin

        r_wr_offset <= r_wr_offset + i_wr_ch_grp_stride;
        r_tl_ch_offset <= r_tl_ch_offset + i_tl_ch_grp_stride;

      end
    end

  end


  // ====================== module ========================= 
endmodule

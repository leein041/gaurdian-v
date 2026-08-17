

`include "defines.vh"
`include "network_config.vh"
module loader_addr_gen #(
    localparam FBUF_DEPTH     = `MAX_FILTER_GROUP_NUM * `MAX_IPT_AREA * `CONV_LAYER_NUM,
    localparam WGT_BANK_DEPTH = `MAX_CHANNEL * `CONV_3X3_AREA
) (
    input                                         i_clk,
    input                                         i_rstn,
    // bias
    input                                         i_bl_nxt_lyr,
    input                                         i_bl_nxt_filt_grp,
    // weight
    input                                         i_wl_nxt_lyr,
    input                                         i_wl_nxt_filt_grp,
    // tile
    input                                         i_nxt_lyr,
    input                                         i_nxt_filt_grp,
    input                                         i_nxt_tile_col,
    input                                         i_nxt_tile_row,
    input                                         i_nxt_ch_grp,
    // 
    output reg [`CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] o_bl_addr,
    output reg [ `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] o_wl_addr,
    output reg [     `CLOG2_SAFE(`DDR_DEPTH)-1:0] o_tl_addr,
    //
    input      [`CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] i_bl_filt_grp_stride,
    input      [ `CLOG2_SAFE(WGT_BANK_DEPTH) : 0] i_wl_filt_grp_stride,
    input      [  `CLOG2_SAFE(`MAX_IPT_AREA) : 0] i_tl_row_stride,
    input      [  `CLOG2_SAFE(`MAX_IPT_AREA) : 0] i_tl_col_stride,
    input      [  `CLOG2_SAFE(`MAX_IPT_AREA) : 0] i_tl_ch_grp_stride,
    input      [     `CLOG2_SAFE(`DDR_DEPTH) : 0] i_tl_base_addr
);
  // ====================== parmeter =======================   
  integer                                    i;
  // ====================== wire =========================== 
  wire                                       w_lyr_vld;
  wire    [  `OPT_BIT*`MAX_GROUP_FILTER-1:0] w_lyr_dat;
  // ====================== reg ============================     
  reg     [`CLOG2_SAFE(`MAX_BIAS_DEPTH)-1:0] r_bl_offset;
  reg     [ `CLOG2_SAFE(`MAX_WGT_DEPTH)-1:0] r_wl_offset;
  reg     [  `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_tl_row_offset;
  reg     [  `CLOG2_SAFE(`MAX_IPT_AREA) : 0] r_tl_col_offset;
  reg     [     `CLOG2_SAFE(FBUF_DEPTH) : 0] r_tl_ch_offset;
  // ====================== assign =========================     
  always @(*) begin
    o_bl_addr = r_bl_offset;
    o_wl_addr = r_wl_offset;
    o_tl_addr = i_tl_base_addr + r_tl_col_offset + r_tl_row_offset + r_tl_ch_offset;
  end

  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_bl_offset     <= 'd0;
      r_wl_offset     <= 'd0;
      r_tl_row_offset <= 'd0;
      r_tl_col_offset <= 'd0;
      r_tl_ch_offset  <= 'd0;
    end else begin

      if (i_bl_nxt_filt_grp) begin
        r_bl_offset <= r_bl_offset + i_bl_filt_grp_stride;
      end else if (i_bl_nxt_lyr) begin
        r_bl_offset <= 'd0;
      end

      if (i_wl_nxt_filt_grp) begin
        r_wl_offset <= r_wl_offset + i_wl_filt_grp_stride;
      end else if (i_wl_nxt_lyr) begin
        r_wl_offset <= 'd0;
      end

      if (i_nxt_lyr) begin
        r_tl_row_offset <= 'd0;
        r_tl_col_offset <= 'd0;
        r_tl_ch_offset  <= 'd0;
      end else if (i_nxt_filt_grp) begin
        r_tl_row_offset <= 'd0;
        r_tl_col_offset <= 'd0;
        r_tl_ch_offset  <= 'd0;
      end else if (i_nxt_tile_col || i_nxt_tile_row) begin
        r_tl_ch_offset <= 'd0;
        // update tile  
        if (i_nxt_tile_col) begin
          r_tl_col_offset <= r_tl_col_offset + i_tl_col_stride;
        end else if (i_nxt_tile_row) begin
          r_tl_col_offset <= 'd0;
          r_tl_row_offset <= r_tl_row_offset + i_tl_row_stride;
        end
      end else if (i_nxt_ch_grp) begin
        r_tl_ch_offset <= r_tl_ch_offset + i_tl_ch_grp_stride;
      end

    end

  end


  // ====================== module ========================= 
endmodule

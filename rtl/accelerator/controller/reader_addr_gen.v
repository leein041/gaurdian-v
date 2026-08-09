

`include "defines.vh"
`include "network_config.vh"
module reader_addr_gen #(
    localparam FBUF_DEPTH     = `MAX_FILTER_GROUP_NUM * `MAX_IPT_AREA,
    localparam WGT_BANK_DEPTH = `MAX_CHANNEL * `CONV_3X3_AREA
) (
    input                                               i_clk,
    input                                               i_rstn,
    input                                               i_commit_addr,
    // scheduler
    input                                               i_nxt_lyr,
    input                                               i_nxt_filt_grp,
    input                                               i_nxt_tile_col,
    input                                               i_nxt_tile_row,
    input                                               i_nxt_ch_grp,
    input                                               i_br_prefetch,
    //  
    output reg [`CLOG2_SAFE(`MAX_FILTER_GROUP_NUM)-1:0] o_br_addr,
    output reg [       `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] o_wr_addr,
    output reg [   `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] o_tr_addr,
    output reg [           `CLOG2_SAFE(FBUF_DEPTH)-1:0] o_ts_addr,
    // 
    input      [      `CLOG2_SAFE(`MAX_BIAS_DEPTH) : 0] i_br_filt_grp_stride,
    input      [       `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] i_wr_ch_grp_stride,
    input      [        `CLOG2_SAFE(`MAX_IPT_AREA) : 0] i_ts_row_stride,
    input      [        `CLOG2_SAFE(`MAX_IPT_AREA) : 0] i_ts_col_stride,
    input      [        `CLOG2_SAFE(`MAX_IPT_AREA) : 0] i_ts_ch_grp_stride
);
  // ====================== parmeter =======================   
  integer                                          i;
  // ====================== wire =========================== 
  wire                                             w_lyr_vld;
  wire    [        `OPT_BIT*`MAX_GROUP_FILTER-1:0] w_lyr_dat;
  // ====================== reg ============================    
  // current 
  reg     [`CLOG2_SAFE(`MAX_FILTER_GROUP_NUM)-1:0] r_cur_br_offset;
  reg     [       `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] r_cur_wr_offset;
  reg     [           `CLOG2_SAFE(FBUF_DEPTH) : 0] r_cur_ts_row_offset;
  reg     [           `CLOG2_SAFE(FBUF_DEPTH) : 0] r_cur_ts_col_offset;
  reg     [           `CLOG2_SAFE(FBUF_DEPTH) : 0] r_cur_ts_ch_offset;
  // next 
  reg     [`CLOG2_SAFE(`MAX_FILTER_GROUP_NUM)-1:0] r_nxt_br_offset;
  reg     [       `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] r_nxt_wr_offset;
  reg     [           `CLOG2_SAFE(FBUF_DEPTH) : 0] r_nxt_ts_row_offset;
  reg     [           `CLOG2_SAFE(FBUF_DEPTH) : 0] r_nxt_ts_col_offset;
  reg     [           `CLOG2_SAFE(FBUF_DEPTH) : 0] r_nxt_ts_ch_offset;
  // ====================== assign =========================     
  always @(*) begin
    o_br_addr = r_nxt_br_offset;
    o_wr_addr = r_nxt_wr_offset;
    o_tr_addr = 'd0;
    o_ts_addr = r_cur_ts_col_offset + r_cur_ts_row_offset + r_cur_ts_ch_offset;
  end

  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_cur_br_offset     <= 'd0;
      r_cur_wr_offset     <= 'd0;
      r_cur_ts_col_offset <= 'd0;
      r_cur_ts_row_offset <= 'd0;
      r_cur_ts_ch_offset  <= 'd0;
    end else if (i_commit_addr) begin
      r_cur_br_offset     <= r_nxt_br_offset;
      r_cur_wr_offset     <= r_nxt_wr_offset;
      r_cur_ts_col_offset <= r_nxt_ts_col_offset;
      r_cur_ts_row_offset <= r_nxt_ts_row_offset;
      r_cur_ts_ch_offset  <= r_nxt_ts_ch_offset;
    end

  end

  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_nxt_br_offset     <= 'd0;
      r_nxt_wr_offset     <= 'd0;
      r_nxt_ts_col_offset <= 'd0;
      r_nxt_ts_row_offset <= 'd0;
      r_nxt_ts_ch_offset  <= 'd0;
    end else begin
      if (i_nxt_lyr) begin
        r_nxt_br_offset     <= 'd0;
        r_nxt_wr_offset     <= 'd0;
        r_nxt_ts_col_offset <= 'd0;
        r_nxt_ts_row_offset <= 'd0;
        r_nxt_ts_ch_offset  <= 'd0;
      end else if (i_nxt_filt_grp) begin
        r_nxt_wr_offset     <= 'd0;
        r_nxt_ts_col_offset <= 'd0;
        r_nxt_ts_row_offset <= 'd0;
        r_nxt_ts_ch_offset  <= r_nxt_ts_ch_offset + i_ts_ch_grp_stride;
      end else if (i_nxt_tile_col || i_nxt_tile_row) begin
        r_nxt_wr_offset <= 'd0;
        // update tile  
        if (i_nxt_tile_col) begin
          r_nxt_ts_col_offset <= r_nxt_ts_col_offset + i_ts_col_stride;
        end else if (i_nxt_tile_row) begin
          r_nxt_ts_col_offset <= 'd0;
          r_nxt_ts_row_offset <= r_nxt_ts_row_offset + i_ts_row_stride;
        end
      end else if (i_nxt_ch_grp) begin

        r_nxt_wr_offset <= r_nxt_wr_offset + i_wr_ch_grp_stride;
      end

      if (i_br_prefetch) begin
        r_nxt_br_offset <= r_nxt_br_offset + i_br_filt_grp_stride;
      end
    end

  end


  // ====================== module ========================= 
endmodule

`include "defines.vh"
`include "network_config.vh"
module tile_scatter #(
    localparam FBUF_DEPTH = `MAX_FILTER_GROUP_NUM * `MAX_IPT_AREA
) (
    input                                        i_clk,
    input                                        i_rstn,
    input                                        i_st,
    output                                       o_dn,
    //
    input      [   `CLOG2_SAFE(`MAX_IPT_SIDE):0] i_img_side,
    input      [    `CLOG2_SAFE(FBUF_DEPTH)-1:0] i_base_addr,
    //
    input                                        i_vld,
    input      [`OPT_BIT* `MAX_GROUP_FILTER-1:0] i_din,
    // 
    output reg                                   o_obuf_we,
    output reg [`OPT_BIT* `MAX_GROUP_FILTER-1:0] o_obuf_wdout,
    output reg [    `CLOG2_SAFE(FBUF_DEPTH)-1:0] o_obuf_waddr
);
  // ====================== parmeter =======================   
  // ====================== reg ============================ 
  reg                               r_busy;
  reg [`CLOG2_SAFE(FBUF_DEPTH)-1:0] r_wcnt;
  //
  reg [`CLOG2_SAFE(FBUF_DEPTH)-1:0] r_base_addr;
  reg [`CLOG2_SAFE(FBUF_DEPTH) : 0] r_col_idx;
  reg [`CLOG2_SAFE(FBUF_DEPTH) : 0] r_row_base_addr;
  // ====================== assign =========================
  assign o_dn = r_busy && (r_wcnt == `MAX_TILE_AREA - 1);
  // ====================== always =========================

  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_busy <= 'b0;
    end else begin
      if (i_st) begin
        r_busy <= 'b1;
      end else if (r_wcnt == `MAX_TILE_AREA - 1) begin
        r_busy <= 'b0;
      end
    end
  end

  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_wcnt          <= 'd0;
      o_obuf_we       <= 'd0;
      o_obuf_wdout    <= 'd0;
      o_obuf_waddr    <= 'd0;
      r_row_base_addr <= 'd0;
      r_col_idx       <= 'd0;
    end else begin

      if (i_st) begin
        r_base_addr     <= i_base_addr;
        r_wcnt          <= 'd0;
        r_row_base_addr <= 'd0;
        r_col_idx       <= 'd0;
      end

      if (r_busy && i_vld) begin
        r_wcnt       <= r_wcnt + 'd1;
        o_obuf_we    <= 'b1;
        o_obuf_wdout <= i_din;
        o_obuf_waddr <= r_base_addr + r_col_idx + r_row_base_addr;
        if (r_col_idx < `MAX_TILE_SIDE - 1) begin
          r_col_idx <= r_col_idx + 'd1;
        end else begin
          r_row_base_addr <= r_row_base_addr + i_img_side;
          r_col_idx <= 'd0;
        end
      end else begin
        o_obuf_we <= 'b0;
      end
    end
  end

  // ====================== module ========================= 
endmodule

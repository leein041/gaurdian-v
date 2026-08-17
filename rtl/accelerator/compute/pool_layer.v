
`include "defines.vh"
`include "network_config.vh"
module pool_layer (
    input                                   i_clk,
    input                                   i_rstn,
    input                                   i_clr,
    //
    input                                   i_maxpool_en,
    // ipt 
    output                                  o_ipt_rdy,
    input                                   i_ipt_vld,
    input  [`IPT_BIT*`MAX_GROUP_FILTER-1:0] i_ipt_din,
    // opt
    input                                   i_opt_rdy,
    output                                  o_opt_vld,
    output [`OPT_BIT*`MAX_GROUP_FILTER-1:0] o_opt_dout
);
  // ====================== parmeter =======================   
  localparam MAXPOOL_AREA = `POOL_2X2_SIDE * `POOL_2X2_SIDE;
  genvar c, p;
  // ====================== wire ===========================  
  // line bufferS    
  wire lbuf_ptch_vld;
  wire [`IPT_BIT* `MAX_GROUP_CHANNEL*`POOL_2X2_SIDE-1:0] lbuf_ptch_dat;
  wire lbuf_ptch_win_vld;
  // patch
  wire ptch_lbuf_rdy;
  wire ptch_pool_vld;
  wire [`IPT_BIT*`MAX_GROUP_CHANNEL* MAXPOOL_AREA-1:0] ptch_pool_dat_bus;
  wire [`IPT_BIT* MAXPOOL_AREA-1:0] ptch_pool_dat[0:`MAX_GROUP_CHANNEL-1];
  // max pool
  wire [`MAX_GROUP_FILTER-1:0] w_maxpool_rdy;
  wire [`MAX_GROUP_FILTER-1:0] w_maxpool_vld;
  wire [`OPT_BIT-1:0] w_maxpool_dat[0:`MAX_GROUP_FILTER-1];
  wire [`OPT_BIT*`MAX_GROUP_FILTER-1:0] w_maxpool_dat_bus;

  // ====================== reg ============================  
  // ====================== assign =========================    
  generate
    for (c = 0; c < `MAX_GROUP_CHANNEL; c = c + 1) begin
      for (p = 0; p < MAXPOOL_AREA; p = p + 1) begin
        assign ptch_pool_dat[c][p*`IPT_BIT+:`IPT_BIT] = 
                  ptch_pool_dat_bus[c*`IPT_BIT + p*`IPT_BIT*`MAX_GROUP_CHANNEL+:`IPT_BIT];
      end

      assign w_maxpool_dat_bus[c*`OPT_BIT+:`OPT_BIT] = w_maxpool_dat[c];
    end
  endgenerate
  // ====================== always =========================   
  // ====================== assign =========================
  assign o_opt_vld  = (i_maxpool_en) ? w_maxpool_vld[0] : i_ipt_vld;
  assign o_opt_dout = (i_maxpool_en) ? w_maxpool_dat_bus : i_ipt_din;
  // ====================== module =========================  
  line_buffer #(
      .LINE_BIT   (`IPT_BIT * `MAX_GROUP_CHANNEL),
      .LINE_HEIGHT(`POOL_2X2_SIDE),
      .LINE_WIDTH (`MAX_TILE_SIDE),
      .STRIDE     (`POOL_2X2_STRIDE)
  ) inst_maxpool_line_buffer (
      .i_clk       (i_clk),
      .i_rstn      (i_rstn),
      .i_clr       (i_clr),
      // ipt
      .o_ipt_rdy   (o_ipt_rdy),
      .i_ipt_din   (i_ipt_din),
      .i_ipt_vld   (i_ipt_vld),
      // opt
      .i_opt_rdy   (ptch_lbuf_rdy),
      .o_opt_vld   (lbuf_ptch_vld),
      .o_opt_dout  (lbuf_ptch_dat),
      // 
      .o_window_vld(lbuf_ptch_win_vld)
  );
  patch #(
      .WIDTH     (`IPT_BIT * `MAX_GROUP_CHANNEL),
      .PATCH_SIDE(`POOL_2X2_SIDE)
  ) inst_pool_patch_buffer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_clr     (i_clr),
      // ipt
      .i_ipt_vld (lbuf_ptch_vld),
      .i_ipt_din (lbuf_ptch_dat),
      .o_ipt_rdy (ptch_lbuf_rdy),
      // opt
      .i_opt_rdy ('b1),
      .o_opt_vld (ptch_pool_vld),
      .o_opt_dout(ptch_pool_dat_bus),
      //
      .i_ptch_vld(lbuf_ptch_win_vld)
  );

  generate
    for (c = 0; c < `MAX_GROUP_FILTER; c = c + 1) begin
      max_pool #(
          .POOL_SIDE(`POOL_2X2_SIDE)
      ) inst_max_pool (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          // ipt
          .i_ipt_din (ptch_pool_dat[c]),
          .i_ipt_vld (ptch_pool_vld),
          .o_ipt_rdy (),
          // opt
          .i_opt_rdy ('b1),
          .o_opt_vld (w_maxpool_vld[c]),
          .o_opt_dout(w_maxpool_dat[c])
      );
    end
  endgenerate
  // ====================== output ========================= 

endmodule

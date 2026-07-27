
`include "defines.vh"
`include "network_config.vh"
module pool_layer (
    input                                   i_clk,
    input                                   i_rstn,
    // ipt 
    output                                  o_ipt_rdy,
    input                                   i_ipt_vld,
    input  [`IPT_BIT*`MAX_GROUP_FILTER-1:0] i_ipt_din,
    // opt
    input                                   i_opt_rdy,
    output                                  o_opt_vld,
    output [`OPT_BIT*`MAX_GROUP_FILTER-1:0] o_opt_dout,
    //
    input  [       $clog2(`MAX_IPT_SIDE):0] i_img_side,
    input  [         `MAX_GROUP_FILTER-1:0] i_lbuf_st
);
  // ====================== parmeter =======================   
  localparam MAXPOOL_AREA = `POOL_2X2_SIDE * `POOL_2X2_SIDE;
  localparam LINEBUFFER_SIDE = `MAX_IPT_SIDE + 2;
  localparam LINEBUFFER_AREA = LINEBUFFER_SIDE * LINEBUFFER_SIDE;
  genvar c;
  // ====================== wire =========================== 
  // IO port 
  wire signed [`IPT_BIT-1:0] w_ipt_dat[0:`MAX_GROUP_FILTER-1];
  // line bufferS   
  wire [`MAX_GROUP_FILTER-1:0] w_lbuf_rdy;
  wire [`MAX_GROUP_FILTER-1:0] w_lbuf_vld;
  wire [`IPT_BIT*`POOL_2X2_SIDE-1:0] w_lbuf_dat[0:`MAX_GROUP_FILTER-1];
  // patch
  wire [`MAX_GROUP_FILTER-1:0] w_ptch_rdy;
  wire [`MAX_GROUP_FILTER-1:0] w_ptch_vld;
  wire [`IPT_BIT*MAXPOOL_AREA-1:0] w_ptch_dat[0:`MAX_GROUP_FILTER-1];
  // max pool
  wire [`MAX_GROUP_FILTER-1:0] w_maxpool_rdy;
  wire [`MAX_GROUP_FILTER-1:0] w_maxpool_vld;
  wire [`OPT_BIT-1:0] w_maxpool_dat[0:`MAX_GROUP_FILTER-1];
  wire [`OPT_BIT*`MAX_GROUP_FILTER-1:0] w_maxpool_dat_bus;

  // ====================== reg ============================ 
  // line buffer    
  reg [`MAX_GROUP_FILTER-1:0] r_lbuf_st;  // for timing with below
  reg [$clog2(LINEBUFFER_SIDE):0] r_line_width;
  reg [$clog2(LINEBUFFER_AREA):0] r_lbuf_area;

  // ====================== assign =========================   
  assign o_ipt_rdy = w_lbuf_rdy[0];
  // ====================== always =========================  
  // comput line buffer size   
  always @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
      r_lbuf_st <= 'd0;
      r_line_width <= 'd0;
      r_lbuf_area <= 'd0;
    end else begin
      r_lbuf_st <= i_lbuf_st;
      if (i_lbuf_st[0]) begin
        r_line_width <= i_img_side;
        r_lbuf_area  <= i_img_side * i_img_side;
      end
    end
  end

  // ====================== assign =========================

  generate
    for (c = 0; c < `MAX_GROUP_FILTER; c = c + 1) begin
      assign w_ipt_dat[c]                            = i_ipt_din[c*`IPT_BIT+:`IPT_BIT];
      assign w_maxpool_dat_bus[c*`OPT_BIT+:`OPT_BIT] = w_maxpool_dat[c];
    end
  endgenerate

  // ====================== module ========================= 

  // line buffer
  generate
    for (c = 0; c < `MAX_GROUP_FILTER; c = c + 1) begin
      line_buffer #(
          .LINE_BIT   (`IPT_BIT * `MAX_GROUP_CHANNEL),
          .LINE_HEIGHT(`POOL_2X2_SIDE),
          .LINE_WIDTH (`MAX_TILE_SIDE)
      ) inst_maxpool_linebuffer (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .i_clr     (r_lbuf_st[c]),
          // ipt
          .o_ipt_rdy (w_lbuf_rdy[c]),
          .i_ipt_din (w_ipt_dat[c]),
          .i_ipt_vld (i_ipt_vld),
          // opt
          .i_opt_rdy (w_ptch_rdy[c]),
          .o_opt_vld (w_lbuf_vld[c]),
          .o_opt_dout(w_lbuf_dat[c])
      );

      patch #(
          .STRIDE(`POOL_2X2_STRIDE),
          .PATCH_SIDE(`POOL_2X2_SIDE)
      ) inst_maxpool_patch_buffer (
          .i_clk       (i_clk),
          .i_rstn      (i_rstn),
          .i_clr       (r_lbuf_st[c]),
          // ipt
          .i_ipt_din   (w_lbuf_dat[c]),
          .i_ipt_vld   (w_lbuf_vld[c]),
          .o_ipt_rdy   (w_ptch_rdy[c]),
          // opt
          .i_opt_rdy   (w_maxpool_rdy[c]),
          .o_opt_vld   (w_ptch_vld[c]),
          .o_opt_dout  (w_ptch_dat[c]),
          //
          .i_line_width(r_line_width)
      );
      max_pool #(
          .POOL_SIDE(`POOL_2X2_SIDE)
      ) inst_max_pool (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          // ipt
          .i_ipt_din (w_ptch_dat[c]),
          .i_ipt_vld (w_ptch_vld[c]),
          .o_ipt_rdy (w_maxpool_rdy[c]),
          // opt
          .i_opt_rdy (i_opt_rdy),
          .o_opt_vld (w_maxpool_vld[c]),
          .o_opt_dout(w_maxpool_dat[c])
      );
    end
  endgenerate
  // ====================== output ========================= 
  assign o_opt_vld  = w_maxpool_vld[0];
  assign o_opt_dout = w_maxpool_dat_bus;

endmodule

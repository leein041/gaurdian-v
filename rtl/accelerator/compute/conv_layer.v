
`include "defines.vh"
`include "network_config.vh"
module conv_layer (
    input                                      i_clk,
    input                                      i_rstn,
    input                                      i_clr,
    output                                     o_dn,
    // wgt    
    input                                      i_wr_dn, 
    input                                      i_wgt_vld,
    input  [ `WGT_BIT * `MAX_GROUP_FILTER-1:0] i_wgt_din,
    output                                     o_ws_wr_rdy,
    output                                     o_ws_rd_rdy,
    // ipt 
    output                                     o_ipt_rdy,
    input                                      i_ipt_vld,
    input  [  `IPT_BIT*`MAX_GROUP_CHANNEL-1:0] i_ipt_din,
    // opt
    input  [    `CLOG2_SAFE(`MAX_TILE_AREA):0] i_opt_area,
    input                                      i_opt_rdy,
    output                                     o_opt_vld,
    output [  `PSUM_BIT*`MAX_GROUP_FILTER-1:0] o_opt_dout,
    // temp
    input                                      i_relu_en,
    input  [`CLOG2_SAFE(`MAX_GROUP_CHANNEL):0] i_in_ch,
    input  [           `MAX_GROUP_CHANNEL-1:0] i_ch_mask,
    input  [            `MAX_GROUP_FILTER-1:0] i_filt_mask
);
  // ====================== parmeter =======================   
  localparam LINE_HEIGHT = `CONV_3X3_SIDE;
  localparam PE_OPT_BIT = `IPT_BIT + `WGT_BIT;
  localparam PU_OPT_BIT = PE_OPT_BIT + `CLOG2_SAFE(`CONV_3X3_AREA);
  localparam AT_OPT_BIT = PU_OPT_BIT + `CLOG2_SAFE(`MAX_GROUP_FILTER);
  localparam AD_OPT_BIT = AT_OPT_BIT + 1;


  integer i, j;
  genvar l, c, p;

  // ====================== reg ============================ 
  reg r_ws_wr_sel;
  reg r_ws_rd_sel;
  reg [1:0] r_buf_full;
  // interenal counter 
  reg [`CLOG2_SAFE(`MAX_GROUP_FILTER):0] r_ch_idx;
  reg [`CLOG2_SAFE(`CONV_3X3_AREA):0] r_pe_idx;
  // pu
  reg signed [`WGT_BIT-1:0] r_pu_wdat[0:`MAX_GROUP_FILTER-1];
  reg r_pu_wvld[0:`MAX_GROUP_CHANNEL-1];
  // done
  reg [`CLOG2_SAFE(`MAX_TILE_AREA):0] r_opt_cnt;
  reg r_dn;
  // ====================== wire ===========================   
  // line bufferS    
  wire lbuf_ptch_vld;
  wire [`IPT_BIT* `MAX_GROUP_CHANNEL*LINE_HEIGHT-1:0] lbuf_ptch_dat;
  wire lbuf_ptch_win_vld;
  // patch
  wire ptch_lbuf_rdy;
  wire ptch_pu_vld;
  wire lbuf_pu_req_wgt;
  wire [`IPT_BIT*`MAX_GROUP_CHANNEL*`CONV_3X3_AREA-1:0] ptch_pu_dat_bus;
  wire [`IPT_BIT*`CONV_3X3_AREA-1:0] ptch_pu_dat[0:`MAX_GROUP_CHANNEL-1];
  // pu
  wire [`MAX_GROUP_CHANNEL-1:0] pu_ptch_rdy[0:`MAX_GROUP_FILTER-1];
  wire [`MAX_GROUP_CHANNEL-1:0] w_pu_vld[0:`MAX_GROUP_FILTER-1];
  wire signed [PU_OPT_BIT-1:0] w_pu_dat[0:`MAX_GROUP_CHANNEL-1][0:`MAX_GROUP_FILTER-1];
  wire [`MAX_GROUP_CHANNEL*PU_OPT_BIT-1:0] w_pu_dat_bus[0:`MAX_GROUP_FILTER-1];
  // channel adder tree 
  wire w_cat_rdy[0:`MAX_GROUP_FILTER-1];
  wire w_cat_vld[0:`MAX_GROUP_FILTER-1];
  wire signed [AT_OPT_BIT-1:0] w_cat_dat[0:`MAX_GROUP_FILTER-1];
  wire signed [`PSUM_BIT-1:0] w_ex_cat_dat[0:`MAX_GROUP_FILTER-1];
  wire signed [`PSUM_BIT * `MAX_GROUP_FILTER-1:0] w_ex_cat_dat_bus;

  // ====================== assign =========================       
  assign o_ws_wr_rdy = ~r_buf_full[r_ws_wr_sel];
  assign o_ws_rd_rdy = r_buf_full[r_ws_rd_sel];

  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_ws_wr_sel <= 'b0;
      r_ws_rd_sel <= 'b0;
      r_buf_full  <= 'd0;
    end else begin
      if (i_wr_dn) begin
        r_buf_full[r_ws_wr_sel] <= 'b1;
        r_ws_wr_sel             <= ~r_ws_wr_sel;
      end
      if (o_dn) begin
        r_buf_full[r_ws_rd_sel] <= 'b0;
        r_ws_rd_sel             <= ~r_ws_rd_sel;
      end
    end
  end


  generate
    for (c = 0; c < `MAX_GROUP_CHANNEL; c = c + 1) begin
      for (p = 0; p < `CONV_3X3_AREA; p = p + 1) begin
        assign ptch_pu_dat[c][p*`IPT_BIT+:`IPT_BIT] = 
                  ptch_pu_dat_bus[c*`IPT_BIT + p*`IPT_BIT*`MAX_GROUP_CHANNEL+:`IPT_BIT];
      end
    end

    for (c = 0; c < `MAX_GROUP_CHANNEL; c = c + 1) begin
      for (p = 0; p < `MAX_GROUP_FILTER; p = p + 1) begin
        assign w_pu_dat_bus[p][c*PU_OPT_BIT+:PU_OPT_BIT] = w_pu_dat[p][c];
      end
    end

    for (p = 0; p < `MAX_GROUP_FILTER; p = p + 1) begin
      assign w_ex_cat_dat_bus[p*`PSUM_BIT+:`PSUM_BIT] = w_ex_cat_dat[p];
    end
  endgenerate

  assign o_dn = r_dn;
  // ====================== always ========================= 
  // conv layer compute done signal
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_cnt <= 'd0;
      r_dn      <= 'b0;
    end else begin
      // base
      r_dn <= 'b0;
      if (o_opt_vld && i_opt_rdy) begin
        if (r_opt_cnt == i_opt_area - 1) begin
          r_dn      <= 'b1;
          r_opt_cnt <= 'd0;
        end else begin
          r_opt_cnt <= r_opt_cnt + 'd1;
        end
      end
    end
  end
  // count internal index
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_pe_idx <= 'd0;
      r_ch_idx <= 'd0;
    end else if (i_wgt_vld) begin
      if (r_pe_idx < `CONV_3X3_AREA - 1) begin
        r_pe_idx <= r_pe_idx + 'd1;
      end else begin
        r_pe_idx <= 'd0;
        if (r_ch_idx < i_in_ch - 1) begin
          r_ch_idx <= r_ch_idx + 'd1;
        end else begin
          r_ch_idx <= 'd0;
        end
      end
    end
  end

  // select PU for initializing weight data
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      for (i = 0; i < `MAX_GROUP_FILTER; i = i + 1) begin
        r_pu_wdat[i] <= 'd0;
      end
      for (i = 0; i < `MAX_GROUP_CHANNEL; i = i + 1) begin
        r_pu_wvld[i] <= 'b0;
      end
    end else begin
      for (i = 0; i < `MAX_GROUP_CHANNEL; i = i + 1) begin
        if (i_wgt_vld && (r_ch_idx == i)) begin
          r_pu_wvld[i] <= 1'b1;
        end else begin
          r_pu_wvld[i] <= 1'b0;
        end
      end

      for (i = 0; i < `MAX_GROUP_FILTER; i = i + 1) begin
        r_pu_wdat[i] <= i_wgt_din[`WGT_BIT*i+:`WGT_BIT];
      end
    end
  end



  // ====================== module =========================    
  line_buffer #(
      .LINE_BIT   (`IPT_BIT * `MAX_GROUP_CHANNEL),
      .LINE_HEIGHT(LINE_HEIGHT),
      .LINE_WIDTH (`MAX_PAD_TILE_SIDE)              // padded
  ) inst_line_buffer (
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
      .o_req_wgt   (lbuf_pu_req_wgt),
      .o_window_vld(lbuf_ptch_win_vld)
  );
  patch #(
      .WIDTH     (`IPT_BIT * `MAX_GROUP_CHANNEL),
      .STRIDE    (`CONV_3X3_STRIDE),
      .PATCH_SIDE(`CONV_3X3_SIDE),
      .LINE_WIDTH(`MAX_PAD_TILE_SIDE)
  ) inst_conv_patch_buffer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_clr     (i_clr),
      // ipt
      .i_ipt_vld (lbuf_ptch_vld),
      .i_ipt_din (lbuf_ptch_dat),
      .o_ipt_rdy (ptch_lbuf_rdy),
      // opt
      .i_opt_rdy (pu_ptch_rdy[0][0]),
      .o_opt_vld (ptch_pu_vld),
      .o_opt_dout(ptch_pu_dat_bus),
      //
      .i_ptch_vld(lbuf_ptch_win_vld)
  );

  generate
    for (p = 0; p < `MAX_GROUP_FILTER; p = p + 1) begin : pu_array
      for (c = 0; c < `MAX_GROUP_CHANNEL; c = c + 1) begin : ch_array
        // process unit
        pu #(
            .CONV_AREA(`CONV_3X3_SIDE * `CONV_3X3_SIDE)
        ) inst_pu (
            .i_clk      (i_clk),
            .i_rstn     (i_rstn),
            .i_clr      (i_clr),
            .i_ws_wr_sel(r_ws_wr_sel),
            .i_ws_rd_sel(r_ws_rd_sel),
            .i_req_wgt  (ptch_pu_vld),                                    // TEST :
            .i_wgt_vld  (r_pu_wvld[c]),
            .i_wgt_din  (r_pu_wdat[p]),
            .o_ipt_rdy  (pu_ptch_rdy[p][c]),
            .i_ipt_vld  (ptch_pu_vld && i_ch_mask[c] && i_filt_mask[p]),
            .i_ipt_din  (ptch_pu_dat[c]),
            .i_opt_rdy  (w_cat_rdy[p]),
            .o_opt_vld  (w_pu_vld[p][c]),
            .o_opt_dout (w_pu_dat[p][c])
        );
      end

      // channel adder tree
      adder_tree #(
          .IPT_BIT(PU_OPT_BIT),
          .IPT_NUM(`MAX_GROUP_CHANNEL)
      ) inst_ch_at (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .o_ipt_rdy (w_cat_rdy[p]),
          .i_ipt_vld (w_pu_vld[p]),
          .i_ipt_din (w_pu_dat_bus[p]),
          .i_opt_rdy (i_opt_rdy),
          .o_opt_vld (w_cat_vld[p]),
          .o_opt_dout(w_cat_dat[p])
      );
      bit_extender #(
          .IPT_BIT(AT_OPT_BIT),
          .OPT_BIT(`PSUM_BIT),
          .LSB_PAD(0),
          .SIGNED (1)
      ) inst_bit_extender (
          .i_din (w_cat_dat[p]),
          .o_dout(w_ex_cat_dat[p])
      );
    end
  endgenerate
  // ====================== output ========================= 
  assign o_opt_vld  = w_cat_vld[0];
  assign o_opt_dout = w_ex_cat_dat_bus;

endmodule

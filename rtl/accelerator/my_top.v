
`include "defines.vh"
`include "network_config.vh"
module my_top #(
    parameter IPT_INIT_FILE     = "",
    //     
    parameter L1_WGT_INIT_FILE  = "",
    parameter L1_BIAS_INIT_FILE = "",
    //
    parameter L2_WGT_INIT_FILE  = "",
    parameter L2_BIAS_INIT_FILE = "",
    //  
    parameter L3_WGT_INIT_FILE  = "",
    parameter L3_BIAS_INIT_FILE = "",


    parameter PARAM_END_DUMMY = 0
) (
`ifdef DEBUG
    input                                i_rdy_test,
    output        [$clog2(`LAYER_NUM):0] o_lyr_num,
    output                               o_lyr_vld,
    output signed [        `IPT_BIT-1:0] o_lyr_dat,
`endif
    input                                i_clk,
    input                                i_rstn,
    input                                i_start,
    output                               o_done
);
  // ====================== parmeter =======================  
  genvar g, f;
  integer i;

  localparam L1_BIAS_ADDR = (`L1_BIAS_DEPTH <= 1) ? 1 : $clog2(`L1_BIAS_DEPTH);
  localparam L1_WGT_ADDR = (`L1_WGT_DEPTH <= 1) ? 1 : $clog2(`L1_WGT_DEPTH);
  localparam L2_BIAS_ADDR = (`L2_BIAS_DEPTH <= 1) ? 1 : $clog2(`L2_BIAS_DEPTH);
  localparam L2_WGT_ADDR = (`L2_WGT_DEPTH <= 1) ? 1 : $clog2(`L2_WGT_DEPTH);
  localparam L3_BIAS_ADDR = (`L3_BIAS_DEPTH <= 1) ? 1 : $clog2(`L3_BIAS_DEPTH);
  localparam L3_WGT_ADDR = (`L3_WGT_DEPTH <= 1) ? 1 : $clog2(`L3_WGT_DEPTH);
  localparam BIAS_ADDR = $clog2(`MAX_BIAS_DEPTH);
  localparam MAX_WGT_ADDR = $clog2(`MAX_WGT_DEPTH);
  localparam IPT_ADDR = $clog2(`MAX_IPT_AREA);
  localparam TILE_ADDR = $clog2(`MAX_TILE_AREA);
  localparam ACT_ADDR = $clog2(`MAX_IPT_AREA);

  wire                                     w_ctrl_rdy;
  wire [                   `LAYER_NUM-1:0] w_wbuf_vld;
  wire [                     `WGT_BIT-1:0] w_wbuf_dat       [0:`LAYER_NUM-1];
  // bias buffer
  wire [                   `LAYER_NUM-1:0] w_bias_sel;
  wire                                     w_bias_re;
  wire [                    BIAS_ADDR-1:0] w_bias_raddr;
  wire [                   `LAYER_NUM-1:0] w_bias_vld;
  wire [                     `IPT_BIT-1:0] w_bias_dat       [0:`LAYER_NUM-1];
  // global controller (GC) 
  wire                                     gc_bl_st;
  wire [      $clog2(`MAX_BIAS_DEPTH) : 0] gc_bl_rlen;
  wire [      $clog2(`MAX_BIAS_DEPTH)-1:0] gc_bl_st_addr;
  wire                                     gc_wl_st;
  wire [       $clog2(`MAX_WGT_DEPTH) : 0] gc_wl_rlen;
  wire [       $clog2(`MAX_WGT_DEPTH)-1:0] gc_wl_st_addr;
  wire                                     gc_tl_st;
  wire [          $clog2(`MAX_IPT_SIDE):0] gc_tl_org_x;
  wire [          $clog2(`MAX_IPT_SIDE):0] gc_tl_org_y;
  // intput mem (DDR)
  wire                                     ibuf_rc_vld;
  wire [                     `IPT_BIT-1:0] ibuf_rc_dat;
  // read controller (RC)
  wire                                     rc_bias_re;
  wire [      $clog2(`MAX_BIAS_DEPTH)-1:0] rc_bias_raddr;
  wire                                     rc_wbuf_re;
  wire [                 MAX_WGT_ADDR-1:0] rc_wbuf_raddr;
  wire                                     rc_ibuf_re;
  wire [                     IPT_ADDR-1:0] rc_ibuf_raddr;
  wire                                     rc_bl_rdn;
  wire                                     rc_wl_rdn;
  wire                                     rc_tl_rdn;
  wire                                     bias_rc_fifo_vld;
  wire [                     `IPT_BIT-1:0] bias_rc_fifo_dat;
  wire                                     wgt_rc_fifo_vld;
  wire [                     `WGT_BIT-1:0] wgt_rc_fifo_dat;
  wire                                     img_rc_fifo_vld;
  wire [  `IPT_BIT*`MAX_GROUP_CHANNEL-1:0] img_rc_fifo_dat;
  // FIFO 
  wire                                     fifo_bl_vld;
  wire [                     `IPT_BIT-1:0] fifo_bl_dat;
  wire                                     fifo_wl_vld;
  wire [                     `WGT_BIT-1:0] fifo_wl_dat;
  wire                                     fifo_tl_vld;
  wire [                    `IPT_BIT -1:0] fifo_tl_dat;
  // bias loader (BL) 
  wire                                     bl_gc_dn;
  wire [      $clog2(`MAX_BIAS_DEPTH) : 0] bl_rc_rlen;
  wire                                     bl_rc_req;
  wire [      $clog2(`MAX_BIAS_DEPTH)-1:0] bl_rc_raddr;
  wire                                     bl_lyr_vld;
  wire [                    `WGT_BIT -1:0] bl_lyr_dat;
  wire                                     bl_fifo_rdy;
  // weight loader (WL) 
  wire                                     wl_gc_dn;
  wire [       $clog2(`MAX_WGT_DEPTH) : 0] wl_rc_rlen;
  wire                                     wl_rc_req;
  wire [       $clog2(`MAX_WGT_DEPTH)-1:0] wl_rc_raddr;
  wire                                     wl_lyr_vld;
  wire [                    `WGT_BIT -1:0] wl_lyr_dat;
  wire                                     wl_fifo_rdy;
  // tile loader (TL) 
  wire                                     tl_gc_dn;
  wire [        $clog2(`MAX_IPT_AREA) : 0] tl_rc_rlen;
  wire                                     tl_rc_req;
  wire [        $clog2(`MAX_IPT_AREA)-1:0] tl_rc_raddr;
  wire                                     tl_fifo_rdy;
  wire                                     tl_lyr_vld;
  wire [`IPT_BIT * `MAX_GROUP_CHANNEL-1:0] tl_lyr_dat;
  // act buffer
  wire                                     w_abuf_we;
  wire [                     ACT_ADDR-1:0] w_abuf_waddr;
  wire [   `IPT_BIT*`MAX_GROUP_FILTER-1:0] w_abuf_wdat;
  wire                                     w_abuf_re;
  wire [                     ACT_ADDR-1:0] w_abuf_raddr;
  wire                                     w_abuf0_vld;
  wire [   `IPT_BIT*`MAX_GROUP_FILTER-1:0] w_abuf0_dat;
  wire                                     w_abuf1_vld;
  wire [   `IPT_BIT*`MAX_GROUP_FILTER-1:0] w_abuf1_dat;
  wire                                     w_abuf_vld;
  wire [   `IPT_BIT*`MAX_GROUP_FILTER-1:0] w_abuf_dat;
  // act/image buffer select
  wire                                     w_sel_vld;
  wire [   `IPT_BIT*`MAX_GROUP_FILTER-1:0] w_sel_dat;
  // skid
  wire                                     w_skid_rdy;
  wire [   `IPT_BIT*`MAX_GROUP_FILTER-1:0] w_skid_dat;
  wire                                     w_skid_vld;
  // layer   
  wire [          $clog2(`MAX_IPT_SIDE):0] w_img_side;
  wire                                     w_lyr_relu_en;
  wire                                     w_lyr_pad_en;
  wire                                     w_lyr_rdy;
  wire                                     w_conv_lyr_rdy;
  wire                                     w_conv_lyr_vld;
  wire [         `IPT_BIT*`MAX_FILTER-1:0] w_conv_lyr_dat;
  wire                                     w_pool_lyr_rdy;
  wire                                     w_pool_lyr_vld;
  wire [   `IPT_BIT*`MAX_GROUP_FILTER-1:0] w_pool_lyr_dat;
  wire [             $clog2(`LAYER_NUM):0] w_lyr_idx;
  // temp
  wire [         $clog2(`MAX_TILE_SIDE):0] w_tile_side;
  wire [      $clog2(`MAX_GROUP_FILTER):0] w_ch_num;
  wire [            $clog2(`MAX_FILTER):0] w_pu_num;
  wire                                     w_lyr_clr;
  wire [        $clog2(`MAX_LAYER_TYPE):0] w_lyr_type;
  wire [           `MAX_GROUP_CHANNEL-1:0] w_ch_mask;
  wire [            `MAX_GROUP_FILTER-1:0] w_pu_mask;
  wire                                     w_abuf_sel;
  // ====================== reg ============================  
  reg                                      r_wbuf_vld;
  reg  [                     `WGT_BIT-1:0] r_wbuf_dat;
  reg                                      r_bias_vld;
  reg  [                     `IPT_BIT-1:0] r_bias_dat;
  // ====================== assign =========================  
  assign w_sel_dat = (w_lyr_idx == 'd1) ? {{(`IPT_BIT*(`MAX_GROUP_FILTER-1)){1'b0}} ,ibuf_rc_dat} : w_abuf_dat;
  assign w_sel_vld = (w_lyr_idx == 'd1) ? ibuf_rc_vld : w_abuf_vld;

  assign w_lyr_rdy = (w_lyr_type == `LAYER_TYPE_CONV) ? w_conv_lyr_rdy : w_pool_lyr_rdy;

`ifdef DEBUG
  assign o_lyr_vld = w_conv_lyr_vld;
  assign o_lyr_dat = w_conv_lyr_dat;
  assign o_lyr_num = w_lyr_idx;
`endif
  // ====================== always =========================  
  // select WGT data
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_wbuf_vld <= 'b0;
      r_wbuf_dat <= 'd0;
    end else begin
      if (|w_wbuf_vld) begin
        r_wbuf_vld <= 'b1;
        for (i = 0; i < `LAYER_NUM; i = i + 1) begin
          if (w_wbuf_vld[i]) begin
            r_wbuf_dat <= w_wbuf_dat[i];
          end
        end
      end else r_wbuf_vld <= 'b0;
    end
  end
  // select bias data
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_bias_vld <= 'b0;
      r_bias_dat <= 'd0;
    end else begin
      if (|w_bias_vld) begin
        r_bias_vld <= 'b1;
        for (i = 0; i < `LAYER_NUM; i = i + 1) begin
          if (w_bias_vld[i]) begin
            r_bias_dat <= w_bias_dat[i];
          end
        end
      end else r_bias_vld <= 'b0;
    end
  end

  //


  // WGT DDR
  generate
    for (g = 1; g <= `LAYER_NUM; g = g + 1) begin : WGT_BUFFER
      localparam TEMP_WGT_DEPTH = (g == 1) ? `L1_WGT_DEPTH :
                                     (g == 2) ? `L2_WGT_DEPTH : 
                                     (g == 3) ? `L3_WGT_DEPTH : `L3_WGT_DEPTH;

      localparam TEMP_WGT_ADDR =  (g == 1) ? L1_WGT_ADDR :
                                     (g == 2) ? L2_WGT_ADDR : 
                                     (g == 3) ? L3_WGT_ADDR : L3_WGT_ADDR;

      localparam TEMP_WGT_INIT =  (g == 1) ? L1_WGT_INIT_FILE :
                                     (g == 2) ? L2_WGT_INIT_FILE : 
                                     (g == 3) ? L3_WGT_INIT_FILE : "";
      simple_dual_port_ram #(
          .WIDTH    (`WGT_BIT),
          .DEPTH    (TEMP_WGT_DEPTH),
          .INIT_FILE(TEMP_WGT_INIT)
      ) wgt_buf (
          .i_clk  (i_clk),
          .i_rstn (i_rstn),
          .i_re   (rc_wbuf_re && (w_lyr_idx == g)),
          .i_raddr(rc_wbuf_raddr[TEMP_WGT_ADDR-1:0]),
          .i_we   (),
          .i_waddr(),
          .i_wdin (),
          .o_vld  (w_wbuf_vld[g]),
          .o_dout (w_wbuf_dat[g])
      );
    end
  endgenerate
  // bias buffer
  generate
    for (g = 1; g <= `LAYER_NUM; g = g + 1) begin : BIAS_BUFFER
      localparam TEMP_BIAS_DEPTH = (g == 1) ? `L1_BIAS_DEPTH :
                                     (g == 2) ? `L2_BIAS_DEPTH : 
                                     (g == 3) ? `L3_BIAS_DEPTH : `L3_BIAS_DEPTH;

      localparam TEMP_BIAS_ADDR = (g == 1) ? L1_BIAS_ADDR :
                                    (g == 2) ? L2_BIAS_ADDR : 
                                    (g == 3) ? L3_BIAS_ADDR : L3_BIAS_ADDR;

      localparam TEMP_BIAS_INIT = (g == 1) ?  L1_BIAS_INIT_FILE :
                                    (g == 2)  ? L2_BIAS_INIT_FILE : 
                                    (g == 3)  ? L3_BIAS_INIT_FILE : "";
      simple_dual_port_ram #(
          .WIDTH    (`IPT_BIT),
          .DEPTH    (TEMP_BIAS_DEPTH),
          .INIT_FILE(TEMP_BIAS_INIT)
      ) bias_buf (
          .i_clk  (i_clk),
          .i_rstn (i_rstn),
          .i_re   (rc_bias_re && (w_lyr_idx == g)),
          .i_raddr(rc_bias_raddr[TEMP_BIAS_ADDR-1:0]),
          .i_we   (),
          .i_waddr(),
          .i_wdin (),
          .o_vld  (w_bias_vld[g]),
          .o_dout (w_bias_dat[g])
      );
    end
  endgenerate
  // input buffer (DDR)
  simple_dual_port_ram #(
      .WIDTH    (`IPT_BIT),
      .DEPTH    (`MAX_IPT_AREA),
      .MEM_TYPE (`BRAM_TYPE),
      .INIT_FILE(IPT_INIT_FILE)
  ) input_buf (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_re   (rc_ibuf_re),
      .i_raddr(rc_ibuf_raddr),
      .i_we   (),
      .i_waddr(),
      .i_wdin (),
      .o_vld  (ibuf_rc_vld),
      .o_dout (ibuf_rc_dat)
  );
  // ====================== module ========================= 
  rcursiv_global_ctrl #() inst_global_ctl (
      .i_clk         (i_clk),
      .i_rstn        (i_rstn),
      .i_st          (i_start),
      .o_ctrl_rdy    (w_ctrl_rdy),
      // bias
      .o_bias_re     (w_bias_re),
      .o_bias_raddr  (w_bias_raddr),
      .o_bias_sel    (w_bias_sel),
      // bias loader (BL) 
      .o_bl_st       (gc_bl_st),
      .o_bl_rlen     (gc_bl_rlen),
      .o_bl_st_addr  (gc_bl_st_addr),
      .i_bl_dn       (),
      // weight loader (WL)
      .o_wl_st       (gc_wl_st),
      .o_wl_rlen     (gc_wl_rlen),
      .o_wl_st_addr  (gc_wl_st_addr),
      .i_wl_dn       (wl_gc_dn),
      // tile loader (TL) 
      .o_tl_st       (gc_tl_st),
      .o_tl_org_x    (gc_tl_org_x),        // origin position
      .o_tl_org_y    (gc_tl_org_y),
      .i_tl_dn       (tl_gc_dn),
      // act buffer
      .o_abuf_re     (w_abuf_re),
      .o_abuf_raddr  (w_abuf_raddr),
      .o_abuf_we     (w_abuf_we),
      .o_abuf_waddr  (w_abuf_waddr),
      .o_abuf_wdout  (w_abuf_wdat),
      // skid
      .i_skid_rdy    (w_skid_rdy),
      // lyr  
      .i_conv_lyr_vld(w_conv_lyr_vld),
      .i_conv_lyr_din(w_conv_lyr_dat),
      .i_pool_lyr_vld(w_pool_lyr_vld),
      .i_pool_lyr_din(w_pool_lyr_dat),
      .o_lyr_clr     (w_lyr_clr),
      .o_lyr_relu_en (w_lyr_relu_en),
      .o_lyr_pad_en  (w_lyr_pad_en),
      .o_lyr_idx     (w_lyr_idx),
      // opt mem
      .o_obuf_we     (output_bram_wen),
      .o_obuf_addr   (output_bram_waddr),
      .o_obuf_dout   (L3_p_out),
      .o_done        (o_done),
      // temp
      .o_img_side    (w_img_side),
      .o_tile_side   (w_tile_side),
      .o_ch_num      (w_ch_num),
      .o_pu_num      (w_pu_num),
      .o_lyr_type    (w_lyr_type),
      // group 
      .o_abuf_sel    (w_abuf_sel),
      .o_ch_mask     (w_ch_mask),
      .o_pu_mask     (w_pu_mask)
  );

  // bias read controller (BC)
  read_controller #(
      .WIDTH(`IPT_BIT),
      .DEPTH(`MAX_BIAS_DEPTH)
  ) inst_bias_rd_ctrl (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // WL 
      .i_rlen    (bl_rc_rlen),
      .i_req     (bl_rc_req),
      .i_raddr   (bl_rc_raddr),
      .o_rdn     (rc_bl_rdn),
      // DDR
      .o_re      (rc_bias_re),
      .o_raddr   (rc_bias_raddr),
      .i_rvld    (r_bias_vld),
      .i_rdin    (r_bias_dat),
      // opt
      .o_opt_vld (bias_rc_fifo_vld),
      .o_opt_dout(bias_rc_fifo_dat)
  );
  // weight read controller (WC)
  read_controller #(
      .WIDTH(`WGT_BIT),
      .DEPTH(`MAX_WGT_DEPTH)
  ) inst_wgt_rd_ctrl (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // WL 
      .i_rlen    (wl_rc_rlen),
      .i_req     (wl_rc_req),
      .i_raddr   (wl_rc_raddr),
      .o_rdn     (rc_wl_rdn),
      // DDR
      .o_re      (rc_wbuf_re),
      .o_raddr   (rc_wbuf_raddr),
      .i_rvld    (r_wbuf_vld),
      .i_rdin    (r_wbuf_dat),
      // opt
      .o_opt_vld (wgt_rc_fifo_vld),
      .o_opt_dout(wgt_rc_fifo_dat)
  );
  // image read controller (RC)
  read_controller #(
      .WIDTH(`IPT_BIT * `MAX_GROUP_CHANNEL),
      .DEPTH(`MAX_IPT_AREA)
  ) inst_img_rd_ctrl (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // TL
      .i_rlen    (tl_rc_rlen),
      .i_req     (tl_rc_req),
      .i_raddr   (tl_rc_raddr),
      .o_rdn     (rc_tl_rdn),
      // DDR
      .o_re      (rc_ibuf_re),
      .o_raddr   (rc_ibuf_raddr),
      .i_rvld    (ibuf_rc_vld),
      .i_rdin    (ibuf_rc_dat),
      // opt
      .o_opt_vld (img_rc_fifo_vld),
      .o_opt_dout(img_rc_fifo_dat)
  );

  // bias fifo (FIFO)
  fifo #(
      .WIDTH(`IPT_BIT),
      .DEPTH(`MAX_BIAS_DEPTH)
  ) inst_bias_fifo (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // RC
      .o_ipt_rdy (),
      .i_ipt_vld (bias_rc_fifo_vld),
      .i_ipt_din (bias_rc_fifo_dat),
      // TL
      .i_opt_rdy (bl_fifo_rdy),
      .o_opt_vld (fifo_bl_vld),
      .o_opt_dout(fifo_bl_dat)
  );
  // weight fifo (FIFO)
  fifo #(
      .WIDTH(`WGT_BIT),
      .DEPTH(`MAX_WGT_DEPTH)
  ) inst_wgt_fifo (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // RC
      .o_ipt_rdy (),
      .i_ipt_vld (wgt_rc_fifo_vld),
      .i_ipt_din (wgt_rc_fifo_dat),
      // TL
      .i_opt_rdy (wl_fifo_rdy),
      .o_opt_vld (fifo_wl_vld),
      .o_opt_dout(fifo_wl_dat)
  );

  // image fifo (FIFO)
  fifo #(
      .WIDTH(`IPT_BIT * `MAX_GROUP_CHANNEL),
      .DEPTH(`MAX_TILE_AREA)
  ) inst_img_fifo (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // RC
      .o_ipt_rdy (),
      .i_ipt_vld (img_rc_fifo_vld),
      .i_ipt_din (img_rc_fifo_dat),
      // TL
      .i_opt_rdy (tl_fifo_rdy),
      .o_opt_vld (fifo_tl_vld),
      .o_opt_dout(fifo_tl_dat)
  );

  // bias loader (BL)
  loader inst_bias_loader (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_clr     (),
      .i_st      (gc_bl_st),
      .o_dn      (),
      //
      .i_rlen    (gc_bl_rlen),
      .i_st_addr (gc_bl_st_addr),
      //
      .o_rlen    (bl_rc_rlen),
      .o_req     (bl_rc_req),
      .o_raddr   (bl_rc_raddr),
      .i_rdn     (rc_bl_rdn),
      //
      .o_ipt_rdy (bl_fifo_rdy),
      .i_ipt_vld (fifo_bl_vld),
      .i_ipt_din (fifo_bl_dat),
      //
      .i_opt_rdy ('b1),            // TODO :
      .o_opt_vld (bl_lyr_vld),
      .o_opt_dout(bl_lyr_dat)
  );
  // weight loader (WL)
  loader inst_weight_loader (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_clr     (),
      .i_st      (gc_wl_st),
      .o_dn      (wl_gc_dn),
      //
      .i_rlen    (gc_wl_rlen),
      .i_st_addr (gc_wl_st_addr),
      //
      .o_rlen    (wl_rc_rlen),
      .o_req     (wl_rc_req),
      .o_raddr   (wl_rc_raddr),
      .i_rdn     (rc_wl_rdn),
      //
      .o_ipt_rdy (wl_fifo_rdy),
      .i_ipt_vld (fifo_wl_vld),
      .i_ipt_din (fifo_wl_dat),
      //
      .i_opt_rdy ('b1),            // TODO :
      .o_opt_vld (wl_lyr_vld),
      .o_opt_dout(wl_lyr_dat)
  );
  // tile loader (TL)
  tile_loader #(
      .TILE_SIDE(`MAX_TILE_SIDE),
      .HALO     (1)
  ) inst_tile_loader (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_st      (gc_tl_st),
      .o_dn      (tl_gc_dn),
      // GC
      .i_img_side(w_img_side),
      .i_org_x   (gc_tl_org_x),
      .i_org_y   (gc_tl_org_y),
      // RC
      .o_rlen    (tl_rc_rlen),
      .o_req     (tl_rc_req),
      .o_raddr   (tl_rc_raddr),
      .i_rdn     (rc_tl_rdn),
      // FIFO
      .o_ipt_rdy (tl_fifo_rdy),
      .i_ipt_vld (fifo_tl_vld),
      .i_ipt_din (fifo_tl_dat),
      // opt (layer)
      .i_opt_rdy (w_lyr_rdy),
      .o_opt_vld (tl_lyr_vld),
      .o_opt_dout(tl_lyr_dat)
  );

  // act buffer 1
  simple_dual_port_ram #(
      .WIDTH   (`IPT_BIT * `MAX_GROUP_FILTER),
      .DEPTH   (`MAX_ACT_DPETH),
      .MEM_TYPE(`URAM_TYPE)
  ) inst_act_buf_0 (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_re   (w_abuf_re),
      .i_raddr(w_abuf_raddr),
      .i_we   (w_abuf_we),
      .i_waddr(w_abuf_waddr),
      .i_wdin (w_abuf_wdat),
      .o_vld  (w_abuf0_vld),
      .o_dout (w_abuf0_dat)
  );
  // act buffer 2
  simple_dual_port_ram #(
      .WIDTH   (`IPT_BIT * `MAX_GROUP_FILTER),
      .DEPTH   (`MAX_ACT_DPETH),
      .MEM_TYPE(`URAM_TYPE)
  ) inst_act_buf_1 (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_re   (w_abuf_re),
      .i_raddr(w_abuf_raddr),
      .i_we   (w_abuf_we),
      .i_waddr(w_abuf_waddr),
      .i_wdin (w_abuf_wdat),
      .o_vld  (w_abuf1_vld),
      .o_dout (w_abuf1_dat)
  );

  // image/act - layer skid buffer
  skid_buffer #(
      .WIDTH   (`IPT_BIT * `MAX_GROUP_FILTER),
      .LATENCY (3),
      .MEM_SKID(1)
  ) inst_skid_buffer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // ipt
      .i_ipt_vld (w_sel_vld),
      .i_ipt_din (w_sel_dat),
      .o_ipt_rdy (w_skid_rdy),
      // opt
      .i_opt_rdy (w_lyr_rdy),
      .o_opt_dout(w_skid_dat),
      .o_opt_vld (w_skid_vld)
  );

  //      _____     _____    ____                      _       _   _                    _                          
  //     |___ /_  _|___ /   / ___|___  _ ____   _____ | |_   _| |_(_) ___  _ __   | |    __ _ _   _  ___ _ __ 
  //       |_ \ \/ / |_ \  | |   / _ \| '_ \ \ / / _ \| | | | | __| |/ _ \| '_ \  | |   / _` | | | |/ _ \ '__|
  //      ___) >  < ___) | | |__| (_) | | | \ V / (_) | | |_| | |_| | (_) | | | | | |__| (_| | |_| |  __/ |   
  //     |____/_/\_\____/   \____\___/|_| |_|\_/ \___/|_|\__,_|\__|_|\___/|_| |_| |_____\__,_|\__, |\___|_|   
  //                                                                                          |___/           
  conv_layer inst_conv_layer (
      .i_clk      (i_clk),
      .i_rstn     (i_rstn),
      .i_clr      (w_lyr_clr),
      // wgt 
      .i_wgt_vld  (wl_lyr_vld),
      .i_wgt_din  (wl_lyr_dat),
      // bias
      .i_bias_vld (r_bias_vld),
      .i_bias_din (r_bias_dat),
      // ipt 
      .o_ipt_rdy  (w_conv_lyr_rdy),
      .i_ipt_vld  (tl_lyr_vld),
      .i_ipt_din  (tl_lyr_dat),
      // opt  
      .i_opt_rdy  (w_ctrl_rdy),
      .o_opt_vld  (w_conv_lyr_vld),
      .o_opt_dout (w_conv_lyr_dat),
      // temp
      .i_tile_side(w_tile_side),
      .i_relu_en  (w_lyr_relu_en),
      .i_ch_num   (w_ch_num),
      .i_pu_num   (w_pu_num),
      .i_ch_mask  (w_ch_mask),
      .i_pu_mask  (w_pu_mask)
  );
  //      __  __              ____             _   _                          
  //     |  \/  | __ ___  __ |  _ \ ___   ___ | | | |    __ _ _   _  ___ _ __ 
  //     | |\/| |/ _` \ \/ / | |_) / _ \ / _ \| | | |   / _` | | | |/ _ \ '__|
  //     | |  | | (_| |>  <  |  __/ (_) | (_) | | | |__| (_| | |_| |  __/ |   
  //     |_|  |_|\__,_/_/\_\ |_|   \___/ \___/|_| |_____\__,_|\__, |\___|_|   
  //                                                          |___/           
  pool_layer inst_pool_layer (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // ipt
      .o_ipt_rdy (w_pool_lyr_rdy),
      .i_ipt_vld (w_skid_vld),
      .i_ipt_din (w_skid_dat),
      // opt
      .i_opt_rdy (w_ctrl_rdy),
      .o_opt_vld (w_pool_lyr_vld),
      .o_opt_dout(w_pool_lyr_dat),
      //    
      .i_img_side(w_tile_side),
      .i_lbuf_st ((w_lyr_clr & {`MAX_GROUP_FILTER{w_lyr_type == `LAYER_TYPE_MAXPOOL}}))
  );

endmodule

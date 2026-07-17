

`include "defines.vh"
`include "network_config.vh"
module rcursiv_global_ctrl #(
    localparam MAX_BIAS_ADDR = $clog2(`MAX_BIAS_DEPTH),
    localparam MAX_WGT_ADDR  = $clog2(`MAX_WGT_DEPTH),
    localparam MAX_IPT_ADDR  = $clog2(`MAX_IPT_AREA),
    localparam MAX_TILE_ADDR = $clog2(`MAX_TILE_AREA),
    localparam MAX_ACT_ADDR  = $clog2(`MAX_ACT_DPETH),
    localparam MAX_OPT_ADDR  = MAX_IPT_ADDR

) (
    input                                   i_clk,
    input                                   i_rstn,
    input                                   i_st,
    output                                  o_ctrl_rdy,
    // bias buffer
    output                                  o_bias_re,
    output [             MAX_BIAS_ADDR-1:0] o_bias_raddr,
    output [                `LAYER_NUM-1:0] o_bias_sel,
    // bias loader
    output                                  o_bl_st,
    output [    $clog2(`MAX_WGT_DEPTH) : 0] o_bl_rlen,
    output [    $clog2(`MAX_WGT_DEPTH)-1:0] o_bl_st_addr,
    input                                   i_bl_dn,
    // weight loader
    output                                  o_wl_st,
    output [    $clog2(`MAX_WGT_DEPTH) : 0] o_wl_rlen,
    output [    $clog2(`MAX_WGT_DEPTH)-1:0] o_wl_st_addr,
    input                                   i_wl_dn,
    // tile loader 
    output                                  o_tl_st,
    output [       $clog2(`MAX_IPT_SIDE):0] o_tl_org_x,      // origin position
    output [       $clog2(`MAX_IPT_SIDE):0] o_tl_org_y,
    input                                   i_tl_dn,
    // img buffer  
    output                                  o_abuf_sel,
    output                                  o_abuf_re,
    output [              MAX_ACT_ADDR-1:0] o_abuf_raddr,
    output                                  o_abuf_we,
    output [              MAX_ACT_ADDR-1:0] o_abuf_waddr,
    output [`OPT_BIT*`MAX_GROUP_FILTER-1:0] o_abuf_wdout,
    // skid
    input                                   i_skid_rdy,
    // layer    
    input                                   i_conv_lyr_vld,
    input  [`OPT_BIT*`MAX_GROUP_FILTER-1:0] i_conv_lyr_din,
    input                                   i_pool_lyr_vld,
    input  [`OPT_BIT*`MAX_GROUP_FILTER-1:0] i_pool_lyr_din,
    output                                  o_lyr_clr,
    output [     $clog2(`MAX_LAYER_TYPE):0] o_lyr_type,
    output                                  o_lyr_relu_en,
    output                                  o_lyr_pad_en,
    output [         $clog2( `LAYER_NUM):0] o_lyr_idx,
    // opt mem  
    output                                  o_obuf_we,
    output [              MAX_OPT_ADDR-1:0] o_obuf_addr,
    output [                  `OPT_BIT-1:0] o_obuf_dout,
    output                                  o_done,
    // temp 
    output [      $clog2(`MAX_TILE_SIDE):0] o_tile_side,
    output [       $clog2(`MAX_IPT_SIDE):0] o_img_side,
    output [   $clog2(`MAX_GROUP_FILTER):0] o_ch_num,
    output [         $clog2(`MAX_FILTER):0] o_pu_num,
    output [        `MAX_GROUP_CHANNEL-1:0] o_ch_mask,
    output [         `MAX_GROUP_FILTER-1:0] o_pu_mask
);
  // ====================== parmeter ======================= 
  localparam IDLE = 4'd0;
  localparam LOAD_WGT_BIAS = 4'd1;
  localparam LOAD_TILE = 4'd2;  // load image and write layer 1 output at act buffer  
  localparam COMP = 4'd3;  // load image and write layer 1 output at act buffer  
  localparam NEXT = 4'd4;
  localparam STATE_END = 4'd5;


  integer                                               i;
  // ====================== wire =========================== 
  wire                                                  w_lyr_vld;
  wire    [             `OPT_BIT*`MAX_GROUP_FILTER-1:0] w_lyr_dat;
  // ====================== reg ============================ 
  reg     [                      $clog2(STATE_END)-1:0] r_cstat;  // current state
  reg     [                      $clog2(STATE_END)-1:0] r_nstat;  // next state   
  // ctrl
  reg                                                   r_ctrl_rdy;
  // bias loader  
  reg                                                   r_bl_st;
  reg     [                            MAX_BIAS_ADDR:0] r_bl_rlen;
  reg     [                          MAX_BIAS_ADDR-1:0] r_bl_st_addr;
  // weight loader  
  reg                                                   r_wl_st;
  reg     [                             MAX_WGT_ADDR:0] r_wl_rlen;
  reg     [                           MAX_WGT_ADDR-1:0] r_wl_st_addr;
  // bias buffer 
  reg                                                   r_bias_re; 
  reg     [                           `LAYER_NUM-1 : 0] r_bias_sel;
  // tile loader (TL)
  reg                                                   r_tl_st;
  reg     [                    $clog2(`MAX_IPT_SIDE):0] r_tl_org_x;
  reg     [                    $clog2(`MAX_IPT_SIDE):0] r_tl_org_y;
  // ipt buffer  
  reg                                                   r_ibuf_vld;
  reg     [                                 `IPT_BIT:0] r_ibuf_rdat;
  // act buffer
  reg                                                   r_abuf_sel;
  reg                                                   r_abuf_re;
  reg     [                           MAX_ACT_ADDR : 0] r_abuf_rcnt;
  reg     [                         MAX_ACT_ADDR - 1:0] r_abuf_raddr;
  reg                                                   r_abuf_we;
  reg     [                           MAX_ACT_ADDR : 0] r_abuf_wcnt;
  reg     [                         MAX_ACT_ADDR - 1:0] r_abuf_waddr;
  reg     [            `OPT_BIT*`MAX_GROUP_CHANNEL-1:0] r_abuf_wdat;
  // layer 
  reg     [                       $clog2(`LAYER_NUM):0] r_lyr_idx;
  reg     [                    $clog2(`MAX_IPT_AREA):0] r_ipt_depth;
  reg     [                    $clog2(`MAX_IPT_AREA):0] r_ipt_grp_depth;
  reg     [                    $clog2(`MAX_IPT_AREA):0] r_opt_depth;
  reg     [                   $clog2(`MAX_TILE_SIDE):0] r_tile_side;
  reg     [                    $clog2(`MAX_IPT_SIDE):0] r_img_side;
  reg     [                     $clog2(`MAX_CHANNEL):0] r_cur_ch;
  reg     [               $clog2(`MAX_GROUP_CHANNEL):0] r_lyr_group_ch;
  reg     [                      $clog2(`MAX_FILTER):0] r_cur_pu;
  reg                                                   r_lyr_pad;
  reg                                                   r_lyr_relu;
  // opt  
  reg                                                   r_o_done;
  reg                                                   r_obuf_we;
  reg     [                             MAX_OPT_ADDR:0] r_obuf_wcnt;
  reg     [                           MAX_OPT_ADDR-1:0] r_obuf_waddr;
  reg     [                                 `OPT_BIT:0] r_obuf_wdat;
  // line buffer 
  reg                                                   r_lyr_clr;
  reg     [                  $clog2(`MAX_LAYER_TYPE):0] r_lyr_type;
  // group  
  reg     [               $clog2(`MAX_GROUP_CHANNEL):0] r_channel_o;
  reg     [  $clog2(`MAX_FILTER / `MAX_GROUP_FILTER):0] r_filt_grp_last;
  reg     [  $clog2(`MAX_FILTER / `MAX_GROUP_FILTER):0] r_filter_grp_idx;
  reg     [$clog2(`MAX_CHANNEL / `MAX_GROUP_CHANNEL):0] r_ch_grp_last;
  reg     [$clog2(`MAX_CHANNEL / `MAX_GROUP_CHANNEL):0] r_channel_grp_idx;
  // 
  reg     [                     $clog2(`MAX_CHANNEL):0] r_ch_st_idx;
  reg     [               $clog2(`MAX_GROUP_CHANNEL):0] r_ch_remain;
  reg     [                     `MAX_GROUP_CHANNEL-1:0] r_ch_mask;
  reg     [                      $clog2(`MAX_FILTER):0] r_pu_st_idx;
  reg     [                $clog2(`MAX_GROUP_FILTER):0] r_pu_remain;
  reg     [                      `MAX_GROUP_FILTER-1:0] r_pu_mask;
  // ====================== assign ========================= 
  assign o_ctrl_rdy    = r_ctrl_rdy;
  assign o_lyr_idx     = r_lyr_idx;
  assign o_lyr_clr     = r_lyr_clr;
  assign o_lyr_type    = r_lyr_type;
  assign o_lyr_relu_en = r_lyr_relu;
  assign o_lyr_pad_en  = r_lyr_pad;
  assign o_tile_side   = r_tile_side;
  assign o_img_side    = r_img_side;
  assign o_bl_st       = r_bl_st;
  assign o_bl_rlen     = r_bl_rlen;
  assign o_bl_st_addr  = r_bl_st_addr;
  assign o_wl_st       = r_wl_st;
  assign o_wl_rlen     = r_wl_rlen;
  assign o_wl_st_addr  = r_wl_st_addr;
  assign o_bias_re     = r_bias_re; 
  assign o_bias_sel    = r_bias_sel;
  assign o_tl_st       = r_tl_st;
  assign o_tl_org_x    = r_tl_org_x;
  assign o_tl_org_y    = r_tl_org_y;
  assign o_abuf_sel    = r_abuf_sel;
  assign o_abuf_re     = r_abuf_re;
  assign o_abuf_raddr  = r_abuf_raddr;
  assign o_abuf_we     = r_abuf_we;
  assign o_abuf_waddr  = r_abuf_waddr;
  assign o_abuf_wdout  = r_abuf_wdat;
  assign o_obuf_we     = r_obuf_we;
  assign o_obuf_addr   = r_obuf_waddr;
  assign o_obuf_dout   = r_obuf_wdat;
  assign o_done        = r_o_done;
  assign o_ch_num      = r_cur_ch;
  assign o_pu_num      = r_cur_pu;
  assign o_ch_mask     = r_ch_mask;
  assign o_pu_mask     = r_pu_mask;


  assign w_lyr_vld     = (r_lyr_type == `LAYER_TYPE_CONV) ? i_conv_lyr_vld : i_pool_lyr_vld;
  assign w_lyr_dat     = (r_lyr_type == `LAYER_TYPE_CONV) ? i_conv_lyr_din : i_pool_lyr_din;
  // ====================== FSM ============================ 
  //  initialize and update state register    
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_cstat <= IDLE;
    end else begin
      r_cstat <= r_nstat;
    end
  end
  // compute next state 
  always @(*) begin
    r_nstat = r_cstat;
    case (r_cstat)
      IDLE: if (i_st) r_nstat = LOAD_WGT_BIAS;

      LOAD_WGT_BIAS: if (i_wl_dn) r_nstat = LOAD_TILE;
      LOAD_TILE: r_nstat = COMP;
      COMP:
      if (r_opt_depth <= r_abuf_wcnt) begin
        if (r_channel_grp_idx < r_ch_grp_last) r_nstat = COMP;
        else if (r_filter_grp_idx < r_filt_grp_last) r_nstat = LOAD_WGT_BIAS;
        else r_nstat = NEXT;
      end

      NEXT: r_nstat = IDLE;

      default: ;
    endcase
  end
  //
  always @(*) begin
    r_tile_side = 'd0;
    r_img_side  = 'd0;
    r_cur_ch    = 'd0;
    r_cur_pu    = 'd0;
    r_wl_rlen   = 'd0;
    r_bl_rlen   = 'd0;
    r_bias_sel  = 3'b000;
    r_abuf_sel  = 'b0;
    case (r_lyr_idx)
      1: begin
        r_lyr_type = `L1_TYPE;
        r_cur_ch = (`L1_CHANNEL_GROUP_NUM < `L1_CHANNEL) ? `L1_CHANNEL_GROUP_NUM : `L1_CHANNEL;
        r_cur_pu = (`L1_FILTER_GROUP_NUM < `L1_FILTER) ? `L1_FILTER_GROUP_NUM : `L1_FILTER;
        r_lyr_relu = `L1_RELU;
        r_lyr_pad = `L1_PAD;
        r_img_side = `L1_IPT_SIDE;
        r_tile_side = (`L1_IPT_SIDE < `MAX_TILE_SIDE) ? `L1_IPT_SIDE : `MAX_TILE_SIDE;
        r_ipt_depth = `L1_IPT_SIDE * `L1_IPT_SIDE;
        r_opt_depth = `L1_OPT_SIDE * `L1_OPT_SIDE;
        r_wl_rlen = `L1_WGT_DEPTH / (`L1_FILTER_GROUP_NUM * `L1_CHANNEL_GROUP_NUM);
        r_bl_rlen = `L1_BIAS_DEPTH / `L1_FILTER_GROUP_NUM;
        //
        r_filt_grp_last = `L1_FILTER_GROUP_NUM - 1;
        r_ch_grp_last = `L1_CHANNEL_GROUP_NUM - 1;
        r_ch_remain = r_cur_ch - r_ch_st_idx;
        r_pu_remain = r_cur_pu - r_pu_st_idx;
        for (i = 0; i < `MAX_GROUP_CHANNEL; i = i + 1) r_ch_mask[i] = (i < r_ch_remain);
        for (i = 0; i < `MAX_GROUP_FILTER; i = i + 1) r_pu_mask[i] = (i < r_pu_remain);
        // 
        r_bias_sel = 3'b001;
        r_abuf_sel = 'b0;
      end
      // Layer 2
      2: begin
        r_lyr_type = `L2_TYPE;
        r_cur_ch = (`L2_CHANNEL_GROUP_NUM < `L2_CHANNEL) ? `L2_CHANNEL_GROUP_NUM : `L2_CHANNEL;
        r_cur_pu = (`L2_FILTER_GROUP_NUM < `L2_FILTER) ? `L2_FILTER_GROUP_NUM : `L2_FILTER;
        r_lyr_relu = `L2_RELU;
        r_lyr_pad = `L2_PAD;
        r_img_side = `L2_IPT_SIDE;
        r_tile_side = (`L2_IPT_SIDE < `MAX_TILE_SIDE) ? `L2_IPT_SIDE : `MAX_TILE_SIDE;
        r_ipt_depth = `L2_IPT_SIDE * `L2_IPT_SIDE;
        r_opt_depth = `L2_OPT_SIDE * `L2_OPT_SIDE;
        r_wl_rlen = `L2_WGT_DEPTH / (`L2_FILTER_GROUP_NUM * `L2_CHANNEL_GROUP_NUM);
        r_bl_rlen = `L2_BIAS_DEPTH / `L2_FILTER_GROUP_NUM;
        //      
        r_filt_grp_last = `L2_FILTER_GROUP_NUM - 1;
        r_ch_grp_last = `L2_CHANNEL_GROUP_NUM - 1;
        r_ch_remain = r_cur_ch - r_ch_st_idx;
        r_pu_remain = r_cur_pu - r_pu_st_idx;
        for (i = 0; i < `MAX_GROUP_CHANNEL; i = i + 1) r_ch_mask[i] = (i < r_ch_remain);
        for (i = 0; i < `MAX_GROUP_FILTER; i = i + 1) r_pu_mask[i] = (i < r_pu_remain);
        // 
        r_bias_sel = 3'b010;
        r_abuf_sel = 'b1;
      end
      3: begin
        r_lyr_type = `L3_TYPE;
        r_cur_ch = (`L3_CHANNEL_GROUP_NUM < `L3_CHANNEL) ? `L3_CHANNEL_GROUP_NUM : `L3_CHANNEL;
        r_cur_pu = (`L3_FILTER_GROUP_NUM < `L3_FILTER) ? `L3_FILTER_GROUP_NUM : `L3_FILTER;
        r_lyr_relu = `L3_RELU;
        r_lyr_pad = `L3_PAD;
        r_img_side = `L3_IPT_SIDE;
        r_tile_side = (`L3_IPT_SIDE < `MAX_TILE_SIDE) ? `L3_IPT_SIDE : `MAX_TILE_SIDE;
        r_ipt_depth = `L3_IPT_SIDE * `L3_IPT_SIDE;
        r_opt_depth = `L3_OPT_SIDE * `L3_OPT_SIDE;
        r_wl_rlen = `L3_WGT_DEPTH / (`L3_FILTER_GROUP_NUM * `L3_CHANNEL_GROUP_NUM);
        r_bl_rlen = `L3_BIAS_DEPTH / `L3_FILTER_GROUP_NUM;
        //
        r_filt_grp_last = `L3_FILTER_GROUP_NUM - 1;
        r_ch_grp_last = `L3_CHANNEL_GROUP_NUM - 1;
        r_ch_remain = r_cur_ch - r_ch_st_idx;
        r_pu_remain = r_cur_pu - r_pu_st_idx;
        for (i = 0; i < `MAX_GROUP_CHANNEL; i = i + 1) r_ch_mask[i] = (i < r_ch_remain);
        for (i = 0; i < `MAX_GROUP_FILTER; i = i + 1) r_pu_mask[i] = (i < r_pu_remain);
        // 
        r_bias_sel = 3'b100;
        r_abuf_sel = 'b0;
      end
      NEXT:    ;
      default: ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_ctrl_rdy        <= 'b0;
      r_lyr_clr         <= 'b0;
      r_lyr_idx         <= 'd1;
      r_bl_st           <= 'b0;
      r_bl_st_addr      <= 'd0;
      r_wl_st           <= 'b0;
      r_wl_st_addr      <= 'd0; 
      r_tl_st           <= 'b0; 
      r_abuf_re         <= 'd0;
      r_abuf_raddr      <= {MAX_ACT_ADDR{1'b1}};
      r_abuf_we         <= 'd0;
      r_abuf_waddr      <= {MAX_ACT_ADDR{1'b1}};
      r_abuf_rcnt       <= 'd0;
      r_abuf_wcnt       <= 'd0;
      r_abuf_wdat       <= 'd0;
      r_obuf_we         <= 'd0;
      r_obuf_waddr      <= {MAX_OPT_ADDR{1'b1}};
      r_obuf_wcnt       <= 'd0;
      r_obuf_wdat       <= 'd0;
      r_o_done          <= 'd0;
      // local ctrl
      r_filter_grp_idx  <= 'd0;
      r_channel_grp_idx <= 'd0;
      r_ch_st_idx       <= 'd0;
      r_pu_st_idx       <= 'd0;
      //
      r_tl_org_x        <= 'd0;
      r_tl_org_y        <= 'd0;

    end else begin
      r_ctrl_rdy <= 'b1;  // 일단 항상 받기   
      r_o_done   <= 'd0;
      case (r_cstat)
        IDLE: begin
          if (i_st) begin
            r_wl_st <= 'b1;
            r_bl_st <= 'b1;
          end
        end
        LOAD_WGT_BIAS: begin
          // reset previous data
          r_wl_st      <= 'b0;
          // BL
          r_bl_st_addr <= 'd0;
          // WL
          r_wl_st_addr <= 'd0;
        end
        LOAD_TILE: begin
          r_tl_st   <= 'b1;
          r_lyr_clr <= 'b1;
        end
        COMP: begin
          // init previous couter  
          r_tl_st   <= 'b0;
          r_lyr_clr <= 'b0;


          // count write adress for result of layer computation 
          if (w_lyr_vld) begin
            r_abuf_we    <= 'd1;
            r_abuf_wcnt  <= r_abuf_wcnt + 'd1;
            r_abuf_waddr <= r_abuf_waddr + 'd1;
            r_abuf_wdat  <= w_lyr_dat;
          end else begin
            r_abuf_we <= 'd0;
          end

          // done signal
          if (r_obuf_wcnt == r_ipt_depth) r_o_done <= 1'b1;
        end
        NEXT: begin

        end
        default: ;
      endcase
    end
  end

  // ====================== module ========================= 
endmodule

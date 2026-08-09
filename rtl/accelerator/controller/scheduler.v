

`include "defines.vh"
`include "network_config.vh"
module scheduler #(
    localparam FBUF_DEPTH = `MAX_FILTER_GROUP_NUM * `MAX_IPT_AREA,
    localparam WGT_BANK_DEPTH = `MAX_CHANNEL * `CONV_3X3_AREA
) (
    // System 
    input                                                    i_clk,
    input                                                    i_rstn,
    input                                                    i_st,
    output reg                                               o_dn,
    output reg                                               o_ctrl_rdy,
    // Layer Config 
    output reg [                `CLOG2_SAFE(`LAYER_NUM)-1:0] o_lyr_idx,
    input      [           `CLOG2_SAFE(`MAX_LAYER_TYPE)-1:0] i_lyr_type,
    input      [                 `CLOG2_SAFE(`MAX_FILTER):0] i_filt,
    input      [       `CLOG2_SAFE(`MAX_FILTER_GROUP_NUM):0] i_filt_grp_num,
    input      [                `CLOG2_SAFE(`MAX_CHANNEL):0] i_ch,
    input      [      `CLOG2_SAFE(`MAX_CHANNEL_GROUP_NUM):0] i_ch_grp_num,
    input      [              `CLOG2_SAFE(`MAX_TILE_SIDE):0] i_tile_side,
    input      [               `CLOG2_SAFE(`MAX_TILE_NUM):0] i_tile_num,
    input      [`CLOG2_SAFE(`MAX_IPT_SIDE/`MAX_TILE_SIDE):0] i_tile_num_x,
    input      [`CLOG2_SAFE(`MAX_IPT_SIDE/`MAX_TILE_SIDE):0] i_tile_num_y,
    input      [              `CLOG2_SAFE(`MAX_TILE_AREA):0] i_lyr_opt_area,
    input      [               `CLOG2_SAFE(`MAX_IPT_SIDE):0] i_img_side,
    // Address Generator Control
    output reg                                               o_nxt_lyr,
    output reg                                               o_nxt_filt_grp,
    output reg                                               o_nxt_tile_col,
    output reg                                               o_nxt_tile_row,
    output reg                                               o_nxt_ch_grp,
    output reg                                               o_br_prefetch,
    output reg                                               o_wgt_prefetch,
    // Module Start
    output reg                                               o_bl_st,
    output reg                                               o_br_st,
    output reg                                               o_wl_st,
    output reg                                               o_wr_st,
    output reg                                               o_tl_st,
    output reg                                               o_tr_st,
    output reg                                               o_psc_st,
    output reg                                               o_ts_st,
    // Module Done
    input                                                    i_bl_dn,
    input                                                    i_br_dn,
    input                                                    i_wl_dn,
    input                                                    i_wr_dn,
    input                                                    i_tl_dn,
    input                                                    i_tr_dn,
    input                                                    i_lyr_dn,
    input                                                    i_ts_dn,
    //
    // Layer Control
    output reg                                               o_lyr_clr,
    output reg                                               o_lyr_ws_swap,
    output     [              `CLOG2_SAFE(`MAX_TILE_AREA):0] o_lyr_opt_num,
    // Tile loader Metadata
    output reg [               `CLOG2_SAFE(`MAX_IPT_SIDE):0] o_tl_org_x,
    output reg [               `CLOG2_SAFE(`MAX_IPT_SIDE):0] o_tl_org_y,
    // Layer Metadata
    output reg [           `CLOG2_SAFE(`MAX_GROUP_FILTER):0] o_in_ch,
    output reg [                 `CLOG2_SAFE(`MAX_FILTER):0] o_out_ch,
    output reg [                     `MAX_GROUP_CHANNEL-1:0] o_ch_mask,
    output reg [                      `MAX_GROUP_FILTER-1:0] o_filt_mask,
    // Feature Buffer control
    output reg                                               o_fbuf_wr_swap,
    output reg                                               o_fbuf_rd_swap,
    output reg                                               o_bb_rd_swap,
    output reg                                               o_bb_wr_swap,
    output reg                                               o_wb_wr_swap,
    output reg                                               o_wb_rd_swap,
    output reg                                               o_tb_wr_swap,
    output reg                                               o_tb_rd_swap,
    output reg                                               o_pp_bias_swap,
    output reg                                               o_ag_commit_addr
);
  // ====================== parmeter ======================= 
  localparam IDLE = 1;
  // bias
  localparam START_BL = 2;
  localparam WAIT_BL = 3;
  localparam START_BR = 4;
  localparam WAIT_BR = 5;
  // weight
  localparam START_WL = 6;
  localparam WAIT_WL = 7;
  localparam START_WR = 8;
  localparam WAIT_WR = 9;
  // tile
  localparam START_TL = 10;
  localparam WAIT_TL = 11;
  localparam START_TR = 12;
  localparam START_TS = 13;
  localparam RUN_LAYER = 14;
  localparam WAIT_TS = 15;
  localparam WAIT_PRELOD = 16;

  localparam NEXT_FILTER_GRP = 17;
  localparam NEXT_TILE = 18;
  localparam NEXT_CHANNEL_GRP = 19;
  localparam NEXT_LAYER = 20;

  localparam DONE = 21;

  localparam STATE_END = 22;


  integer                                                    i;
  // ====================== reg ============================ 
  reg     [                      `CLOG2_SAFE(STATE_END)-1:0] r_cstat;  // current state
  reg     [                      `CLOG2_SAFE(STATE_END)-1:0] r_nstat;  // next state     
  reg     [                     `CLOG2_SAFE(`MAX_CHANNEL):0] r_ch_idx;
  reg     [`CLOG2_SAFE(`MAX_CHANNEL / `MAX_GROUP_CHANNEL):0] r_ch_grp_idx;
  reg     [                     `CLOG2_SAFE(`MAX_CHANNEL):0] r_ch_left;
  // filter  
  reg     [                `CLOG2_SAFE(`MAX_GROUP_FILTER):0] r_filt_idx;
  reg     [    `CLOG2_SAFE(`MAX_FILTER/`MAX_GROUP_FILTER):0] r_filt_grp_idx;
  reg     [                      `CLOG2_SAFE(`MAX_FILTER):0] r_filt_left;
  // tile   
  reg     [   `CLOG2_SAFE(`MAX_IPT_AREA / `MAX_TILE_AREA):0] r_tile_idx;
  reg     [   `CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] r_tile_cnt_x;
  reg     [   `CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] r_tile_cnt_y;
  //
  reg     [                                             1:0] r_prefetch_tl;
  reg     [                                             1:0] r_prefetch_stage;
  //
  reg                                                        r_bl_busy;
  reg                                                        r_br_busy;
  reg                                                        r_wl_busy;
  reg                                                        r_wr_busy;
  reg                                                        r_tl_busy;
  reg                                                        r_tr_busy;
  // ====================== wire ===========================  
  wire                                                       w_ch_grp_first;
  wire                                                       w_tile_first;
  wire                                                       w_filt_grp_first;
  wire                                                       w_ch_grp_last;
  wire                                                       w_tile_last;
  wire                                                       w_filt_grp_last;
  // ====================== assign =========================  
  assign w_ch_grp_first   = (r_ch_grp_idx == 0);
  assign w_tile_first     = (r_tile_idx == 0);
  assign w_filt_grp_first = (r_filt_idx == 0);
  assign w_ch_grp_last    = (r_ch_grp_idx == i_ch_grp_num - 1);
  assign w_tile_last      = (r_tile_idx == i_tile_num - 1);
  assign w_filt_grp_last  = (r_filt_grp_idx == i_filt_grp_num - 1);
  assign o_lyr_opt_num    = i_lyr_opt_area;


  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_bl_busy <= 'b0;
      r_br_busy <= 'b0;
      r_wl_busy <= 'b0;
      r_wr_busy <= 'b0;
      r_tl_busy <= 'b0;
      r_tr_busy <= 'b0;
    end else begin
      if (o_bl_st) r_bl_busy <= 'b1;
      else if (i_bl_dn) r_bl_busy <= 'b0;
      if (o_br_st) r_br_busy <= 'b1;
      else if (i_br_dn) r_br_busy <= 'b0;
      if (o_wl_st) r_wl_busy <= 'b1;
      else if (i_wl_dn) r_wl_busy <= 'b0;
      if (o_wr_st) r_wr_busy <= 'b1;
      else if (i_wr_dn) r_wr_busy <= 'b0;
      if (o_tl_st) r_tl_busy <= 'b1;
      else if (i_tl_dn) r_tl_busy <= 'b0;
      if (o_tr_st) r_tr_busy <= 'b1;
      else if (i_tr_dn) r_tr_busy <= 'b0;
    end
  end
  // ====================== FSM ============================ 
  //  initialize and update state register    
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_cstat <= IDLE;
    end else begin
      r_cstat <= r_nstat;
    end
  end
  //

  always @(*) begin
    r_ch_left   = i_ch - r_ch_idx;
    r_filt_left = i_filt - r_filt_idx;
    for (i = 0; i < `MAX_GROUP_CHANNEL; i = i + 1) o_ch_mask[i] = (i < r_ch_left);
    for (i = 0; i < `MAX_GROUP_FILTER; i = i + 1) o_filt_mask[i] = (i < r_filt_left);
    if (r_ch_left > `MAX_GROUP_CHANNEL) o_in_ch = `MAX_GROUP_CHANNEL;
    else o_in_ch = r_ch_left;
    if (r_filt_left > `MAX_GROUP_FILTER) o_out_ch = `MAX_GROUP_FILTER;
    else o_out_ch = r_filt_left;
  end
  // compute next state 
  always @(*) begin
    r_nstat = r_cstat;
    case (r_cstat)

      IDLE: begin
        if (i_st) r_nstat = START_BL;
      end

      START_BL: begin
        r_nstat = WAIT_BL;
      end

      WAIT_BL: begin
        if (i_bl_dn) r_nstat = START_WL;
      end

      START_WL: begin
        r_nstat = WAIT_WL;
      end

      WAIT_WL: begin
        if (i_wl_dn) r_nstat = START_TL;
      end

      START_TL: begin
        r_nstat = WAIT_TL;
      end

      WAIT_TL: begin
        if (i_tl_dn) r_nstat = START_BR;
      end

      START_BR: begin
        r_nstat = WAIT_BR;
      end

      WAIT_BR: begin
        if (i_br_dn) r_nstat = START_WR;
      end

      START_WR: begin
        r_nstat = WAIT_WR;
      end

      WAIT_WR: begin
        if (i_wr_dn) r_nstat = START_TR;
      end

      START_TR: begin
        r_nstat = RUN_LAYER;
      end

      RUN_LAYER: begin
        if (i_lyr_dn) begin
          if (w_ch_grp_last) r_nstat = WAIT_TS;
          else r_nstat = WAIT_PRELOD;
        end
      end

      WAIT_TS: begin
        if (i_ts_dn) begin
          r_nstat = WAIT_PRELOD;
        end
      end

      WAIT_PRELOD: begin
        if (!r_tl_busy) begin
          if (!w_ch_grp_last) r_nstat = NEXT_CHANNEL_GRP;
          else if (!w_tile_last) r_nstat = NEXT_TILE;
          else if (!w_filt_grp_last) r_nstat = NEXT_FILTER_GRP;
          else r_nstat = NEXT_LAYER;
        end
      end

      NEXT_FILTER_GRP: begin
        r_nstat = START_TR;
      end

      NEXT_TILE: begin
        r_nstat = START_TR;
      end

      NEXT_CHANNEL_GRP: begin
        r_nstat = START_TR;
      end

      NEXT_LAYER: begin
        if (o_lyr_idx != `LAYER_NUM - 1) begin
          r_nstat = START_BL;
        end else begin
          r_nstat = DONE;
        end
      end

      DONE: begin
        r_nstat = IDLE;
      end

      default: ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      o_dn             <= 'd0;
      o_ctrl_rdy       <= 'b0;
      o_lyr_clr        <= 'b0;
      o_lyr_ws_swap    <= 'b0;
      o_lyr_idx        <= 'd0;
      o_bl_st          <= 'b0;
      o_br_st          <= 'b0;
      o_wl_st          <= 'b0;
      o_wr_st          <= 'b0;
      o_tl_st          <= 'b0;
      o_tr_st          <= 'b0;
      o_psc_st         <= 'b0;
      o_ts_st          <= 'b0;
      //
      o_fbuf_wr_swap   <= 'b0;
      o_fbuf_rd_swap   <= 'b0;
      o_bb_rd_swap     <= 'b0;
      o_bb_wr_swap     <= 'b0;
      o_wb_wr_swap     <= 'b0;
      o_wb_rd_swap     <= 'b0;
      o_tb_wr_swap     <= 'b0;
      o_tb_rd_swap     <= 'b0;
      o_pp_bias_swap   <= 'b0;
      o_ag_commit_addr <= 'b0;
      // local ctrl  
      r_filt_grp_idx   <= 'd0;
      r_filt_idx       <= 'd0;
      r_ch_grp_idx     <= 'd0;
      r_ch_idx         <= 'd0;
      r_tile_idx       <= 'd0;
      r_tile_cnt_x     <= 'd0;
      r_tile_cnt_y     <= 'd0;
      o_tl_org_x       <= 'd0;
      o_tl_org_y       <= 'd0;
      //    
      //
      o_nxt_lyr        <= 'b0;
      o_nxt_filt_grp   <= 'b0;
      o_nxt_tile_col   <= 'b0;
      o_nxt_tile_row   <= 'b0;
      o_nxt_ch_grp     <= 'b0;
      o_br_prefetch    <= 'b0;
      o_wgt_prefetch   <= 'b0;
      //
      r_prefetch_stage <= 'd0;
      r_prefetch_tl    <= 'd0;
    end else begin
      o_ag_commit_addr <= 'b0;  // TODO
      o_ctrl_rdy       <= 'b1;  // 일단 항상 받기    
      o_lyr_clr        <= 'b0;
      o_nxt_lyr        <= 'b0;
      o_nxt_filt_grp   <= 'b0;
      o_nxt_tile_col   <= 'b0;
      o_nxt_tile_row   <= 'b0;
      o_nxt_ch_grp     <= 'b0;
      o_wgt_prefetch   <= 'b0;
      case (r_cstat)
        IDLE: begin
          o_dn <= 'b0;
          if (i_st) begin
            o_fbuf_wr_swap <= 'b1;
          end
        end

        START_BL: begin
          o_fbuf_rd_swap <= 'b0;
          o_fbuf_wr_swap <= 'b0;
          o_bl_st        <= 'b1;
        end

        WAIT_BL: begin
          o_bl_st <= 'b0;
        end

        START_WL: begin
          o_wl_st <= 'b1;
        end

        WAIT_WL: begin
          o_wl_st <= 'b0;
        end

        START_TL: begin
          o_tl_st <= 'b1;
        end

        WAIT_TL: begin
          o_tl_st <= 'b0;
        end

        START_BR: begin
          o_br_st <= 'b1;
        end

        WAIT_BR: begin
          o_br_st <= 'b0;
        end

        START_WR: begin
          o_wr_st <= 'b1;
        end

        WAIT_WR: begin
          o_wr_st <= 'b0;
        end

        START_TR: begin
          o_wb_rd_swap <= 'b0;
          o_tb_rd_swap <= 'b0;
          o_tr_st      <= 'b1;
          if (r_ch_grp_idx == 0) o_psc_st <= 'b1;
          if (r_ch_grp_idx == i_ch_grp_num - 1) o_ts_st <= 'b1;
        end

        RUN_LAYER: begin
          case (r_prefetch_stage)
            0: begin
              r_prefetch_stage <= 1;

              if (w_ch_grp_first && w_tile_first && !w_filt_grp_last) begin
                o_wgt_prefetch <= 'b1;
                o_br_prefetch  <= 'b1;
              end
              if (!w_ch_grp_last) begin
                o_nxt_ch_grp <= 'b1;
              end else if (!w_tile_last) begin
                if (r_tile_cnt_x < i_tile_num_x - 1) begin
                  o_nxt_tile_col <= 'b1;
                  r_tile_cnt_x   <= r_tile_cnt_x + 'd1;
                  o_tl_org_x     <= o_tl_org_x + i_tile_side;
                end else begin
                  r_tile_cnt_x <= 'd0;
                  o_tl_org_x   <= 0;
                  if (r_tile_cnt_y < i_tile_num_y - 1) begin
                    o_nxt_tile_row <= 'b1;
                    r_tile_cnt_y   <= r_tile_cnt_y + 'd1;
                    o_tl_org_y     <= o_tl_org_y + i_tile_side;
                  end
                end
              end else if (!w_filt_grp_last) begin
                o_nxt_filt_grp <= 'b1;
                o_tl_org_x     <= 0;
                o_tl_org_y     <= 0;
                r_tile_cnt_x   <= 'd0;
                r_tile_cnt_y   <= 'd0;
              end else if (o_lyr_idx != `LAYER_NUM - 1) begin
                o_nxt_lyr    <= 'b1;
                o_tl_org_x   <= 'd0;
                o_tl_org_y   <= 'd0;
                r_tile_cnt_x <= 'd0;
                r_tile_cnt_y <= 'd0;
              end
            end

            1: begin
              r_prefetch_stage <= 2;
              o_lyr_ws_swap    <= 'b1;
              o_nxt_ch_grp     <= 'b0;
              o_nxt_tile_col   <= 'b0;
              o_nxt_tile_row   <= 'b0;
              o_nxt_filt_grp   <= 'b0;
              o_nxt_lyr        <= 'b0;
              o_br_prefetch    <= 'b0;
              o_wgt_prefetch   <= 'b0;
              if (w_ch_grp_first && w_tile_first) begin
                o_pp_bias_swap <= 'b1;
              end
              if (w_ch_grp_first && w_tile_first && !w_filt_grp_last) begin
                o_br_st      <= 'b1;
                o_bb_rd_swap <= 'b1;
                o_wl_st      <= 'b1;
                o_wb_wr_swap <= 'b1;
              end
              if (w_ch_grp_last && w_tile_last && !w_filt_grp_last) begin
                o_wb_rd_swap <= 'b1;
              end
              if (!(w_ch_grp_last && w_tile_last && w_filt_grp_last)) begin
                o_wr_st      <= 'b1;
                o_tl_st      <= 'b1;
                o_tb_wr_swap <= 'b1;
              end
            end

            2: begin
              o_pp_bias_swap <= 'b0;
              o_bb_wr_swap   <= 'b0;
              o_br_st        <= 'b0;
              o_bb_rd_swap   <= 'b0;
              o_wb_rd_swap   <= 'b0;
              o_wl_st        <= 'b0;
              o_wr_st        <= 'b0;
              o_tl_st        <= 'b0;
              o_wb_wr_swap   <= 'b0;
              o_lyr_ws_swap  <= 'b0;
              o_tb_wr_swap   <= 'b0;
            end

            default: ;
          endcase

          o_tb_rd_swap <= 'b0;
          o_tr_st      <= 'b0;
          o_psc_st     <= 'b0;
          o_ts_st      <= 'b0;
        end

        WAIT_TS: begin
        end

        WAIT_PRELOD: begin
        end

        NEXT_FILTER_GRP: begin
          o_lyr_clr        <= 'b1;
          o_tb_rd_swap     <= 'b1;
          r_prefetch_stage <= 'd0;
          o_ag_commit_addr <= 'b1;
          // 
          r_tile_idx       <= 'd0;
          r_ch_grp_idx     <= 'd0;
          r_ch_idx         <= 'd0;
          r_filt_grp_idx   <= r_filt_grp_idx + 'd1;
          r_filt_idx       <= r_filt_idx + `MAX_GROUP_FILTER;
        end

        NEXT_TILE: begin
          o_lyr_clr        <= 'b1;
          o_tb_rd_swap     <= 'b1;
          r_prefetch_stage <= 'd0;
          o_ag_commit_addr <= 'b1;
          // 
          r_ch_grp_idx     <= 'd0;
          r_ch_idx         <= 'd0;
          r_tile_idx       <= r_tile_idx + 'd1;

        end

        NEXT_CHANNEL_GRP: begin
          o_lyr_clr        <= 'b1;
          o_tb_rd_swap     <= 'b1;
          r_prefetch_stage <= 'd0;
          o_ag_commit_addr <= 'b1;
          // 
          r_ch_grp_idx     <= r_ch_grp_idx + 'd1;
          r_ch_idx         <= r_ch_idx + `MAX_GROUP_CHANNEL;
        end

        NEXT_LAYER: begin
          if (o_lyr_idx != `LAYER_NUM - 1) begin
            o_lyr_clr        <= 'b1;
            r_prefetch_stage <= 'd0;
            o_ag_commit_addr <= 'b1;
            //
            o_lyr_idx        <= o_lyr_idx + 'd1;
            o_fbuf_rd_swap   <= 'b1;
            o_fbuf_wr_swap   <= 'b1;
            r_filt_grp_idx   <= 'd0;
            r_filt_idx       <= 'd0;
            r_tile_idx       <= 'd0;
            r_ch_grp_idx     <= 'd0;
            r_ch_idx         <= 'd0;
          end
        end

        DONE: begin
          o_dn <= 'b1;
        end

        default: ;
      endcase
    end
  end

  // ====================== module ========================= 
endmodule

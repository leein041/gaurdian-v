

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
    output reg                                               o_tb_wr_swap,
    output reg                                               o_tb_rd_swap,
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
  localparam START_TS = 14;
  localparam RUN_LAYER = 13;
  localparam WAIT_TS = 14;

  localparam NEXT_FILTER_GRP = 15;
  localparam NEXT_TILE = 16;
  localparam NEXT_CHANNEL_GRP = 17;
  localparam NEXT_LAYER = 18;

  localparam WAIT_ADDR = 19;
  localparam COMMIT_ADDR = 20;

  localparam DONE = 21;

  localparam STATE_END = 22;


  integer                                                    i;
  // ====================== wire ===========================  
  // ====================== reg ============================ 
  reg     [                      `CLOG2_SAFE(STATE_END)-1:0] r_cstat;  // current state
  reg     [                      `CLOG2_SAFE(STATE_END)-1:0] r_nstat;  // next state    
  reg     [                      `CLOG2_SAFE(STATE_END)-1:0] r_after_commit;  // next state    
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
  reg     [                                             1:0] r_prefetch_dn;
  // ====================== assign =========================  
  assign o_lyr_opt_num = i_lyr_opt_area;
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
  end
  // compute next state 
  always @(*) begin
    r_nstat = r_cstat;
    case (r_cstat)

      IDLE: begin
        if (i_st) r_nstat = START_TL;
      end

      START_TL: begin
        r_nstat = WAIT_TL;
      end

      WAIT_TL: begin
        if (i_tl_dn) r_nstat = START_BL;
      end

      START_BL: begin
        r_nstat = WAIT_BL;
      end

      WAIT_BL: begin
        if (i_bl_dn) r_nstat = START_BR;
      end

      START_BR: begin
        r_nstat = WAIT_BR;
      end

      WAIT_BR: begin
        if (i_br_dn) r_nstat = START_WL;
      end

      START_WL: begin
        r_nstat = WAIT_WL;
      end

      WAIT_WL: begin
        if (i_wl_dn) r_nstat = START_WR;
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
          if (r_ch_grp_idx != i_ch_grp_num - 1) r_nstat = NEXT_CHANNEL_GRP;
          else r_nstat = WAIT_TS;
        end
      end

      WAIT_TS: begin
        if (i_ts_dn) begin
          if (r_tile_idx != i_tile_num - 1) r_nstat = NEXT_TILE;
          else if (r_filt_grp_idx != i_filt_grp_num - 1) r_nstat = NEXT_FILTER_GRP;
          else r_nstat = NEXT_LAYER;
        end
      end

      NEXT_FILTER_GRP: begin
        r_after_commit = START_BL;
        r_nstat        = COMMIT_ADDR;
      end

      NEXT_TILE: begin
        r_after_commit = START_WR;
        r_nstat        = COMMIT_ADDR;
      end

      NEXT_CHANNEL_GRP: begin
        r_after_commit = START_WR;
        r_nstat        = COMMIT_ADDR;
      end

      NEXT_LAYER: begin
        if (o_lyr_idx != `LAYER_NUM - 1) begin
          r_after_commit = START_TL;
          r_nstat        = COMMIT_ADDR;
        end else begin
          r_nstat = DONE;
        end
      end

      WAIT_ADDR: begin
        r_nstat = COMMIT_ADDR;
      end

      COMMIT_ADDR: begin
        r_nstat = r_after_commit;
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
      o_tb_wr_swap     <= 'b0;
      o_tb_rd_swap     <= 'b0;
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
      //
      r_prefetch_dn    <= 'd0;
    end else begin
      o_ag_commit_addr <= 'b0;  // TODO
      o_ctrl_rdy       <= 'b1;  // 일단 항상 받기    
      o_lyr_clr        <= 'b0;
      o_nxt_lyr        <= 'b0;
      o_nxt_filt_grp   <= 'b0;
      o_nxt_tile_col   <= 'b0;
      o_nxt_tile_row   <= 'b0;
      o_nxt_ch_grp     <= 'b0;
      case (r_cstat)
        IDLE: begin
          o_dn <= 'b0;
          if (i_st) begin
            o_fbuf_wr_swap <= 'b1;
          end
        end

        START_TL: begin
          o_fbuf_wr_swap <= 'b0;
          o_tb_wr_swap   <= 'b1;
          o_tl_st        <= 'b1;
        end

        WAIT_TL: begin
          o_tb_wr_swap <= 'b0;
          o_tl_st      <= 'b0;
        end

        START_BL: begin
          o_bl_st <= 'b1;
        end

        WAIT_BL: begin
          o_bl_st <= 'b0;
        end

        START_BR: begin
          o_br_st <= 'b1;
        end

        WAIT_BR: begin
          o_br_st <= 'b0;
        end

        START_WL: begin
          o_wl_st <= 'b1;
        end

        WAIT_WL: begin
          o_wl_st <= 'b0;
        end

        START_WR: begin
          o_wr_st <= 'b1;
        end

        WAIT_WR: begin
          o_wr_st <= 'b0;
        end

        START_TR: begin
          o_tr_st      <= 'b1;
          o_tb_rd_swap <= 'b1;
          if (r_ch_grp_idx == 0) o_psc_st <= 'b1;
          if (r_ch_grp_idx == i_ch_grp_num - 1) o_ts_st <= 'b1;
        end

        RUN_LAYER: begin
          if (r_prefetch_dn == 0) begin
            r_prefetch_dn <= 1;
            if (r_ch_grp_idx != i_ch_grp_num - 1) begin
              o_nxt_ch_grp <= 'b1;
            end else if (r_tile_idx != i_tile_num - 1) begin
              if (r_tile_cnt_x < i_tile_num_x - 1) begin
                r_tile_cnt_x <= r_tile_cnt_x + 'd1;
                o_tl_org_x <= o_tl_org_x + i_tile_side;
                o_nxt_tile_col <= 'b1;
              end else begin
                r_tile_cnt_x <= 'd0;
                o_tl_org_x   <= 0;
                if (r_tile_cnt_y < i_tile_num_y - 1) begin
                  r_tile_cnt_y <= r_tile_cnt_y + 'd1;
                  o_tl_org_y <= o_tl_org_y + i_tile_side;
                  o_nxt_tile_row <= 'b1;
                end
              end

            end else if (r_filt_grp_idx != i_filt_grp_num - 1) begin
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
          end else if (r_prefetch_dn == 1) begin
            r_prefetch_dn  <= 2;
            o_nxt_ch_grp   <= 'b0;
            o_nxt_tile_col <= 'b0;
            o_nxt_tile_row <= 'b0;
            o_nxt_filt_grp <= 'b0;
            o_nxt_lyr      <= 'b0;
            if(r_ch_grp_idx == i_ch_grp_num - 1 && r_tile_idx == i_tile_num-1 && r_filt_grp_idx == i_filt_grp_num-1 )begin
            end else begin
              o_tl_st <= 'b1;
              o_tb_wr_swap <= 'b1;
            end
          end else begin
            o_tl_st      <= 'b0;
            o_tb_wr_swap <= 'b0;
          end

          o_tb_rd_swap <= 'b0;
          o_tr_st      <= 'b0;
          o_psc_st     <= 'b0;
          o_ts_st      <= 'b0;
        end

        NEXT_FILTER_GRP: begin
          o_lyr_clr      <= 'b1;
          r_tile_idx     <= 'd0;
          r_ch_grp_idx   <= 'd0;
          r_ch_idx       <= 'd0;
          //
          r_filt_grp_idx <= r_filt_grp_idx + 'd1;
          r_filt_idx     <= r_filt_idx + `MAX_GROUP_FILTER;
        end

        NEXT_TILE: begin
          o_lyr_clr    <= 'b1;
          r_ch_grp_idx <= 'd0;
          r_ch_idx     <= 'd0;
          r_tile_idx   <= r_tile_idx + 'd1;

        end

        NEXT_CHANNEL_GRP: begin
          o_lyr_clr    <= 'b1;
          r_ch_grp_idx <= r_ch_grp_idx + 'd1;
          r_ch_idx     <= r_ch_idx + `MAX_GROUP_CHANNEL;
        end

        NEXT_LAYER: begin
          if (o_lyr_idx != `LAYER_NUM - 1) begin
            o_lyr_idx      <= o_lyr_idx + 'd1;
            o_lyr_clr      <= 'b1;
            o_fbuf_rd_swap <= 'b1;
            o_fbuf_wr_swap <= 'b1;
            // init filt 
            r_filt_grp_idx <= 'd0;
            r_filt_idx     <= 'd0;
            // init tile
            r_tile_idx     <= 'd0;
            // init ch 
            r_ch_grp_idx   <= 'd0;
            r_ch_idx       <= 'd0;
          end
        end

        WAIT_ADDR: begin
        end

        COMMIT_ADDR: begin
          o_fbuf_rd_swap   <= 'b0;
          o_fbuf_wr_swap   <= 'b0;
          r_prefetch_dn    <= 'd0;
          o_ag_commit_addr <= 'b1;
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

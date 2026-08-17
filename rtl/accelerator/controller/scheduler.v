

`include "defines.vh"
`include "network_config.vh"
module scheduler #(
    localparam FBUF_DEPTH = `MAX_FILTER_GROUP_NUM * `MAX_IPT_AREA * `CONV_LAYER_NUM,
    localparam WGT_BANK_DEPTH = `MAX_CHANNEL * `CONV_3X3_AREA
) (
    // System 
    input                                                    i_clk,
    input                                                    i_rstn,
    input                                                    i_st,
    output reg                                               o_dn,
    output reg                                               o_ctrl_rdy,
    // Layer Config  
    input      [                 `CLOG2_SAFE(`MAX_FILTER):0] i_filt,
    input      [       `CLOG2_SAFE(`MAX_FILTER_GROUP_NUM):0] i_filt_grp_num,
    input      [                `CLOG2_SAFE(`MAX_CHANNEL):0] i_ch,
    input      [      `CLOG2_SAFE(`MAX_CHANNEL_GROUP_NUM):0] i_ch_grp_num,
    input      [              `CLOG2_SAFE(`MAX_TILE_SIDE):0] i_tile_ipt_side,
    input      [               `CLOG2_SAFE(`MAX_TILE_NUM):0] i_tile_num,
    input      [`CLOG2_SAFE(`MAX_IPT_SIDE/`MAX_TILE_SIDE):0] i_tile_num_x,
    input      [`CLOG2_SAFE(`MAX_IPT_SIDE/`MAX_TILE_SIDE):0] i_tile_num_y,
    // Address Generator Control
    output reg                                               o_bl_nxt_lyr,
    output reg                                               o_bl_nxt_filt_grp,
    //
    output reg                                               o_wl_nxt_lyr,
    output reg                                               o_wl_nxt_filt_grp,
    //
    output reg                                               o_tl_nxt_lyr,
    output reg                                               o_tl_nxt_filt_grp,
    output reg                                               o_tl_nxt_tile_col,
    output reg                                               o_tl_nxt_tile_row,
    output reg                                               o_tl_nxt_ch_grp,
    //
    output reg                                               o_wr_nxt_lyr,
    output reg                                               o_wr_nxt_filt_grp,
    output reg                                               o_wr_nxt_tile,
    output reg                                               o_wr_nxt_ch_grp,
    //
    output reg                                               o_tr_nxt_lyr,
    output reg                                               o_tr_nxt_filt_grp,
    output reg                                               o_tr_nxt_tile_col,
    output reg                                               o_tr_nxt_tile_row,
    output reg                                               o_tr_nxt_ch_grp,
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
    input                                                    i_psc_dn,
    input                                                    i_ts_dn,
    // Layer
    output reg [                `CLOG2_SAFE(`CONV_LAYER_NUM)-1:0] o_lyr_idx,
    output reg                                               o_lyr_clr,
    input                                                    i_bs_rdy,
    output reg                                               o_bs_swap,
    input                                                    i_ws_rdy,
    output reg                                               o_ws_swap,
    output reg                                               o_wb_rd_swap,
    // Tile tl Metadata
    output reg [               `CLOG2_SAFE(`MAX_IPT_SIDE):0] o_tl_org_x,
    output reg [               `CLOG2_SAFE(`MAX_IPT_SIDE):0] o_tl_org_y,
    // Layer Metadata
    output reg [           `CLOG2_SAFE(`MAX_GROUP_FILTER):0] o_in_ch,
    output reg [                 `CLOG2_SAFE(`MAX_FILTER):0] o_out_ch,
    output reg [                     `MAX_GROUP_CHANNEL-1:0] o_ch_mask,
    output reg [                      `MAX_GROUP_FILTER-1:0] o_filt_mask,
    // Feature Buffer control
    output reg                                               o_fbuf_wr_swap,
    output reg                                               o_fbuf_rd_swap
);
  // ====================== parmeter ======================= 
  localparam IDLE = 1; 
  localparam RUN_LAYER = 2; 
  localparam DONE = 3; 
  localparam STATE_END = 4;
 
  integer                                                    i;
  // ====================== reg ============================ 
  reg     [                      `CLOG2_SAFE(STATE_END)-1:0] r_cstat;  // current state
  reg     [                      `CLOG2_SAFE(STATE_END)-1:0] r_nstat;  // next state     
  reg     [                     `CLOG2_SAFE(`MAX_CHANNEL):0] r_ch_left;
  reg     [                      `CLOG2_SAFE(`MAX_FILTER):0] r_filt_left;
  // bias loader 
  reg     [                      `CLOG2_SAFE(`MAX_FILTER):0] r_bl_filt_idx;
  reg     [    `CLOG2_SAFE(`MAX_FILTER/`MAX_GROUP_FILTER):0] r_bl_filt_grp_idx;
  // weight loader 
  reg     [                      `CLOG2_SAFE(`MAX_FILTER):0] r_wl_filt_idx;
  reg     [    `CLOG2_SAFE(`MAX_FILTER/`MAX_GROUP_FILTER):0] r_wl_filt_grp_idx;
  // tile loader
  reg     [                     `CLOG2_SAFE(`MAX_CHANNEL):0] r_tl_ch_idx;
  reg     [`CLOG2_SAFE(`MAX_CHANNEL / `MAX_GROUP_CHANNEL):0] r_tl_ch_grp_idx;
  reg     [   `CLOG2_SAFE(`MAX_IPT_AREA / `MAX_TILE_AREA):0] r_tl_tile_idx;
  reg     [   `CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] r_tl_tile_cnt_x;
  reg     [   `CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] r_tl_tile_cnt_y;
  reg     [                      `CLOG2_SAFE(`MAX_FILTER):0] r_tl_filt_idx;
  reg     [    `CLOG2_SAFE(`MAX_FILTER/`MAX_GROUP_FILTER):0] r_tl_filt_grp_idx;
  //br 
  reg     [                      `CLOG2_SAFE(`MAX_FILTER):0] r_br_filt_idx;
  reg     [    `CLOG2_SAFE(`MAX_FILTER/`MAX_GROUP_FILTER):0] r_br_filt_grp_idx;
  // wr
  reg     [                     `CLOG2_SAFE(`MAX_CHANNEL):0] r_wr_ch_idx;
  reg     [`CLOG2_SAFE(`MAX_CHANNEL / `MAX_GROUP_CHANNEL):0] r_wr_ch_grp_idx;
  reg     [   `CLOG2_SAFE(`MAX_IPT_AREA / `MAX_TILE_AREA):0] r_wr_tile_idx;
  reg     [                      `CLOG2_SAFE(`MAX_FILTER):0] r_wr_filt_idx;
  reg     [    `CLOG2_SAFE(`MAX_FILTER/`MAX_GROUP_FILTER):0] r_wr_filt_grp_idx;
  // compute
  reg     [                     `CLOG2_SAFE(`MAX_CHANNEL):0] r_tr_ch_idx;
  reg     [`CLOG2_SAFE(`MAX_CHANNEL / `MAX_GROUP_CHANNEL):0] r_tr_ch_grp_idx;
  reg     [   `CLOG2_SAFE(`MAX_IPT_AREA / `MAX_TILE_AREA):0] r_tr_tile_idx;
  reg     [   `CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] r_tr_tile_cnt_x;
  reg     [   `CLOG2_SAFE(`MAX_IPT_SIDE / `MAX_TILE_SIDE):0] r_tr_tile_cnt_y;
  reg     [                      `CLOG2_SAFE(`MAX_FILTER):0] r_tr_filt_idx;
  reg     [    `CLOG2_SAFE(`MAX_FILTER/`MAX_GROUP_FILTER):0] r_tr_filt_grp_idx;
  //
  reg     [                                             1:0] r_prefetch_tl;
  reg     [                                             2:0] r_bl_stage;
  reg     [                                             2:0] r_wl_stage;
  reg     [                                             2:0] r_tl_stage;
  reg     [                                             2:0] r_br_stage;
  reg     [                                             2:0] r_wr_stage;
  reg     [                                             2:0] r_tr_stage;
  //
  reg                                                        r_bl_busy;
  reg                                                        r_br_busy;
  reg                                                        r_wl_busy;
  reg                                                        r_wr_busy;
  reg                                                        r_tl_busy;
  reg                                                        r_tr_busy;
  reg                                                        r_lyr_busy;
  reg                                                        r_psum_busy;
  reg                                                        r_ts_busy;
  // ====================== wire ===========================   
  wire                                                       w_bl_filt_grp_first;
  wire                                                       w_bl_filt_grp_last;
  //  
  wire                                                       w_wl_filt_grp_first;
  wire                                                       w_wl_filt_grp_last;
  //
  wire                                                       w_tl_ch_grp_first;
  wire                                                       w_tl_tile_first;
  wire                                                       w_tl_filt_grp_first;
  wire                                                       w_tl_ch_grp_last;
  wire                                                       w_tl_tile_last;
  wire                                                       w_tl_filt_grp_last;
  //
  wire                                                       w_br_filt_grp_first;
  wire                                                       w_br_filt_grp_last;
  //
  wire                                                       w_wr_ch_grp_first;
  wire                                                       w_wr_tile_first;
  wire                                                       w_wr_filt_grp_first;
  wire                                                       w_wr_ch_grp_last;
  wire                                                       w_wr_tile_last;
  wire                                                       w_wr_filt_grp_last;
  //
  wire                                                       w_tr_ch_grp_first;
  wire                                                       w_tr_tile_first;
  wire                                                       w_tr_filt_grp_first;
  wire                                                       w_tr_ch_grp_last;
  wire                                                       w_tr_tile_last;
  wire                                                       w_tr_filt_grp_last;
  // ====================== assign =========================  

  assign w_bl_filt_grp_last  = (r_bl_filt_grp_idx == i_filt_grp_num - 1);
  assign w_bl_filt_grp_first = (r_bl_filt_idx == 0);
  //
  assign w_wl_filt_grp_last  = (r_wl_filt_grp_idx == i_filt_grp_num - 1);
  assign w_wl_filt_grp_first = (r_wl_filt_idx == 0);
  //
  assign w_tl_ch_grp_first   = (r_tl_ch_grp_idx == 0);
  assign w_tl_ch_grp_last    = (r_tl_ch_grp_idx == i_ch_grp_num - 1);
  assign w_tl_tile_first     = (r_tl_tile_idx == 0);
  assign w_tl_tile_last      = (r_tl_tile_idx == i_tile_num - 1);
  assign w_tl_filt_grp_first = (r_tl_filt_idx == 0);
  assign w_tl_filt_grp_last  = (r_tl_filt_grp_idx == i_filt_grp_num - 1);
  //
  assign w_br_filt_grp_first = (r_br_filt_grp_idx == 0);
  assign w_br_filt_grp_last  = (r_br_filt_grp_idx == i_filt_grp_num - 1);
  // 
  assign w_wr_ch_grp_first   = (r_wr_ch_grp_idx == 0);
  assign w_wr_tile_first     = (r_wr_tile_idx == 0);
  assign w_wr_filt_grp_first = (r_wr_filt_idx == 0);
  assign w_wr_ch_grp_last    = (r_wr_ch_grp_idx == i_ch_grp_num - 1);
  assign w_wr_tile_last      = (r_wr_tile_idx == i_tile_num - 1);
  assign w_wr_filt_grp_last  = (r_wr_filt_grp_idx == i_filt_grp_num - 1);
  // 
  assign w_tr_ch_grp_first   = (r_tr_ch_grp_idx == 0);
  assign w_tr_tile_first     = (r_tr_tile_idx == 0);
  assign w_tr_filt_grp_first = (r_tr_filt_idx == 0);
  assign w_tr_ch_grp_last    = (r_tr_ch_grp_idx == i_ch_grp_num - 1);
  assign w_tr_tile_last      = (r_tr_tile_idx == i_tile_num - 1);
  assign w_tr_filt_grp_last  = (r_tr_filt_grp_idx == i_filt_grp_num - 1);
  // 


  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_bl_busy   <= 'b0;
      r_br_busy   <= 'b0;
      r_wl_busy   <= 'b0;
      r_wr_busy   <= 'b0;
      r_tl_busy   <= 'b0;
      r_tr_busy   <= 'b0;
      r_lyr_busy  <= 'b0;
      r_psum_busy <= 'b0;
      r_ts_busy   <= 'b0;
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
      if (o_tr_st) r_lyr_busy <= 'b1;
      else if (i_lyr_dn) r_lyr_busy <= 'b0;
      if (o_psc_st) r_psum_busy <= 'b1;
      else if (i_psc_dn) r_psum_busy <= 'b0;
      if (o_ts_st) r_ts_busy <= 'b1;
      else if (i_ts_dn) r_ts_busy <= 'b0;
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
    r_ch_left   = i_ch - r_tl_ch_idx;
    r_filt_left = i_filt - r_tl_filt_idx;
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
        if (i_st) r_nstat = RUN_LAYER;
      end

      RUN_LAYER: begin
        if (r_tr_stage == 5) begin
        end else if (r_tr_stage == 6) begin
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
      o_dn              <= 'd0;
      o_ctrl_rdy        <= 'b0;
      o_lyr_clr         <= 'b0;
      o_ws_swap         <= 'b0;
      o_lyr_idx         <= 'd0;
      o_bl_st           <= 'b0;
      o_br_st           <= 'b0;
      o_wl_st           <= 'b0;
      o_wr_st           <= 'b0;
      o_tl_st           <= 'b0;
      o_tr_st           <= 'b0;
      o_psc_st          <= 'b0;
      o_ts_st           <= 'b0;
      //
      o_fbuf_wr_swap    <= 'b0;
      o_fbuf_rd_swap    <= 'b0;
      o_wb_rd_swap      <= 'b0;
      o_bs_swap         <= 'b0;
      // 
      r_bl_filt_grp_idx <= 'd0;
      r_bl_filt_idx     <= 'd0;
      // 
      r_wl_filt_grp_idx <= 'd0;
      r_wl_filt_idx     <= 'd0;
      // tl
      r_tl_filt_grp_idx <= 'd0;
      r_tl_filt_idx     <= 'd0;
      r_tl_ch_grp_idx   <= 'd0;
      r_tl_ch_idx       <= 'd0;
      r_tl_tile_idx     <= 'd0;
      r_tl_tile_cnt_x   <= 'd0;
      r_tl_tile_cnt_y   <= 'd0;
      o_tl_org_x        <= 'd0;
      o_tl_org_y        <= 'd0;
      // 
      r_br_filt_idx     <= 'd0;
      r_br_filt_grp_idx <= 'd0;
      //
      r_wr_ch_idx       <= 'd0;
      r_wr_ch_grp_idx   <= 'd0;
      r_wr_tile_idx     <= 'd0;
      r_wr_filt_idx     <= 'd0;
      r_wr_filt_grp_idx <= 'd0;
      //    reader
      r_tr_ch_grp_idx   <= 'd0;
      r_tr_ch_idx       <= 'd0;
      r_tr_tile_idx     <= 'd0;
      r_tr_tile_cnt_x   <= 'd0;
      r_tr_tile_cnt_y   <= 'd0;
      r_tr_filt_idx     <= 'd0;
      r_tr_filt_grp_idx <= 'd0;
      //
      o_bl_nxt_lyr      <= 'd0;
      o_bl_nxt_filt_grp <= 'd0;
      //
      o_wl_nxt_lyr      <= 'd0;
      o_wl_nxt_filt_grp <= 'd0;
      //
      o_tl_nxt_lyr      <= 'b0;
      o_tl_nxt_filt_grp <= 'b0;
      o_tl_nxt_tile_col <= 'b0;
      o_tl_nxt_tile_row <= 'b0;
      o_tl_nxt_ch_grp   <= 'b0;
      //
      o_tr_nxt_lyr      <= 'b0;
      o_tr_nxt_filt_grp <= 'b0;
      o_tr_nxt_tile_col <= 'b0;
      o_tr_nxt_tile_row <= 'b0;
      o_tr_nxt_ch_grp   <= 'b0;
      //
      r_bl_stage        <= 'd0;
      r_wl_stage        <= 'd0;
      r_tl_stage        <= 'd0;
      r_br_stage        <= 'd0;
      r_wr_stage        <= 'd0;
      r_tr_stage        <= 'd0;
      r_prefetch_tl     <= 'd0;
    end else begin
      o_ctrl_rdy        <= 'b1;  // 일단 항상 받기    
      o_lyr_clr         <= 'b0;
      o_tl_nxt_lyr      <= 'b0;
      o_tl_nxt_filt_grp <= 'b0;
      o_tl_nxt_tile_col <= 'b0;
      o_tl_nxt_tile_row <= 'b0;
      o_tl_nxt_ch_grp   <= 'b0;
      o_bl_nxt_lyr      <= 'd0;
      o_bl_nxt_filt_grp <= 'd0;
      o_wl_nxt_lyr      <= 'd0;
      o_wl_nxt_filt_grp <= 'd0;
      o_wr_nxt_lyr      <= 'b0;
      o_wr_nxt_filt_grp <= 'b0;
      o_wr_nxt_tile     <= 'b0;
      o_wr_nxt_ch_grp   <= 'b0;
      o_tr_nxt_lyr      <= 'b0;
      o_tr_nxt_filt_grp <= 'b0;
      o_tr_nxt_tile_col <= 'b0;
      o_tr_nxt_tile_row <= 'b0;
      o_tr_nxt_ch_grp   <= 'b0;
      o_fbuf_rd_swap    <= 'b0;
      o_fbuf_wr_swap    <= 'b0;
      o_bs_swap         <= 'b0;
      o_ws_swap         <= 'b0;
      o_wb_rd_swap      <= 'b0;
      case (r_cstat)
        IDLE: begin
          o_dn <= 'b0;
          if (i_st) begin
            o_fbuf_wr_swap <= 'b1;
          end
        end

        RUN_LAYER: begin

          // tile load part
          case (r_bl_stage)
            0: begin
              r_bl_stage <= 1;

            end
            1: begin
              r_bl_stage <= 2;

              o_bl_st <= 'b1;
            end

            2: begin
              r_bl_stage <= 3;

              o_bl_st    <= 'b0;
            end

            3: begin
              if (!r_bl_busy) begin
                r_bl_stage <= 4;
              end
            end

            4: begin
              if (!w_bl_filt_grp_last) begin
                r_bl_stage        <= 'd0;
                // 
                o_bl_nxt_filt_grp <= 'b1;
                //  
                r_bl_filt_grp_idx <= r_bl_filt_grp_idx + 'd1;
                r_bl_filt_idx     <= r_bl_filt_idx + `MAX_GROUP_FILTER;
              end else if (o_lyr_idx != `CONV_LAYER_NUM - 1) begin
                r_bl_stage        <= 'd5;
                //
                o_bl_nxt_lyr      <= 'b1;
                // 
                r_bl_filt_grp_idx <= 'd0;
                r_bl_filt_idx     <= 'd0;
              end else begin
                r_bl_stage <= 'd6;
              end
            end

            5: begin
            end

            6: begin
            end

            default: ;
          endcase

          // weight load part
          case (r_wl_stage)
            0: begin
              r_wl_stage <= 1;

            end
            1: begin
              r_wl_stage <= 2;
              o_wl_st    <= 'b1;

            end

            2: begin
              r_wl_stage <= 3;
              o_wl_st    <= 'b0;
            end

            3: begin
              if (!r_wl_busy) begin
                r_wl_stage <= 4;
              end
            end

            4: begin
              if (!w_wl_filt_grp_last) begin
                r_wl_stage        <= 'd0;
                //
                o_wl_nxt_filt_grp <= 'b1;
                //  
                r_wl_filt_grp_idx <= r_wl_filt_grp_idx + 'd1;
                r_wl_filt_idx     <= r_wl_filt_idx + `MAX_GROUP_FILTER;
              end else if (o_lyr_idx != `CONV_LAYER_NUM - 1) begin
                r_wl_stage        <= 'd5;
                //  
                o_wl_nxt_lyr      <= 'b1;
                //
                r_wl_filt_grp_idx <= 'd0;
                r_wl_filt_idx     <= 'd0;
              end else begin
                r_wl_stage <= 'd6;
              end
            end

            5: begin
            end

            6: begin
            end

            default: ;
          endcase

          // tile load part
          case (r_tl_stage)
            0: begin
              r_tl_stage <= 1;

            end
            1: begin
              r_tl_stage <= 2;
              o_tl_st <= 'b1;
            end

            2: begin
              r_tl_stage <= 3;

              o_tl_st    <= 'b0;
            end

            3: begin
              if (!r_tl_busy) begin
                r_tl_stage <= 4;
              end
            end

            4: begin
              if (!w_tl_ch_grp_last) begin
                r_tl_stage      <= 'd0;
                //
                o_tl_nxt_ch_grp <= 'b1;
                //
                r_tl_ch_grp_idx <= r_tl_ch_grp_idx + 'd1;
                r_tl_ch_idx     <= r_tl_ch_idx + `MAX_GROUP_CHANNEL;
              end else if (!w_tl_tile_last) begin
                r_tl_stage <= 'd0;
                if (r_tl_tile_cnt_x < i_tile_num_x - 1) begin
                  o_tl_nxt_tile_col <= 'b1;
                  r_tl_tile_cnt_x   <= r_tl_tile_cnt_x + 'd1;
                  o_tl_org_x        <= o_tl_org_x + i_tile_ipt_side;
                end else begin
                  r_tl_tile_cnt_x <= 'd0;
                  o_tl_org_x <= 0;
                  if (r_tl_tile_cnt_y < i_tile_num_y - 1) begin
                    o_tl_nxt_tile_row <= 'b1;
                    r_tl_tile_cnt_y   <= r_tl_tile_cnt_y + 'd1;
                    o_tl_org_y        <= o_tl_org_y + i_tile_ipt_side;
                  end
                end
                // 
                r_tl_ch_grp_idx <= 'd0;
                r_tl_ch_idx     <= 'd0;
                r_tl_tile_idx   <= r_tl_tile_idx + 'd1;
              end else if (!w_tl_filt_grp_last) begin
                r_tl_stage        <= 'd0;
                //
                o_tl_nxt_filt_grp <= 'b1;
                o_tl_org_x        <= 0;
                o_tl_org_y        <= 0;
                r_tl_tile_cnt_x   <= 'd0;
                r_tl_tile_cnt_y   <= 'd0;
                // 
                r_tl_ch_grp_idx   <= 'd0;
                r_tl_ch_idx       <= 'd0;
                r_tl_tile_idx     <= 'd0;
                r_tl_filt_grp_idx <= r_tl_filt_grp_idx + 'd1;
                r_tl_filt_idx     <= r_tl_filt_idx + `MAX_GROUP_FILTER;
              end else if (o_lyr_idx != `CONV_LAYER_NUM - 1) begin
                r_tl_stage        <= 'd5;
                //
                o_tl_nxt_lyr      <= 'b1;
                o_tl_org_x        <= 'd0;
                o_tl_org_y        <= 'd0;
                r_tl_tile_cnt_x   <= 'd0;
                r_tl_tile_cnt_y   <= 'd0;
                //
                r_tl_ch_grp_idx   <= 'd0;
                r_tl_ch_idx       <= 'd0;
                r_tl_tile_idx     <= 'd0;
                r_tl_filt_grp_idx <= 'd0;
                r_tl_filt_idx     <= 'd0;
              end else begin
                r_tl_stage <= 'd6;
              end
            end

            5: begin
            end

            6: begin
            end

            default: ;
          endcase
          // br stationary stage
          case (r_br_stage)

            0: begin
              r_br_stage <= 1;
            end

            1: begin
              r_br_stage <= 2;
              o_br_st <= 'b1;
            end

            // wait pipeline until update busy reg (1->st->busy)
            2: begin
              r_br_stage <= 3;
              o_br_st    <= 'b0;
            end

            3: begin
              if (!r_br_busy) begin
                r_br_stage <= 4;
              end
            end

            4: begin
              if (!w_br_filt_grp_last) begin
                r_br_stage        <= 0;
                //  
                r_br_filt_grp_idx <= r_br_filt_grp_idx + 1;
                r_br_filt_idx     <= r_br_filt_idx + `MAX_GROUP_FILTER;
              end else if (o_lyr_idx != `CONV_LAYER_NUM - 1) begin
                r_br_stage        <= 5;
                // 
                r_br_filt_grp_idx <= 'd0;
                r_br_filt_idx     <= 'd0;
              end
            end

            5: begin
            end

            6: begin
            end


            default: ;

          endcase
          // wr stationary stage
          case (r_wr_stage)

            0: begin
              r_wr_stage <= 1;
            end

            1: begin
              r_wr_stage <= 2;
              o_wr_st <= 'b1;
            end

            // wait pipeline until update busy reg (1->st->busy)
            2: begin
              r_wr_stage <= 3;
              o_wr_st    <= 'b0;
            end

            3: begin
              if (!r_wr_busy) begin
                r_wr_stage <= 4;
              end
            end

            4: begin
              if (!w_wr_ch_grp_last) begin
                r_wr_stage      <= 0;
                //
                o_wr_nxt_ch_grp <= 'b1;
                //
                r_wr_ch_grp_idx <= r_wr_ch_grp_idx + 'd1;
                r_wr_ch_idx     <= r_wr_ch_idx + `MAX_GROUP_CHANNEL;

              end else if (!w_wr_tile_last) begin
                r_wr_stage      <= 0;
                //
                o_wr_nxt_tile   <= 'b1;
                //
                r_wr_ch_grp_idx <= 'd0;
                r_wr_ch_idx     <= 'd0;
                r_wr_tile_idx   <= r_wr_tile_idx + 1;
                //    
              end else if (!w_wr_filt_grp_last) begin
                r_wr_stage        <= 0;
                //
                o_wr_nxt_filt_grp <= 'b1;
                // 
                r_wr_ch_grp_idx   <= 'd0;
                r_wr_ch_idx       <= 'd0;
                r_wr_tile_idx     <= 'd0;
                r_wr_filt_grp_idx <= r_wr_filt_grp_idx + 1;
                r_wr_filt_idx     <= r_wr_filt_idx + `MAX_GROUP_FILTER;
                //
                o_wb_rd_swap      <= 'b1;
              end else if (o_lyr_idx != `CONV_LAYER_NUM - 1) begin
                r_wr_stage        <= 5;
                //
                o_wr_nxt_lyr      <= 'b1;
                //
                r_wr_ch_grp_idx   <= 'd0;
                r_wr_ch_idx       <= 'd0;
                r_wr_tile_idx     <= 'd0;
                r_wr_filt_grp_idx <= 'd0;
                r_wr_filt_idx     <= 'd0;
                //
                o_wb_rd_swap      <= 'b1;

              end
            end

            5: begin
            end

            6: begin
            end


            default: ;

          endcase
          // read part
          case (r_tr_stage)
            0: begin
              if (i_bs_rdy && i_ws_rdy) begin
                r_tr_stage <= 1;
                o_lyr_clr  <= 'b1;
              end
            end

            1: begin
              r_tr_stage <= 2;
              o_lyr_clr  <= 'b0;

              o_tr_st    <= 'b1;
              if (r_tr_ch_grp_idx == 0) o_psc_st <= 'b1;
              if (r_tr_ch_grp_idx == i_ch_grp_num - 1) o_ts_st <= 'b1;

            end

            // wait pipeline until update busy reg (1->st->busy)
            2: begin
              r_tr_stage <= 3;
              o_tr_st    <= 'b0;
              o_psc_st   <= 'b0;
              o_ts_st    <= 'b0;
            end

            3: begin
              if (!r_lyr_busy && ((!w_tr_ch_grp_last) || (!r_ts_busy))) begin
                r_tr_stage <= 4;
              end
            end

            4: begin


              if (!w_tr_ch_grp_last) begin
                r_tr_stage      <= 'd0;
                //
                o_tr_nxt_ch_grp <= 'b1;
                //
                r_tr_ch_grp_idx <= r_tr_ch_grp_idx + 'd1;
                r_tr_ch_idx     <= r_tr_ch_idx + `MAX_GROUP_CHANNEL;
                // 
                o_ws_swap       <= 'b1;
              end else if (!w_tr_tile_last) begin
                r_tr_stage <= 'd0;
                //
                if (r_tr_tile_cnt_x < i_tile_num_x - 1) begin
                  o_tr_nxt_tile_col <= 'b1;
                  r_tr_tile_cnt_x   <= r_tr_tile_cnt_x + 'd1;
                end else begin
                  r_tr_tile_cnt_x <= 'd0;
                  if (r_tr_tile_cnt_y < i_tile_num_y - 1) begin
                    o_tr_nxt_tile_row <= 'b1;
                    r_tr_tile_cnt_y   <= r_tr_tile_cnt_y + 'd1;
                  end
                end
                //
                r_tr_ch_grp_idx <= 'd0;
                r_tr_ch_idx     <= 'd0;
                r_tr_tile_idx   <= r_tr_tile_idx + 'd1;
                // 
                o_ws_swap       <= 'b1;
              end else if (!w_tr_filt_grp_last) begin
                r_tr_stage        <= 'd0;
                o_tr_nxt_filt_grp <= 'b1;
                // 
                r_tr_tile_cnt_x   <= 'd0;
                r_tr_tile_cnt_y   <= 'd0;
                //
                r_tr_ch_grp_idx   <= 'd0;
                r_tr_ch_idx       <= 'd0;
                r_tr_tile_idx     <= 'd0;
                r_tr_filt_grp_idx <= r_tr_filt_grp_idx + 1;
                r_tr_filt_idx     <= r_tr_filt_idx + `MAX_GROUP_FILTER;
                //
                o_bs_swap         <= 'b1;
                o_ws_swap         <= 'b1;
              end else if (o_lyr_idx != `CONV_LAYER_NUM - 1) begin
                r_tr_stage        <= 'd5;
                o_tr_nxt_lyr      <= 'b1;
                //
                o_lyr_idx         <= o_lyr_idx + 'd1;
                o_fbuf_rd_swap    <= 'b1;
                o_fbuf_wr_swap    <= 'b1;
                // 
                r_tr_tile_cnt_x   <= 'd0;
                r_tr_tile_cnt_y   <= 'd0;
                //
                r_tr_ch_grp_idx   <= 'd0;
                r_tr_ch_idx       <= 'd0;
                r_tr_tile_idx     <= 'd0;
                r_tr_filt_grp_idx <= 'd0;
                r_tr_filt_idx     <= 'd0;
                //
                o_bs_swap         <= 'b1;
                o_ws_swap         <= 'b1;
              end else begin
                r_tr_stage <= 'd6;
              end
            end

            // end layer
            5: begin
              // 아 이거 분리 해야 되는데
              r_bl_stage <= 'd0;
              r_wl_stage <= 'd0;
              r_tl_stage <= 'd0;
              r_br_stage <= 'd0;
              r_wr_stage <= 'd0;
              r_tr_stage <= 'd0;
            end

            6: begin
            end

            default: ;
          endcase
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


`include "defines.vh"
`include "network_config.vh"

module tile_loader #(
    parameter  TILE_SIDE        = `MAX_TILE_SIDE,
    parameter  HALO             = 1,
    //
    localparam MAX_IPT_ADDR     = $clog2(`MAX_IPT_AREA),
    localparam MAX_TILE_ADDR    = $clog2(`MAX_TILE_AREA),
    localparam PADDED_TILE_SIDE = TILE_SIDE + 2,
    localparam PADDED_TILE_AREA = PADDED_TILE_SIDE * PADDED_TILE_SIDE,
    localparam PADDED_TILE_ADDR = $clog2(PADDED_TILE_AREA)
) (
    input                                      i_clk,
    input                                      i_rstn,
    input                                      i_st,
    output                                     o_dn,
    // GC
    input  [          $clog2(`MAX_IPT_SIDE):0] i_img_side,
    input  [          $clog2(`MAX_IPT_SIDE):0] i_org_x,
    input  [          $clog2(`MAX_IPT_SIDE):0] i_org_y,
    // RC
    output [        $clog2(`MAX_IPT_AREA) : 0] o_rlen,
    output                                     o_req,
    output [        $clog2(`MAX_IPT_AREA)-1:0] o_raddr,
    input                                      i_rdn,
    // ipt (FIFO)
    output                                     o_ipt_rdy,
    input                                      i_ipt_vld,
    input  [`IPT_BIT * `MAX_GROUP_CHANNEL-1:0] i_ipt_din,
    // opt (layer)
    input                                      i_opt_rdy,
    output                                     o_opt_vld,
    output [`IPT_BIT * `MAX_GROUP_CHANNEL-1:0] o_opt_dout
);
  // ====================== parmeter =======================  
  localparam REQ_IDLE = 0;
  localparam REQ_ROW = 1;
  localparam REQ_WAIT = 2;
  localparam REQ_DONE = 3;
  localparam REQ_END = 4;

  localparam OUT_IDLE = 0;
  localparam OUT_RUN = 1;
  localparam OUT_DONE = 2;
  localparam OUT_END = 3;

  // ====================== wire ===========================    
  //
  wire                                     w_req_pad_row;
  wire                                     w_req_pad_left;
  wire                                     w_req_pad_right;
  //
  wire                                     w_out_pad_u;
  wire                                     w_out_pad_d;
  wire                                     w_out_pad_l;
  wire                                     w_out_pad_r;
  wire                                     w_out_pad;
  // ====================== reg ============================
  reg  [              $clog2(REQ_END)-1:0] r_req_cstat;
  reg  [              $clog2(REQ_END)-1:0] r_req_nstat;
  reg  [              $clog2(OUT_END)-1:0] r_out_cstat;
  reg  [              $clog2(OUT_END)-1:0] r_out_nstat;
  //
  reg                                      r_dn;
  // RC
  reg  [     $clog2(PADDED_TILE_SIDE)-1:0] r_row_cnt;
  reg  [        $clog2(`MAX_IPT_AREA) : 0] r_rlen;
  reg                                      r_req;
  reg  [        $clog2(`MAX_IPT_AREA)-1:0] r_raddr;
  reg  [        $clog2(`MAX_IPT_AREA)-1:0] r_base_addr;
  // output
  reg  [     $clog2(PADDED_TILE_SIDE)-1:0] r_out_tile_x;
  reg  [     $clog2(PADDED_TILE_SIDE)-1:0] r_out_tile_y;
  reg                                      r_opt_vld;
  reg  [`IPT_BIT * `MAX_GROUP_CHANNEL-1:0] r_opt_dat;
  // ====================== assign =========================     
  assign o_ipt_rdy       = i_opt_rdy && !w_out_pad;

  // req
  assign w_req_pad_row   = ($signed(i_org_y + r_row_cnt) - HALO < 0);
  assign w_req_pad_left  = ($signed(i_org_x) - HALO < 0);
  assign w_req_pad_right = ($signed(i_org_x) + TILE_SIDE + HALO >= i_img_side);
  // out
  assign w_out_pad_u     = ($signed(i_org_y + r_out_tile_y) - HALO < 0);
  assign w_out_pad_d     = ($signed(i_org_y + r_out_tile_y) - HALO >= i_img_side);
  assign w_out_pad_l     = ($signed(i_org_x + r_out_tile_x) - HALO < 0);
  assign w_out_pad_r     = ($signed(i_org_x + r_out_tile_x) - HALO >= i_img_side);
  assign w_out_pad       = w_out_pad_u || w_out_pad_d || w_out_pad_l || w_out_pad_r;
  //
  assign o_dn            = r_dn;
  assign o_rlen          = r_rlen;
  assign o_req           = r_req;
  assign o_raddr         = r_raddr;
  // ====================== FSM ============================
  //      ____                _   _____ ____  __  __ 
  //     |  _ \ ___  __ _  __| | |  ___/ ___||  \/  |
  //     | |_) / _ \/ _` |/ _` | | |_  \___ \| |\/| |
  //     |  _ <  __/ (_| | (_| | |  _|  ___) | |  | |
  //     |_| \_\___|\__,_|\__,_| |_|   |____/|_|  |_|
  //                                                 
  //  initialize and update state register    
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) r_req_cstat <= REQ_IDLE;
    else r_req_cstat <= r_req_nstat;

  end
  // compute next state 
  always @(*) begin
    r_req_nstat = r_req_cstat;
    case (r_req_cstat)
      REQ_IDLE: begin
        if (i_st) r_req_nstat = REQ_ROW;
      end

      REQ_ROW: begin
        r_req_nstat = REQ_WAIT;
      end

      REQ_WAIT: begin
        if (i_rdn) begin
          if (r_row_cnt < PADDED_TILE_SIDE) r_req_nstat = REQ_ROW;
          else r_req_nstat = REQ_DONE;
        end
      end

      REQ_DONE: begin
        r_req_nstat = REQ_IDLE;
      end

      default: ;
    endcase
  end
  // 
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_row_cnt   <= 'd0;
      r_rlen      <= 0;
      r_req       <= 0;
      r_raddr     <= 0;
      r_base_addr <= 0;
    end else begin
      case (r_req_cstat)
        REQ_IDLE: ;

        REQ_ROW: begin
          // count
          r_row_cnt <= r_row_cnt + 'd1;

          // request
          r_req     <= 'b1;

          // length
          if (w_req_pad_row) begin
            r_rlen <= 0;
          end else begin
            if (w_req_pad_left && w_req_pad_right) begin
              r_rlen <= PADDED_TILE_SIDE - 2 * HALO;
            end else if (w_req_pad_left || w_req_pad_right) begin
              r_rlen <= PADDED_TILE_SIDE - HALO;
            end else begin
              r_rlen <= PADDED_TILE_SIDE;
            end
          end

          // request address
          if (w_req_pad_left) begin
            r_raddr <= r_base_addr + i_org_x;
          end else begin
            r_raddr <= r_base_addr + i_org_x - 'd1;
          end

          // update next request address

          // update request address 
          if (!w_req_pad_row) begin
            r_base_addr <= r_base_addr + i_img_side;
          end
        end

        REQ_WAIT: begin
          r_req <= 0;
        end

        REQ_DONE: begin
          r_dn <= 'b0;
        end

        default: ;

      endcase
    end
  end
  //       ___        _               _     _____ ____  __  __ 
  //      / _ \ _   _| |_ _ __  _   _| |_  |  ___/ ___||  \/  |
  //     | | | | | | | __| '_ \| | | | __| | |_  \___ \| |\/| |
  //     | |_| | |_| | |_| |_) | |_| | |_  |  _|  ___) | |  | |
  //      \___/ \__,_|\__| .__/ \__,_|\__| |_|   |____/|_|  |_|
  //                     |_|                                   

  //  initialize and update state register    
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) r_out_cstat <= REQ_IDLE;
    else r_out_cstat <= r_out_nstat;

  end
  // compute next state 
  always @(*) begin
    r_out_nstat = r_out_cstat;

    case (r_out_cstat)
      OUT_IDLE: begin
        if (i_st) r_out_nstat = OUT_RUN;
      end

      OUT_RUN: begin
        if (r_out_tile_x == PADDED_TILE_SIDE - 1 && r_out_tile_y == PADDED_TILE_SIDE - 1) begin
          r_out_nstat = OUT_DONE;
        end
      end

      OUT_DONE: begin
      end

      default: ;
    endcase
  end
  // 
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_out_tile_x <= 'd0;
      r_out_tile_y <= 'd0;
      r_opt_vld    <= 'b0;
      r_opt_dat    <= 'd0;
    end else begin
      case (r_out_cstat)
        OUT_IDLE: begin
        end

        OUT_RUN: begin
          if ((i_ipt_vld && o_ipt_rdy) || w_out_pad) begin

            // count tile x/y
            if (r_out_tile_x < PADDED_TILE_SIDE - 1) begin
              r_out_tile_x <= r_out_tile_x + 'd1;
            end else begin
              if (r_out_tile_y < PADDED_TILE_SIDE - 1) begin
                r_out_tile_x <= 'd0;
                r_out_tile_y <= r_out_tile_y + 'd1;
              end
            end

            // output
            r_opt_vld <= 'b1;
            if (i_ipt_vld) begin
              r_opt_dat <= i_ipt_din;
            end else if (w_out_pad) begin
              r_opt_dat <= 'd0;
            end
          end else begin
            r_opt_vld <= 'b0;
          end
        end
        OUT_DONE: begin
          r_opt_vld    <= 'b0;
          r_out_tile_x <= 'd0;
          r_out_tile_y <= 'd0;
        end

        default: ;

      endcase
    end
  end
  // ====================== output =========================
  assign o_opt_vld  = r_opt_vld;
  assign o_opt_dout = r_opt_dat;

endmodule

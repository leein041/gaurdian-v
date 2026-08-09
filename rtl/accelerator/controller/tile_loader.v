
`include "defines.vh"
`include "network_config.vh"

module tile_loader #(
    parameter  TILE_SIDE        = `MAX_TILE_SIDE,
    parameter  FBUF_DEPTH       = 0,
    parameter  HALO             = 1,
    // 
    localparam PADDED_TILE_SIDE = TILE_SIDE + 2,
    localparam PADDED_TILE_AREA = PADDED_TILE_SIDE * PADDED_TILE_SIDE,
    localparam PADDED_TILE_ADDR = `CLOG2_SAFE(PADDED_TILE_AREA)
) (
    input                                        i_clk,
    input                                        i_rstn,
    input                                        i_st,
    output                                       o_dn,
    // GC
    input  [     `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] i_img_side,
    input  [     `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] i_tl_org_x,
    input  [     `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] i_tl_org_y,
    input  [        `CLOG2_SAFE(FBUF_DEPTH)-1:0] i_tl_req_addr,
    // RC
    output [        `CLOG2_SAFE(FBUF_DEPTH) : 0] o_req_len,
    output                                       o_req,
    output [        `CLOG2_SAFE(FBUF_DEPTH)-1:0] o_req_addr,
    input                                        i_req_dn,
    // ipt (FIFO)
    output                                       o_ipt_rdy,
    input                                        i_ipt_vld,
    input  [  `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] i_ipt_din,
    // write    
    output                                       o_we,
    output [`CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] o_waddr,
    output [  `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] o_wdat
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
  wire                                       w_req_pad_bottom;
  wire                                       w_req_pad_top;
  wire                                       w_req_pad_row;
  wire                                       w_req_pad_left;
  wire                                       w_req_pad_right;
  //
  wire                                       w_out_pad_u;
  wire                                       w_out_pad_d;
  wire                                       w_out_pad_l;
  wire                                       w_out_pad_r;
  wire                                       w_act_pad;
  // 
  wire                                       w_act_in = (i_ipt_vld && o_ipt_rdy);
  // ====================== reg ============================
  reg  [           `CLOG2_SAFE(REQ_END)-1:0] r_req_cstat;
  reg  [           `CLOG2_SAFE(REQ_END)-1:0] r_req_nstat;
  reg  [           `CLOG2_SAFE(OUT_END)-1:0] r_out_cstat;
  reg  [           `CLOG2_SAFE(OUT_END)-1:0] r_out_nstat;
  //
  reg                                        r_dn;
  // RC
  reg  [  `CLOG2_SAFE(PADDED_TILE_SIDE) : 0] r_row_cnt;
  reg  [        `CLOG2_SAFE(FBUF_DEPTH) : 0] r_req_len;
  reg                                        r_req;
  reg  [        `CLOG2_SAFE(FBUF_DEPTH)-1:0] r_req_addr;
  reg  [        `CLOG2_SAFE(FBUF_DEPTH)-1:0] r_base_addr;
  // output
  reg  [`CLOG2_SAFE(`MAX_PAD_TILE_SIDE)-1:0] r_out_tile_x;
  reg  [`CLOG2_SAFE(`MAX_PAD_TILE_SIDE)-1:0] r_out_tile_y;
  // 
  reg                                        r_we;
  reg  [`CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] r_wptr;
  reg  [`CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] r_waddr;
  reg  [  `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] r_wdat;
  // ====================== assign =========================     
  assign o_ipt_rdy = (!w_act_pad) && (r_out_cstat == OUT_RUN);

  wire signed [`CLOG2_SAFE(`MAX_IPT_SIDE)+1:0] cur_x = i_tl_org_x - HALO;
  wire signed [`CLOG2_SAFE(`MAX_IPT_SIDE)+1:0] nxt_x = i_tl_org_x + `MAX_TILE_SIDE;
  wire signed [`CLOG2_SAFE(`MAX_IPT_SIDE)+1:0] cur_y = i_tl_org_y + r_row_cnt - HALO;

  assign w_req_pad_left   = (cur_x < 0);

  // req
  assign w_req_pad_top    = (cur_y < 0);
  assign w_req_pad_bottom = (cur_y >= i_img_side);
  assign w_req_pad_left   = (cur_x < 0);
  assign w_req_pad_right  = (nxt_x >= i_img_side);
  assign w_req_pad_row    = w_req_pad_top || w_req_pad_bottom;
  // out
  assign w_out_pad_u      = (i_tl_org_y + r_out_tile_y < HALO + 0);
  assign w_out_pad_d      = (i_tl_org_y + r_out_tile_y >= HALO + i_img_side);
  assign w_out_pad_l      = (i_tl_org_x + r_out_tile_x < HALO + 0);
  assign w_out_pad_r      = (i_tl_org_x + r_out_tile_x >= HALO + i_img_side);
  assign w_act_pad        = w_out_pad_u || w_out_pad_d || w_out_pad_l || w_out_pad_r;
  //
  assign o_dn             = r_dn;
  assign o_req_len        = r_req_len;
  assign o_req            = r_req;
  assign o_req_addr       = r_req_addr;
  // 
  assign o_we             = r_we;
  assign o_waddr          = r_waddr;
  assign o_wdat           = r_wdat;
  // ====================== FSM ============================
  //      ____                            _     _____ ____  __  __ 
  //     |  _ \ ___  __ _ _   _  ___  ___| |_  |  ___/ ___||  \/  |
  //     | |_) / _ \/ _` | | | |/ _ \/ __| __| | |_  \___ \| |\/| |
  //     |  _ <  __/ (_| | |_| |  __/\__ \ |_  |  _|  ___) | |  | |
  //     |_| \_\___|\__, |\__,_|\___||___/\__| |_|   |____/|_|  |_|
  //                   |_|                                         
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
        if (r_row_cnt == PADDED_TILE_SIDE - 1) r_req_nstat = REQ_DONE;
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
      r_base_addr <= 'd0;
      r_req_len   <= 0;
      r_req       <= 0;
      r_req_addr  <= 0;
    end else begin
      case (r_req_cstat)

        REQ_IDLE: begin
          if (i_st) begin
            if (i_tl_org_y < HALO) begin
              r_base_addr <= i_tl_req_addr;
            end else begin
              r_base_addr <= i_tl_req_addr - i_img_side;
            end
          end
        end

        REQ_ROW: begin
          // count
          r_row_cnt <= r_row_cnt + 'd1;

          // request
          if (w_req_pad_row) begin
            r_req <= 'b0;
          end else begin
            r_req <= 'b1;
          end

          // length
          if (w_req_pad_row) begin
            r_req_len <= 0;
          end else begin
            if (w_req_pad_left && w_req_pad_right) begin
              r_req_len <= PADDED_TILE_SIDE - 2;
            end else if (w_req_pad_left || w_req_pad_right) begin
              r_req_len <= PADDED_TILE_SIDE - 1;
            end else begin
              r_req_len <= PADDED_TILE_SIDE;
            end
          end

          // request
          if (w_req_pad_left) begin
            r_req_addr <= r_base_addr;
          end else begin
            r_req_addr <= r_base_addr - 'd1;
          end

          // update next request address 
          if (!w_req_pad_row) begin
            r_base_addr <= r_base_addr + i_img_side;
          end
        end

        REQ_DONE: begin
          r_req <= 0;
          r_row_cnt <= 'd0;

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
        if (r_wptr == `MAX_PAD_TILE_AREA - 1) begin
          r_out_nstat = OUT_DONE;
        end
      end

      OUT_DONE: begin
        r_out_nstat = OUT_IDLE;
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
      //
      r_we         <= 'b0;
      r_wptr       <= 'd0;
      r_waddr      <= 'd0;
      r_wdat       <= 'd0;
      r_dn         <= 'b0;
    end else begin
      case (r_out_cstat)
        OUT_IDLE: begin
          r_dn <= 'b0;
        end

        OUT_RUN: begin
          if (w_act_in || w_act_pad) begin

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
            r_we    <= 'b1;
            r_wptr  <= r_wptr + 'd1;
            r_waddr <= r_wptr;
            if (w_act_pad) begin
              r_wdat <= 'd0;
            end else if (i_ipt_vld) begin
              r_wdat <= i_ipt_din;
            end
          end else begin
            r_we <= 'b0;
          end
        end
        OUT_DONE: begin
          r_dn         <= 'b1;
          r_we         <= 'b0;
          r_wptr       <= 'd0;
          r_out_tile_x <= 'd0;
          r_out_tile_y <= 'd0;
        end

        default: ;

      endcase
    end
  end
  // ====================== output =========================  

endmodule


`include "defines.vh"
`include "network_config.vh"

module tile_req_gen #(
    parameter  TILE_SIDE        = `MAX_TILE_SIDE,
    parameter  FBUF_DEPTH       = 0,
    parameter  HALO             = 1,
    parameter  TILE_QUE_WIDTH   = 0,
    // 
    localparam PADDED_TILE_SIDE = TILE_SIDE + 2
) (
    input                                             i_clk,
    input                                             i_rstn,
    input                                             i_st,
    output reg                                        o_dn,
    input                                             i_que_full,
    // GC
    input      [      `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] i_img_side,
    input      [      `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] i_tl_org_x,
    input      [      `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] i_tl_org_y,
    input      [         `CLOG2_SAFE(FBUF_DEPTH)-1:0] i_tl_req_addr,
    // RC
    output     [         `CLOG2_SAFE(FBUF_DEPTH) : 0] o_req_len,
    output                                            o_req,
    output     [         `CLOG2_SAFE(FBUF_DEPTH)-1:0] o_req_addr,
    //
    output reg                                        o_desc_vld,
    output reg [3*(`CLOG2_SAFE(`MAX_IPT_SIDE)+1)-1:0] o_desc_dout     // {side,x,y}
);
  // ====================== parmeter =======================  
  localparam REQ_IDLE = 0;
  localparam REQ_ROW = 1;
  localparam REQ_WAIT = 2;
  localparam REQ_DONE = 3;
  localparam REQ_END = 4;

  // ====================== wire ===========================    
  //
  wire                                            w_req_pad_bottom;
  wire                                            w_req_pad_top;
  wire                                            w_req_pad_row;
  wire                                            w_req_pad_left;
  wire                                            w_req_pad_right;
  // ====================== reg ============================
  reg         [         `CLOG2_SAFE(REQ_END)-1:0] r_req_cstat;
  reg         [         `CLOG2_SAFE(REQ_END)-1:0] r_req_nstat;
  // RC
  reg         [`CLOG2_SAFE(PADDED_TILE_SIDE) : 0] r_row_cnt;
  reg         [      `CLOG2_SAFE(FBUF_DEPTH) : 0] r_req_len;
  reg                                             r_req;
  reg         [      `CLOG2_SAFE(FBUF_DEPTH)-1:0] r_req_addr;
  reg         [      `CLOG2_SAFE(FBUF_DEPTH)-1:0] r_base_addr;
  //
  // ====================== assign =========================      

  wire signed [   `CLOG2_SAFE(`MAX_IPT_SIDE)+1:0] cur_x = i_tl_org_x - HALO;
  wire signed [   `CLOG2_SAFE(`MAX_IPT_SIDE)+1:0] nxt_x = i_tl_org_x + `MAX_TILE_SIDE;
  wire signed [   `CLOG2_SAFE(`MAX_IPT_SIDE)+1:0] cur_y = i_tl_org_y + r_row_cnt - HALO;

  assign w_req_pad_left   = (cur_x < 0);

  // req
  assign w_req_pad_top    = (cur_y < 0);
  assign w_req_pad_bottom = (cur_y >= i_img_side);
  assign w_req_pad_left   = (cur_x < 0);
  assign w_req_pad_right  = (nxt_x >= i_img_side);
  assign w_req_pad_row    = w_req_pad_top || w_req_pad_bottom;
  // 
  assign o_req_len        = r_req_len;
  assign o_req            = r_req;
  assign o_req_addr       = r_req_addr;
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
      o_dn        <= 'b0;
      r_row_cnt   <= 'd0;
      r_base_addr <= 'd0;
      r_req_len   <= 0;
      r_req       <= 0;
      r_req_addr  <= 0;
      o_desc_vld  <= 'b0;
    end else begin
      case (r_req_cstat)

        REQ_IDLE: begin
          o_dn <= 'b0;
          if (i_st) begin
            r_row_cnt <= 'd0;

            if (i_tl_org_y < HALO) begin
              r_base_addr <= i_tl_req_addr;
            end else begin
              r_base_addr <= i_tl_req_addr - i_img_side;
            end

            o_desc_vld  <= 'b1;
            o_desc_dout <= {i_img_side, i_tl_org_x, i_tl_org_y};
          end
        end

        REQ_ROW: begin
          if (!i_que_full) begin
            o_desc_vld <= 'b0;

            // count
            r_row_cnt  <= r_row_cnt + 'd1;

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
          end else begin
            r_req <= 'b0;
          end
        end

        REQ_DONE: begin
          r_req <= 0;
          o_dn  <= 'b1;
        end

        default: ;

      endcase
    end
  end
  // ====================== output =========================  

endmodule


`include "defines.vh"
`include "network_config.vh"

module tile_buf_writer #(
    parameter  TILE_SIDE        = `MAX_TILE_SIDE,
    parameter  HALO             = 1,
    // 
    localparam PADDED_TILE_SIDE = TILE_SIDE + 2
) (
    input                                             i_clk,
    input                                             i_rstn,
    input                                             i_st,
    output reg                                        o_dn,
    //
    input                                             i_pad,
    input      [       `CLOG2_SAFE(`MAX_TILE_AREA):0] i_tile_ipt_area,
    input      [   `CLOG2_SAFE(`MAX_PAD_TILE_SIDE):0] i_pad_tile_side,
    input      [   `CLOG2_SAFE(`MAX_PAD_TILE_AREA):0] i_pad_tile_area,
    // 
    output reg                                        o_desc_rdy,
    input                                             i_desc_vld,
    input      [3*(`CLOG2_SAFE(`MAX_IPT_SIDE)+1)-1:0] i_desc_din,       // side, x , y
    // ipt (FIFO)
    output                                            o_ipt_rdy,
    input                                             i_ipt_vld,
    input      [   `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] i_ipt_din,
    // write    
    input                                             i_buf_wr_rdy,
    output reg                                        o_we,
    output reg [ `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] o_waddr,
    output reg [   `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] o_wdat
);
  // ====================== parmeter =======================   
  localparam IDLE = 0;
  localparam RUN = 1;
  localparam DONE = 2;
  localparam END_STATE = 3;

  // ====================== reg ============================ 
  reg  [         `CLOG2_SAFE(END_STATE)-1:0] r_out_cstat;
  reg  [         `CLOG2_SAFE(END_STATE)-1:0] r_out_nstat;
  //
  reg  [     `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] r_img_side;
  reg  [     `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] r_tl_org_x;
  reg  [     `CLOG2_SAFE(`MAX_IPT_SIDE) : 0] r_tl_org_y;
  // output
  reg  [`CLOG2_SAFE(`MAX_PAD_TILE_SIDE)-1:0] r_out_tile_x;
  reg  [`CLOG2_SAFE(`MAX_PAD_TILE_SIDE)-1:0] r_out_tile_y;
  //  
  reg  [`CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] r_wptr;
  // ====================== wire ===========================      
  wire                                       w_out_pad_u;
  wire                                       w_out_pad_d;
  wire                                       w_out_pad_l;
  wire                                       w_out_pad_r;
  wire                                       w_act_pad;
  wire                                       w_act_in = (i_ipt_vld && o_ipt_rdy);
  wire [  `CLOG2_SAFE(`MAX_PAD_TILE_AREA):0] w_opt_area;
  // ====================== assign =========================     
  assign o_ipt_rdy   = i_buf_wr_rdy && (!w_act_pad) && (r_out_cstat == RUN);
  assign w_opt_area  = (i_pad) ? i_pad_tile_area : i_tile_ipt_area;

  // out
  assign w_out_pad_u = (r_tl_org_y + r_out_tile_y < HALO + 0);
  assign w_out_pad_d = (r_tl_org_y + r_out_tile_y >= HALO + r_img_side);
  assign w_out_pad_l = (r_tl_org_x + r_out_tile_x < HALO + 0);
  assign w_out_pad_r = (r_tl_org_x + r_out_tile_x >= HALO + r_img_side);
  assign w_act_pad   = i_pad && (w_out_pad_u || w_out_pad_d || w_out_pad_l || w_out_pad_r);
  // ====================== FSM ============================ 
  //  initialize and update state register    
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) r_out_cstat <= IDLE;
    else r_out_cstat <= r_out_nstat;

  end
  // compute next state 
  always @(*) begin
    r_out_nstat = r_out_cstat;

    case (r_out_cstat)
      IDLE: begin
        if (i_desc_vld) r_out_nstat = RUN;
      end

      RUN: begin
        if ((r_wptr == w_opt_area - 1) && i_buf_wr_rdy && (w_act_in || w_act_pad)) begin
          r_out_nstat = DONE;
        end
      end

      DONE: begin
        r_out_nstat = IDLE;
      end

      default: ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_out_tile_x <= 'd0;
      r_out_tile_y <= 'd0;
      o_we         <= 'b0;
      r_wptr       <= 'd0;
      o_waddr      <= 'd0;
      o_wdat       <= 'd0;
      o_dn         <= 'b0;
      r_img_side   <= 'd0;
      r_tl_org_x   <= 'd0;
      r_tl_org_y   <= 'd0;
      o_desc_rdy   <= 'd0;
    end else begin
      case (r_out_cstat)
        IDLE: begin
          o_dn <= 'b0;
          if (i_desc_vld) begin
            {r_img_side, r_tl_org_x, r_tl_org_y} <= i_desc_din;
            o_desc_rdy                           <= 'b1;
          end
        end

        RUN: begin
          o_desc_rdy <= 'b0;

          if (i_buf_wr_rdy && (w_act_in || w_act_pad)) begin

            // output
            o_we    <= 'b1;
            r_wptr  <= r_wptr + 'd1;
            o_waddr <= r_wptr;

            if (w_act_pad) begin
              o_wdat <= 'd0;
            end else if (i_ipt_vld) begin
              o_wdat <= i_ipt_din;
            end

            // count tile x/y
            if (r_out_tile_x < PADDED_TILE_SIDE - 1) begin
              r_out_tile_x <= r_out_tile_x + 'd1;
            end else begin
              if (r_out_tile_y < PADDED_TILE_SIDE - 1) begin
                r_out_tile_x <= 'd0;
                r_out_tile_y <= r_out_tile_y + 'd1;
              end
            end
          end else begin
            o_we <= 'b0;
          end
        end

        DONE: begin
          o_dn         <= 'b1;
          o_we         <= 'b0;
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

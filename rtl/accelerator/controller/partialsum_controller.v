
`include "defines.vh"
`include "network_config.vh"
module partialsum_controller #(
    localparam SUM_CNT = `MAX_CHANNEL / `MAX_GROUP_CHANNEL
) (
    input                                          i_clk,
    input                                          i_rstn,
    input                                          i_st,
    output reg                                     o_dn,
    // GC
    input      [           `CLOG2_SAFE(SUM_CNT):0] i_sum_cnt, 
    input      [  `CLOG2_SAFE(`MAX_TILE_AREA) : 0] i_tile_opt_area,
    //
    input                                          i_bias_vld,
    input      [  `IPT_BIT* `MAX_GROUP_FILTER-1:0] i_bias_din,
    // partialsum buffer
    input                                          i_psb_rdy,
    output reg                                     o_psb_re,
    output reg [  `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] o_psb_raddr,
    input                                          i_psb_rvld,
    input      [`PSUM_BIT * `MAX_GROUP_FILTER-1:0] i_psb_rdin,
    output reg                                     o_psb_we,
    output reg [  `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] o_psb_waddr,
    output reg [ `PSUM_BIT* `MAX_GROUP_FILTER-1:0] o_psb_wdout,
    output                                         o_psc_rdy,
    // ipt (layer)
    input      [ `PSUM_BIT* `MAX_GROUP_FILTER-1:0] i_ipt_din,
    input                                          i_ipt_vld,
    output                                         o_ipt_rdy,
    input                                          i_opt_rdy,
    output reg                                     o_opt_vld,
    output reg [ `PSUM_BIT* `MAX_GROUP_FILTER-1:0] o_opt_dout
);
  // ====================== parmeter ======================= 

  localparam IDLE = 0;
  localparam START_SUM = 1;
  localparam SUM = 2;
  localparam DONE = 3;
  localparam STATE_END = 4;

  integer i;
  genvar p;
  // ====================== reg ============================ 
  //
  reg  [         $clog2( STATE_END)-1:0] r_cstat;
  reg  [         $clog2( STATE_END)-1:0] r_nstat;
  //
  reg  [         `CLOG2_SAFE(SUM_CNT):0] r_sum_cnt;
  reg  [`CLOG2_SAFE(`MAX_TILE_AREA) : 0] r_rptr;
  reg  [`CLOG2_SAFE(`MAX_TILE_AREA)-1:0] r_wptr;
  // 
  reg  [`CLOG2_SAFE(`MAX_TILE_AREA) : 0] r_pix_cnt;
  // ============F========== wire ===========================  
  wire [`PSUM_BIT*`MAX_GROUP_FILTER-1:0] w_sum;
  // ====================== assign =========================  
  assign o_psc_rdy = (i_ipt_vld && (r_cstat == SUM));
  assign o_ipt_rdy = 'd1;  // TODO
  generate
    for (p = 0; p < `MAX_GROUP_FILTER; p = p + 1) begin
      assign w_sum[p*`PSUM_BIT+:`PSUM_BIT] = $signed(
          i_ipt_din[p*`PSUM_BIT+:`PSUM_BIT]
      ) + $signed(
          i_psb_rdin[p*`PSUM_BIT+:`PSUM_BIT]
      );
    end
  endgenerate

  // ====================== FSM ============================

  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_cstat <= IDLE;
    end else begin
      r_cstat <= r_nstat;
    end
  end
  always @(*) begin
    r_nstat = r_cstat;
    case (r_cstat)

      IDLE: begin
        if (i_st) begin
          r_nstat = START_SUM;
        end
      end

      START_SUM: begin
        r_nstat = SUM;
      end

      SUM: begin
        if ((r_pix_cnt == i_tile_opt_area - 1) && i_ipt_vld) begin
          if (r_sum_cnt == i_sum_cnt) r_nstat = DONE;
          else r_nstat = START_SUM;
        end
      end

      DONE: begin
        r_nstat = IDLE;
      end

      default: ;

    endcase
  end
  // 
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      o_dn        <= 'd0;
      r_sum_cnt   <= 'd0;
      o_psb_re    <= 'b0;
      r_rptr      <= 'd0;
      o_psb_raddr <= 'd0;
      r_pix_cnt   <= 'd0;
      o_opt_dout  <= 'd0;
      o_opt_vld   <= 'b0;
      o_psb_we    <= 'b0;
      r_wptr      <= 'd0;
      o_psb_waddr <= 'd0;
      o_psb_wdout <= 'd0;
    end else begin
      o_dn <= 'd0;
      case (r_cstat)

        IDLE: begin
        end

        START_SUM: begin
          r_sum_cnt <= r_sum_cnt + 'd1;
          r_pix_cnt <= 'd0;
          o_psb_re  <= 'b0;
          r_rptr    <= 'd0;
          o_psb_we  <= 'b0;
          r_wptr    <= 'd0;
        end

        SUM: begin
          if (i_sum_cnt == 1) begin  // bypass
            if (i_ipt_vld) begin
              r_pix_cnt  <= r_pix_cnt + 1;
              o_opt_vld  <= 'b1;
              o_opt_dout <= i_ipt_din;
            end else begin
              o_opt_vld <= 'b0;
            end
          end else if (r_sum_cnt == 1) begin  // write
            if (i_ipt_vld) begin
              r_pix_cnt   <= r_pix_cnt + 1;
              o_psb_we    <= 'b1;
              o_psb_wdout  <= i_ipt_din;
              r_wptr  <= r_wptr + 'd1;
              o_psb_waddr <= r_wptr;
            end else begin
              o_psb_we <= 'b0;
            end

          end else if (r_sum_cnt == i_sum_cnt) begin  // read

            if (i_psb_rdy && (r_rptr < i_tile_opt_area)) begin
              o_psb_re    <= 'b1;
              o_psb_raddr <= r_rptr;
              r_rptr  <= r_rptr + 'd1;
            end else begin
              o_psb_re <= 'b0;
            end

            if (i_ipt_vld) begin
              r_pix_cnt  <= r_pix_cnt + 1;
              o_opt_vld  <= 'b1;
              o_opt_dout <= w_sum;
            end else begin
              o_opt_vld <= 'b0;
            end
          end else begin  // read + write
            if (i_psb_rdy && (r_rptr < i_tile_opt_area)) begin
              o_psb_re    <= 'b1;
              o_psb_raddr <= r_rptr;
              r_rptr  <= r_rptr + 'd1;
            end else begin
              o_psb_re <= 'b0;
            end

            if (i_ipt_vld) begin
              r_pix_cnt   <= r_pix_cnt + 1;
              o_psb_we    <= 'b1;
              o_psb_wdout <= w_sum;
              r_wptr      <= r_wptr + 'd1;
              o_psb_waddr <= r_wptr;
            end else begin
              o_psb_we <= 'b0;
            end
          end

        end

        DONE: begin
          o_dn      <= 'd1;
          r_sum_cnt <= 'd0;
          r_pix_cnt <= 'd0;
          r_rptr    <= 'd0;
          r_wptr    <= 'd0;
          o_psb_re  <= 'b0;
          r_sum_cnt <= 'd0;
          o_psb_we  <= 'b0;
          o_opt_vld <= 'b0;
        end

        default: ;
      endcase
    end
  end
  // ====================== always =========================  
  // ====================== module ========================= 
  // ====================== output =========================  
endmodule

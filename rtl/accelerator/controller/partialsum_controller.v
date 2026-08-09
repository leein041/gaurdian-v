
`include "defines.vh"
`include "network_config.vh"
module partialsum_controller #(
    localparam SUM_CNT = `MAX_CHANNEL / `MAX_GROUP_CHANNEL
) (
    input                                      i_clk,
    input                                      i_rstn,
    input                                      i_st,
    output                                     o_dn,
    // GC
    input  [           `CLOG2_SAFE(SUM_CNT):0] i_sum_cnt,
    input                                      i_relu,
    //
    input                                      i_bias_vld,
    input  [  `IPT_BIT* `MAX_GROUP_FILTER-1:0] i_bias_din,
    // partialsum buffer
    input                                      i_psb_rdy,
    output                                     o_psb_re,
    output [  `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] o_psb_raddr,
    input                                      i_psb_rvld,
    input  [`PSUM_BIT * `MAX_GROUP_FILTER-1:0] i_psb_rdin,
    output                                     o_psb_we,
    output [  `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] o_psb_waddr,
    output [ `PSUM_BIT* `MAX_GROUP_FILTER-1:0] o_psb_wdout,
    output                                     o_psc_rdy,
    // ipt (layer)
    input  [ `PSUM_BIT* `MAX_GROUP_FILTER-1:0] i_ipt_din,
    input                                      i_ipt_vld,
    output                                     o_ipt_rdy,
    input                                      i_opt_rdy,
    output                                     o_opt_vld,
    output [ `PSUM_BIT* `MAX_GROUP_FILTER-1:0] o_opt_dout
);
  // ====================== parmeter ======================= 

  localparam IDLE = 0;
  localparam START_SUM = 1;
  localparam SUM = 2;
  localparam CHECK_LAST = 3;
  localparam OUTPUT = 4;
  localparam DONE = 5;
  localparam STATE_END = 5;

  integer i;
  genvar p;
  // ============F========== wire ===========================  
  wire [ `PSUM_BIT*`MAX_GROUP_FILTER-1:0] w_sum;
  // ====================== reg ============================ 
  //
  reg  [          $clog2( STATE_END)-1:0] r_cstat;
  reg  [          $clog2( STATE_END)-1:0] r_nstat;
  reg                                     r_dn;
  //
  reg  [          `CLOG2_SAFE(SUM_CNT):0] r_sum_cnt;
  reg                                     r_re;
  reg  [ `CLOG2_SAFE(`MAX_TILE_AREA) : 0] r_rptr;
  reg  [ `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] r_raddr;
  reg                                     r_we;
  reg  [ `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] r_wptr;
  reg  [ `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] r_waddr;
  reg  [`PSUM_BIT* `MAX_GROUP_FILTER-1:0] r_wdat;
  // 
  reg  [ `CLOG2_SAFE(`MAX_TILE_AREA) : 0] r_pix_cnt;
  reg  [`PSUM_BIT* `MAX_GROUP_FILTER-1:0] r_odat;
  reg                                     r_ovld;
  //
  reg  [   `CLOG2_SAFE(`MAX_TILE_AREA):0] r_opt_cnt;
  // ====================== function =======================
  // ====================== hand shake =====================
  // ====================== assign ========================= 
  assign o_dn        = r_dn;
  assign o_psb_re    = r_re;
  assign o_psb_raddr = r_raddr;
  assign o_psb_we    = r_we;
  assign o_psb_waddr = r_waddr;
  assign o_psb_wdout = r_wdat;
  assign o_psc_rdy   = (i_ipt_vld && (r_cstat == SUM)) || (r_cstat == OUTPUT);
  assign o_ipt_rdy   = 'd1;  // TODO
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
  // compute CHECK_LAST state 
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
        if (r_pix_cnt == `MAX_TILE_AREA - 1) begin
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
      r_dn      <= 'd0;
      r_sum_cnt <= 'd0;
      r_re      <= 'b0;
      r_rptr    <= 'd0;
      r_raddr   <= 'd0;
      r_pix_cnt <= 'd0;
      r_odat    <= 'd0;
      r_ovld    <= 'b0;
      r_we      <= 'b0;
      r_wptr    <= 'd0;
      r_waddr   <= 'd0;
      r_wdat    <= 'd0;
      r_opt_cnt <= 'd0;
    end else begin
      r_dn <= 'd0;
      case (r_cstat)

        IDLE: begin
        end

        START_SUM: begin
          r_sum_cnt <= r_sum_cnt + 'd1;
          r_pix_cnt <= 'd0;
          r_re      <= 'b0;
          r_rptr    <= 'd0;
          r_we      <= 'b0;
          r_wptr    <= 'd0;
        end

        SUM: begin
          if (i_sum_cnt == 1) begin  // bypass
            if (i_ipt_vld) begin
              r_pix_cnt <= r_pix_cnt + 1;
              r_ovld <= 'b1;
              r_odat <= i_ipt_din;
            end else begin
              r_ovld <= 'b0;
            end
          end else if (r_sum_cnt == 1) begin  // write
            if (i_ipt_vld) begin
              r_pix_cnt   <= r_pix_cnt + 1;
              r_we    <= 'b1;
              r_wdat  <= i_ipt_din;
              r_wptr  <= r_wptr + 'd1;
              r_waddr <= r_wptr;
            end else begin
              r_we <= 'b0;
            end

          end else if (r_sum_cnt == i_sum_cnt) begin  // read

            if (i_psb_rdy && (r_rptr < `MAX_TILE_AREA)) begin
              r_re    <= 'b1;
              r_raddr <= r_rptr;
              r_rptr  <= r_rptr + 'd1;
            end else begin
              r_re <= 'b0;
            end

            if (i_ipt_vld) begin
              r_pix_cnt <= r_pix_cnt + 1;
              r_ovld    <= 'b1;
              r_odat    <= w_sum;
            end else begin
              r_ovld <= 'b0;
            end
          end else begin  // read + write
            if (i_psb_rdy && (r_rptr < `MAX_TILE_AREA)) begin
              r_re    <= 'b1;
              r_raddr <= r_rptr;
              r_rptr  <= r_rptr + 'd1;
            end else begin
              r_re <= 'b0;
            end

            if (i_ipt_vld) begin
              r_pix_cnt <= r_pix_cnt + 1;
              r_we      <= 'b1;
              r_wdat    <= w_sum;
              r_wptr    <= r_wptr + 'd1;
              r_waddr   <= r_wptr;
            end else begin
              r_we <= 'b0;
            end
          end

        end

        DONE: begin
          r_dn      <= 'd1;
          r_sum_cnt <= 'd0;
          r_pix_cnt <= 'd0;
          r_rptr    <= 'd0;
          r_wptr    <= 'd0;
          r_re      <= 'b0;
          r_sum_cnt <= 'd0;
          r_we      <= 'b0;
          r_ovld    <= 'b0;
        end

        default: ;
      endcase
    end
  end
  // ====================== always =========================  
  // ====================== module ========================= 
  // ====================== output ========================= 
  assign o_opt_vld  = r_ovld;
  assign o_opt_dout = r_odat;
endmodule

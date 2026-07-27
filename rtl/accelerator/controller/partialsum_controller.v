
`include "defines.vh"
`include "network_config.vh"
module partialsum_controller #(
    localparam SUM_CNT = `MAX_CHANNEL / `MAX_GROUP_CHANNEL
) (
    input                                             i_clk,
    input                                             i_rstn,
    // GC
    input                                             i_st,
    output                                            o_dn,
    input         [           `CLOG2_SAFE(SUM_CNT):0] i_sum_cnt,
    input                                             i_relu,
    //
    input                                             i_bias_vld,
    input         [  `IPT_BIT* `MAX_GROUP_FILTER-1:0] i_bias_din,
    // partialsum buffer
    input                                             i_psb_rdy,
    output                                            o_psb_re,
    output        [  `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] o_psb_raddr,
    input                                             i_psb_rvld,
    input         [`PSUM_BIT * `MAX_GROUP_FILTER-1:0] i_psb_rdin,
    output                                            o_psb_we,
    output        [  `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] o_psb_waddr,
    output        [ `PSUM_BIT* `MAX_GROUP_FILTER-1:0] o_psb_wdout,
    output                                            o_psc_rdy,
    // ipt (layer)
    input  signed [ `PSUM_BIT* `MAX_GROUP_FILTER-1:0] i_ipt_din,
    input                                             i_ipt_vld,
    output                                            o_ipt_rdy,
    // opt (GC)
    input                                             i_opt_rdy,
    output                                            o_opt_vld,
    output signed [  `OPT_BIT* `MAX_GROUP_FILTER-1:0] o_opt_dout
);
  // ====================== parmeter ======================= 

  localparam IDLE = 0;
  localparam START_SUM = 1;
  localparam SUM = 2;
  localparam CHECK_LAST = 3;
  localparam POST_PROC = 4;
  localparam DONE = 5;
  localparam STATE_END = 5;

  integer i;
  genvar p;
  // ============F========== wire ===========================
  wire signed [                   `PSUM_BIT-1:0] w_bias_ex_dat  [0:`MAX_GROUP_FILTER-1];
  // adder 
  wire                                           w_adder_vld    [0:`MAX_GROUP_FILTER-1];
  wire signed [                   `PSUM_BIT-1:0] w_adder_dat    [0:`MAX_GROUP_FILTER-1];
  // slicer
  wire                                           w_slicer_rdy   [0:`MAX_GROUP_FILTER-1];
  wire                                           w_slicer_vld   [0:`MAX_GROUP_FILTER-1];
  wire        [                    `OPT_BIT-1:0] w_slicer_dat   [0:`MAX_GROUP_FILTER-1];
  // relu
  wire                                           w_relu_rdy     [0:`MAX_GROUP_FILTER-1];
  wire                                           w_relu_vld     [0:`MAX_GROUP_FILTER-1];
  wire        [                    `OPT_BIT-1:0] w_relu_dat     [0:`MAX_GROUP_FILTER-1];
  wire        [  `MAX_GROUP_FILTER*`OPT_BIT-1:0] w_relu_dat_bus;
  //
  wire        [ `PSUM_BIT*`MAX_GROUP_FILTER-1:0] w_sum;
  // ====================== reg ============================

  reg signed  [                    `IPT_BIT-1:0] r_bias_dat     [0:`MAX_GROUP_FILTER-1];
  //
  reg         [          $clog2( STATE_END)-1:0] r_cstat;
  reg         [          $clog2( STATE_END)-1:0] r_nstat;
  reg                                            r_dn;
  //
  reg         [          `CLOG2_SAFE(SUM_CNT):0] r_sum_idx;
  reg                                            r_re;
  reg         [ `CLOG2_SAFE(`MAX_TILE_AREA) : 0] r_rptr;
  reg         [ `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] r_raddr;
  reg                                            r_we;
  reg         [ `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] r_wptr;
  reg         [ `CLOG2_SAFE(`MAX_TILE_AREA)-1:0] r_waddr;
  reg         [`PSUM_BIT* `MAX_GROUP_FILTER-1:0] r_wdat;
  // 
  reg         [`PSUM_BIT* `MAX_GROUP_FILTER-1:0] r_rdat;
  reg                                            r_rvld;
  //
  reg         [   `CLOG2_SAFE(`MAX_TILE_AREA):0] r_opt_cnt;
  // ====================== function =======================
  // ====================== hand shake =====================
  // ====================== assign ========================= 
  assign o_dn        = r_dn;
  assign o_psb_re    = r_re;
  assign o_psb_raddr = r_raddr;
  assign o_psb_we    = r_we;
  assign o_psb_waddr = r_waddr;
  assign o_psb_wdout = r_wdat;
  assign o_psc_rdy   = (i_ipt_vld && (r_cstat == SUM)) || (r_cstat == POST_PROC);
  assign o_ipt_rdy   = 'd1;  // TODO
  generate
    for (p = 0; p < `MAX_GROUP_FILTER; p = p + 1) begin
      assign w_relu_dat_bus[p*`OPT_BIT+:`OPT_BIT] = w_relu_dat[p];
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
        if (r_wptr == `MAX_TILE_AREA - 1) begin
          r_nstat = CHECK_LAST;
        end
      end

      CHECK_LAST: begin
        if (r_sum_idx == i_sum_cnt - 1) begin
          r_nstat = POST_PROC;
        end else begin
          r_nstat = START_SUM;
        end
      end

      POST_PROC: begin
        if (r_opt_cnt == `MAX_TILE_AREA - 1) begin
          r_nstat = DONE;
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
      r_sum_idx <= 'd0;
      r_re      <= 'b0;
      r_rptr    <= 'd0;
      r_raddr   <= 'd0;
      r_rdat    <= 'd0;
      r_rvld    <= 'b0;
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
        end

        SUM: begin
          if (r_sum_idx == 0) begin

            if (i_ipt_vld) begin
              r_we    <= 'b1;
              r_wdat  <= i_ipt_din;
              r_wptr  <= r_wptr + 'd1;
              r_waddr <= r_wptr;
            end else begin
              r_we <= 'b0;
            end

          end else begin

            if (i_psb_rdy && (r_rptr < `MAX_TILE_AREA)) begin
              r_re    <= 'b1;
              r_raddr <= r_rptr;
              r_rptr  <= r_rptr + 'd1;
            end else begin
              r_re <= 'b0;
            end

            if (i_ipt_vld) begin
              r_we    <= 'b1;
              r_wdat  <= w_sum;
              r_wptr  <= r_wptr + 'd1;
              r_waddr <= r_wptr;
            end else begin
              r_we <= 'b0;
            end

          end
        end

        CHECK_LAST: begin
          r_we   <= 'b0;
          r_wptr <= 'd0;
          r_rptr <= 'd0;
          if (r_sum_idx < i_sum_cnt - 1) begin
            r_sum_idx <= r_sum_idx + 'd1;
          end
        end

        POST_PROC: begin

          if (r_rptr < `MAX_TILE_AREA) begin
            r_re    <= 'b1;
            r_raddr <= r_rptr;
            r_rptr  <= r_rptr + 'd1;
          end else begin
            r_re <= 'b0;
          end

          if (i_psb_rvld) begin
            r_rvld <= 'b1;
            r_rdat <= i_psb_rdin;
          end else begin
            r_rvld <= 'b0;
          end

          if (o_opt_vld) begin
            r_opt_cnt <= r_opt_cnt + 'd1;
          end
        end

        DONE: begin
          r_sum_idx <= 'd0;
          r_dn      <= 'd1;
          r_rptr    <= 'd0;
          r_wptr    <= 'd0;
          r_re      <= 'b0;
          r_opt_cnt <= 'd0;
          r_rvld    <= 'b0;
        end

        default: ;
      endcase
    end
  end
  // ====================== always ========================= 
  // update bias data
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      for (i = 0; i < `MAX_GROUP_FILTER; i = i + 1) begin
        r_bias_dat[i] <= 'd0;
      end
    end else begin
      if (i_bias_vld) begin
        for (i = 0; i < `MAX_GROUP_FILTER; i = i + 1) begin
          r_bias_dat[i] <= i_bias_din[i*`IPT_BIT+:`IPT_BIT];
        end
      end
    end
  end
  // ====================== module =========================

  for (p = 0; p < `MAX_GROUP_FILTER; p = p + 1) begin
    bit_extender #(
        .IPT_BIT(`IPT_BIT),
        .OPT_BIT(`PSUM_BIT),
        .LSB_PAD(8),
        .SIGNED (1)
    ) inst_bit_extender (
        .i_din (r_bias_dat[p]),
        .o_dout(w_bias_ex_dat[p])
    );
    // bias adder
    adder #(
        .BIT(`PSUM_BIT)
    ) inst_bias_adder (
        .i_clk     (i_clk),
        .i_rstn    (i_rstn),
        .o_ipt1_rdy(),
        .i_ipt1_vld(r_rvld),
        .i_ipt1_din(r_rdat[p*`PSUM_BIT+:`PSUM_BIT]),
        .o_ipt2_rdy(),
        .i_ipt2_vld('b1),
        .i_ipt2_din(w_bias_ex_dat[p]),
        .i_opt_rdy ('b1),                             // TODO
        .o_opt_vld (w_adder_vld[p]),
        .o_opt_dout(w_adder_dat[p])
    );

    // bit slice
    bit_slicer #(
        .IPT_BIT(`PSUM_BIT),
        .OPT_BIT(`OPT_BIT)
    ) inst_bit_slicer (
        .i_clk     (i_clk),
        .i_rstn    (i_rstn),
        .i_ipt_din (w_adder_dat[p]),
        .i_ipt_vld (w_adder_vld[p]),
        .o_ipt_rdy (),
        .i_opt_rdy ('b1),
        .o_opt_vld (w_slicer_vld[p]),
        .o_opt_dout(w_slicer_dat[p])
    );

    // ReLU
    relu #(
        .BITS(`OPT_BIT)
    ) inst_relu (
        .i_clk     (i_clk),
        .i_rstn    (i_rstn),
        .i_relu_en (i_relu),           // TODO
        // ipt
        .i_ipt_din (w_slicer_dat[p]),
        .i_ipt_vld (w_slicer_vld[p]),
        .o_ipt_rdy (w_relu_rdy[p]),
        // opt
        .i_opt_rdy ('b1),
        .o_opt_vld (w_relu_vld[p]),
        .o_opt_dout(w_relu_dat[p])
    );
  end
  // ====================== output ========================= 
  assign o_opt_vld  = w_relu_vld[0];
  assign o_opt_dout = w_relu_dat_bus;
endmodule


`include "defines.vh"
`include "network_config.vh"

module weight_reader #(
    parameter WIDTH     = 0,
    parameter BUF_DEPTH = 0
) (
    input                               i_clk,
    input                               i_rstn,
    input                               i_clr,
    input                               i_st,
    output                              o_dn,
    input                               i_ws_wr_rdy,
    // 
    input  [`CLOG2_SAFE(BUF_DEPTH) : 0] i_read_len,
    input  [     $clog2(BUF_DEPTH)-1:0] i_read_addr,
    // Buffer read
    input                               i_buf_rd_rdy,
    output                              o_re,
    output [     $clog2(BUF_DEPTH)-1:0] o_raddr,
    // Buffer Data
    output                              o_ipt_rdy,
    input                               i_ipt_vld,
    input  [                 WIDTH-1:0] i_ipt_din,
    // Stream Output
    input                               i_opt_rdy,
    output                              o_opt_vld,
    output [                 WIDTH-1:0] o_opt_dout
);
  // ====================== parmeter =======================  
  localparam READ_IDLE = 0;
  localparam READ_READY = 1;
  localparam READ_RUN = 2;
  localparam READ_DONE = 3;
  localparam READ_STATE_END = 4;

  localparam OUT_IDLE = 0;
  localparam OUT_RUN = 1;
  localparam OUT_DONE = 2;
  localparam OUT_STATE_END = 1;
  // ====================== wire =========================== 
  // ====================== reg ============================  
  wire                              w_act_out;
  //
  reg  [$clog2(READ_STATE_END)-1:0] r_read_cstat;
  reg  [$clog2(READ_STATE_END)-1:0] r_read_nstat;
  reg                               r_read_dn;
  reg  [ $clog2(OUT_STATE_END)-1:0] r_out_cstat;
  reg  [ $clog2(OUT_STATE_END)-1:0] r_out_nstat;
  reg                               r_out_dn;
  // RC
  reg                               r_dn;
  reg                               r_re;
  reg  [     $clog2(BUF_DEPTH) : 0] r_rcnt;
  reg  [     $clog2(BUF_DEPTH) : 0] r_base_addr;
  reg  [     $clog2(BUF_DEPTH)-1:0] r_raddr;
  // 
  reg  [     $clog2(BUF_DEPTH) : 0] r_opt_cnt;
  reg                               r_opt_vld;
  reg  [                 WIDTH-1:0] r_opt_dat;
  // ====================== assign =========================     
  assign o_dn       = r_dn;

  assign o_re       = r_re;
  assign o_raddr    = r_raddr;

  assign o_ipt_rdy  = i_opt_rdy || !r_opt_vld;
  assign o_opt_vld  = r_opt_vld;
  assign o_opt_dout = r_opt_dat;

  assign w_act_out  = o_opt_vld && i_opt_rdy;
  // ====================== FSM ============================

  //      ____                _   _____ ____  __  __ 
  //     |  _ \ ___  __ _  __| | |  ___/ ___||  \/  |
  //     | |_) / _ \/ _` |/ _` | | |_  \___ \| |\/| |
  //     |  _ <  __/ (_| | (_| | |  _|  ___) | |  | |
  //     |_| \_\___|\__,_|\__,_| |_|   |____/|_|  |_|
  //                                                 
  //  initialize and update state register    
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) r_read_cstat <= READ_IDLE;
    else r_read_cstat <= r_read_nstat;

  end
  // compute next state 
  always @(*) begin
    r_read_nstat = r_read_cstat;
    case (r_read_cstat)
      READ_IDLE: begin
        if (i_st) r_read_nstat = READ_READY;
      end

      READ_READY: begin
        if (i_buf_rd_rdy && i_ws_wr_rdy) r_read_nstat = READ_RUN;
      end

      READ_RUN: begin
        if (r_rcnt == i_read_len) r_read_nstat = READ_DONE;
      end

      READ_DONE: begin
        r_read_nstat = READ_IDLE;
      end

      default: ;
    endcase
  end
  // 
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_re        <= 'b0;
      r_rcnt      <= 'd0;
      r_base_addr <= 'd0;
      r_raddr     <= 'd0;
    end else begin
      case (r_read_cstat)

        READ_IDLE: begin
          if (i_st) r_base_addr <= i_read_addr;
        end

        READ_READY: begin
        end

        READ_RUN: begin
          if (r_rcnt < i_read_len) begin
            r_re    <= 'b1;
            r_base_addr  <= r_base_addr + 'd1;
            r_raddr <= r_base_addr;
            r_rcnt  <= r_rcnt + 'd1;
          end else begin
            r_re <= 'b0;
          end
        end

        READ_DONE: begin
          r_rcnt <= 'd0;
          r_re   <= 'b0;
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
    if (~i_rstn) r_out_cstat <= OUT_IDLE;
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
        if ((r_opt_cnt == i_read_len) && w_act_out) r_out_nstat = OUT_DONE;
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
      r_opt_vld <= 'b0;
      r_opt_dat <= 'd0;
      r_opt_cnt <= 'd0;
      r_dn      <= 'b0;
    end else begin
      case (r_out_cstat)
        OUT_IDLE: begin
          r_dn <= 'b0;
        end

        OUT_RUN: begin
          if (i_ipt_vld) begin
            r_opt_vld <= 'b1;
            r_opt_dat <= i_ipt_din;
            r_opt_cnt <= r_opt_cnt + 'd1;
          end else begin
            r_opt_vld <= 'b0;
          end
        end
        OUT_DONE: begin
          r_dn      <= 'b1;
          r_opt_cnt <= 'd0;
        end

        default: ;

      endcase
    end
  end
  // ====================== output ========================= 
endmodule

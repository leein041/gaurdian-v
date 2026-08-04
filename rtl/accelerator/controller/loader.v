
`include "defines.vh"
`include "network_config.vh"

module loader #(
    parameter WIDTH      = 0,
    parameter IPT_DEPTH  = 0,
    parameter BUF_DEPTH  = 0,
    parameter BANK_NUM   = 0,
    parameter BANK_DEPTH = 0
) (
    input                          i_clk,
    input                          i_rstn,
    input                          i_clr,
    input                          i_st,
    output                         o_dn,
    // Config 
    input  [ $clog2(BANK_DEPTH):0] i_bank_depth,
    // Request Info
    input  [$clog2(IPT_DEPTH) : 0] i_req_len,
    input  [$clog2(IPT_DEPTH)-1:0] i_req_addr,
    // Request Reader
    output [  $clog2(IPT_DEPTH):0] o_req_len,
    output                         o_req,
    output [$clog2(IPT_DEPTH)-1:0] o_req_addr,
    input                          i_req_dn,
    // ipt (FIFO)
    output                         o_ipt_rdy,
    input                          i_ipt_vld,
    input  [            WIDTH-1:0] i_ipt_din,
    // opt (buffer)
    output [ $clog2(BANK_NUM) : 0] o_bank_idx,
    output                         o_we,
    output [  $clog2(BUF_DEPTH):0] o_waddr,
    output [            WIDTH-1:0] o_wdat
);
  // ====================== parmeter =======================  
  localparam REQ_IDLE = 0;
  localparam REQ_RUN = 1;
  localparam REQ_WAIT = 2;
  localparam REQ_DONE = 3;
  localparam REQ_STATE_END = 4;

  localparam OUT_IDLE = 0;
  localparam OUT_RUN = 1;
  localparam OUT_WAIT = 2;
  localparam OUT_DONE = 3;
  localparam OUT_STATE_END = 4;

  // ====================== wire =========================== 
  // ====================== reg ============================ 
  //
  reg [$clog2(REQ_STATE_END)-1:0] r_req_cstat;
  reg [$clog2(REQ_STATE_END)-1:0] r_req_nstat;
  reg [$clog2(OUT_STATE_END)-1:0] r_out_cstat;
  reg [$clog2(OUT_STATE_END)-1:0] r_out_nstat;
  // 
  reg                             r_dn;
  reg [    $clog2(IPT_DEPTH) : 0] r_req_len;
  reg                             r_req;
  reg [    $clog2(IPT_DEPTH)-1:0] r_raddr;
  // 
  reg                             r_we;
  reg [     $clog2(BANK_NUM) : 0] r_bank_ptr;
  reg [     $clog2(BANK_NUM) : 0] r_bank_idx;
  reg [                WIDTH-1:0] r_wdat;
  reg [    $clog2(IPT_DEPTH) : 0] r_wcnt;
  reg [    $clog2(BUF_DEPTH) : 0] r_wptr;
  reg [    $clog2(BUF_DEPTH)-1:0] r_waddr;
  // ====================== assign =========================     
  assign o_dn       = r_dn;

  assign o_ipt_rdy  = 'b1;  // always ready

  assign o_req_len  = r_req_len;
  assign o_req      = r_req;
  assign o_req_addr = r_raddr;
  //
  assign o_we       = r_we;
  assign o_bank_idx = r_bank_idx;
  assign o_waddr    = r_waddr;
  assign o_wdat     = r_wdat;

  // ====================== FSM ============================
  //      ____                            _     _____ ____  __  __ 
  //     |  _ \ ___  __ _ _   _  ___  ___| |_  |  ___/ ___||  \/  |
  //     | |_) / _ \/ _` | | | |/ _ \/ __| __| | |_  \___ \| |\/| |
  //     |  _ <  __/ (_| | |_| |  __/\__ \ |_  |  _|  ___) | |  | |
  //     |_| \_\___|\__, |\__,_|\___||___/\__| |_|   |____/|_|  |_|
  //                   |_|                                         
  //  initialize and update state register    
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_req_cstat <= REQ_IDLE;
    end else begin
      r_req_cstat <= r_req_nstat;
    end
  end
  // compute next state 
  always @(*) begin
    r_req_nstat = r_req_cstat;
    case (r_req_cstat)

      REQ_IDLE: begin
        if (i_st) r_req_nstat = REQ_RUN;
      end

      REQ_RUN: begin
        r_req_nstat = REQ_WAIT;
      end

      REQ_WAIT: begin
        if (i_req_dn) r_req_nstat = REQ_DONE;
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
      r_req <= 'b0;
      r_req_len <= 'd0;
      r_raddr <= 'd0;
    end else begin
      case (r_req_cstat)
        REQ_IDLE: begin
        end

        REQ_RUN: begin
          r_req     <= 'b1;
          r_req_len <= i_req_len;
          r_raddr   <= i_req_addr;
        end

        REQ_WAIT: begin
          r_req <= 'b0;

        end

        REQ_DONE: begin
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
        if (r_wcnt == i_req_len) begin
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
      r_we       <= 'b0;
      r_bank_ptr <= 'd0;
      r_bank_idx <= 'd0;
      r_wptr     <= 'd0;
      r_wcnt     <= 'd0;
      r_waddr    <= 'd0;
      r_wdat     <= 'd0;
      r_dn       <= 'b0;
    end else begin
      case (r_out_cstat)
        OUT_IDLE: begin
          r_dn <= 'b0;
        end

        OUT_RUN: begin
          if (i_ipt_vld) begin  // TOOD : consider o_ipt_rdy

            if (r_wptr < i_bank_depth - 1) begin
              r_wptr <= r_wptr + 'd1;
            end else begin
              r_wptr <= 'd0;
              if (r_bank_ptr < BANK_NUM - 1) begin
                r_bank_ptr <= r_bank_ptr + 'd1;
              end else begin
                r_bank_ptr <= 'd0;
              end
            end
            r_bank_idx <= r_bank_ptr;
            r_wcnt     <= r_wcnt + 'd1;
            r_we       <= 'b1;
            r_waddr    <= r_wptr;
            r_wdat     <= i_ipt_din;
          end else begin
            r_we <= 'b0;
          end
        end
        OUT_DONE: begin
          r_wcnt <= 'd0;
          r_dn   <= 'b1;
          r_we   <= 'b0;
        end

        default: ;

      endcase
    end
  end
  // ====================== output ========================= 
endmodule

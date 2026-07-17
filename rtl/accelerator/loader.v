
`include "defines.vh"
`include "network_config.vh"

module loader (
    input                               i_clk,
    input                               i_rstn,
    input                               i_clr,
    input                               i_st,
    output                              o_dn,
    // GC
    input  [$clog2(`MAX_WGT_DEPTH) : 0] i_rlen,
    input  [$clog2(`MAX_WGT_DEPTH)-1:0] i_st_addr,
    // RC
    output [  $clog2(`MAX_WGT_DEPTH):0] o_rlen,
    output                              o_req,
    output [$clog2(`MAX_WGT_DEPTH)-1:0] o_raddr,
    input                               i_rdn,
    // ipt (FIFO)
    output                              o_ipt_rdy,
    input                               i_ipt_vld,
    input  [              `WGT_BIT-1:0] i_ipt_din,
    // opt (layer)
    input                               i_opt_dn,
    input                               i_opt_rdy,
    output                              o_opt_vld,
    output [              `WGT_BIT-1:0] o_opt_dout
);
  // ====================== parmeter =======================  
  localparam IDLE = 0;
  localparam REQ = 1;
  localparam WAIT = 2;
  localparam DONE = 3;
  localparam STATE_END = 4;
 
  // ====================== wire =========================== 
  // ====================== reg ============================ 
  //
  reg [     $clog2(STATE_END)-1:0] r_cstat;
  reg [     $clog2(STATE_END)-1:0] r_nstat;
  reg                              r_dn;
  // RC

  reg [$clog2(`MAX_WGT_DEPTH) : 0] r_rlen;
  reg                              r_req;
  reg [$clog2(`MAX_WGT_DEPTH)-1:0] r_raddr;
  // ====================== assign =========================     
  assign o_dn       = r_dn;

  assign o_rlen     = r_rlen;
  assign o_req      = r_req;
  assign o_raddr    = r_raddr;

  assign o_ipt_rdy  = i_opt_rdy;
  assign o_opt_vld  = i_ipt_vld;
  assign o_opt_dout = i_ipt_din;

  // ====================== FSM ============================
  //  initialize and update state register    
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_cstat <= IDLE;
    end else begin
      r_cstat <= r_nstat;
    end
  end
  // compute next state 
  always @(*) begin
    r_nstat = r_cstat;
    case (r_cstat)

      IDLE: begin
        if (i_st) r_nstat = REQ;
      end

      REQ: begin
        r_nstat = WAIT;
      end

      WAIT: begin
        if (i_rdn) r_nstat = DONE;
      end

      DONE: begin
      end

      default: ;
    endcase
  end
  // 
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_dn    <= 'b0;
      r_req   <= 'b0;
      r_rlen  <= 'd0;
      r_raddr <= 'd0;
    end else begin
      case (r_cstat)
        IDLE: begin
          r_dn <= 'b0;
        end

        REQ: begin
          r_req   <= 'b1;
          r_rlen  <= i_rlen;
          r_raddr <= i_st_addr;
        end

        WAIT: begin
          r_req <= 'b0;

        end

        DONE: begin
          r_dn <= 'b1;
        end
        default: ;
      endcase
    end
  end

  // ====================== output ========================= 
endmodule

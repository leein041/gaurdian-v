
`include "defines.vh"
`include "network_config.vh"

module read_controller #(
    parameter WIDTH = 0,
    parameter DEPTH = 0
) (
    input                      i_clk,
    input                      i_rstn,
    // tl  
    input  [  $clog2(DEPTH):0] i_req_len,
    input                      i_req,
    input  [$clog2(DEPTH)-1:0] i_req_addr,
    output                     o_req_dn,
    // DDR
    output                     o_re,
    output [$clog2(DEPTH)-1:0] o_raddr,
    input                      i_rvld,
    input  [        WIDTH-1:0] i_rdin,
    // FIFO 
    output                     o_opt_vld,
    output [        WIDTH-1:0] o_opt_dout
);
  // ====================== parmeter =======================    
  localparam IDLE = 0;
  localparam READ = 1;
  localparam DONE = 2;
  localparam STATE_END = 3;
  // ====================== wire ==========================  

  // ====================== reg ============================  
  reg [$clog2(STATE_END)-1:0] r_cstat;
  reg [$clog2(STATE_END)-1:0] r_nstat;
  //
  reg [      $clog2(DEPTH):0] r_req_len;
  reg                         r_re;
  reg [      $clog2(DEPTH):0] r_rptr;
  reg [      $clog2(DEPTH):0] r_rcnt;
  reg [    $clog2(DEPTH)-1:0] r_raddr;
  //
  reg                         r_rdn;
  // ====================== assign =========================    
  assign o_req_dn = r_rdn;
  // ====================== always =========================  
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
      IDLE: if (i_req) r_nstat = READ;
      READ: if (r_req_len == r_rcnt) r_nstat = DONE;
      DONE: r_nstat = IDLE;
      default: ;
    endcase
  end
  // 
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_rdn     <= 'b0;
      r_re      <= 'b0;
      r_rptr    <= 'd0;
      r_raddr   <= 'd0;
      r_req_len <= 'd0;
      r_rcnt    <= 'd0;
    end else begin
      case (r_cstat)

        IDLE: begin
          r_rdn <= 'b0;
          if (i_req) begin
            r_rptr    <= i_req_addr;
            r_req_len <= i_req_len;
          end
        end

        READ: begin
          if (r_rcnt < r_req_len) begin
            r_rcnt  <= r_rcnt + 'd1;
            r_re    <= 'b1;
            r_rptr  <= r_rptr + 'd1;
            r_raddr <= r_rptr;

          end else begin

            r_re <= 'b0;

          end
        end

        DONE: begin
          r_rcnt <= 'd0;
          r_rdn  <= 'b1;
        end

        default: ;

      endcase
    end
  end
  // ====================== output ========================= 
  assign o_re       = r_re;
  assign o_raddr    = r_raddr;
  // bypass
  assign o_opt_vld  = i_rvld;
  assign o_opt_dout = i_rdin;
endmodule

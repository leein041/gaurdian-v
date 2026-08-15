
`include "defines.vh"
`include "network_config.vh"

module read_controller #(
    parameter WIDTH        = 0,
    parameter DEPTH        = 0,
    parameter REQ_LEN_BIT  = 0,
    parameter REQ_ADDR_BIT = 0
) (
    input                                         i_clk,
    input                                         i_rstn,
    output reg                                    o_dn,
    // que
    input                                         i_que_empty,
    input      [REQ_LEN_BIT + REQ_ADDR_BIT - 1:0] i_que_din,
    output reg                                    o_que_pop,
    // DDR
    output reg                                    o_re,
    output reg [          `CLOG2_SAFE(DEPTH)-1:0] o_raddr,
    input                                         i_rvld,
    input      [                       WIDTH-1:0] i_rdin,
    // FIFO 
    input                                         i_opt_rdy,
    output                                        o_opt_vld,
    output     [                       WIDTH-1:0] o_opt_dout
);
  // ====================== parmeter =======================    
  localparam IDLE = 0;
  localparam READ = 1;
  localparam DONE = 2;
  localparam STATE_END = 3;
  // ====================== wire ==========================  

  // ====================== reg ============================  
  reg [`CLOG2_SAFE(STATE_END)-1:0] r_cstat;
  reg [`CLOG2_SAFE(STATE_END)-1:0] r_nstat;
  //
  reg [      `CLOG2_SAFE(DEPTH):0] r_req_len;
  reg [      `CLOG2_SAFE(DEPTH):0] r_rptr;
  reg [      `CLOG2_SAFE(DEPTH):0] r_rcnt;
  // ====================== assign =========================     
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
      IDLE: begin
        if (!i_que_empty) r_nstat = READ;
      end

      READ: begin
        if ((r_rcnt == r_req_len) && i_opt_rdy) begin
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
      o_dn      <= 'b0;
      o_re      <= 'b0;
      r_rptr    <= 'd0;
      o_raddr   <= 'd0;
      r_req_len <= 'd0;
      r_rcnt    <= 'd0;
      o_que_pop <= 'b0;
    end else begin
      case (r_cstat)

        IDLE: begin
          o_dn <= 'b0;
          if (!i_que_empty) begin
            o_que_pop <= 'b1;
            r_req_len <= i_que_din[REQ_LEN_BIT+REQ_ADDR_BIT-1:REQ_ADDR_BIT];
            r_rptr    <= i_que_din[REQ_ADDR_BIT-1:0];
          end
        end

        READ: begin
          o_que_pop <= 'b0;
          if (i_opt_rdy && r_rcnt < r_req_len) begin
            r_rcnt  <= r_rcnt + 'd1;
            o_re    <= 'b1;
            r_rptr  <= r_rptr + 'd1;
            o_raddr <= r_rptr; 
          end else begin
            o_re <= 'b0;
          end
        end

        DONE: begin
          o_re   <= 'b0;
          r_rcnt <= 'd0;
          o_dn   <= 'b1;
        end

        default: ;

      endcase
    end
  end
  // ====================== output =========================  
  // bypass
  assign o_opt_vld  = i_rvld;
  assign o_opt_dout = i_rdin;
endmodule

`include "defines.vh"
`include "network_config.vh"
module module (
    input  i_clk,
    input  i_rstn,
    input  i_st,
    output o_dn,
    //
    output o_sched_st,
    input  i_sched_dn
);
  // ====================== parmeter ======================= 
  localparam IDLE = 1;
  // bias
  localparam START = 2;
  localparam RUN = 3;
  localparam DONE = 4;

  localparam STATE_END = 5;


  integer                              i;
  // ====================== wire ===========================  
  // ====================== reg ============================ 
  reg     [`CLOG2_SAFE(STATE_END)-1:0] r_cstat;  // current state
  reg     [`CLOG2_SAFE(STATE_END)-1:0] r_nstat;  // next state     
  // ====================== assign =========================  
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
      end

      START: begin 
      end

      RUN: begin 
      end

      DONE: begin 
      end

      default: ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_dn       <= 'd0;
      r_sched_st <= 'b0;
    end else begin
      case (r_cstat)

        IDLE: begin 
        end

        START: begin 
        end

        RUN: begin
        end

        DONE: begin 
        end

        default: ;
      endcase
    end
  end

  // ====================== module ========================= 
endmodule



`include "defines.vh"
`include "network_config.vh"
module global_ctrl (
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
  reg                                  r_dn;
  reg                                  r_sched_st;
  // ====================== assign ========================= 
  assign o_sched_st = r_sched_st;
  assign o_dn       = r_dn;
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
        if (i_st) r_nstat = START;
      end

      START: begin
        r_nstat = RUN;
      end

      RUN: begin
        if (i_sched_dn) r_nstat = DONE;
      end

      DONE: begin
        r_nstat = IDLE;
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
          r_dn <= 'b0;
          if (i_st) begin
            r_sched_st = 'b1;
          end
        end

        START: begin
          r_sched_st = 'b0;
        end

        RUN: begin
        end

        DONE: begin
          r_dn <= 'b1;
        end

        default: ;
      endcase
    end
  end

  // ====================== module ========================= 
endmodule

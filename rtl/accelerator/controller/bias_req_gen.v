
`include "defines.vh"
`include "network_config.vh"

module bias_req_gen #(
    parameter BIAS_BUF_DEPTH      = 0,
    parameter MAX_BIAS_BANK_DEPTH = 0,
    parameter MAX_BIAS_BANK_NUM   = 0
) (
    input                                                                            i_clk,
    input                                                                            i_rstn,
    input                                                                            i_st,
    output reg                                                                       o_dn,
    //
    input                                                                            i_que_full,
    input      [                                 `CLOG2_SAFE(MAX_BIAS_BANK_DEPTH):0] i_bank_depth,
    input      [                                   `CLOG2_SAFE(MAX_BIAS_BANK_NUM):0] i_bank_num,
    // 
    input      [                                    `CLOG2_SAFE(BIAS_BUF_DEPTH) : 0] i_req_len,
    input      [                                    `CLOG2_SAFE(BIAS_BUF_DEPTH)-1:0] i_req_addr,
    // request que
    output reg                                                                       o_req,
    output reg [                                    `CLOG2_SAFE(BIAS_BUF_DEPTH) : 0] o_req_len,
    output reg [                                    `CLOG2_SAFE(BIAS_BUF_DEPTH)-1:0] o_req_addr,
    // desc fifo
    output reg                                                                       o_desc_vld,
    output reg [`CLOG2_SAFE(MAX_BIAS_BANK_DEPTH)+`CLOG2_SAFE(MAX_BIAS_BANK_NUM)+1:0] o_desc_dout
);
  // ====================== parmeter =======================  
  localparam REQ_IDLE = 0;
  localparam REQ_RUN = 1;
  localparam REQ_DONE = 2;
  localparam REQ_END = 3;

  // ====================== reg ============================
  reg [`CLOG2_SAFE(REQ_END)-1:0] r_req_cstat;
  reg [`CLOG2_SAFE(REQ_END)-1:0] r_req_nstat;
  // ====================== wire ===========================     
  // ====================== assign =========================         
  //  
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
        if (i_st) begin
          r_req_nstat = REQ_RUN;
        end
      end

      REQ_RUN: begin
        if (!i_que_full) begin
          r_req_nstat = REQ_DONE;  // only one request
        end
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
      o_req       <= 'd0;
      o_req_len   <= 'd0;
      o_req_addr  <= 'd0;
      o_desc_vld  <= 'd0;
      o_desc_dout <= 'd0;
    end else begin
      case (r_req_cstat)
        REQ_IDLE: begin
          o_dn <= 'b0;
          if (i_st) begin
            o_desc_vld  <= 'b1;
            o_desc_dout <= {i_bank_depth, i_bank_num};
          end
        end

        REQ_RUN: begin
          o_desc_vld <= 'b0;

          if (!i_que_full) begin
            o_req      <= 'b1;
            o_req_len  <= i_req_len;
            o_req_addr <= i_req_addr;
          end else begin
            o_req <= 'b0;
          end
        end

        REQ_DONE: begin
          o_dn  <= 'b1;
          o_req <= 'b0;
        end
        default: ;
      endcase
    end
  end
  // ====================== output =========================  

endmodule

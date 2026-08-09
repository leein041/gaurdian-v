
module queue #(
    parameter WIDTH = 0,
    parameter DEPTH = 0
) (
    input                      i_clk,
    input                      i_rstn,
    //
    input                      i_push,
    input                      i_pop,
    output                     o_full,
    output                     o_empty,
    // ipt 
    input  signed [WIDTH -1:0] i_ipt_din,
    // opt 
    output signed [WIDTH -1:0] o_opt_dout
);
  // ====================== parmeter =======================       
  integer                   i;
  // ====================== reg ============================ 
  reg     [     WIDTH -1:0] r_que      [0:DEPTH-1];
  reg     [$clog2(DEPTH):0] r_push_ptr;
  reg     [$clog2(DEPTH):0] r_pop_ptr;
  reg     [$clog2(DEPTH):0] r_cnt;
  // ====================== wire ===========================
  // ====================== assign =========================  
  assign o_opt_dout = r_que[r_pop_ptr];
  assign o_full     = (DEPTH - 1 <= r_cnt);
  assign o_empty    = (r_cnt == 0);
  // ====================== always ========================= 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_push_ptr <= 0;
      r_pop_ptr <= 0;
      r_cnt <= 0;
      for (i = 0; i < DEPTH; i = i + 1) begin
        r_que[i] <= 'd0;
      end
    end else begin
      case ({
        i_push, i_pop
      })
        2'b10: begin  // 쓰기만
          r_que[r_push_ptr] <= i_ipt_din;
          r_push_ptr        <= (r_push_ptr == DEPTH - 1) ? 0 : r_push_ptr + 1;
          r_cnt             <= r_cnt + 1;
        end 
        2'b01: begin  // 읽기만
          r_pop_ptr <= (r_pop_ptr == DEPTH - 1) ? 0 : r_pop_ptr + 1;
          r_cnt    <= r_cnt - 1;
        end
        2'b11: begin  // 동시 발생
          r_que[r_push_ptr] <= i_ipt_din;
          r_push_ptr        <= (r_push_ptr == DEPTH - 1) ? 0 : r_push_ptr + 1;
          r_pop_ptr         <= (r_pop_ptr == DEPTH - 1) ? 0 : r_pop_ptr + 1;
          // count 유지
        end
      endcase
    end
  end

endmodule

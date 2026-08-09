module fifo_reg #(
    parameter WIDTH = 0,
    parameter DEPTH = 0
) (
    input              i_clk,
    input              i_rstn,
    // input
    output             o_ipt_rdy,
    input              i_ipt_vld,
    input  [WIDTH-1:0] i_ipt_din,
    // output
    input              i_opt_rdy,
    output             o_opt_vld,
    output [WIDTH-1:0] o_opt_dout
);

  integer                     i;
  // ====================== reg ============================

  reg     [        WIDTH-1:0] fifo_mem                       [0:DEPTH-1];

  reg     [$clog2(DEPTH)-1:0] r_wr_ptr;
  reg     [$clog2(DEPTH)-1:0] r_rd_ptr;
  reg     [  $clog2(DEPTH):0] r_cnt;
  // ====================== wire =========================== 
  wire                        wr_en = i_ipt_vld && o_ipt_rdy;
  wire                        rd_en = o_opt_vld && i_opt_rdy;

  //============================================================

  assign o_ipt_rdy  = (r_cnt != DEPTH);
  assign o_opt_vld  = (r_cnt != 0);
  assign o_opt_dout = fifo_mem[r_rd_ptr];

  //============================================================

  always @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
      r_wr_ptr <= 0;
      r_rd_ptr <= 0;
      r_cnt    <= 0;
      for (i = 0; i < DEPTH; i = i + 1) fifo_mem[i] <= 0;
    end else begin

      case ({
        wr_en, rd_en
      })

        2'b10: begin
          fifo_mem[r_wr_ptr] <= i_ipt_din;
          r_wr_ptr <= (r_wr_ptr==DEPTH-1)?0:r_wr_ptr+1;
          r_cnt    <= r_cnt+1;
        end

        2'b01: begin
          r_rd_ptr <= (r_rd_ptr==DEPTH-1)?0:r_rd_ptr+1;
          r_cnt    <= r_cnt-1;
        end

        2'b11: begin
          fifo_mem[r_wr_ptr] <= i_ipt_din;
          r_wr_ptr <= (r_wr_ptr == DEPTH - 1) ? 0 : r_wr_ptr + 1;
          r_rd_ptr <= (r_rd_ptr == DEPTH - 1) ? 0 : r_rd_ptr + 1;

        end

      endcase
    end
  end

endmodule

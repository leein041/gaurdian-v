
`include "defines.vh"
`include "network_config.vh"
module fifo_buffer #(
    parameter WIDTH    = 0,
    parameter DEPTH    = 0,
    parameter MEM_TYPE = `BRAM_TYPE
) (
    input               i_clk,
    input               i_rstn,
    // ipt
    output              o_ipt_rdy,
    input               i_ipt_vld,
    input  [WIDTH -1:0] i_ipt_din,
    // opt
    input               i_opt_rdy,
    output              o_opt_vld,
    output [WIDTH -1:0] o_opt_dout
);
  generate
    if (MEM_TYPE == `REG_TYPE) begin
      fifo_reg #(
          .WIDTH(WIDTH),
          .DEPTH(DEPTH)
      ) inst_fifo_reg (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .o_ipt_rdy (o_ipt_rdy),
          .i_ipt_vld (i_ipt_vld),
          .i_ipt_din (i_ipt_din),
          .i_opt_rdy (i_opt_rdy),
          .o_opt_vld (o_opt_vld),
          .o_opt_dout(o_opt_dout)
      );
    end else begin
      fifo_mem #(
          .WIDTH(WIDTH),
          .DEPTH(DEPTH),
          .MEM_TYPE(MEM_TYPE)
      ) inst_fifo_mem (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .o_ipt_rdy (o_ipt_rdy),
          .i_ipt_vld (i_ipt_vld),
          .i_ipt_din (i_ipt_din),
          .i_opt_rdy (i_opt_rdy),
          .o_opt_vld (o_opt_vld),
          .o_opt_dout(o_opt_dout)
      );
    end
  endgenerate
endmodule

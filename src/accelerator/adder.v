`timescale 1ns / 1ps

module adder #(
    parameter BITS = 32
) (
    input                      i_clk,
    input                      i_rstn,
    input                      i_add_en,
    // ipt 1 
    input  signed [BITS - 1:0] i_ipt1_din,
    // ipt 2 
    input  signed [BITS - 1:0] i_ipt2_din,
    // opt  
    output signed [  BITS : 0] o_opt_dout
);
  // ------------------------- wire ------------------------
  wire signed [  BITS:0] w_ipt1_ext;
  wire signed [  BITS:0] w_ipt2_ext;
  wire signed [  BITS:0] w_sum;
  // ------------------------- reg ------------------------- 
  reg signed  [BITS : 0] r_opt_dat;
  // ------------------------ assign ----------------------- 
  assign w_ipt1_ext = {i_ipt1_din[BITS-1], i_ipt1_din};
  assign w_ipt2_ext = {i_ipt2_din[BITS-1], i_ipt2_din};
  assign w_sum      = w_ipt1_ext + w_ipt2_ext;
  // ------------------------ always -----------------------  
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_dat <= 'd0;
    end else if (i_add_en) begin
      r_opt_dat <= w_sum;
    end else begin
      r_opt_dat <= 'd0;
    end
  end
  // ------------------------- output ----------------------  
  assign o_opt_dout = r_opt_dat;



endmodule

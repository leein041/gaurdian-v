`timescale 1ns / 1ps

module leaky_relu #(
    parameter BIT = 32
) (
    input                   i_clk,
    input                   i_rstn,
    input                   i_leaky_relu_en,
    // ipt
    input  signed [BIT-1:0] i_ipt_din,
    input                   i_ipt_vld,
    // opt 
    output                  o_opt_vld,
    output        [BIT-1:0] o_opt_dout
);
  // ====================== reg ============================
  reg                  r_opt_vld;
  reg signed [BIT-1:0] r_opt_dat;
  // ====================== wire ===========================   
  // ====================== assign =========================   
  // ====================== always ========================= 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_dat <= 'd0;
      r_opt_vld <= 'b0;
    end else begin
      if (i_ipt_vld) begin
        r_opt_vld <= 1'b1;
        if (i_leaky_relu_en && i_ipt_din[BIT-1]) begin
          r_opt_dat <= (i_ipt_din >>> 3) - (i_ipt_din >>> 5); // 0.09375
        end else begin
          r_opt_dat <= i_ipt_din;
        end
      end else begin
        r_opt_vld <= 1'b0;
      end
    end
  end
  // ====================== output ========================= 
  assign o_opt_vld  = r_opt_vld;
  assign o_opt_dout = r_opt_dat;



endmodule

`timescale 1ns / 1ps

module adder #(
    parameter BIT = 32
) (
    input                     i_clk,
    input                     i_rstn,
    // ipt 1 
    input  signed [BIT - 1:0] i_ipt1_din,
    input                     i_ipt1_vld,
    output                    o_ipt1_rdy,
    // ipt 2 
    input  signed [BIT - 1:0] i_ipt2_din,
    input                     i_ipt2_vld,
    output                    o_ipt2_rdy,
    // opt  
    input                     i_opt_rdy,
    output                    o_opt_vld,
    output signed [BIT-1 : 0] o_opt_dout
);
  // ====================== wire =========================== 
  wire signed [  BIT-1:0] w_sum;

  wire                    w_ipt_vld = i_ipt1_vld && i_ipt2_vld;
  wire                    w_ipt_rdy = o_ipt1_rdy && o_ipt2_rdy;

  wire                    w_act_in = w_ipt_rdy && w_ipt_vld;
  wire                    w_act_out = i_opt_rdy && o_opt_vld;
  // ====================== reg ============================
  reg                     r_opt_vld;
  reg signed  [BIT-1 : 0] r_opt_dat;

  // ====================== assign =========================  
  assign o_ipt1_rdy = w_act_out || !r_opt_vld;
  assign o_ipt2_rdy = w_act_out || !r_opt_vld;

  assign w_sum      = i_ipt1_din + i_ipt2_din;

  // ====================== always ========================= 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_dat <= 'd0;
      r_opt_vld <= 'b0;
    end else begin
      case ({
        w_act_in, w_act_out
      })
        2'b10, 2'b11: begin
          r_opt_vld <= 'b1;
          r_opt_dat <= w_sum;
        end
        2'b01:   r_opt_vld <= 1'b0;
        default: ;
      endcase
    end
  end

  // ====================== output ========================= 
  assign o_opt_vld  = r_opt_vld;
  assign o_opt_dout = r_opt_dat;

endmodule

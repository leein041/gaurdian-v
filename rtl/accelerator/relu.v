`timescale 1ns / 1ps

module relu #(
    parameter BITS = 32
) (
    input                    i_clk,
    input                    i_rstn,
    input                    i_relu_en,
    // ipt
    input  signed [BITS-1:0] i_ipt_din,
    input                    i_ipt_vld,
    output                   o_ipt_rdy,
    // opt
    input                    i_opt_rdy,
    output                   o_opt_vld,
    output        [BITS-1:0] o_opt_dout
);
  // ====================== wire =========================== 
  wire                  w_act_in = o_ipt_rdy && i_ipt_vld;
  wire                  w_act_out = i_opt_rdy && o_opt_vld;
  // ====================== reg ============================
  reg                   r_opt_vld;
  reg signed [BITS : 0] r_opt_dat;
  // ====================== assign =========================  
  assign o_ipt_rdy = w_act_out || !r_opt_vld;
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
          // 새 데이터 들어옴 
          r_opt_vld <= 1'b1;

          if (i_relu_en && i_ipt_din[BITS-1]) r_opt_dat <= 'd0;
          else r_opt_dat <= i_ipt_din;
        end
        2'b01: r_opt_vld <= 1'b0;

        default: begin
          // 아무 일 없음
        end
      endcase
    end
  end
  // ====================== output ========================= 
  assign o_opt_vld  = r_opt_vld;
  assign o_opt_dout = r_opt_dat;



endmodule

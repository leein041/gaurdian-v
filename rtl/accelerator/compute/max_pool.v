`timescale 1ns / 1ps

module max_pool #(
    parameter  POOL_SIDE = `POOL_2X2_SIDE,
    localparam POOL_AREA = POOL_SIDE * POOL_SIDE,
    localparam OPT_BIT   = `IPT_BIT
) (
    input                                  i_clk,
    input                                  i_rstn,
    // ipt
    input         [`IPT_BIT*POOL_AREA-1:0] i_ipt_din,
    input                                  i_ipt_vld,
    output                                 o_ipt_rdy,
    // opt
    input                                  i_opt_rdy,
    output                                 o_opt_vld,
    output signed [           OPT_BIT-1:0] o_opt_dout
);
  // ====================== parmeter =======================  
  genvar g;
  // ====================== wire =========================== 
  wire signed [ `IPT_BIT-1:0] w_ipt_dat                          [0:POOL_AREA-1];
  wire signed [ `IPT_BIT-1:0] w_max_1;
  wire signed [ `IPT_BIT-1:0] w_max_2;
  wire signed [ `IPT_BIT-1:0] w_max_dat;
  wire                        w_act_in = o_ipt_rdy && i_ipt_vld;
  wire                        w_act_out = i_opt_rdy && o_opt_vld;
  // ====================== reg ============================
  reg                         r_opt_vld;
  reg signed  [OPT_BIT-1 : 0] r_opt_dat;
  // ====================== assign =========================  
  assign o_ipt_rdy = w_act_out || !r_opt_vld;
  generate
    for (g = 0; g < POOL_AREA; g = g + 1) begin
      assign w_ipt_dat[g] = i_ipt_din[g*`IPT_BIT+:`IPT_BIT];
    end
  endgenerate
  assign w_max_1   = (w_ipt_dat[0] > w_ipt_dat[1]) ? w_ipt_dat[0] : w_ipt_dat[1];
  assign w_max_2   = (w_ipt_dat[2] > w_ipt_dat[3]) ? w_ipt_dat[2] : w_ipt_dat[3];
  assign w_max_dat = (w_max_1 > w_max_2) ? w_max_1 : w_max_2;
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
          r_opt_dat <= w_max_dat;
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

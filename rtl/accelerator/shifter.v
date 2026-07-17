
`include "defines.vh"
`include "network_config.vh"

module right_shifter #(
    parameter IPT_NUM = 3
) (
    input                                  i_clk,
    input                                  i_rstn,
    // ipt
    input  signed [`IPT_BIT * IPT_NUM-1:0] i_ipt_din,
    input                                  i_ipt_vld,
    output                                 o_ipt_rdy,
    // opt
    input                                  i_opt_rdy,
    output                                 o_opt_vld,
    output        [`IPT_BIT * IPT_NUM-1:0] o_opt_dout,
    //  
    input         [     $clog2(IPT_NUM):0] i_shift_cnt
);
  // ====================== parmeter =======================  

  integer                          i;
  // ====================== hand shake ======
  // ====================== wire =======================s==== 
  wire                             w_act_in = o_ipt_rdy && i_ipt_vld;
  wire                             w_act_out = i_opt_rdy && o_opt_vld;
  // ====================== reg ============================
  reg                              r_opt_vld;
  reg     [`IPT_BIT * IPT_NUM-1:0] r_shifted_dat;
  reg     [`IPT_BIT * IPT_NUM-1:0] r_opt_dat;
  // ====================== assign =========================  
  assign o_ipt_rdy = w_act_out || !r_opt_vld;
  // ====================== always ========================= 
  always @(*) begin
    for (i = 0; i < IPT_NUM; i = i + 1) begin
      r_shifted_dat[i*`IPT_BIT+:`IPT_BIT] = i_ipt_din[((i+i_shift_cnt)%IPT_NUM)*`IPT_BIT+:`IPT_BIT];
    end

  end
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_vld <= 'b0;
      r_opt_dat <= 'd0;
    end else begin
      case ({
        w_act_in, w_act_out
      })
        2'b10, 2'b11: begin
          // 새 데이터 들어옴 
          r_opt_vld <= 1'b1;
          r_opt_dat <= r_shifted_dat;
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

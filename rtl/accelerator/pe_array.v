`include "defines.vh"
`include "network_config.vh"

module pe_array #(
    parameter OPT_BIT = 32,
    parameter PE_NUM  = 9
) (
    input                                 i_clk,
    input                                 i_rstn,
    // wgt
    input  signed [         `WGT_BIT-1:0] i_wgt_din,
    input                                 i_wgt_vld,
    // ipt
    input         [`IPT_BIT * PE_NUM-1:0] i_ipt_din,
    input                                 i_ipt_vld,
    output                                o_ipt_rdy,
    // opt
    input                                 i_opt_rdy,
    output                                o_opt_vld,
    output        [ OPT_BIT * PE_NUM-1:0] o_opt_dout
);
  // ====================== parmeter ======================= 
  integer i;
  genvar g, p;
  // ====================== wire =========================== 
  wire signed [`IPT_BIT-1:0] w_ipt_dat                          [0:PE_NUM-1];
  wire signed [ OPT_BIT-1:0] w_opt_dat                          [0:PE_NUM-1];
  wire                       w_act_in = o_ipt_rdy && i_ipt_vld;
  wire                       w_act_out = i_opt_rdy && o_opt_vld;
  // ====================== reg ============================
  // wgt
  reg signed  [`IPT_BIT-1:0] r_wgt_dat                          [0:PE_NUM-1];
  // opt
  reg                        r_opt_vld;
  // ====================== assign =========================  
  generate
    for (g = 0; g < PE_NUM; g = g + 1) begin
      assign w_ipt_dat[g] = i_ipt_din[g*`IPT_BIT+:`IPT_BIT];
    end
  endgenerate
  assign o_ipt_rdy = w_act_out || !r_opt_vld;
  // ====================== always ========================= 

  // initialize weight data
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      for (i = 0; i < PE_NUM; i = i + 1) r_wgt_dat[i] <= 'd0;
    end else if (i_wgt_vld) begin
      // insert
      r_wgt_dat[PE_NUM-1] <= i_wgt_din;
      // shift
      for (i = 0; i < PE_NUM - 1; i = i + 1) r_wgt_dat[i] <= r_wgt_dat[i+1];
    end
  end

  // handshake
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_vld <= 'b0;
    end else begin
      case ({
        w_act_in, w_act_out
      })
        2'b10, 2'b11: r_opt_vld <= 1'b1;

        2'b01: r_opt_vld <= 1'b0;

        default: ;
      endcase
    end
  end

  generate
    for (p = 0; p < PE_NUM; p = p + 1) begin : pe_array
      pe inst_pe (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .i_pe_en   (w_act_in),
          // wgt  
          .i_wgt_din (r_wgt_dat[p]),
          // ipt  
          .i_ipt_vld (),
          .i_ipt_din (w_ipt_dat[p]),
          // opt  
          .o_opt_vld (),
          .o_opt_dout(w_opt_dat[p])
      );
    end
  endgenerate
  // ====================== output ========================= 
  assign o_opt_vld = r_opt_vld;
  generate
    for (g = 0; g < PE_NUM; g = g + 1) begin
      assign o_opt_dout[g*OPT_BIT+:OPT_BIT] = w_opt_dat[g];
    end
  endgenerate



endmodule

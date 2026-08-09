`include "defines.vh"
`include "network_config.vh"

module pe_array #(
    parameter OPT_BIT = 32,
    parameter PE_NUM  = 9
) (
    input                                 i_clk,
    input                                 i_rstn,
    //
    input                                 i_ws_swap,
    input                                 i_req_wgt,
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
  // ====================== reg ============================ 
  reg                                   r_sel;
  reg                                   r_opt_vld;
  reg         [`CLOG2_SAFE(PE_NUM)-1:0] r_bank_idx;
  // ====================== wire ===========================  
  wire signed [           `IPT_BIT-1:0] w_ipt_dat                          [0:PE_NUM-1];
  wire signed [            OPT_BIT-1:0] w_opt_dat                          [0:PE_NUM-1];
  //
  wire        [    `WGT_BIT*PE_NUM-1:0] w_ws_rdat_bus;
  wire        [           `WGT_BIT-1:0] w_ws_rdat                          [0:PE_NUM-1];
  wire                                  w_ws_rvld;
  wire                                  w_ws_we = i_wgt_vld;
  //
  wire                                  w_act_in = o_ipt_rdy && i_ipt_vld;
  wire                                  w_act_out = i_opt_rdy && o_opt_vld;
  // ====================== assign =========================  
  generate
    for (g = 0; g < PE_NUM; g = g + 1) begin
      assign w_ws_rdat[g] = w_ws_rdat_bus[g*`WGT_BIT+:`WGT_BIT];
      assign w_ipt_dat[g] = i_ipt_din[g*`IPT_BIT+:`IPT_BIT];
    end
  endgenerate
  assign o_ipt_rdy = w_act_out || !r_opt_vld;
  // ====================== always =========================  
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_sel <= 'b0;
    end else begin
      if (i_ws_swap) r_sel <= ~r_sel;
    end
  end
  // initialize weight statinary buffer
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_bank_idx <= 'd0;
    end else if (i_ws_swap) begin
      r_bank_idx <= 'd0;
    end else if (i_wgt_vld) begin
      r_bank_idx <= r_bank_idx + 'd1;
    end
  end

  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_vld <= 'b0;
    end else begin
      // 1 cylce delay -> DSP spend 1 clock for computing
      if (i_ipt_vld) begin
        r_opt_vld <= 1'b1;
      end else begin
        r_opt_vld <= 1'b0;
      end
    end
  end
  // ====================== module ========================= 
  bank_mem #(
      .WIDTH     (`WGT_BIT),
      .BANK_DEPTH(2),
      .MEM_TYPE  (`LUT_TYPE),
      .BANK_NUM  (PE_NUM)
  ) inst_wgt_stationary_buf_0 (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      //
      .i_re      (i_req_wgt),
      .i_raddr   (!r_sel),
      .o_rvld    (w_ws_rvld),
      .o_rdout   (w_ws_rdat_bus),
      //
      .i_bank_idx(r_bank_idx),
      .i_we      (w_ws_we),
      .i_waddr   (r_sel),
      .i_wdin    (i_wgt_din)
  );
  generate
    for (p = 0; p < PE_NUM; p = p + 1) begin : pe_array
      pe inst_pe (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .i_pe_en   (w_act_in),
          // wgt  
          .i_wgt_din (w_ws_rdat[p]),
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

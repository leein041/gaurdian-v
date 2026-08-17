
`include "defines.vh"
`include "network_config.vh"
module patch #(
    parameter  WIDTH      = 0,
    parameter  PATCH_SIDE = 0,  
    localparam PATCH_AREA = PATCH_SIDE * PATCH_SIDE
) (
    input                                  i_clk,
    input                                  i_rstn,
    input                                  i_clr,
    // ipt
    input         [WIDTH * PATCH_SIDE-1:0] i_ipt_din,
    input                                  i_ipt_vld,
    output                                 o_ipt_rdy,
    // opt
    input                                  i_opt_rdy,
    output                                 o_opt_vld,
    output signed [WIDTH * PATCH_AREA-1:0] o_opt_dout,
    // 
    input                                  i_ptch_vld
);
  // ====================== parmeter =======================   
  genvar g, h;
  integer i, j;

  // ====================== reg ============================    
  reg signed [WIDTH-1:0] r_opt_dat                          [0:PATCH_SIDE-1][0:PATCH_SIDE-1];
  reg                    r_opt_vld;
  // ====================== wire =========================== 
  wire                   w_act_in = o_ipt_rdy && i_ipt_vld;
  wire                   w_act_out = i_opt_rdy && o_opt_vld;
  assign o_ipt_rdy = w_act_out || !r_opt_vld;
  assign o_opt_vld = r_opt_vld;
  // ====================== always =========================   
  // output valid
  always @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
      r_opt_vld <= 'b0;
    end else begin
      r_opt_vld <= i_ipt_vld & i_ptch_vld;
      for (i = 0; i < PATCH_SIDE; i = i + 1) begin
        for (j = 0; j < PATCH_SIDE - 1; j = j + 1) begin
          r_opt_dat[i][j] <= r_opt_dat[i][j+1];
        end
      end

      for (i = 0; i < PATCH_SIDE; i = i + 1) begin
        r_opt_dat[i][PATCH_SIDE-1] <= i_ipt_din[i*WIDTH+:WIDTH];
      end
    end
  end

  // ====================== Unpack / Pack ==================

  generate
    for (g = 0; g < PATCH_SIDE; g = g + 1) begin
      for (h = 0; h < PATCH_SIDE; h = h + 1) begin
        assign o_opt_dout[(g*PATCH_SIDE+h)*WIDTH+:WIDTH] = r_opt_dat[g][h];
      end
    end
  endgenerate
endmodule

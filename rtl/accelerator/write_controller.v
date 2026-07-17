
`include "defines.vh"
`include "network_config.vh"

module write_controller #(
    parameter WIDTH = 0,
    parameter DEPTH = 0
) (
    input                      i_clk,
    input                      i_rstn,
    //
    input                      i_len,
    input                      i_weq,
    input  [$clog2(DEPTH)-1:0] i_waddr,
    // DDR 
    output                     o_we,
    output [$clog2(DEPTH)-1:0] o_waddr,
    output [        WIDTH-1:0] o_wdout
);
  // ====================== parmeter =======================    
  // ====================== wire ==========================  
  // ====================== reg ============================ 

  // ====================== assign =========================    
  assign o_re       = i_req;
  assign o_raddr    = i_raddr;
  assign o_opt_vld  = i_rvld;
  assign o_opt_dout = i_rdin;
  // ====================== always ========================= 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
    end else if (i_res_vld) begin
      bram_we      <= 1'b1;
      bram_addr    <= current_addr;
      bram_wdata   <= i_res_data;
      current_addr <= current_addr + 1;
    end
  end

endmodule

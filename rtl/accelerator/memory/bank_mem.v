`include "defines.vh"
`include "network_config.vh"
module bank_mem #(
    parameter WIDTH      = 0,
    parameter BANK_DEPTH = 0,
    parameter MEM_TYPE   = `BRAM_TYPE,
    parameter BANK_NUM   = 0
) (
    input                                  i_clk,
    input                                  i_rstn,
    input  [    `CLOG2_SAFE(BANK_NUM)-1:0] i_bank_idx,
    //
    input                                  i_re,
    input  [`CLOG2_SAFE(BANK_DEPTH)-1 : 0] i_raddr,
    output                                 o_rvld,
    output [         WIDTH * BANK_NUM-1:0] o_rdout,
    //
    input                                  i_we,
    input  [`CLOG2_SAFE(BANK_DEPTH)-1 : 0] i_waddr,
    input  [                    WIDTH-1:0] i_wdin 
);
  genvar g;
  // ====================== wire ===========================
  wire             mem_vld   [0:BANK_NUM-1];
  wire [WIDTH-1:0] mem_dat   [0:BANK_NUM-1]; 
  // ====================== assign =========================


  // ====================== module =========================

  generate
    for (g = 0; g < BANK_NUM; g = g + 1) begin
      simple_dual_port_ram #(
          .WIDTH   (WIDTH),
          .DEPTH   (BANK_DEPTH),
          .MEM_TYPE(MEM_TYPE)
      ) inst_mem (
          .i_clk  (i_clk),
          .i_rstn (i_rstn),
          .i_re   (i_re),
          .i_raddr(i_raddr),
          .i_we   (i_we && i_bank_idx == g),
          .i_waddr(i_waddr),
          .i_wdin (i_wdin),
          .o_rvld (mem_vld[g]),
          .o_rdout(mem_dat[g])
      );
    end
  endgenerate
  // ====================== output ========================= 
  generate
    for (g = 0; g < BANK_NUM; g = g + 1) begin
      assign o_rdout[g*WIDTH+:WIDTH] = mem_dat[g];
    end
  endgenerate
  assign o_rvld = mem_vld[0];  // 동시 작업이므로 LUT 최소화

endmodule

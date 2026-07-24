`include "defines.vh"
`include "network_config.vh"
module buffer #(
    parameter WIDTH      = 0,
    parameter BANK_DEPTH = 0,
    parameter MEM_TYPE   = `BRAM_TYPE,
    parameter BANK_NUM   = 0
) (
    input                                  i_clk,
    input                                  i_rstn,
    //
    input                                  i_re,
    input  [`CLOG2_SAFE(BANK_DEPTH)-1 : 0] i_raddr,
    //
    input  [    `CLOG2_SAFE(BANK_NUM)-1:0] i_bank_idx,
    input                                  i_we,
    input  [`CLOG2_SAFE(BANK_DEPTH)-1 : 0] i_waddr,
    input  [                    WIDTH-1:0] i_wdat,
    // opt
    output                                 o_ipt_rdy,
    input                                  i_opt_rdy,
    output                                 o_opt_vld,
    output [         WIDTH * BANK_NUM-1:0] o_opt_dout
);
  genvar g;
  // ====================== wire ===========================
  wire             mem_skid_vld[0:BANK_NUM-1];
  wire [WIDTH-1:0] mem_skid_dat[0:BANK_NUM-1];
  wire             w_skid_vld  [0:BANK_NUM-1];
  wire [WIDTH-1:0] w_skid_dat  [0:BANK_NUM-1];
  // ====================== assign =========================


  // ====================== module =========================

  generate
    for (g = 0; g < BANK_NUM; g = g + 1) begin
      // tile buffer  
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
          .i_wdin (i_wdat),
          .o_vld  (mem_skid_vld[g]),
          .o_dout (mem_skid_dat[g])
      );

      skid_buffer #(
          .WIDTH   (WIDTH),
          .LATENCY (1),
          .MEM_SKID(1)
      ) inst_skid_buffer (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          // ipt
          .i_ipt_vld (mem_skid_vld[g]),
          .i_ipt_din (mem_skid_dat[g]),
          .o_ipt_rdy (o_ipt_rdy),
          // opt
          .i_opt_rdy (i_opt_rdy),
          .o_opt_vld (w_skid_vld[g]),
          .o_opt_dout(w_skid_dat[g])
      );
    end
  endgenerate
  // ====================== output ========================= 
  generate
    for (g = 0; g < BANK_NUM; g = g + 1) begin
      assign o_opt_dout[g*WIDTH+:WIDTH] = w_skid_dat[g];
    end
  endgenerate
  assign o_opt_vld = w_skid_vld[0];  // 동시 작업이므로 LUT 최소화

endmodule

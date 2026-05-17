`timescale 1ns / 1ps

module simple_dual_port_uram #(
    parameter WIDTH      = 16,
    parameter DEPTH      = 1024,
    parameter ADDR_WIDTH = $clog2(DEPTH),
    parameter INIT_FILE  = ""
) (
    input                       i_clk,
    input                       i_rstn,
    input                       i_re,
    input      [ADDR_WIDTH-1:0] i_raddr,
    input                       i_we,
    input      [ADDR_WIDTH-1:0] i_waddr,
    input      [     WIDTH-1:0] i_wdin,
    output reg                  o_vld,
    output reg [     WIDTH-1:0] o_dout
);

  // BRAM
  (* ram_style = "ultra" *) reg [WIDTH-1:0] r_mem[0:DEPTH-1];

  generate
    if (INIT_FILE != "") begin : use_init_file
      initial begin
        $readmemh(INIT_FILE, r_mem);
      end
    end
  endgenerate

  always @(posedge i_clk) begin
    if (i_we) r_mem[i_waddr] <= i_wdin;
    if (i_re) o_dout <= r_mem[i_raddr];  // READ_FIRST  
  end
  // 2. 유효 신호 제어 (리셋 필요)
  always @(posedge i_clk) begin
    if (~i_rstn) begin
      o_vld <= 1'b0;
    end else begin
      o_vld <= i_re;
    end
  end
endmodule

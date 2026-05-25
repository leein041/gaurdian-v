 
`timescale 1ns / 1ps
 
`define BRAM_TYPE 0
`define URAM_TYPE 1

module simple_dual_port_ram #(
    parameter WIDTH      = 16,
    parameter DEPTH      = 1024,
    parameter MEM_TYPE   = `BRAM_TYPE,   
    parameter INIT_FILE  = "",
    
    localparam ADDR_WIDTH = $clog2(DEPTH)
) (
    input                               i_clk,
    input                               i_rstn,
    input                               i_re,
    input              [ADDR_WIDTH-1:0] i_raddr,
    input                               i_we,
    input              [ADDR_WIDTH-1:0] i_waddr,
    input  signed      [     WIDTH-1:0] i_wdin,
    output reg                          o_vld,
    output reg signed  [     WIDTH-1:0] o_dout
);

  //==========================================================================
  //  BRAM 모드 ( 1 clock )
  //==========================================================================
  if (MEM_TYPE == `BRAM_TYPE) begin  
    (* ram_style = "block" *) reg signed [WIDTH-1:0] r_mem[0:DEPTH-1];
    reg signed [WIDTH-1:0] r_dat_dly;  
    reg                    r_vld_dly;  
 
    always @(posedge i_clk) begin
      if (i_we) r_mem[i_waddr] <= i_wdin;
    end
 
    always @(posedge i_clk or negedge i_rstn) begin
      if (~i_rstn) begin
        r_vld_dly  <= 1'b0;
        o_vld     <= 1'b0;    
        r_dat_dly <= 0;
        o_dout    <= 0;   
      end else begin      
        o_vld     <= i_re;
        o_dout    <= r_mem[i_raddr];
      end
    end
 
    if (INIT_FILE != "") begin
      initial begin
        $readmemh(INIT_FILE, r_mem);
      end
    end
  end

  //==========================================================================
  //  URAM 모드 ( 2 clock )
  //==========================================================================
  else if (MEM_TYPE == `URAM_TYPE) begin : gen_uram
    (* ram_style = "ultra" *) reg signed [WIDTH-1:0] r_mem[0:DEPTH-1];
    reg signed [WIDTH-1:0] r_dat_dly;
    reg                    r_vld_dly;
 
    always @(posedge i_clk) begin
      if (i_we) r_mem[i_waddr] <= i_wdin;
    end
 
    always @(posedge i_clk or negedge i_rstn) begin
      if (~i_rstn) begin
        r_vld_dly  <= 1'b0;
        o_vld     <= 1'b0;
        r_dat_dly <= 0;
        o_dout    <= 0;
      end else begin 
        r_vld_dly  <= i_re;
        if (i_re) r_dat_dly <= r_mem[i_raddr];
 
        o_vld     <= r_vld_dly;
        o_dout    <= r_dat_dly;
      end
    end

    // 초기화 파일 로드
    if (INIT_FILE != "") begin
      initial begin
        $readmemh(INIT_FILE, r_mem);
      end
    end
  end

endmodule
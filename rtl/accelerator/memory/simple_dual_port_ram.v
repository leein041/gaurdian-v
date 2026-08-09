
`include "defines.vh"
`include "network_config.vh"

module simple_dual_port_ram #(
    parameter WIDTH     = 16,
    parameter DEPTH     = 1024,
    parameter MEM_TYPE  = `BRAM_TYPE,
    parameter INIT_FILE = ""

) (
    input                                  i_clk,
    input                                  i_rstn,
    input                                  i_re,
    input         [`CLOG2_SAFE(DEPTH)-1:0] i_raddr,
    output                                 o_rvld,
    output signed [             WIDTH-1:0] o_rdout,
    input                                  i_we,
    input         [`CLOG2_SAFE(DEPTH)-1:0] i_waddr,
    input  signed [             WIDTH-1:0] i_wdin
);
  generate
    if (MEM_TYPE == `LUT_TYPE) begin : LUT_RAM

      //==========================================================================
      //  LUT RAM (Distributed RAM) 모드 ( 1 clock )
      //==========================================================================
      (* ram_style = "distributed" *) reg signed [WIDTH-1:0] r_mem[0:DEPTH-1];
      // 동기 쓰기
      always @(posedge i_clk) begin
        if (i_we) r_mem[i_waddr] <= i_wdin;
      end

      assign o_rvld  = i_re;
      assign o_rdout = r_mem[i_raddr];

      if (INIT_FILE != "") begin
        initial begin
          $readmemh(INIT_FILE, r_mem);
        end
      end


    end else if (MEM_TYPE == `BRAM_TYPE) begin : BRAM_TYPE

      //==========================================================================
      //  BRAM 모드 ( 1 clock )
      //==========================================================================
      (* ram_style = "block" *)reg signed [WIDTH-1:0] r_mem  [0:DEPTH-1];
      reg                    r_rvld;
      reg signed [WIDTH-1:0] r_rdat;

      always @(posedge i_clk) begin
        if (i_we) r_mem[i_waddr] <= i_wdin;
      end

      always @(posedge i_clk or negedge i_rstn) begin
        if (~i_rstn) begin
          r_rvld <= 1'b0;
          r_rdat <= 0;
        end else begin
          r_rvld <= i_re;
          r_rdat <= r_mem[i_raddr];
        end
      end

      if (INIT_FILE != "") begin
        initial begin
          $readmemh(INIT_FILE, r_mem);
        end
      end

      assign o_rvld  = r_rvld;
      assign o_rdout = r_rdat;
    end else if (MEM_TYPE == `URAM_TYPE) begin : URAM_TYPE
      //==========================================================================
      //  URAM 모드 ( 3 clock )
      //==========================================================================    
      (* ram_style = "ultra" *)reg signed [WIDTH-1:0] r_mem      [0:DEPTH-1];
      reg                    r_vld_dly1;
      reg signed [WIDTH-1:0] r_dat_dly1;
      reg                    r_vld_dly2;
      reg signed [WIDTH-1:0] r_dat_dly2;
      reg                    r_rvld;
      reg signed [WIDTH-1:0] r_rdat;

      always @(posedge i_clk) begin
        if (i_we) r_mem[i_waddr] <= i_wdin;
      end

      always @(posedge i_clk or negedge i_rstn) begin
        if (~i_rstn) begin
          r_vld_dly1 <= 1'b0;
          r_dat_dly1 <= 0;
          r_vld_dly2 <= 1'b0;
          r_dat_dly2 <= 0;
          r_rvld     <= 1'b0;
          r_rdat     <= 0;
        end else begin
          r_vld_dly1 <= i_re;
          if (i_re) r_dat_dly1 <= r_mem[i_raddr];

          r_vld_dly2 <= r_vld_dly1;
          r_dat_dly2 <= r_dat_dly1;

          r_rvld     <= r_vld_dly2;
          r_rdat     <= r_dat_dly2;
        end
      end

      // 초기화 파일 로드
      if (INIT_FILE != "") begin
        initial begin
          $readmemh(INIT_FILE, r_mem);
        end
      end

      assign o_rvld  = r_rvld;
      assign o_rdout = r_rdat;
    end
  endgenerate
endmodule

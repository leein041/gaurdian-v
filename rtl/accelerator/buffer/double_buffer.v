`include "defines.vh"
`include "network_config.vh"
module double_buffer #(
    parameter WIDTH    = 0,
    parameter DEPTH    = 0,
    parameter MEM_TYPE = `BRAM_TYPE
) (
    input                             i_clk,
    input                             i_rstn,
    input                             i_switch,
    //
    input                             i_re,
    input  [`CLOG2_SAFE(DEPTH)-1 : 0] i_raddr,
    output                            o_rvld,
    output [               WIDTH-1:0] o_rdout,
    //
    input                             i_we,
    input  [`CLOG2_SAFE(DEPTH)-1 : 0] i_waddr,
    input  [               WIDTH-1:0] i_wdin
);
  genvar g;
  // ====================== wire ===========================
  wire             w_buf_vld     [0:1];
  wire [WIDTH-1:0] w_buf_dat     [0:1];
  wire             w_buf_sel_vld;
  wire [WIDTH-1:0] w_buf_sel_dat;
  // ====================== reg ============================
  reg              r_read_buf;
  // ====================== assign =========================
  assign w_buf_sel_vld = (r_read_buf == 0) ? w_buf_vld[0] : w_buf_vld[1];
  assign w_buf_sel_dat = (r_read_buf == 0) ? w_buf_dat[0] : w_buf_dat[1];
  // ====================== always =========================
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_read_buf <= 'b0;
    end else begin
      if (i_switch) begin
        r_read_buf <= !r_read_buf;
      end
    end
  end
  // ====================== module =========================

  // double buffer
  simple_dual_port_ram #(
      .WIDTH    (WIDTH),
      .DEPTH    (DEPTH),
      .MEM_TYPE (MEM_TYPE),
      .INIT_FILE()
  ) inst_buf_0 (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_re   (i_re && r_read_buf == 0),
      .i_raddr(i_raddr),
      .i_we   (i_we && r_read_buf == 1),
      .i_waddr(i_waddr),
      .i_wdin (i_wdin),
      .o_rvld (w_buf_vld[0]),
      .o_rdout(w_buf_dat[0])
  );

  simple_dual_port_ram #(
      .WIDTH   (WIDTH),
      .DEPTH   (DEPTH),
      .MEM_TYPE(MEM_TYPE)
  ) inst_buf_1 (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_re   (i_re && r_read_buf == 1),
      .i_raddr(i_raddr),
      .i_we   (i_we && r_read_buf == 0),
      .i_waddr(i_waddr),
      .i_wdin (i_wdin),
      .o_rvld (w_buf_vld[1]),
      .o_rdout(w_buf_dat[1])
  );

  // ====================== output =========================  
  assign o_rvld  = w_buf_sel_vld;
  assign o_rdout = w_buf_sel_dat;
endmodule

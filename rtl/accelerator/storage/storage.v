`include "defines.vh"
`include "network_config.vh"
module storage #(
    parameter WIDTH = 0,
    parameter DEPTH = 0,

    parameter INIT_FILE0 = "",
    parameter INIT_FILE1 = "",
    parameter INIT_FILE2 = ""
) (
    input                                i_clk,
    input                                i_rstn,
    //
    input                                i_re,
    input  [     `CLOG2_SAFE(DEPTH)-1:0] i_raddr,
    output                               o_rvld,
    output [                  WIDTH-1:0] o_rdout,
    //
    input                                i_we,
    input  [     `CLOG2_SAFE(DEPTH)-1:0] i_waddr,
    input  [                  WIDTH-1:0] i_wdin,
    //
    input  [`CLOG2_SAFE(`LAYER_NUM)-1:0] i_lyr_idx
);
  genvar g;
  integer             i;


  // ====================== reg ============================ 
  reg                 r_rvld;
  reg     [WIDTH-1:0] r_rdat;
  // ====================== wire =========================== 
  wire                w_storage_vld[0:`LAYER_NUM-1];
  wire    [WIDTH-1:0] w_storage_dat[0:`LAYER_NUM-1];
  // ====================== assign =========================   
  always @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
      r_rvld <= 0;
      r_rdat <= 0;
    end else begin
      r_rvld <= 0;
      for (i = 0; i < `LAYER_NUM; i = i + 1) begin
        if (i_lyr_idx == i) begin
          r_rvld <= w_storage_vld[i];
          r_rdat <= w_storage_dat[i];
        end
      end
    end
  end
  // ====================== module ========================= 
  generate
    for (g = 0; g < `LAYER_NUM; g = g + 1) begin : SOTRAGES
      localparam TEMP_INIT =
                                    (g==0) ? INIT_FILE0 :
                                    (g==1) ? INIT_FILE1 :
                                    (g==2) ? INIT_FILE2 : "";
      simple_dual_port_ram #(
          .WIDTH    (WIDTH),
          .DEPTH    (DEPTH),
          .INIT_FILE(TEMP_INIT)
      ) storage (
          .i_clk  (i_clk),
          .i_rstn (i_rstn),
          .i_re   (i_re && (i_lyr_idx == g)),
          .i_raddr(i_raddr),
          .i_we   (),
          .i_waddr(),
          .i_wdin (),
          .o_rvld  (w_storage_vld[g]),
          .o_rdout (w_storage_dat[g])
      );
    end
  endgenerate
  // ====================== output =========================   
  assign o_rvld  = r_rvld;
  assign o_rdout = r_rdat;
endmodule

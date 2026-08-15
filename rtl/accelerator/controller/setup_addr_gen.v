

`include "defines.vh"
`include "network_config.vh"
module wr_addr_gen #(
    localparam WGT_BANK_DEPTH = `MAX_CHANNEL * `CONV_3X3_AREA
) (
    input                                               i_clk,
    input                                               i_rstn,
    // scheduler
    input                                               i_nxt_lyr,
    input                                               i_nxt_filt_grp,
    input                                               i_nxt_tile,
    input                                               i_nxt_ch_grp,
    //  
    output reg [`CLOG2_SAFE(`MAX_FILTER_GROUP_NUM)-1:0] o_br_addr,
    output reg [       `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] o_wr_addr,
    //  
    input      [       `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] i_wr_ch_grp_stride
);
  // ====================== parmeter =======================   
  integer                                          i; 
  // ====================== reg ============================      
  reg     [`CLOG2_SAFE(`MAX_FILTER_GROUP_NUM)-1:0] r_br_offset;
  reg     [       `CLOG2_SAFE(WGT_BANK_DEPTH)-1:0] r_wr_offset;
  // ====================== assign =========================     
  always @(*) begin
    o_br_addr = r_br_offset;
    o_wr_addr = r_wr_offset;
  end

  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_br_offset <= 'd0;
      r_wr_offset <= 'd0;
    end else begin
      if (i_nxt_lyr) begin
        r_wr_offset <= 'd0;
      end else if (i_nxt_filt_grp) begin
        r_wr_offset <= 'd0;
      end else if (i_nxt_tile) begin
        r_wr_offset <= 'd0;
      end else if (i_nxt_ch_grp) begin
        r_wr_offset <= r_wr_offset + i_wr_ch_grp_stride;
      end
    end

  end


  // ====================== module ========================= 
endmodule

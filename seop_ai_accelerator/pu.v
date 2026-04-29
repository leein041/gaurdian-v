`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/23 16:06:57
// Design Name: 
// Module Name: PU
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module pu #(
    parameter INPUT_BITS    = 16,
    parameter INPUT_WIDTH   = 5,
    parameter INPUT_HEIGHT  = 5,
    parameter WEIGHT_BITS   = 16,
    parameter WEIGHT_WIDTH  = 3,
    parameter WEIGHT_HEIGHT = 3,
    parameter OUTPUT_BITS   = 48,
    parameter LINE_BITS     = 16,
    parameter LINE_WIDTH    = 5,
    parameter LINE_HEIGHT   = 3,
    parameter PATCH_WIDTH   = 3,
    parameter PATCH_HEIGHT  = 3,
    parameter CHANNEL_NUM   = 3,

    localparam PATCH_AREA          = PATCH_HEIGHT * PATCH_WIDTH,
    localparam PATCH_SIZE          = LINE_BITS * PATCH_AREA,
    localparam WEIGHT_CHANNEL_SIZE = WEIGHT_BITS * CHANNEL_NUM,
    localparam INPUT_CHANNEL_SIZE  = INPUT_BITS * CHANNEL_NUM,
    localparam OUTPUT_CHANNEL_SIZE = OUTPUT_BITS * CHANNEL_NUM
) (
    input                             i_clk,
    input                             i_rstn,
    input                             i_pu_en,
    input                             i_weight_valid,
    input  [WEIGHT_CHANNEL_SIZE -1:0] i_weight_data,
    input                             i_input_valid,
    input  [INPUT_CHANNEL_SIZE - 1:0] i_input_data,
    output                            o_line_rd_done,
    output [       OUTPUT_BITS - 1:0] o_pu_data,
    output                            o_pu_valid
);
  localparam LINE_123 = 1;
  localparam LINE_234 = 2;
  localparam LINE_345 = 3;

  // packed wire
  wire [CHANNEL_SIZE- 1:0] w_pe_pck_data;
  // unpacked wire
  wire [CHANNEL_NUM-1 : 0] w_pe_valid;
  wire [ PATCH_SIZE - 1:0] w_patch_data                                      [0:CHANNEL_NUM-1];
  wire [OUTPUT_BITS - 1:0] w_pe_data                                         [0:CHANNEL_NUM-1];
  wire [ INPUT_BITS - 1:0] w_input_data                                      [0:CHANNEL_NUM-1];
  wire [WEIGHT_BITS - 1:0] w_weight_data                                     [0:CHANNEL_NUM-1];

  wire                     w_patch_valid                                     [0:CHANNEL_NUM-1];

  // reg
  reg  [              1:0] r_slide_sel;  // 커널이 슬라이드 한 횟수
  reg                      r_slide_en;  // 커널 슬라이드 시작 
  reg  [             15:0] r_o_idx;
  reg  [  OUTPUT_BITS-1:0] r_output                                          [            0:8];
  reg                      r_o_valid;


  // 커널 슬라이드 로직
  // 0-1-2-3-0..... 0-1-2-3-0......
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_slide_sel <= 'd0;
      r_slide_en  <= 1'b0;
    end else begin
      if (o_line_rd_done) begin  // 라인 버퍼 읽기 준비 완료
        r_slide_en  <= 1'b1;  // 슬라이드 시작
        r_slide_sel <= LINE_123;
      end
      if (r_slide_en) begin
        if (r_slide_sel >= LINE_345) begin  // 슬라이드 123 열부터 345열까지
          r_slide_en  <= 1'b0;
          r_slide_sel <= 'd0;
        end else begin
          r_slide_sel <= r_slide_sel + 'd1;
        end
      end
    end
  end

  genvar c;
  generate
    for (c = 0; c < CHANNEL_NUM; c = c + 1) begin : UNPACK_DATA
      assign w_input_data[c]  = i_input_data[LINE_BITS*c+:LINE_BITS];
      assign w_weight_data[c] = i_weight_data[WEIGHT_BITS*c+:WEIGHT_BITS];
    end
  endgenerate
  generate
    for (c = 0; c < CHANNEL_NUM; c = c + 1) begin : PACK_DATA
      assign w_pe_pck_data[OUTPUT_BITS*c+:OUTPUT_BITS] = w_pe_data[c];
    end
  endgenerate

  genvar g;
  generate
    for (g = 0; g < 3; g = g + 1) begin : LINE_BUFFER_ARRAY
      LINE_BUFFER #(
          .INPUT_BITS  (INPUT_BITS),
          .INPUT_WIDTH  (INPUT_WIDTH),
          .INPUT_HEIGHT (INPUT_HEIGHT),
          .WEIGHT_BITS (WEIGHT_BITS),
          .WEIGHT_WIDTH (WEIGHT_WIDTH),
          .WEIGHT_HEIGHT(WEIGHT_HEIGHT),
          .OUTPUT_BITS (OUTPUT_BITS),
          .LINE_BITS   (LINE_BITS),
          .LINE_WIDTH   (LINE_WIDTH),
          .LINE_HEIGHT  (LINE_HEIGHT),
          .PATCH_WIDTH  (PATCH_WIDTH),
          .PATCH_HEIGHT (PATCH_HEIGHT)
      ) inst_LINE_BUFFER (
          .i_clk         (i_clk),
          .i_rstn        (i_rstn),
          .i_ch          (i_ch),
          .i_line_done   (i_line_done),
          .i_input_valid (i_input_valid),
          .i_input_data  (w_input_data[g]),
          .i_slide_en    (r_slide_en),
          .i_slide_sel   (r_slide_sel),
          .o_line_rd_done(o_line_rd_done),
          .o_patch_data  (w_patch_data[g]),
          .o_patch_valid (w_patch_valid[g])
      );
    end
  endgenerate

  generate
    for (g = 0; g < 3; g = g + 1) begin : PE_ARRAY
      PE #(
          .INPUT_BITS (INPUT_BITS),
          .WEIGHT_BITS(WEIGHT_BITS),
          .OUTPUT_BITS(OUTPUT_BITS)
      ) inst_PE (
          .i_clk         (i_clk),
          .i_rstn        (i_rstn),
          .i_pe_en       (i_pu_en),
          .i_weight_valid(i_weight_valid),
          .i_weight_data (w_weight_data[g]),
          .i_input_valid (w_patch_valid[g]),
          .i_input_data  (w_patch_data[g]),
          .o_pe_valid    (w_pe_valid[g]),
          .o_pe_data     (w_pe_data[g])
      );
    end
  endgenerate

  adder_tree #(
      .OUTPUT_BITS(OUTPUT_BITS),
      .INPUT_SIZE (CHANNEL_NUM)
  ) inst_adder_tree (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      .i_valid(w_pe_valid[0]),  // 동시 작업이므로 대표로 0번 PE만 
      .i_data (w_pe_pck_data),
      .o_data (o_pu_data),
      .o_valid(o_pu_valid)
  );
endmodule

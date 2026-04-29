`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/23 15:44:47
// Design Name: 
// Module Name: LINE_BUFFER
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

module line_buffer #(
    parameter INPUT_BITS  = 16,
    parameter INPUT_WIDTH  = 5,
    parameter INPUT_HEIGHT = 5,

    parameter WEIGHT_BITS  = 16,
    parameter WEIGHT_WIDTH  = 3,
    parameter WEIGHT_HEIGHT = 3,

    parameter OUTPUT_BITS = 48,

    parameter LINE_BITS  = 16,
    parameter LINE_WIDTH  = 5,
    parameter LINE_HEIGHT = 3,

    parameter PATCH_WIDTH  = 3,
    parameter PATCH_HEIGHT = 3
) (
    input                                                      i_clk,
    input                                                      i_rstn,
    input      [                                          1:0] i_ch,
    input                                                      i_line_done,
    input                                                      i_input_valid,
    input      [                              INPUT_BITS-1:0] i_input_data,
    input                                                      i_slide_en,
    input      [                                          1:0] i_slide_sel,
    output reg                                                 o_line_rd_done,
    output reg [LINE_BITS * PATCH_HEIGHT * PATCH_WIDTH - 1:0] o_patch_data,
    output reg                                                 o_patch_valid
);
  localparam LINE_123 = 1;
  localparam LINE_234 = 2;
  localparam LINE_345 = 3;



  reg [                         5:0] r_line_cnt;  // 0~ 25 카운트
  reg [LINE_WIDTH *LINE_BITS-1 : 0] r_line                         [0:LINE_HEIGHT-1];

  reg [                         1:0] r_ch;
  reg                                r_ch_change;

  // 채널 변화 감지 로직
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_ch <= 'd0;
      r_ch_change <= 'd0;
    end else begin
      r_ch <= i_ch;
      r_ch_change <= (r_ch == i_ch) ? 'd0 : 'd1;
    end
  end

  // 라인버퍼 채우는 로직
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_line[0]    <= 'd0;
      r_line[1]    <= 'd0;
      r_line[2]    <= 'd0;
      r_line_cnt   <= 'd0;
      o_line_rd_done <= 'd0;
    end else begin
      o_line_rd_done <= 'd0;
      if (i_input_valid) begin
        r_line[0] <= {r_line[0][63:0], r_line[1][79:64]};
        r_line[1] <= {r_line[1][63:0], r_line[2][79:64]};
        r_line[2] <= {r_line[2][63:0], i_input_data};
        r_line_cnt <= r_line_cnt + 'd1;
        o_line_rd_done <= (r_line_cnt == 'd14) ? 'd1 :
                        (r_line_cnt == 'd19) ? 'd1 : 
                        (r_line_cnt == 'd24) ? 'd1 : 'd0;

      end
      //if (r_ch_change) r_line_cnt <= 'd0;
    end
  end

  // 라인버퍼 출력 로직
  integer i;
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      o_patch_data <= 'd0;
    end else begin
      o_patch_valid <= 'd0;
      if (i_slide_en) begin
        case (i_slide_sel)
          LINE_123: begin
            o_patch_valid <= 'd1;
            o_patch_data  <= {r_line[0][79-:48], r_line[1][79-:48], r_line[2][79-:48]};
          end
          LINE_234: begin
            o_patch_valid <= 'd1;
            o_patch_data  <= {r_line[0][63-:48], r_line[1][63-:48], r_line[2][63-:48]};
          end
          LINE_345: begin
            o_patch_valid <= 'd1;
            o_patch_data  <= {r_line[0][47-:48], r_line[1][47-:48], r_line[2][47-:48]};
          end
          default: ;
        endcase
      end
    end
  end



endmodule

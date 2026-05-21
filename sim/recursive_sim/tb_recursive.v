//============================================================================
// Copyright (c) 2026 Seoul National University of Science and Technology
//                     (SEOULTECH)
//                     Intelligence Digital System Design Lab (IDSL)
//
// Course: Digital System Design, Spring 2026
//
// This source code is provided as educational material for the
// Digital System Design course at SEOULTECH. It is released under
// the MIT License to encourage learning and reuse.
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject
// to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//============================================================================
`timescale 1ns / 1ps
`include "defines.vh"
module tbtb ();

  //
  parameter IMAGE_NUM = 1;
  parameter PADDING_EN = 1;
  parameter L1_CHANNEL_NUM = 1;
  parameter L1_FILTER_NUM = 2;
  parameter L2_CHANNEL_NUM = 2;
  parameter L2_FILTER_NUM = 2;
  parameter L3_CHANNEL_NUM = 2;
  parameter L3_FILTER_NUM = 1;
  parameter MAX_CHANNEL_NUM = 2;
  parameter MAX_FILTER_NUM = 2;
  parameter WEIGHT_BITS = 16;
  parameter INPUT_BITS = 16;
  parameter OUTPUT_BITS = 16 * MAX_FILTER_NUM;
  parameter INPUT_WIDTH = 5;
  parameter INPUT_HEIGHT = 5;
  parameter PATCH_WIDTH = 3;
  parameter PATCH_HEIGHT = 3;

  localparam INPUT_DEPTH = INPUT_WIDTH * INPUT_HEIGHT;
  localparam IMAGE_DEPTH = INPUT_WIDTH * INPUT_HEIGHT * IMAGE_NUM;
  localparam ACT_BUF_DEPTH = INPUT_WIDTH * INPUT_HEIGHT * MAX_CHANNEL_NUM;
  localparam FMAP_WIDTH = INPUT_WIDTH + (2 * PADDING_EN);
  localparam FMAP_HEIGHT = INPUT_HEIGHT * IMAGE_NUM + (2 * PADDING_EN);
  localparam LINE_WIDTH = INPUT_WIDTH + (2 * PADDING_EN);
  localparam LINE_HEIGHT = 3;
  localparam INPUT_AREA = INPUT_WIDTH * INPUT_HEIGHT;
  localparam INPUT_ADDR = $clog2(INPUT_DEPTH);
  localparam OUTPUT_ADDR = $clog2(IMAGE_DEPTH);
  // layer 1
  parameter L1_WEIGHT_DEPTH = L1_CHANNEL_NUM * L1_FILTER_NUM * PATCH_WIDTH * PATCH_HEIGHT;
  parameter L1_BIAS_DEPTH = L1_FILTER_NUM;
  // layer 2 
  parameter L2_WEIGHT_DEPTH = L2_CHANNEL_NUM * L2_FILTER_NUM * PATCH_WIDTH * PATCH_HEIGHT;
  parameter L2_BIAS_DEPTH = L2_FILTER_NUM;
  // layer 3      
  parameter L3_WEIGHT_DEPTH = L3_CHANNEL_NUM * L3_FILTER_NUM * PATCH_WIDTH * PATCH_HEIGHT;
  parameter L3_BIAS_DEPTH = L3_FILTER_NUM;

  // BRAM INIT FILE
`ifdef IMAGE_1
  parameter IMAGE_FILE = "c:/seop_tb/test_image_1.txt";
`elsif IMAGE_3
  parameter IMAGE_FILE = "c:/seop_tb/test_image_3.txt";
`endif
  parameter L1_WEIGHT_INIT_FILE = "c:/seop_tb/w_L1.txt";
  parameter L1_BIAS_INIT_FILE = "c:/seop_tb/bias_L1.txt";
  parameter L2_WEIGHT_INIT_FILE = "c:/seop_tb/w_L2.txt";
  parameter L2_BIAS_INIT_FILE = "c:/seop_tb/bias_L2.txt";
  parameter L3_WEIGHT_INIT_FILE = "c:/seop_tb/w_L3.txt";
  parameter L3_BIAS_INIT_FILE = "c:/seop_tb/bias_L3.txt";

  //-------------------------------------------------------------------------------
  // SYSTEM SIGNALS
  //-------------------------------------------------------------------------------
  wire o_opt_vld;
  wire signed [INPUT_BITS-1:0] o_opt_dat; // 본인의 데이터 비트 폭에 맞게 수정하세요.

  reg i_clk;
  reg i_rstn;
  reg i_st;


  initial i_clk = 1'b0;

  always #5 i_clk = !i_clk;

  // debug

  reg i_rdy_test;
  //-------------------------------------------------------------------------------
  // DBG (Reset / Start)
  //-------------------------------------------------------------------------------

  initial begin
    i_rstn     = 1'b0;
    i_st       = 1'b0;
    i_rdy_test = 1'b0;
    #50;
    i_st   = 1'b1;
    i_rstn = 1'b1;
    #10;
    i_st = 1'b0;
    i_rdy_test = 1'b0;
    #1000;
    i_rdy_test = 1'b1;
    #50;
    i_rdy_test = 1'b0;
    #50;
    i_rdy_test = 1'b1;
    #50;
    i_rdy_test = 1'b0;
    #50;
    i_rdy_test = 1'b1;
    #50;
    i_rdy_test = 1'b0;
    #50;
    i_rdy_test = 1'b0;
    #50;
    i_rdy_test = 1'b1;
    #50;
    i_rdy_test = 1'b0;
    #50;
    i_rdy_test = 1'b1;
    #50;
  end


  //-------------------------------------------------------------------------------
  // Component Define
  //-------------------------------------------------------------------------------

  // TOP prac3
  my_top #(
`ifdef DEBUG
      .IMAGE_NUM          (IMAGE_NUM),
      .PADDING_EN         (PADDING_EN),
      .L1_CHANNEL_NUM     (L1_CHANNEL_NUM),
      .L1_FILTER_NUM      (L1_FILTER_NUM),
      .L2_CHANNEL_NUM     (L2_CHANNEL_NUM),
      .L2_FILTER_NUM      (L2_FILTER_NUM),
      .L3_CHANNEL_NUM     (L3_CHANNEL_NUM),
      .L3_FILTER_NUM      (L3_FILTER_NUM),
      .IMAGE_FILE         (IMAGE_FILE),
      .WEIGHT_BITS        (WEIGHT_BITS),
      .INPUT_BITS         (INPUT_BITS),
      .OUTPUT_BITS        (OUTPUT_BITS),
      .INPUT_WIDTH        (INPUT_WIDTH),
      .INPUT_HEIGHT       (INPUT_HEIGHT),
      .PATCH_WIDTH        (PATCH_WIDTH),
      .PATCH_HEIGHT       (PATCH_HEIGHT),
      .L1_WEIGHT_DEPTH    (L1_WEIGHT_DEPTH),
      .L1_WEIGHT_INIT_FILE(L1_WEIGHT_INIT_FILE),
      .L1_BIAS_DEPTH      (L1_BIAS_DEPTH),
      .L1_BIAS_INIT_FILE  (L1_BIAS_INIT_FILE),
      .L2_WEIGHT_DEPTH    (L2_WEIGHT_DEPTH),
      .L2_WEIGHT_INIT_FILE(L2_WEIGHT_INIT_FILE),
      .L2_BIAS_DEPTH      (L2_BIAS_DEPTH),
      .L2_BIAS_INIT_FILE  (L2_BIAS_INIT_FILE),
      .L3_WEIGHT_DEPTH    (L3_WEIGHT_DEPTH),
      .L3_WEIGHT_INIT_FILE(L3_WEIGHT_INIT_FILE),
      .L3_BIAS_DEPTH      (L3_BIAS_DEPTH),
      .L3_BIAS_INIT_FILE  (L3_BIAS_INIT_FILE)
`endif
  ) top_inst (
`ifdef DEBUG
      .i_rdy_test       (i_rdy_test),
`endif
      .i_clk            (i_clk),
      .i_rstn           (i_rstn),
      .i_start          (i_st),
      .output_bram_wen  (o_opt_vld),
      .output_bram_waddr(),
      .L3_p_out         (o_opt_dat),
      .o_done           ()
  );

  //-------------------------------------------------------------------------------
  // SYSTEM
  //-------------------------------------------------------------------------------

  integer file_handle;

  initial begin
`ifdef DEUBUF_MODE
    // 여기에는 디버깅 결과 저장할 txt 파일 경로를 적어주면 됌
    file_handle = $fopen("c:/", "w");
`elsif RELEASE_4_2
    file_handle = $fopen("c:/DSD26_Termproject_Materials/01_Reference_SW/save_4_2/output.txt", "w");
`elsif RELEASE_8_8
    file_handle = $fopen("c:/DSD26_Termproject_Materials/01_Reference_SW/save_8_8/output.txt", "w");
`endif

    if (file_handle == 0) begin
      $display("file open ERROR!");
      $finish;
    end
  end

  always @(posedge i_clk) begin
    if (o_opt_vld) begin
      $fdisplay(file_handle, "%d", o_opt_dat);
      $fflush(file_handle);
    end
  end


  initial begin
`ifdef DEBUG
    #5000;
`else
    #1000000;
`endif
    if (file_handle != 0) begin
      $fclose(file_handle);
      $display("ALL SAVED !");
    end
    $finish;
  end
endmodule

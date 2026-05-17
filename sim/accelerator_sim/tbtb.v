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

  // MODEL SIZE 
  parameter LAYER_NUM = 2;
  parameter INPUT_BITS = 16;
  parameter WEIGHT_BITS = 16;
  parameter OUTPUT_BITS = 32;
  // layer 1
  parameter L1_RELU_EN = 1;
  parameter L1_PADDING_EN = 1;
  parameter L1_INPUT_WIDTH = 5;
  parameter L1_INPUT_HEIGHT = 5;
  parameter L1_INPUT_DEPTH = 5 * 5 * 3;
  parameter L1_FMAP_WIDTH = L1_INPUT_WIDTH + (2 * L1_PADDING_EN);  // 7
  parameter L1_FMAP_HEIGHT = (L1_INPUT_HEIGHT * 3 + (2 * L1_PADDING_EN));  // 7
  parameter L1_FMAP_DPETH = 7 * 7 * 3;  // 7
  parameter L1_WEIGHT_DEPTH = 18;
  parameter L1_OUTPUT_WIDTH = 5;  // (3 + 2 * 1)
  parameter L1_OUTPUT_HEIGHT = 5;
  parameter L1_LINE_WIDTH = L1_INPUT_WIDTH + (2 * L1_PADDING_EN);  // (5 + 2 * 1)
  parameter L1_LINE_HEIGHT = 3;
  parameter L1_PATCH_WIDTH = 3;
  parameter L1_PATCH_HEIGHT = 3;
  parameter L1_CHANNEL_NUM = 1;
  parameter L1_FILTER_NUM = 2;
  // layer 2
  parameter L2_RELU_EN = 1;
  parameter L2_PADDING_EN = 1;
  parameter L2_INPUT_WIDTH = 5;
  parameter L2_INPUT_HEIGHT = 5;
  parameter L2_FMAP_WIDTH = L2_INPUT_WIDTH + (2 * L2_PADDING_EN);  // 7
  parameter L2_FMAP_HEIGHT = (L2_INPUT_HEIGHT * 3 + (2 * L2_PADDING_EN));  // 7
  parameter L2_FMAP_DEPTH = 7 * 7 * 3;  // 7
  parameter L2_WEIGHT_DEPTH = 18;
  parameter L2_OUTPUT_WIDTH = 5;  // (3 + 2 * 1)
  parameter L2_OUTPUT_HEIGHT = 5;
  parameter L2_LINE_WIDTH = L2_INPUT_WIDTH + (2 * L2_PADDING_EN);  // (5 + 2 * 1)
  parameter L2_LINE_HEIGHT = 3;
  parameter L2_PATCH_WIDTH = 3;
  parameter L2_PATCH_HEIGHT = 3;
  parameter L2_CHANNEL_NUM = 2;
  parameter L2_FILTER_NUM = 2;
  // layer 3 
  parameter L3_RELU_EN = 0;
  parameter L3_PADDING_EN = 1;
  parameter L3_INPUT_WIDTH = 5;
  parameter L3_INPUT_HEIGHT = 5;
  parameter L3_FMAP_WIDTH = L3_INPUT_WIDTH + (2 * L3_PADDING_EN);  // 7
  parameter L3_FMAP_HEIGHT = (L3_INPUT_HEIGHT * 3 + (2 * L3_PADDING_EN));  // 7
  parameter L3_FMAP_DEPTH = 7 * 7 * 3;  // 7
  parameter L3_WEIGHT_DEPTH = 18;
  parameter L3_OUTPUT_WIDTH = 5;  // (3 + 2 * 1)
  parameter L3_OUTPUT_HEIGHT = 5;
  parameter L3_OUTPUT_DEPTH = 75;
  parameter L3_LINE_WIDTH = L3_INPUT_WIDTH + (2 * L3_PADDING_EN);  // (5 + 2 * 1)
  parameter L3_LINE_HEIGHT = 3;
  parameter L3_PATCH_WIDTH = 3;
  parameter L3_PATCH_HEIGHT = 3;
  parameter L3_CHANNEL_NUM = 2;
  parameter L3_FILTER_NUM = 1;

  // BRAM INIT FILE
  parameter INPUT_INIT_FILE = "c:/seop_workspace/seop_verilog/init/accelerator_init/pb6/act.txt";
  parameter L1_WEIGHT_INIT_FILE = "c:/seop_workspace/seop_verilog/init/accelerator_init/pb6/w_L1.txt";
  parameter L1_BIAS_INIT_FILE = "";
  parameter L2_WEIGHT_INIT_FILE = "c:/seop_workspace/seop_verilog/init/accelerator_init/pb6/w_L2.txt";
  parameter L2_BIAS_INIT_FILE = "";
  parameter L3_WEIGHT_INIT_FILE = "c:/seop_workspace/seop_verilog/init/accelerator_init/pb6/w_L3.txt";
  parameter L3_BIAS_INIT_FILE = "";

  //-------------------------------------------------------------------------------
  // SYSTEM SIGNALS
  //-------------------------------------------------------------------------------

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
    #20;
    i_rdy_test = 1'b0;
    #20;
    i_rdy_test = 1'b1;
    #20;
    i_rdy_test = 1'b0;
    #20;
    i_rdy_test = 1'b1;
    #20;
    i_rdy_test = 1'b0;
    #20;
    i_rdy_test = 1'b0;
    #20;
    i_rdy_test = 1'b1;
    #20;
    i_rdy_test = 1'b0;
    #20;
    i_rdy_test = 1'b1;
    #20;
  end


  //-------------------------------------------------------------------------------
  // Component Define
  //-------------------------------------------------------------------------------

  // TOP prac3
  my_top #(
`ifdef DEBUG_MODE
      .LAYER_NUM          (LAYER_NUM),
      .INPUT_BITS         (INPUT_BITS),
      .WEIGHT_BITS        (WEIGHT_BITS),
      .OUTPUT_BITS        (OUTPUT_BITS),
      // layer 1
      .L1_PADDING_EN      (L1_PADDING_EN),
      .L1_RELU_EN         (L1_RELU_EN),
      .L1_INPUT_WIDTH     (L1_INPUT_WIDTH),
      .L1_INPUT_HEIGHT    (L1_INPUT_HEIGHT),
      .L1_INPUT_DEPTH     (L1_INPUT_DEPTH),
      .L1_FMAP_WIDTH      (L1_FMAP_WIDTH),
      .L1_FMAP_HEIGHT     (L1_FMAP_HEIGHT),
      .L1_WEIGHT_DEPTH    (L1_WEIGHT_DEPTH),
      .L1_OUTPUT_WIDTH    (L1_OUTPUT_WIDTH),
      .L1_OUTPUT_HEIGHT   (L1_OUTPUT_HEIGHT),
      .L1_LINE_WIDTH      (L1_LINE_WIDTH),
      .L1_LINE_HEIGHT     (L1_LINE_HEIGHT),
      .L1_PATCH_WIDTH     (L1_PATCH_WIDTH),
      .L1_PATCH_HEIGHT    (L1_PATCH_HEIGHT),
      .L1_CHANNEL_NUM     (L1_CHANNEL_NUM),
      .L1_FILTER_NUM      (L1_FILTER_NUM),
      // layer 2
      .L2_PADDING_EN      (L2_PADDING_EN),
      .L2_RELU_EN         (L2_RELU_EN),
      .L2_INPUT_WIDTH     (L2_INPUT_WIDTH),
      .L2_INPUT_HEIGHT    (L2_INPUT_HEIGHT),
      .L2_FMAP_WIDTH      (L2_FMAP_WIDTH),
      .L2_FMAP_HEIGHT     (L2_FMAP_HEIGHT),
      .L2_WEIGHT_DEPTH    (L2_WEIGHT_DEPTH),
      .L2_OUTPUT_WIDTH    (L2_OUTPUT_WIDTH),
      .L2_OUTPUT_HEIGHT   (L2_OUTPUT_HEIGHT),
      .L2_LINE_WIDTH      (L2_LINE_WIDTH),
      .L2_LINE_HEIGHT     (L2_LINE_HEIGHT),
      .L2_PATCH_WIDTH     (L2_PATCH_WIDTH),
      .L2_PATCH_HEIGHT    (L2_PATCH_HEIGHT),
      .L2_CHANNEL_NUM     (L2_CHANNEL_NUM),
      .L2_FILTER_NUM      (L2_FILTER_NUM),
      // layer 3
      .L3_RELU_EN         (L3_RELU_EN),
      .L3_PADDING_EN      (L3_PADDING_EN),
      .L3_INPUT_WIDTH     (L3_INPUT_WIDTH),
      .L3_INPUT_HEIGHT    (L3_INPUT_HEIGHT),
      .L3_FMAP_WIDTH      (L3_FMAP_WIDTH),
      .L3_FMAP_HEIGHT     (L3_FMAP_HEIGHT),
      .L3_WEIGHT_DEPTH    (L3_WEIGHT_DEPTH),
      .L3_OUTPUT_WIDTH    (L3_OUTPUT_WIDTH),
      .L3_OUTPUT_HEIGHT   (L3_OUTPUT_HEIGHT),
      .L3_OUTPUT_DEPTH    (L3_OUTPUT_DEPTH),
      .L3_LINE_WIDTH      (L3_LINE_WIDTH),
      .L3_LINE_HEIGHT     (L3_LINE_HEIGHT),
      .L3_PATCH_WIDTH     (L3_PATCH_WIDTH),
      .L3_PATCH_HEIGHT    (L3_PATCH_HEIGHT),
      .L3_CHANNEL_NUM     (L3_CHANNEL_NUM),
      .L3_FILTER_NUM      (L3_FILTER_NUM),
      // init mem
      .INPUT_INIT_FILE    (INPUT_INIT_FILE),
      .L1_WEIGHT_INIT_FILE(L1_WEIGHT_INIT_FILE),
      .L1_BIAS_INIT_FILE  (L1_BIAS_INIT_FILE),
      .L2_WEIGHT_INIT_FILE(L2_WEIGHT_INIT_FILE),
      .L2_BIAS_INIT_FILE  (L2_BIAS_INIT_FILE),
      .L3_WEIGHT_INIT_FILE(L3_WEIGHT_INIT_FILE),
      .L3_BIAS_INIT_FILE  (L3_BIAS_INIT_FILE)
`endif
  ) top_inst (
      .i_clk            (i_clk),
      .i_rstn           (i_rstn),
      .i_start          (i_st),
`ifdef DEBUG_MODE
      .i_rdy_test       (i_rdy_test),
`endif
      .output_bram_wen  (),
      .output_bram_waddr(),
      .L3_p_out         (),
      .o_done           ()
  );

  //-------------------------------------------------------------------------------
  // SYSTEM
  //-------------------------------------------------------------------------------

  initial begin
    #40000 $finish();
  end

endmodule

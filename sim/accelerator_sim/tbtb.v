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

module tbtb ();

  //-------------------------------------------------------------------------------
  // Parameter Define
  //-------------------------------------------------------------------------------

  // MODEL SIZE 
  parameter LAYER_NUM = 2;
  parameter INPUT_BITS = 16;
  parameter WEIGHT_BITS = 16;
  parameter OUTPUT_BITS = 32;
  // layer 1
  parameter L1_PADDING_EN = 1;
  parameter L1_INPUT_WIDTH = 5;
  parameter L1_INPUT_HEIGHT = 5;
  parameter L1_FMAP_WIDTH = L1_INPUT_WIDTH + (2 * L1_PADDING_EN);  // 7
  parameter L1_FMAP_HEIGHT = L1_INPUT_HEIGHT + (2 * L1_PADDING_EN);  // 7
  parameter L1_WEIGHT_WIDTH = 3;
  parameter L1_WEIGHT_HEIGHT = 3;
  parameter L1_OUTPUT_WIDTH = 5;  // (3 + 2 * 1)
  parameter L1_OUTPUT_HEIGHT = 5;
  parameter L1_LINE_WIDTH = L1_INPUT_WIDTH + (2 * L1_PADDING_EN);  // (5 + 2 * 1)
  parameter L1_LINE_HEIGHT = 3;
  parameter L1_PATCH_WIDTH = 3;
  parameter L1_PATCH_HEIGHT = 3;
  parameter L1_CHANNEL_NUM = 1;
  // layer 2
  parameter L2_PADDING_EN = 1;
  parameter L2_INPUT_WIDTH = 5;
  parameter L2_INPUT_HEIGHT = 5;
  parameter L2_FMAP_WIDTH = L2_INPUT_WIDTH + (2 * L2_PADDING_EN);  // 7
  parameter L2_FMAP_HEIGHT = L2_INPUT_HEIGHT + (2 * L2_PADDING_EN);  // 7
  parameter L2_WEIGHT_WIDTH = 3;
  parameter L2_WEIGHT_HEIGHT = 3;
  parameter L2_OUTPUT_WIDTH = 5;  // (3 + 2 * 1)
  parameter L2_OUTPUT_HEIGHT = 5;
  parameter L2_LINE_WIDTH = L2_INPUT_WIDTH + (2 * L2_PADDING_EN);  // (5 + 2 * 1)
  parameter L2_LINE_HEIGHT = 3;
  parameter L2_PATCH_WIDTH = 3;
  parameter L2_PATCH_HEIGHT = 3;
  parameter L2_CHANNEL_NUM = 1;

  // BRAM INIT FILE
  parameter INIT_INPUT_BRAM = "c:/seop_workspace/seop_verilog/init/accelerator_init/pb6/act.txt";
  parameter INIT_WEIGHT_BRAM1 = "c:/seop_workspace/seop_verilog/init/accelerator_init/pb6/w_L1.txt";
  parameter INIT_WEIGHT_BRAM2 = "c:/seop_workspace/seop_verilog/init/accelerator_init/pb6/w_L2.txt";


  //-------------------------------------------------------------------------------
  // SYSTEM SIGNALS
  //-------------------------------------------------------------------------------

  reg i_clk;
  reg i_rstn;
  reg i_st;

  initial i_clk = 1'b0;

  always #5 i_clk = !i_clk;

  //-------------------------------------------------------------------------------
  // DBG (Reset / Start)
  //-------------------------------------------------------------------------------

  initial begin
    i_rstn = 1'b0;
    i_st   = 1'b0;
    #50;
    i_rstn = 1'b1;
    #10;
    i_st = 1'b1;
  end


  //-------------------------------------------------------------------------------
  // Component Define
  //-------------------------------------------------------------------------------

  // TOP prac3
  top #(
      .LAYER_NUM        (LAYER_NUM),
      .INPUT_BITS       (INPUT_BITS),
      .WEIGHT_BITS      (WEIGHT_BITS),
      .OUTPUT_BITS      (OUTPUT_BITS),
      // layer 1
      .L1_PADDING_EN    (L1_PADDING_EN),
      .L1_INPUT_WIDTH   (L1_INPUT_WIDTH),
      .L1_INPUT_HEIGHT  (L1_INPUT_HEIGHT),
      .L1_FMAP_WIDTH    (L1_FMAP_WIDTH),
      .L1_FMAP_HEIGHT   (L1_FMAP_HEIGHT),
      .L1_WEIGHT_WIDTH  (L1_WEIGHT_WIDTH),
      .L1_WEIGHT_HEIGHT (L1_WEIGHT_HEIGHT),
      .L1_OUTPUT_WIDTH  (L1_OUTPUT_WIDTH),
      .L1_OUTPUT_HEIGHT (L1_OUTPUT_HEIGHT),
      .L1_LINE_WIDTH    (L1_LINE_WIDTH),
      .L1_LINE_HEIGHT   (L1_LINE_HEIGHT),
      .L1_PATCH_WIDTH   (L1_PATCH_WIDTH),
      .L1_PATCH_HEIGHT  (L1_PATCH_HEIGHT),
      .L1_CHANNEL_NUM   (L1_CHANNEL_NUM),
      // layer 2
      .L2_PADDING_EN    (L2_PADDING_EN),
      .L2_INPUT_WIDTH   (L2_INPUT_WIDTH),
      .L2_INPUT_HEIGHT  (L2_INPUT_HEIGHT),
      .L2_FMAP_WIDTH    (L2_FMAP_WIDTH),
      .L2_FMAP_HEIGHT   (L2_FMAP_HEIGHT),
      .L2_WEIGHT_WIDTH  (L2_WEIGHT_WIDTH),
      .L2_WEIGHT_HEIGHT (L2_WEIGHT_HEIGHT),
      .L2_OUTPUT_WIDTH  (L2_OUTPUT_WIDTH),
      .L2_OUTPUT_HEIGHT (L2_OUTPUT_HEIGHT),
      .L2_LINE_WIDTH    (L2_LINE_WIDTH),
      .L2_LINE_HEIGHT   (L2_LINE_HEIGHT),
      .L2_PATCH_WIDTH   (L2_PATCH_WIDTH),
      .L2_PATCH_HEIGHT  (L2_PATCH_HEIGHT),
      .L2_CHANNEL_NUM   (L2_CHANNEL_NUM),
      // init mem
      .INIT_INPUT_BRAM  (INIT_INPUT_BRAM),
      .INIT_WEIGHT_BRAM1(INIT_WEIGHT_BRAM1),
      .INIT_WEIGHT_BRAM2(INIT_WEIGHT_BRAM2)
  ) top_inst (
      .i_clk (i_clk),
      .i_rstn(i_rstn),
      .i_st  (i_st),
      .o_dn  ()
  );

  //-------------------------------------------------------------------------------
  // SYSTEM
  //-------------------------------------------------------------------------------

  initial begin
    #2000 $finish();
  end

endmodule

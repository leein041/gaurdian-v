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

module simple_dual_port_bram #(
    parameter WIDTH      = 16,
    parameter DEPTH      = 1024,
    parameter ADDR_WIDTH = $clog2(DEPTH),
    parameter INIT_FILE  = ""
) (
    input                              i_clk,
    input                              i_rstn,
    input                              i_re,
    input             [ADDR_WIDTH-1:0] i_raddr,
    input                              i_we,
    input             [ADDR_WIDTH-1:0] i_waddr,
    input  signed     [     WIDTH-1:0] i_wdin,
    output reg                         o_vld,
    output reg signed [     WIDTH-1:0] o_dout
);

  // BRAM
  (* ram_style = "block" *) reg signed [WIDTH-1:0] r_mem[0:DEPTH-1];

  generate
    if (INIT_FILE != "") begin : use_init_file
      initial begin
        $readmemh(INIT_FILE, r_mem);
      end
    end
  endgenerate

  always @(posedge i_clk) begin
    if (i_we) r_mem[i_waddr] <= i_wdin;
    if (i_re) o_dout <= r_mem[i_raddr];  // READ_FIRST  
  end
  // 2. 유효 신호 제어 (리셋 필요)
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      o_vld <= 1'b0;
    end else begin
      o_vld <= i_re;
    end
  end
endmodule

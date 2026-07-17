
`timescale 1ns / 1ps
`include "../../rtl/accelerator/network_config.vh"
module tbtb ();

  //-------------------------------------------------------------------------------
  // parameter
  //-------------------------------------------------------------------------------   
  // MODEL SIZE  
  parameter IPT_BITS = 16;
  parameter WGT_BITS = 16;
  parameter OUTPUT_BITS = 16;

  parameter PATCH_WIDTH = 3;
  parameter PATCH_HEIGHT = 3;
  parameter OUTPUT_WIDTH = 5;
  parameter OUTPUT_HEIGHT = 5;

  // layer 1
  parameter L1_RELU_EN = 1;
  parameter L1_INPUT_WIDTH = 5;
  parameter L1_INPUT_HEIGHT = 5;
  parameter L1_CHANNEL_NUM = 1;
  parameter L1_FILTER_NUM = 4;
  // layer 2
  parameter L2_RELU_EN = 1;
  parameter L2_INPUT_WIDTH = 5;
  parameter L2_INPUT_HEIGHT = 5;
  parameter L2_CHANNEL_NUM = 4;
  parameter L2_FILTER_NUM = 8;
  // layer 3 
  parameter L3_RELU_EN = 0;
  parameter L3_INPUT_WIDTH = 5;
  parameter L3_INPUT_HEIGHT = 5;
  parameter L3_CHANNEL_NUM = 8;
  parameter L3_FILTER_NUM = 1;

  parameter IPT_INIT_FILE = "C:/seop_workspace/seop_verilog/sim/accelerator_sim/golden/input.txt";
  parameter L1_WGT_INIT_FILE = "C:/seop_workspace/seop_verilog/sim/accelerator_sim/golden/layer1_weight.txt";
  parameter L1_BIAS_INIT_FILE = "C:/seop_workspace/seop_verilog/sim/accelerator_sim/golden/layer1_bias.txt";
  parameter L2_WGT_INIT_FILE = "C:/seop_workspace/seop_verilog/sim/accelerator_sim/golden/layer2_weight.txt";
  parameter L2_BIAS_INIT_FILE = "C:/seop_workspace/seop_verilog/sim/accelerator_sim/golden/layer2_bias.txt";
  parameter L3_WGT_INIT_FILE = "C:/seop_workspace/seop_verilog/sim/accelerator_sim/golden/layer3_weight.txt";
  parameter L3_BIAS_INIT_FILE = "C:/seop_workspace/seop_verilog/sim/accelerator_sim/golden/layer3_bias.txt";

  localparam LAYER_NUM = 3;

  //-------------------------------------------------------------------------------
  // internal signal
  //-------------------------------------------------------------------------------

  reg                               i_clk;
  reg                               i_rstn;
  reg                               i_st;
  // layer
  wire        [$clog2(LAYER_NUM):0] w_lyr_num;
  wire                              w_lyr_vld;
  wire signed [       IPT_BITS-1:0] w_lyr_dat;


  initial i_clk = 1'b0;

  always #5 i_clk = !i_clk;

  // debug

  reg i_rdy_test;

  initial begin
    i_rstn     = 1'b0;
    i_st       = 1'b0;
    i_rdy_test = 1'b0;
    #50;
    i_st   = 1'b1;
    i_rstn = 1'b1;
    #10;
    i_st = 1'b0;
    i_rdy_test = 1'b1;
    #1000;
    // #1000;
    // i_rdy_test = 1'b0;
    // #1000;
    // i_rdy_test = 1'b1;
    // #1000;
    // i_rdy_test = 1'b0;
    // #1000;
    // i_rdy_test = 1'b1;
    // #50;
    // i_rdy_test = 1'b0;
    // #50;
    // i_rdy_test = 1'b0;
    // #50;
    // i_rdy_test = 1'b1;
    // #50;
    // i_rdy_test = 1'b0;
    // #50;
    // i_rdy_test = 1'b1;
    // #50;
  end


  //-------------------------------------------------------------------------------
  // Component Define
  //-------------------------------------------------------------------------------

  my_top #(
`ifdef DEBUG
      .IPT_INIT_FILE    (IPT_INIT_FILE),
      // layer 1  
      .L1_WGT_INIT_FILE (L1_WGT_INIT_FILE),
      .L1_BIAS_INIT_FILE(L1_BIAS_INIT_FILE),
      // layer 2 
      .L2_WGT_INIT_FILE (L2_WGT_INIT_FILE),
      .L2_BIAS_INIT_FILE(L2_BIAS_INIT_FILE),
      // layer 3 
      .L3_WGT_INIT_FILE (L3_WGT_INIT_FILE),
      .L3_BIAS_INIT_FILE(L3_BIAS_INIT_FILE)
`endif
  ) top_inst (
`ifdef DEBUG
      .i_rdy_test(i_rdy_test),
      .o_lyr_num (w_lyr_num),
      .o_lyr_vld (w_lyr_vld),
      .o_lyr_dat (w_lyr_dat),
`endif
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_start   (i_st),
      .o_done    ()
  );

  //-------------------------------------------------------------------------------
  // SYSTEM
  //-------------------------------------------------------------------------------

  localparam OUTPUT_DEPTH = 64;

  integer i;

  integer idx = 0;
  integer error = 0;
  integer log_fp;
  reg signed [15:0] golden[0:OUTPUT_DEPTH-1];

  // set init
  initial begin
    log_fp = $fopen("C:/seop_workspace/seop_verilog/log/accelerator/debug.log", "w");
    if (log_fp == 0) begin
      $display("Cannot open debug.log");
      $finish;
    end

    $readmemh("C:/seop_workspace/seop_verilog/sim/accelerator_sim/golden/result.txt",
              golden);
  end

  // saved
  always @(posedge i_clk) begin
    if (w_lyr_vld && w_lyr_num == LAYER_NUM) begin
      if (w_lyr_dat !== golden[idx]) begin
        $fdisplay(log_fp, "=====================");
        $fdisplay(log_fp, "Mismatch!");
        $fdisplay(log_fp, "Index    : %d", idx);
        $fdisplay(log_fp, "Expected : %h", golden[idx]);
        $fdisplay(log_fp, "Actual   : %h", w_lyr_dat);
        $fdisplay(log_fp, "=====================");
        error = error + 1;
      end else $fdisplay(log_fp, "Expected : %h, Actual : %h", golden[idx], w_lyr_dat);
      idx = idx + 1;
    end

    // finish 
    if (idx >= `L3_OPT_SIDE * `L3_OPT_SIDE) begin
      if (error > 0) $display("========== FAIL : %d errors ==========", error);
      else $display("========== PASS ==========");

      $fclose(log_fp);
      $finish;
    end
  end

endmodule

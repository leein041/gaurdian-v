
`timescale 1ns / 1ps
`include "defines.vh"
module tbtb ();

  //-------------------------------------------------------------------------------
  // parameter
  //-------------------------------------------------------------------------------
`ifdef IMAGE_1
  parameter IMAGE_NUM = 1;
  parameter INPUT_INIT_FILE = "c:/seop_tb/test_image_1.txt";
`elsif IMAGE_3
  parameter IMAGE_NUM = 3;
  parameter INPUT_INIT_FILE = "c:/seop_tb/test_image_3.txt";
`endif
  //
  parameter PADDING_EN = 1;
  // MODEL SIZE  
  parameter INPUT_BITS = 16;
  parameter WEIGHT_BITS = 16;
  parameter OUTPUT_BITS = 16;
  parameter INPUT_WIDTH = 5;
  parameter INPUT_HEIGHT = 5;
  parameter IMAGE_WIDTH = 5;
  parameter IMAGE_HEIGHT = 5;
  parameter OUTPUT_WIDTH = 5;
  parameter OUTPUT_HEIGHT = 5;
  parameter PATCH_WIDTH = 3;
  parameter PATCH_HEIGHT = 3;
  // layer 1
  parameter L1_RELU_EN = 1;
  parameter L1_CHANNEL_NUM = 1;
  parameter L1_FILTER_NUM = 2;
  // layer 2
  parameter L2_RELU_EN = 1;
  parameter L2_CHANNEL_NUM = 2;
  parameter L2_FILTER_NUM = 2;
  // layer 3 
  parameter L3_RELU_EN = 0;
  parameter L3_CHANNEL_NUM = 2;
  parameter L3_FILTER_NUM = 1;


  parameter L1_WEIGHT_INIT_FILE = "c:/seop_tb/w_L1.txt";
  parameter L1_BIAS_INIT_FILE = "c:/seop_tb/bias_L1.txt";
  parameter L2_WEIGHT_INIT_FILE = "c:/seop_tb/w_L2.txt";
  parameter L2_BIAS_INIT_FILE = "c:/seop_tb/bias_L2.txt";
  parameter L3_WEIGHT_INIT_FILE = "c:/seop_tb/w_L3.txt";
  parameter L3_BIAS_INIT_FILE = "c:/seop_tb/bias_L3.txt";

  //-------------------------------------------------------------------------------
  // internal signal
  //-------------------------------------------------------------------------------
  wire o_opt_vld;
  wire signed [INPUT_BITS-1:0] o_opt_dat;

  reg i_clk;
  reg i_rstn;
  reg i_st;


  initial i_clk = 1'b0;

  always #5 i_clk = !i_clk;

  // debug

  reg i_rdy_test;
  //-------------------------------------------------------------------------------
  // 핸드셰이크 테스트
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

  my_top #(
`ifdef DEBUG
      .IMAGE_NUM          (IMAGE_NUM),
      .PADDING_EN         (PADDING_EN),
      .WEIGHT_BITS        (WEIGHT_BITS),
      .INPUT_BITS         (INPUT_BITS),
      .OUTPUT_BITS        (OUTPUT_BITS),
      .INPUT_WIDTH        (INPUT_WIDTH),
      .INPUT_HEIGHT       (INPUT_HEIGHT),
      .IMAGE_WIDTH        (IMAGE_WIDTH),
      .IMAGE_HEIGHT       (IMAGE_HEIGHT),
      .OUTPUT_WIDTH       (OUTPUT_WIDTH),
      .OUTPUT_HEIGHT      (OUTPUT_HEIGHT),
      .PATCH_WIDTH        (PATCH_WIDTH),
      .PATCH_HEIGHT       (PATCH_HEIGHT),
      .INPUT_INIT_FILE    (INPUT_INIT_FILE),
      .L1_RELU_EN         (L1_RELU_EN),
      .L1_CHANNEL_NUM     (L1_CHANNEL_NUM),
      .L1_FILTER_NUM      (L1_FILTER_NUM),
      .L1_WEIGHT_INIT_FILE(L1_WEIGHT_INIT_FILE),
      .L1_BIAS_INIT_FILE  (L1_BIAS_INIT_FILE),
      .L2_RELU_EN         (L2_RELU_EN),
      .L2_CHANNEL_NUM     (L2_CHANNEL_NUM),
      .L2_FILTER_NUM      (L2_FILTER_NUM),
      .L2_WEIGHT_INIT_FILE(L2_WEIGHT_INIT_FILE),
      .L2_BIAS_INIT_FILE  (L2_BIAS_INIT_FILE),
      .L3_RELU_EN         (L3_RELU_EN),
      .L3_WEIGHT_INIT_FILE(L3_WEIGHT_INIT_FILE),
      .L3_BIAS_INIT_FILE  (L3_BIAS_INIT_FILE),
      .L3_CHANNEL_NUM     (L3_CHANNEL_NUM),
      .L3_FILTER_NUM      (L3_FILTER_NUM)

`endif  // DEBUG
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
    // 출력 txt 저장 경로
`ifdef DEUBUF_MODE
    // 여기에는 디버깅 결과 저장할 txt 파일 경로를 적어주면 됌, 근데 데이터 적어서 파형으로도 볼수 있으니 굳이
    file_handle = $fopen("c:/", "w");
`elsif RELEASE_4_2
    file_handle = $fopen("c:/DSD26_Termproject_Materials/01_Reference_SW/save_4_2/output.txt", "w");
`elsif RELEASE_8_4
    file_handle = $fopen("c:/DSD26_Termproject_Materials/01_Reference_SW/save_8_4/output.txt", "w");
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
    #100000;
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

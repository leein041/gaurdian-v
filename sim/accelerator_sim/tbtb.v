
`timescale 1ns / 1ps
`include "C:/seop_workspace/seop_verilog/rtl/accelerator/config/network_config.vh"
module tbtb ();

  parameter IMG_INIT_FILE = "C:/seop_workspace/seop_verilog/sim/accelerator_sim/golden/input.txt";
  parameter L0_WGT_INIT_FILE = "C:/seop_workspace/seop_verilog/sim/accelerator_sim/golden/layer0_weight.txt";
  parameter L0_BIAS_INIT_FILE = "C:/seop_workspace/seop_verilog/sim/accelerator_sim/golden/layer0_bias.txt";
  parameter L1_WGT_INIT_FILE = "C:/seop_workspace/seop_verilog/sim/accelerator_sim/golden/layer1_weight.txt";
  parameter L1_BIAS_INIT_FILE = "C:/seop_workspace/seop_verilog/sim/accelerator_sim/golden/layer1_bias.txt";
  parameter L2_WGT_INIT_FILE = "C:/seop_workspace/seop_verilog/sim/accelerator_sim/golden/layer2_weight.txt";
  parameter L2_BIAS_INIT_FILE = "C:/seop_workspace/seop_verilog/sim/accelerator_sim/golden/layer2_bias.txt"; 
  //-------------------------------------------------------------------------------
  // internal signal
  //-------------------------------------------------------------------------------

  reg i_clk;
  reg i_rstn;
  reg i_st;
  reg i_rdy_test;

  initial i_clk = 1'b0;
  always #5 i_clk = !i_clk;
 

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
  end


  //-------------------------------------------------------------------------------
  // Component Define
  //-------------------------------------------------------------------------------

  my_top #(
`ifdef DEBUG
      .IMG_INIT_FILE    (IMG_INIT_FILE),
      // layer 1  
      .L0_WGT_INIT_FILE (L0_WGT_INIT_FILE),
      .L0_BIAS_INIT_FILE(L0_BIAS_INIT_FILE),
      // layer 2 
      .L1_WGT_INIT_FILE (L1_WGT_INIT_FILE),
      .L1_BIAS_INIT_FILE(L1_BIAS_INIT_FILE),
      // layer 3 
      .L2_WGT_INIT_FILE (L2_WGT_INIT_FILE),
      .L2_BIAS_INIT_FILE(L2_BIAS_INIT_FILE)
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
      .o_dn      (w_dn)
  );

  //-------------------------------------------------------------------------------
  // SYSTEM
  //-------------------------------------------------------------------------------
 //-------------------------------------------------------------------------------
// Output Buffer Compare
//-------------------------------------------------------------------------------

localparam OUTPUT_DEPTH = `L2_OPT_AREA;

reg tb_obuf_re;
reg [`CLOG2_SAFE(`MAX_OPT_AREA)-1:0] tb_obuf_raddr;

wire tb_obuf_rvld;
wire signed [15:0] tb_obuf_rdout;

reg compare_start;

integer idx;
integer error;
integer log_fp;

reg signed [15:0] golden [0:OUTPUT_DEPTH-1];

//------------------------------------------------------------
// Golden Init
//------------------------------------------------------------

initial begin

    idx   = 0;
    error = 0;

    compare_start = 0;

    tb_obuf_re    = 0;
    tb_obuf_raddr = 0;

    log_fp = $fopen(
        "C:/seop_workspace/seop_verilog/log/accelerator/debug.log",
        "w"
    );

    if(log_fp == 0) begin
        $display("Cannot open debug.log");
        $finish;
    end

    $readmemh(
        "C:/seop_workspace/seop_verilog/sim/accelerator_sim/golden/result.txt",
        golden
    );

end

//------------------------------------------------------------
// Read Output Buffer
//------------------------------------------------------------

always @(posedge i_clk) begin
    if(!i_rstn) begin 
        compare_start <= 0;  
    end
    else begin
        //----------------------------------------------------
        // Start Compare
        //----------------------------------------------------
        if(w_dn && !compare_start) begin
            compare_start <= 1;
        end 
    end
end

//------------------------------------------------------------
// Compare
//------------------------------------------------------------

always @(posedge i_clk) begin
    if(compare_start) begin
        if(top_inst.inst_fbuf.opt_buf.BRAM_TYPE.r_mem[idx] !== golden[idx]) begin
            $fdisplay(log_fp,"=====================");
            $fdisplay(log_fp,"Mismatch!");
            $fdisplay(log_fp,"Index    : %d",idx);
            $fdisplay(log_fp,"Expected : %h",golden[idx]);
            $fdisplay(log_fp,"Actual   : %h",tb_obuf_rdout);
            $fdisplay(log_fp,"=====================");

            error = error + 1;

        end
        else begin

            $fdisplay(
                log_fp,
                "Expected : %h, Actual : %h",
                golden[idx],
                tb_obuf_rdout
            );

        end

        idx = idx + 1;

        //----------------------------------------------------
        // Finish
        //----------------------------------------------------

        if(idx == OUTPUT_DEPTH) begin

            if(error)
                $display("========== FAIL : %0d errors ==========",error);
            else
                $display("========== PASS ==========");

            $fclose(log_fp);
            $finish;

        end

    end

end
endmodule

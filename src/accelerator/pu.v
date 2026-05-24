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

`include "defines.vh"
module pu #(
    parameter WEIGHT_BITS = 16,
    parameter INPUT_BITS = 16,
    parameter PATCH_WIDTH = 3,
    parameter PATCH_HEIGHT = 3,
    parameter LINE_WIDTH = 5,
    parameter LINE_HEIGHT = 3,
    localparam PATCH_AREA = PATCH_WIDTH * PATCH_HEIGHT,
    localparam PATCH_SIZE = INPUT_BITS * PATCH_AREA,
`ifdef RESOURCE
    localparam PE_OUT_BITS = INPUT_BITS + WEIGHT_BITS + $clog2(PATCH_AREA),
    localparam PU_OUT_BITS = PE_OUT_BITS,
`elsif BALANCE
    localparam PE_OUT_BITS = INPUT_BITS * 2 + 2,
    localparam MAT_OUT_BITS = PE_OUT_BITS + $clog2(PATCH_HEIGHT),
    localparam PU_OUT_BITS = MAT_OUT_BITS,
`elsif PERFORMANCE
    localparam PE_OUT_BITS = INPUT_BITS + WEIGHT_BITS,
    localparam MAT_OUT_BITS = PE_OUT_BITS + $clog2(PATCH_AREA),
    localparam PU_OUT_BITS = MAT_OUT_BITS,
`endif
    localparam DUMMY = 0
) (
    input                                           i_clk,
    input                                           i_rstn,
    input                                           i_clr,
    // wgt 
    input                                           i_wgt_vld,
    input  signed [               WEIGHT_BITS -1:0] i_wgt_din,
    // ipt
    output                                          o_ipt_rdy,
    input                                           i_ipt_vld,
    input  signed [INPUT_BITS * PATCH_HEIGHT - 1:0] i_ipt_din,
    // opt
    input                                           i_opt_rdy,
    output                                          o_opt_vld,
    output signed [              PU_OUT_BITS - 1:0] o_opt_dout
);
  // ====================== parmeter =======================   
  integer i;
  genvar c, p;

  //      ____                                    
  //     |  _ \ ___  ___  ___  _   _ _ __ ___ ___ 
  //     | |_) / _ \/ __|/ _ \| | | | '__/ __/ _ \
  //     |  _ <  __/\__ \ (_) | |_| | | | (_|  __/
  //     |_| \_\___||___/\___/ \__,_|_|  \___\___|
  //                                              
`ifdef RESOURCE
  // ====================== wire ===========================  
  wire                                 w_ptch_vld;
  wire signed [        INPUT_BITS-1:0] w_ptch_dat;
  wire                                 w_pe_act;
  wire        [      PATCH_HEIGHT-1:0] w_pe_vld;
  wire signed [       PE_OUT_BITS-1:0] w_pe_dat   [0:PATCH_HEIGHT-1];
  // ====================== reg ============================ 
  reg         [$clog2(PATCH_AREA)-1:0] r_wgt_cnt;
  reg signed  [       WEIGHT_BITS-1:0] r_wgt_dat  [  0:PATCH_AREA-1];
  // ====================== hand shake =====================  
  assign w_pe_act = w_ptch_vld && i_opt_rdy;
  // ====================== always =========================  
  // initialize weight data
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      for (i = 0; i < PATCH_AREA; i = i + 1) begin
        r_wgt_dat[i] <= 'd0;
      end
    end else if (i_wgt_vld) begin
      for (i = 0; i < PATCH_AREA - 1; i = i + 1) begin
        r_wgt_dat[i] <= r_wgt_dat[i+1];
      end
      r_wgt_dat[PATCH_AREA-1] <= i_wgt_din;
    end
  end
  // weigt counter 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_wgt_cnt <= 'd0;
    end else begin
      if (i_clr) begin
        r_wgt_cnt <= 'd0;
      end else if (w_pe_act) begin
        if (r_wgt_cnt < PATCH_AREA - 1) begin
          r_wgt_cnt <= r_wgt_cnt + 'd1;
        end else begin
          r_wgt_cnt <= 'd0;
        end
      end
    end
  end
  // ====================== module ========================= 
  patch #(
      .INPUT_BITS  (INPUT_BITS),
      .PATCH_WIDTH (PATCH_WIDTH),
      .PATCH_HEIGHT(PATCH_HEIGHT),
      .LINE_WIDTH  (LINE_WIDTH),
      .LINE_HEIGHT (LINE_HEIGHT)
  ) inst_patch_rsc (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_clr     (i_clr),
      // ipt
      .i_ipt_din (i_ipt_din),
      .i_ipt_vld (i_ipt_vld),
      .o_ipt_rdy (o_ipt_rdy),
      // opt
      .i_opt_rdy (i_opt_rdy),
      .o_opt_vld (w_ptch_vld),
      .o_opt_dout(w_ptch_dat)
  );
  pe #(
      .INPUT_BITS  (INPUT_BITS),
      .WEIGHT_BITS (WEIGHT_BITS),
      .PATCH_WIDTH (PATCH_WIDTH),
      .PATCH_HEIGHT(PATCH_HEIGHT)
  ) inst_pe_rsc (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_pe_en   (w_pe_act),
      // wgt 
      .i_wgt_din (r_wgt_dat[r_wgt_cnt]),
      // ipt  
      .i_ipt_vld (w_ptch_vld),
      .i_ipt_din (w_ptch_dat),
      // opt  
      .o_opt_vld (o_opt_vld),
      .o_opt_dout(o_opt_dout)
  );
  //      ____        _                      
  //     | __ )  __ _| | __ _ _ __   ___ ___ 
  //     |  _ \ / _` | |/ _` | '_ \ / __/ _ \
  //     | |_) | (_| | | (_| | | | | (_|  __/
  //     |____/ \__,_|_|\__,_|_| |_|\___\___|
  //                                         
`elsif BALANCE    
  // ====================== wire =========================== 
  wire                                         w_ptch_vld;
  wire signed [                INPUT_BITS-1:0] w_ptch_dat     [0:PATCH_HEIGHT-1];
  wire        [  INPUT_BITS *PATCH_HEIGHT-1:0] w_ptch_dat_pck;
  wire                                         w_pe_act;
  wire        [              PATCH_HEIGHT-1:0] w_pe_vld;    
  wire signed [             PE_OUT_BITS-1:0] w_pe_dat       [0:PATCH_HEIGHT-1];
  wire        [PE_OUT_BITS*PATCH_HEIGHT-1:0] w_pe_dat_pck;    
  wire                                         w_mat_rdy;
  // ====================== reg ============================ 
  reg         [        $clog2(PATCH_AREA)-1:0] r_wgt_cnt;
  reg signed  [               WEIGHT_BITS-1:0] r_wgt_dat      [  0:PATCH_AREA-1];
  // ====================== hand shake =====================  
  assign w_pe_act = w_ptch_vld && w_mat_rdy;
  // ====================== always =========================  
  // initialize weight data
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      for (i = 0; i < PATCH_AREA; i = i + 1) begin
        r_wgt_dat[i] <= 'd0;
      end
    end else if (i_wgt_vld) begin
      for (i = 0; i < PATCH_AREA - 1; i = i + 1) begin
        r_wgt_dat[i] <= r_wgt_dat[i+1];
      end
      r_wgt_dat[PATCH_AREA-1] <= i_wgt_din;
    end
  end
  // weigt counter 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_wgt_cnt <= 'd0;
    end else begin
      if (i_clr) begin
        r_wgt_cnt <= 'd0;
      end else if (w_pe_act) begin
        if (r_wgt_cnt < PATCH_WIDTH - 1) begin
          r_wgt_cnt <= r_wgt_cnt + 'd1;
        end else begin
          r_wgt_cnt <= 'd0;
        end
      end
    end
  end
  // ====================== Unpack / Pack ================== 
  generate
    for (p = 0; p < PATCH_HEIGHT; p = p + 1) begin
      assign w_ptch_dat[p] = w_ptch_dat_pck[p*INPUT_BITS+:INPUT_BITS];
      assign w_pe_dat_pck[p*PE_OUT_BITS+:PE_OUT_BITS] = w_pe_dat[p];
    end
  endgenerate
  // ====================== module ========================= 
  patch #(
      .INPUT_BITS  (INPUT_BITS),
      .PATCH_WIDTH (PATCH_WIDTH),
      .PATCH_HEIGHT(PATCH_HEIGHT),
      .LINE_WIDTH  (LINE_WIDTH),
      .LINE_HEIGHT (LINE_HEIGHT)
  ) inst_patch_bal (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_clr     (i_clr),
      // ipt
      .i_ipt_din (i_ipt_din),
      .i_ipt_vld (i_ipt_vld),
      .o_ipt_rdy (o_ipt_rdy),
      // opt
      .i_opt_rdy (w_mat_rdy),
      .o_opt_vld (w_ptch_vld),
      .o_opt_dout(w_ptch_dat_pck)
  );
  generate
    for (p = 0; p < PATCH_HEIGHT; p = p + 1) begin : pe_array
      pe_bal #(
          .INPUT_BITS  (INPUT_BITS),
          .WEIGHT_BITS (WEIGHT_BITS),
          .OUTPUT_BITS (PE_OUT_BITS),
          .PATCH_WIDTH (PATCH_WIDTH),
          .PATCH_HEIGHT(PATCH_HEIGHT)
      ) inst_pe (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .i_pe_en   (w_pe_act),
          // wgt 
          .i_wgt_din (r_wgt_dat[p*PATCH_WIDTH+r_wgt_cnt]),
          // ipt  
          .i_ipt_vld (w_ptch_vld),
          .i_ipt_din (w_ptch_dat[p]),
          // opt  
          .o_opt_vld (w_pe_vld[p]),
          .o_opt_dout(w_pe_dat[p])
      );
    end
  endgenerate
  adder_tree #(
      .INPUT_BIT(PE_OUT_BITS),
      .INPUT_NUM(PATCH_HEIGHT)
  ) inst_pe_at (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // ipt
      .o_ipt_rdy (w_mat_rdy),
      .i_ipt_vld (w_pe_vld),
      .i_ipt_din (w_pe_dat_pck),
      // opt
      .i_opt_rdy (i_opt_rdy),
      .o_opt_vld (o_opt_vld),
      .o_opt_dout(o_opt_dout)
  );                                                   
`elsif PERFORMANCE
  //      ____            __                                           
  //     |  _ \ ___ _ __ / _| ___  _ __ _ __ ___   __ _ _ __   ___ ___ 
  //     | |_) / _ \ '__| |_ / _ \| '__| '_ ` _ \ / _` | '_ \ / __/ _ \
  //     |  __/  __/ |  |  _| (_) | |  | | | | | | (_| | | | | (_|  __/
  //     |_|   \___|_|  |_|  \___/|_|  |_| |_| |_|\__,_|_| |_|\___\___|
  //                
  wire                                       w_ptch_vld;
  wire signed [              INPUT_BITS-1:0] w_ptch_dat     [0:PATCH_AREA-1];
  wire        [  INPUT_BITS *PATCH_AREA-1:0] w_ptch_dat_pck;
  wire                                       w_pe_act;
  wire                                       w_pe_rdy;
  wire signed [           PE_OUT_BITS-1:0] w_pe_dat           [0:PATCH_AREA-1];
  wire        [PE_OUT_BITS*PATCH_AREA-1:0] w_pe_dat_pck;
  wire        [              PATCH_AREA-1:0] w_mat_ipt_vld;
  wire                                       w_mat_rdy;
  // ====================== reg ============================    
  reg         [        $clog2(PATCH_AREA)-1:0] r_wgt_cnt;
  reg signed  [               WEIGHT_BITS-1:0] r_wgt_dat      [  0:PATCH_AREA-1]; 
  reg         [        $clog2(PATCH_AREA):0] r_pe_cnt;
  reg                                        r_pe_vld;
  // ====================== hand shake =====================  
  assign w_pe_rdy      = w_mat_rdy || !r_pe_vld;
  assign w_pe_act      = w_ptch_vld && w_pe_rdy;
  // ====================== assign ========================= 
  assign w_mat_ipt_vld = (r_pe_vld) ? {PATCH_AREA{1'b1}} : 'd0;
  // ====================== always ========================= 
  // initialize weight data
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      for (i = 0; i < PATCH_AREA; i = i + 1) begin
        r_wgt_dat[i] <= 'd0;
      end
    end else if (i_wgt_vld) begin
      for (i = 0; i < PATCH_AREA - 1; i = i + 1) begin
        r_wgt_dat[i] <= r_wgt_dat[i+1];
      end
      r_wgt_dat[PATCH_AREA-1] <= i_wgt_din;
    end
  end 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_pe_vld <= 'd0;
    end else if (w_pe_rdy) begin
      r_pe_vld <= w_ptch_vld;
    end
  end
  // ====================== Unpack / Pack ================== 
  generate
    for (p = 0; p < PATCH_AREA; p = p + 1) begin
      // patch
      assign w_ptch_dat[p] = w_ptch_dat_pck[p*INPUT_BITS+:INPUT_BITS];
      // pe 
      assign w_pe_dat_pck[p*PE_OUT_BITS+:PE_OUT_BITS] = w_pe_dat[p];
    end
  endgenerate
  // ====================== module ========================= 
  patch #(
      .INPUT_BITS  (INPUT_BITS),
      .PATCH_WIDTH (PATCH_WIDTH),
      .PATCH_HEIGHT(PATCH_HEIGHT),
      .LINE_WIDTH  (LINE_WIDTH),
      .LINE_HEIGHT (LINE_HEIGHT)
  ) inst_patch_perf (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_clr     (i_clr),
      // ipt
      .i_ipt_din (i_ipt_din),
      .i_ipt_vld (i_ipt_vld),
      .o_ipt_rdy (o_ipt_rdy),
      // opt
      .i_opt_rdy (w_pe_rdy),
      .o_opt_vld (w_ptch_vld),
      .o_opt_dout(w_ptch_dat_pck)
  );
  generate
    for (p = 0; p < PATCH_AREA; p = p + 1) begin : pe_array
      pe #(
          .INPUT_BITS  (INPUT_BITS),
          .WEIGHT_BITS (WEIGHT_BITS), 
          .PATCH_WIDTH (PATCH_WIDTH),
          .PATCH_HEIGHT(PATCH_HEIGHT)
      ) inst_pe (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .i_pe_en   (w_pe_act),
          // wgt  
          .i_wgt_din (r_wgt_dat[p]),
          // ipt  
          .i_ipt_din (w_ptch_dat[p]),
          // opt  
          .o_opt_dout(w_pe_dat[p])
      );
    end
  endgenerate
  adder_tree #(
      .INPUT_BIT(PE_OUT_BITS),
      .INPUT_NUM(PATCH_AREA)
  ) inst_mac_at (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // ipt
      .o_ipt_rdy (w_mat_rdy),
      .i_ipt_vld (w_mat_ipt_vld),
      .i_ipt_din (w_pe_dat_pck),
      // opt
      .i_opt_rdy (i_opt_rdy),
      .o_opt_vld (o_opt_vld),
      .o_opt_dout(o_opt_dout)
  );
`endif

endmodule

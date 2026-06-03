`timescale 1ns / 1ps

`include "defines.vh"
module patch #(
    parameter INPUT_BITS   = 16,
    parameter PATCH_WIDTH  = 3,
    parameter PATCH_HEIGHT = 3,
    parameter LINE_WIDTH   = 5,
    parameter LINE_HEIGHT  = 3,

    localparam PATCH_AREA = PATCH_WIDTH * PATCH_HEIGHT,
    localparam PATCH_SIZE = INPUT_BITS * PATCH_WIDTH * PATCH_HEIGHT,

`ifdef RESOURCE
    localparam PATCH_OUT_BITS = INPUT_BITS,
`elsif BALANCE
    localparam PATCH_OUT_BITS = INPUT_BITS * PATCH_HEIGHT,
`elsif PERFORMANCE
    localparam PATCH_OUT_BITS = INPUT_BITS * PATCH_AREA,
`endif
    localparam DUMMY          = 0
) (
    input                                       i_clk,
    input                                       i_rstn,
    input                                       i_clr,
    // ipt
    input         [INPUT_BITS*PATCH_HEIGHT-1:0] i_ipt_din,
    input                                       i_ipt_vld,
    output                                      o_ipt_rdy,
    // opt
    input                                       i_opt_rdy,
    output                                      o_opt_vld,
    output signed [         PATCH_OUT_BITS-1:0] o_opt_dout
);
  // ====================== parmeter =======================   
  genvar g, h;
  integer i, j;
  // ====================== wire =========================== 
  wire w_act_in = o_ipt_rdy && i_ipt_vld;
  wire w_act_out = i_opt_rdy && o_opt_vld;
  // ====================== reg ============================    
  reg signed [INPUT_BITS-1:0] r_ptch_dat[0:PATCH_HEIGHT-1][0:PATCH_WIDTH-1];
  //      ____                                    
  //     |  _ \ ___  ___  ___  _   _ _ __ ___ ___ 
  //     | |_) / _ \/ __|/ _ \| | | | '__/ __/ _ \
  //     |  _ <  __/\__ \ (_) | |_| | | | (_|  __/
  //     |_| \_\___||___/\___/ \__,_|_|  \___\___|
  //    
`ifdef RESOURCE
  wire signed [INPUT_BITS-1:0] w_ptch_dat_delayed;
  // ====================== reg ============================  
  reg [$clog2(
PATCH_WIDTH
)-1:0] r_pcol;
  reg [$clog2(PATCH_HEIGHT)-1:0] r_prow;
  reg [$clog2(  PATCH_AREA):0] r_fill_cnt;
  reg [$clog2(LINE_WIDTH):0] r_lcol_cnt;
  // ====================== hand shake =====================  
  assign o_ipt_rdy = (r_fill_cnt < PATCH_WIDTH);
  assign o_opt_vld = (r_fill_cnt == PATCH_WIDTH);
  // ====================== always =========================   
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_lcol_cnt <= 'd0;
    end else if (i_clr) begin
      r_lcol_cnt <= 'd0;
    end else if (w_act_in) begin
      if (r_lcol_cnt < LINE_WIDTH) r_lcol_cnt <= r_lcol_cnt + 'd1;
      else r_lcol_cnt <= 'd1;
    end
  end

  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_fill_cnt <= 'd0;
      r_pcol     <= 'd0;
      r_prow     <= 'd0;
    end else if (i_clr) begin
      r_fill_cnt <= 'd0;
      r_pcol     <= 'd0;
      r_prow     <= 'd0;
    end else begin
      if (w_act_in) r_fill_cnt <= r_fill_cnt + 1'b1;
      else if (w_act_out) begin
        if (r_pcol < PATCH_WIDTH - 1) r_pcol <= r_pcol + 1'b1;
        else begin
          if (r_prow < PATCH_HEIGHT - 1) r_prow <= r_prow + 1'b1;
          else begin
            r_prow <= 'd0;
            if (r_lcol_cnt == LINE_WIDTH) r_fill_cnt <= 'd0;
            else r_fill_cnt <= PATCH_WIDTH - 1;
          end
          r_pcol <= 'd0;
        end
      end
    end
  end

  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      for (i = 0; i < PATCH_HEIGHT; i = i + 1) begin
        for (j = 0; j < PATCH_WIDTH; j = j + 1) begin
          r_ptch_dat[i][j] <= 'd0;
        end
      end
    end else begin
      if (w_act_in) begin
        for (i = 0; i < PATCH_HEIGHT; i = i + 1) begin
          for (j = 0; j < PATCH_WIDTH - 1; j = j + 1) begin
            r_ptch_dat[i][j] <= r_ptch_dat[i][j+1];
          end
        end
        for (i = 0; i < PATCH_HEIGHT; i = i + 1) begin
          r_ptch_dat[i][PATCH_WIDTH-1] <= i_ipt_din[i*INPUT_BITS+:INPUT_BITS];
        end
      end else if (w_act_out) begin  // ring shift
        // firs row
        for (i = 0; i < PATCH_WIDTH - 1; i = i + 1) begin
          r_ptch_dat[0][i] <= r_ptch_dat[0][i+1];
        end
        r_ptch_dat[0][PATCH_WIDTH-1] <= r_ptch_dat[1][0];

        // middle row
        for (j = 1; j < PATCH_HEIGHT - 1; j = j + 1) begin
          for (i = 0; i < PATCH_WIDTH - 1; i = i + 1) begin
            r_ptch_dat[j][i] <= r_ptch_dat[j][i+1];
          end
          r_ptch_dat[j][PATCH_WIDTH-1] <= r_ptch_dat[j+1][0];
        end

        // last row
        for (i = 0; i < PATCH_WIDTH - 1; i = i + 1) begin
          r_ptch_dat[PATCH_HEIGHT-1][i] <= r_ptch_dat[PATCH_HEIGHT-1][i+1];
        end
        r_ptch_dat[PATCH_HEIGHT-1][PATCH_WIDTH-1] <= r_ptch_dat[0][0];
      end
    end
  end
  // ====================== output =========================  
  assign o_opt_dout = r_ptch_dat[0][0];  // MUX -> shift register
`elsif BALANCE
  //      ____        _                      
  //     | __ )  __ _| | __ _ _ __   ___ ___ 
  //     |  _ \ / _` | |/ _` | '_ \ / __/ _ \
  //     | |_) | (_| | | (_| | | | | (_|  __/
  //     |____/ \__,_|_|\__,_|_| |_|\___\___|
  //    

  // ====================== reg ============================   
  reg [$clog2(
PATCH_WIDTH
)-1:0] r_pcol;
  reg [$clog2(  PATCH_WIDTH):0] r_fill_cnt;
  reg [$clog2(LINE_WIDTH):0] r_lcol_cnt;
  // ====================== hand shake ===================== 
  assign o_ipt_rdy = (r_fill_cnt < PATCH_WIDTH || r_pcol == PATCH_WIDTH - 1);
  assign o_opt_vld = (r_fill_cnt == PATCH_WIDTH);
  // ====================== always =========================  
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_lcol_cnt <= 'd0;
    end else if (i_clr) begin
      r_lcol_cnt <= 'd0;
    end else if (w_act_in) begin
      if (r_lcol_cnt < LINE_WIDTH) r_lcol_cnt <= r_lcol_cnt + 'd1;
      else r_lcol_cnt <= 'd1;
    end
  end
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_fill_cnt <= 'd0;
      r_pcol <= 'd0;
    end else if (i_clr) begin
      r_fill_cnt <= 'd0;
      r_pcol <= 'd0;
    end else begin
      case ({
        w_act_out, w_act_in
      })
        2'b01:   r_fill_cnt <= r_fill_cnt + 1'b1;
        2'b10: begin
          if (r_pcol < PATCH_WIDTH - 1) begin
            r_pcol <= r_pcol + 1'b1;
          end else begin
            r_pcol <= 'd0;
            if (r_lcol_cnt == LINE_WIDTH) r_fill_cnt <= 'd0;
            else r_fill_cnt <= PATCH_WIDTH - 1;
          end
        end
        2'b11: begin
          if (r_pcol < PATCH_WIDTH - 1) begin
            r_pcol     <= r_pcol + 1'b1;
            r_fill_cnt <= r_fill_cnt + 'd1;
          end else begin
            r_pcol <= 'd0;
            if (r_lcol_cnt == LINE_WIDTH) r_fill_cnt <= 'd1;
            else r_fill_cnt <= PATCH_WIDTH;
          end
        end
        default: ;
      endcase
    end
  end
  // patch buffer
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      for (i = 0; i < PATCH_HEIGHT; i = i + 1) begin
        for (j = 0; j < PATCH_WIDTH; j = j + 1) begin
          r_ptch_dat[i][j] <= 'd0;
        end
      end
    end else begin
      case ({
        w_act_out, w_act_in
      })
        2'b01: begin
          for (i = 0; i < PATCH_HEIGHT; i = i + 1) begin
            // shift
            for (j = 0; j < PATCH_WIDTH - 1; j = j + 1) begin
              r_ptch_dat[i][j] <= r_ptch_dat[i][j+1];
            end
            // push
            r_ptch_dat[i][PATCH_WIDTH-1] <= i_ipt_din[i*INPUT_BITS+:INPUT_BITS];
          end
        end
        2'b10: begin
          for (i = 0; i < PATCH_HEIGHT; i = i + 1) begin
            // shift
            for (j = 0; j < PATCH_WIDTH - 1; j = j + 1) begin
              r_ptch_dat[i][j] <= r_ptch_dat[i][j+1];
            end
            r_ptch_dat[i][PATCH_WIDTH-1] <= r_ptch_dat[i][0];
          end
        end
        2'b11: begin
          for (i = 0; i < PATCH_HEIGHT; i = i + 1) begin
            // TODO : 파라미터화 필요
            r_ptch_dat[i][0] <= r_ptch_dat[i][PATCH_WIDTH-1];
            r_ptch_dat[i][1] <= r_ptch_dat[i][0];
            // push
            r_ptch_dat[i][PATCH_WIDTH-1] <= i_ipt_din[i*INPUT_BITS+:INPUT_BITS];
          end
        end
        default: ;
      endcase
    end
  end
  // ====================== output ========================= 
  generate
    for (g = 0; g < PATCH_HEIGHT; g = g + 1) begin
      assign o_opt_dout[g*INPUT_BITS+:INPUT_BITS] = r_ptch_dat[g][0];
    end
  endgenerate

  //      ____            __                                           
  //     |  _ \ ___ _ __ / _| ___  _ __ _ __ ___   __ _ _ __   ___ ___ 
  //     | |_) / _ \ '__| |_ / _ \| '__| '_ ` _ \ / _` | '_ \ / __/ _ \
  //     |  __/  __/ |  |  _| (_) | |  | | | | | | (_| | | | | (_|  __/
  //     |_|   \___|_|  |_|  \___/|_|  |_| |_| |_|\__,_|_| |_|\___\___|
  //  
`elsif PERFORMANCE
  // ====================== reg ============================    
  reg [$clog2(LINE_WIDTH)-1:0] r_ptch_cnt;
  reg                          r_opt_vld;
  // ====================== hand shake =====================    
  assign o_ipt_rdy = i_opt_rdy;
  assign o_opt_vld = r_opt_vld;
  // ====================== always =========================  

  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_ptch_cnt <= 'd0;
    end else begin
      if (i_clr) begin
        r_ptch_cnt <= 'd0;
      end else if (w_act_in) begin
        if (r_ptch_cnt < LINE_WIDTH - 1) r_ptch_cnt <= r_ptch_cnt + 'd1;
        else r_ptch_cnt <= 'd0;
      end
    end
  end
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_vld <= 1'b0;
      for (i = 0; i < PATCH_HEIGHT; i = i + 1) begin
        for (j = 0; j < PATCH_WIDTH; j = j + 1) begin
          r_ptch_dat[i][j] <= 'd0;
        end
      end
    end else begin
      if (o_ipt_rdy) begin
        if (i_ipt_vld) begin
          r_opt_vld <= (r_ptch_cnt >= PATCH_WIDTH - 1);
        end else begin
          r_opt_vld <= 1'b0;
        end
      end

      if (w_act_in) begin
        for (i = 0; i < PATCH_HEIGHT; i = i + 1) begin
          for (j = 0; j < PATCH_WIDTH - 1; j = j + 1) begin
            r_ptch_dat[i][j] <= r_ptch_dat[i][j+1];
          end
        end
        for (i = 0; i < PATCH_HEIGHT; i = i + 1) begin
          r_ptch_dat[i][PATCH_WIDTH-1] <= i_ipt_din[i*INPUT_BITS+:INPUT_BITS];
        end
      end
    end
  end

  // ====================== Unpack / Pack ==================

  generate
    for (g = 0; g < PATCH_HEIGHT; g = g + 1) begin
      for (h = 0; h < PATCH_WIDTH; h = h + 1) begin
        assign o_opt_dout[(g*PATCH_WIDTH+h)*INPUT_BITS+:INPUT_BITS] = r_ptch_dat[g][h];
      end
    end
  endgenerate
`endif
endmodule

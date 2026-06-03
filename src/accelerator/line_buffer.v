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

`include "defines.vh"
module line_buffer #(
    parameter IMAGE_NUM    = 1,
    parameter PADDING_EN   = 1,
    parameter INPUT_BITS   = 16,
    parameter IMAGE_WIDTH  = 5,
    parameter IMAGE_HEIGHT = 5,
    parameter PATCH_WIDTH  = 3,
    parameter PATCH_HEIGHT = 3,

    localparam LINE_WIDTH  = IMAGE_WIDTH + 2,
    localparam LINE_HEIGHT = 3,
    localparam FMAP_WIDTH  = IMAGE_WIDTH + 2,
    localparam FMAP_HEIGHT = IMAGE_HEIGHT + 2,
    localparam FMAP_DEPTH  = FMAP_WIDTH * FMAP_HEIGHT,
    localparam FMAP_AREA   = FMAP_HEIGHT * FMAP_WIDTH,
    localparam PATCH_SIZE  = INPUT_BITS * PATCH_WIDTH * PATCH_HEIGHT
) (
    input                                            i_clk,
    input                                            i_rstn,
    input                                            i_st,
    // ipt
    input  signed [                  INPUT_BITS-1:0] i_ipt_din,
    input                                            i_ipt_vld,
    output                                           o_ipt_rdy,
    // opt
    input                                            i_opt_rdy,
    output                                           o_opt_vld,
    output        [INPUT_BITS * PATCH_HEIGHT  - 1:0] o_opt_dout
);
  // ====================== parmeter ======================= 
  // FSM
  localparam LB_IDLE = 3'd0;
  localparam LB_ENTER_LINE = 31'b1;
  localparam LB_DONE = 3'd2;
  // delay
  localparam PATCH_EN_DLY = 3;
  localparam PROW_DLY = 3;

  integer i, j;
  genvar g, h;
  // ====================== hand shake ===================== 
  // ====================== wire ===========================
  // hand shake 
  wire                                      w_act;
  // ipt
  wire signed [             INPUT_BITS-1:0] w_ipt_dat;
  // feature map
  wire                                      w_pad_en;
  // line buffer
  wire                                      w_lbuf_we    [ 0:LINE_HEIGHT-1];
  wire                                      w_lbuf_vld   [ 0:LINE_HEIGHT-1];
  wire signed [             INPUT_BITS-1:0] w_lbuf_dat   [ 0:LINE_HEIGHT-1];
  // skid buffer
  wire        [            LINE_HEIGHT-1:0] w_sbuf_rdy;
  wire        [            LINE_HEIGHT-1:0] w_sbuf_vld;
  wire signed [             INPUT_BITS-1:0] w_sbuf_dat   [ 0:LINE_HEIGHT-1];
  // patch 
  // opt 
  // ====================== reg ============================ 
  reg         [                        1:0] r_lbuf_cstat;
  reg         [                        1:0] r_lbuf_nstat;
  // feature map 
  reg         [$clog2(FMAP_HEIGHT) - 1 : 0] r_frow;
  reg         [ $clog2(FMAP_WIDTH) - 1 : 0] r_fcol;
  // line buffer   
  reg         [ $clog2(LINE_WIDTH) - 1 : 0] r_lbuf_raddr [ 0:LINE_HEIGHT-1];
  reg                                       r_lbuf_re;
  reg         [$clog2(LINE_HEIGHT) - 1 : 0] r_lbuf_sel;
  reg         [ $clog2(LINE_WIDTH) - 1 : 0] r_lbuf_waddr [ 0:LINE_HEIGHT-1];
  //  
  reg         [     $clog2(FMAP_WIDTH)-1:0] r_ptch_cnt;
  reg         [   $clog2(PATCH_HEIGHT)-1:0] r_ptch_row;
  reg         [             INPUT_BITS-1:0] r_ptch_align [0:PATCH_HEIGHT-1];
  reg         [           PATCH_HEIGHT-1:0] r_ptch_vld;
  // ====================== hand shake ===================== 
  assign o_ipt_rdy = w_sbuf_rdy[0] && !w_pad_en;
  assign w_act = w_sbuf_rdy[0] && (i_ipt_vld || w_pad_en);
  // ====================== assign =========================
  // ipt
  assign w_ipt_dat = (w_pad_en) ? 'd0 : i_ipt_din;
  // feature map    
  assign w_pad_en = (PADDING_EN) 
                 && (r_frow == 0 || (r_frow == FMAP_HEIGHT - 1)   
                 || r_fcol == 0 ||  (r_fcol == FMAP_WIDTH - 1));
  // ====================== always =========================  
  // 패치 정렬 카운터 (ptch_cnt 변수명 모호함)
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_ptch_cnt <= 'd0;
      r_ptch_row <= 'd0;
    end else if (i_st) begin
      r_ptch_cnt <= 'd0;
      r_ptch_row <= 'd0;
    end else if (i_opt_rdy && w_sbuf_vld[0]) begin
      if (r_ptch_cnt < FMAP_WIDTH - 1) r_ptch_cnt <= r_ptch_cnt + 'd1;
      else begin
        r_ptch_cnt <= 'd0;
        if (r_ptch_row < PATCH_HEIGHT - 1) r_ptch_row <= r_ptch_row + 'd1;
        else r_ptch_row <= 'd0;
      end
    end
  end

  // 패치 데이터 재정렬 / TODO : 파라미터화 필요
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_ptch_vld    <= 1'b0;
      r_ptch_align[0] <= 'd0;
      r_ptch_align[1] <= 'd0;
      r_ptch_align[2] <= 'd0;
    end else begin
      if (i_opt_rdy) r_ptch_vld <= w_sbuf_vld;
      if (i_opt_rdy && w_sbuf_vld[0])
        case (r_ptch_row)
          'd0: begin
            r_ptch_align[0] <= w_sbuf_dat[0];
            r_ptch_align[1] <= w_sbuf_dat[1];
            r_ptch_align[2] <= w_sbuf_dat[2];
          end
          'd1: begin
            r_ptch_align[0] <= w_sbuf_dat[1];
            r_ptch_align[1] <= w_sbuf_dat[2];
            r_ptch_align[2] <= w_sbuf_dat[0];
          end
          default: begin
            r_ptch_align[0] <= w_sbuf_dat[2];
            r_ptch_align[1] <= w_sbuf_dat[0];
            r_ptch_align[2] <= w_sbuf_dat[1];
          end
        endcase
    end
  end
  // ====================== FSM ============================    

  //  initialize and update state register
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_lbuf_cstat <= LB_IDLE;
    end else begin
      r_lbuf_cstat <= r_lbuf_nstat;
    end
  end
  // compute next state 
  always @(*) begin
    r_lbuf_nstat = r_lbuf_cstat;
    case (r_lbuf_cstat)
      LB_IDLE: if (i_st) r_lbuf_nstat = LB_ENTER_LINE;

      LB_ENTER_LINE:
      if (w_act && r_frow == FMAP_HEIGHT - 1 && r_fcol == FMAP_WIDTH - 1) r_lbuf_nstat = LB_DONE;

      LB_DONE: r_lbuf_nstat = LB_IDLE;

      default: ;
    endcase
  end
  //  compute RTL operations
  // TODO : 현재 쓰기 신호 wire -> reg 변경필요, 주소 카운터 추가 필요
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_frow    <= 'd0;
      r_fcol    <= 'd0;
      r_lbuf_re <= 'd0;
      r_lbuf_sel    <= 'd0;
      for (i = 0; i < LINE_HEIGHT; i = i + 1) begin
        r_lbuf_waddr[i] <= 'd0;
        r_lbuf_raddr[i] <= 'd0;
      end
    end else begin
      case (r_lbuf_cstat)
        LB_IDLE: begin
          r_frow    <= 'd0;
          r_fcol    <= 'd0;
          r_lbuf_sel    <= 'd0;
          for (i = 0; i < LINE_HEIGHT; i = i + 1) begin
            r_lbuf_waddr[i] <= 'd0;
            r_lbuf_raddr[i] <= 'd0;
          end
        end
        LB_ENTER_LINE: begin
          if (w_act) begin
            // 특징맵 카운트
            if (r_fcol < FMAP_WIDTH - 1) r_fcol <= r_fcol + 1'b1;
            else begin
              r_fcol <= 'd0;
              if (r_frow < FMAP_HEIGHT - 1) r_frow <= r_frow + 1'b1;
              else r_frow <= 'd0;
            end
            // LINE BUFFER 읽기/쓰기 주소 카운트
            if (r_lbuf_waddr[0] < LINE_WIDTH - 1) begin
              for (i = 0; i < LINE_HEIGHT; i = i + 1) begin
                r_lbuf_waddr[i] <= r_lbuf_waddr[i] + 'd1;
              end
            end else begin
              for (i = 0; i < LINE_HEIGHT; i = i + 1) begin
                r_lbuf_waddr[i] <= 'd0;
              end
              if (r_lbuf_sel < LINE_HEIGHT - 1) r_lbuf_sel <= r_lbuf_sel + 1'b1;
              else r_lbuf_sel <= 'd0;
            end
            if ('d2 <= r_frow) r_lbuf_re <= 1'b1;
            for (i = 0; i < LINE_HEIGHT; i = i + 1) r_lbuf_raddr[i] <= r_lbuf_waddr[i];

          end else r_lbuf_re <= 'b0;  // w_act = 0일때 읽기 신호 내림(중복읽기 방지)
        end
        LB_DONE: begin
          r_lbuf_re <= 'b0;
        end
        default: ;
      endcase
    end
  end
  // ====================== Unpack / Pack ==================
  // ====================== module ========================= 
  generate
    for (g = 0; g < LINE_HEIGHT; g = g + 1) begin : line_buf
      assign w_lbuf_we[g] = (w_act && (g == r_lbuf_sel));
      simple_dual_port_ram #(
          .WIDTH   (INPUT_BITS),
          .DEPTH   (LINE_WIDTH),
          .MEM_TYPE(`LUT_TYPE)
      ) inst_line_buf (
          .i_clk  (i_clk),
          .i_rstn (i_rstn),
          .i_re   (r_lbuf_re),
          .i_raddr(r_lbuf_raddr[g]),
          .i_we   (w_lbuf_we[g]),
          .i_waddr(r_lbuf_waddr[g]), // 주소 0부터 
          .i_wdin (w_ipt_dat),
          .o_vld  (w_lbuf_vld[g]),
          .o_dout (w_lbuf_dat[g])
      );
      skid_buffer #(
          .BITS   (INPUT_BITS),
          .LATENCY(3),
          .MEM_SKID(1)
      ) inst_skid_buffer (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .i_ipt_vld (w_lbuf_vld[g]),
          .i_ipt_din (w_lbuf_dat[g]),
          .o_ipt_rdy (w_sbuf_rdy[g]),
          .i_opt_rdy (i_opt_rdy),
          .o_opt_dout(w_sbuf_dat[g]),
          .o_opt_vld (w_sbuf_vld[g])
      );
    end
  endgenerate
  // ====================== output ========================= 
  generate
    for (g = 0; g < LINE_HEIGHT; g = g + 1) begin
      assign o_opt_dout[g*INPUT_BITS+:INPUT_BITS] = r_ptch_align[g];
    end
  endgenerate
  assign o_opt_vld = r_ptch_vld[0];  // 동시 작업이므로 LUT 최소화
endmodule

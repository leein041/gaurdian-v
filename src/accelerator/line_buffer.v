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
  localparam LB_ENTER_LINE = 3'd1;
  localparam LB_DONE = 3'd2;

  integer i, j;
  genvar g, h;
  // ====================== hand shake ===================== 
  // ====================== wire ===========================
  // hand shake  
  wire                                      w_act_in;
  wire                                      w_act_out;
  // ipt
  wire                                      w_pad_vld;
  wire signed [             INPUT_BITS-1:0] w_ipt_dat;
  // line buffer
  wire                                      w_lbuf_we      [ 0:LINE_HEIGHT-1];
  wire                                      w_lbuf_vld     [ 0:LINE_HEIGHT-1];
  wire signed [             INPUT_BITS-1:0] w_lbuf_dat     [ 0:LINE_HEIGHT-1];
  // skid buffer
  wire        [            LINE_HEIGHT-1:0] w_sbuf_rdy;
  wire        [            LINE_HEIGHT-1:0] w_sbuf_vld;
  wire signed [             INPUT_BITS-1:0] w_sbuf_dat     [ 0:LINE_HEIGHT-1];
  // patch 
  // opt 
  // ====================== reg ============================ 
  //ipt data
  reg signed  [             INPUT_BITS-1:0] r_ipt_dat;
  // line buffer
  reg         [                        1:0] r_lbuf_cstat;
  reg         [                        1:0] r_lbuf_nstat;
  // 
  reg         [$clog2(FMAP_HEIGHT) - 1 : 0] r_wpos_row;
  reg         [$clog2(LINE_HEIGHT) - 1 : 0] r_wpos_row_idx;
  reg         [ $clog2(FMAP_WIDTH) - 1 : 0] r_wpos_col;
  reg         [$clog2(FMAP_HEIGHT) - 1 : 0] r_rpos_row;
  reg         [ $clog2(FMAP_WIDTH) - 1 : 0] r_rpos_col;
  // line buffer   

  // read
  reg                                       r_lbuf_re;
  reg         [ $clog2(LINE_WIDTH) - 1 : 0] r_lbuf_raddr;
  reg         [ $clog2(FMAP_DEPTH) - 1 : 0] r_lbuf_rcnt;
  // write
  reg                                       r_lbuf_we;
  reg         [    $clog2(LINE_HEIGHT) : 0] r_lbuf_widx;
  reg         [ $clog2(LINE_WIDTH) - 1 : 0] r_lbuf_waddr;
  reg         [ $clog2(FMAP_DEPTH) - 1 : 0] r_lbuf_wcnt;

  //  
  reg         [     $clog2(FMAP_WIDTH)-1:0] r_opt_cnt;
  reg         [   $clog2(PATCH_HEIGHT)-1:0] r_ptch_row_idx;
  reg         [             INPUT_BITS-1:0] r_opt_dat      [0:PATCH_HEIGHT-1];
  reg         [           PATCH_HEIGHT-1:0] r_opt_vld;
  // ====================== hand shake ===================== 
  assign o_ipt_rdy = w_sbuf_rdy[0] && !w_pad_vld;

  assign w_act_in = w_pad_vld || (o_ipt_rdy && i_ipt_vld);
  assign w_act_out = w_sbuf_rdy[0];
  // ====================== assign ========================= 
  assign w_pad_vld =(r_wpos_row == 0 || (r_wpos_row == FMAP_HEIGHT - 1)   
                  || r_wpos_col == 0 ||  (r_wpos_col == FMAP_WIDTH - 1));
  assign w_ipt_dat = (w_pad_vld) ? 'd0 : i_ipt_din;
  // ====================== always =========================
  // count output index
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_opt_cnt      <= 'd0;
      r_ptch_row_idx <= 'd0;
    end else if (i_st) begin
      r_opt_cnt      <= 'd0;
      r_ptch_row_idx <= 'd0;
    end else if (w_sbuf_vld[0] && i_opt_rdy) begin
      if (r_opt_cnt < LINE_WIDTH - 1) r_opt_cnt <= r_opt_cnt + 'd1;
      else begin
        r_opt_cnt <= 'd0;
        // circulate patch row index ( 012 -> 120 -> 201 -> 012 -> ..)
        if (r_ptch_row_idx < PATCH_HEIGHT - 1) r_ptch_row_idx <= r_ptch_row_idx + 'd1;
        else r_ptch_row_idx <= 'd0;
      end
    end
  end
  // align data for patch
  always @(*) begin
    if (i_opt_rdy) r_opt_vld = w_sbuf_vld;
    if (i_opt_rdy && w_sbuf_vld[0])
      case (r_ptch_row_idx)
        'd0: begin
          r_opt_dat[0] = w_sbuf_dat[0];
          r_opt_dat[1] = w_sbuf_dat[1];
          r_opt_dat[2] = w_sbuf_dat[2];
        end
        'd1: begin
          r_opt_dat[0] = w_sbuf_dat[1];
          r_opt_dat[1] = w_sbuf_dat[2];
          r_opt_dat[2] = w_sbuf_dat[0];
        end
        default: begin
          r_opt_dat[0] = w_sbuf_dat[2];
          r_opt_dat[1] = w_sbuf_dat[0];
          r_opt_dat[2] = w_sbuf_dat[1];
        end
      endcase
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

      LB_ENTER_LINE: if (r_lbuf_rcnt == FMAP_DEPTH) r_lbuf_nstat = LB_DONE;

      LB_DONE: r_lbuf_nstat = LB_IDLE;

      default: ;
    endcase
  end
  //  compute RTL operations
  // TODO : 현재 쓰기 신호 wire -> reg 변경필요, 주소 카운터 추가 필요
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_ipt_dat      <= 'd0;
      r_rpos_row     <= 'd0;
      r_rpos_col     <= 'd0;
      r_wpos_row     <= 'd0;
      r_wpos_row_idx <= 'd0;
      r_wpos_col     <= 'd0;
      r_lbuf_we      <= 'd0;
      r_lbuf_widx    <= 'd1;
      r_lbuf_waddr   <= 'd0;
      r_lbuf_wcnt    <= 'd0;
      r_lbuf_re      <= 'd0;
      r_lbuf_raddr   <= 'd0;
      r_lbuf_rcnt    <= 2 * LINE_WIDTH;
      r_ptch_row_idx <= 'd0;
    end else begin
      case (r_lbuf_cstat)
        LB_IDLE: begin
          r_ipt_dat      <= 'd0;
          r_rpos_row     <= 'd0;
          r_rpos_col     <= 'd0;
          r_wpos_row     <= 'd0;
          r_wpos_row_idx <= 'd0;
          r_wpos_col     <= 'd0;
          r_lbuf_we      <= 'd0;
          r_lbuf_widx    <= 'd1;
          r_lbuf_waddr   <= 'd0;
          r_lbuf_wcnt    <= 'd0;
          r_lbuf_re      <= 'd0;
          r_lbuf_raddr   <= 'd0;
          r_lbuf_rcnt    <= 2 * LINE_WIDTH;
          r_ptch_row_idx <= 'd0;
        end
        LB_ENTER_LINE: begin

          // act in
          if (w_act_in) begin
            r_ipt_dat    <= w_ipt_dat;
            r_lbuf_we    <= 'b1;
            r_lbuf_waddr <= r_wpos_col;
            r_lbuf_widx  <= r_wpos_row_idx;

            // counting write position
            if (r_lbuf_wcnt < FMAP_DEPTH) begin
              r_lbuf_wcnt <= r_lbuf_wcnt + 'd1;

              // update write col position
              if (r_wpos_col < FMAP_WIDTH - 1) r_wpos_col <= r_wpos_col + 1'b1;
              else begin
                // update write row position
                if (r_wpos_row < FMAP_HEIGHT - 1) begin
                  r_wpos_col <= 'd0;
                  r_wpos_row <= r_wpos_row + 1'b1;
                end

                // update write position row index
                if (r_wpos_row_idx < LINE_HEIGHT - 1) r_wpos_row_idx <= r_wpos_row_idx + 1'b1;
                else r_wpos_row_idx <= 'd0;
              end
            end
          end else r_lbuf_we <= 'b0;

          // act out
          if (w_act_out) begin
            // counting line buffer read address  
            if (r_lbuf_rcnt < r_lbuf_wcnt) begin
              r_lbuf_re    <= 1'b1;
              r_lbuf_raddr <= r_rpos_col;

              // counting read position
              if (r_lbuf_rcnt < FMAP_DEPTH) begin
                r_lbuf_rcnt <= r_lbuf_rcnt + 'd1;

                // update read col position
                if (r_rpos_col < FMAP_WIDTH - 1) r_rpos_col <= r_rpos_col + 1'b1;
                else begin
                  // update read row position
                  if (r_rpos_row < FMAP_HEIGHT - 1) begin
                    r_rpos_col <= 'd0;
                    r_rpos_row <= r_rpos_row + 1'b1;
                  end

                end
              end

            end else r_lbuf_re <= 1'b0;

          end else r_lbuf_re <= 1'b0;
        end
      endcase
    end
  end

  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin

    end else begin

    end
  end 
  // ====================== module ========================= 
  generate
    for (g = 0; g < LINE_HEIGHT; g = g + 1) begin : line_buf
      assign w_lbuf_we[g] = (r_lbuf_we && (g == r_lbuf_widx));
      simple_dual_port_ram #(
          .WIDTH   (INPUT_BITS),
          .DEPTH   (LINE_WIDTH),
          .MEM_TYPE(`LUT_TYPE)
      ) inst_line_buf (
          .i_clk  (i_clk),
          .i_rstn (i_rstn),
          .i_re   (r_lbuf_re),
          .i_raddr(r_lbuf_raddr),
          .i_we   (w_lbuf_we[g]),
          .i_waddr(r_lbuf_waddr), // 주소 0부터 
          .i_wdin (r_ipt_dat),
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
      assign o_opt_dout[g*INPUT_BITS+:INPUT_BITS] = r_opt_dat[g];
    end
  endgenerate
  assign o_opt_vld = r_opt_vld[0];  // 동시 작업이므로 LUT 최소화
endmodule

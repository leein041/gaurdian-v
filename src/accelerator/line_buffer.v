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

// 3줄짜리 버퍼. 첫번째 2줄 채워지고 3줄부터는 3개씩 PATCH로 데이터 전달
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
  wire                                      w_lbuf_we    [0:LINE_HEIGHT-1];
  wire                                      w_lbuf_vld   [0:LINE_HEIGHT-1];
  wire signed [             INPUT_BITS-1:0] w_lbuf_dat   [0:LINE_HEIGHT-1];
  // skid buffer
  wire        [            LINE_HEIGHT-1:0] w_sbuf_rdy;
  wire        [            LINE_HEIGHT-1:0] w_sbuf_vld;
  wire signed [             INPUT_BITS-1:0] w_sbuf_dat   [0:LINE_HEIGHT-1];
  // patch 
  // opt 
  // ====================== reg ============================ 
  reg         [                        1:0] r_lbuf_cstat;
  reg         [                        1:0] r_lbuf_nstat;
  // feature map 
  reg         [$clog2(FMAP_HEIGHT) - 1 : 0] r_frow;
  reg         [ $clog2(FMAP_WIDTH) - 1 : 0] r_fcol;
  // line buffer   
  reg         [ $clog2(LINE_WIDTH) - 1 : 0] r_lbuf_raddr;
  reg                                       r_lbuf_re;
  reg         [$clog2(LINE_HEIGHT) - 1 : 0] r_lbuf_sel;
  reg         [ $clog2(LINE_WIDTH) - 1 : 0] r_lbuf_waddr;
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
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_frow    <= 'd0;
      r_fcol    <= 'd0;
      r_lbuf_re <= 'd0;
      r_lbuf_sel    <= 'd0;
      r_lbuf_waddr    <= 'd0;
      r_lbuf_raddr    <= 'd0;
    end else begin
      case (r_lbuf_cstat)
        LB_IDLE: begin
          r_frow    <= 'd0;
          r_fcol    <= 'd0;
          r_lbuf_sel    <= 'd0;
          r_lbuf_waddr    <= 'd0;
          r_lbuf_raddr    <= 'd0;
        end
        LB_ENTER_LINE: begin
          if (w_act) begin
            if (r_fcol < FMAP_WIDTH - 1) r_fcol <= r_fcol + 1'b1;
            else begin
              r_fcol <= 'd0;
              if (r_frow < FMAP_HEIGHT - 1) r_frow <= r_frow + 1'b1;
              else r_frow <= 'd0;
            end
            // LINE BUFFER 카운트
            if (r_lbuf_waddr < LINE_WIDTH - 1) r_lbuf_waddr <= r_lbuf_waddr + 1'b1;
            else begin
              r_lbuf_waddr <= 'd0;
              if (r_lbuf_sel < LINE_HEIGHT - 1) r_lbuf_sel <= r_lbuf_sel + 1'b1;
              else r_lbuf_sel <= 'd0;
            end

            if ('d2 <= r_frow) r_lbuf_re <= 1'b1;
            r_lbuf_raddr <= r_lbuf_waddr;

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
          .WIDTH(INPUT_BITS),
          .DEPTH(LINE_WIDTH)
      ) inst_line_buf (
          .i_clk  (i_clk),
          .i_rstn (i_rstn),
          .i_re   (r_lbuf_re),
          .i_raddr(r_lbuf_raddr),
          .i_we   (w_lbuf_we[g]),
          .i_waddr(r_lbuf_waddr), // 주소 0부터 
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
      assign o_opt_dout[g*INPUT_BITS+:INPUT_BITS] = w_sbuf_dat[g];
    end
  endgenerate
  assign o_opt_vld = w_sbuf_vld[0];  // 동시 작업이므로 LUT 최소화
endmodule

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

// trade off 고려
// 1. 입력 버퍼만 가지고 있기 -> 슬라이딩 완료후에 입력버퍼 업데이트
// 2. 입력, 출력 버퍼 가지고 있기 -> 슬라이딩 하면서 입력버퍼 업데이트
module line_buffer #(
    parameter PADDING_EN    = 0,
    parameter RELU_EN       = 0,
    parameter CHANNEL_NUM   = 1,
    parameter FMAP_WIDTH    = 5,
    parameter FMAP_HEIGHT   = 5,
    parameter INPUT_BITS    = 16,
    parameter INPUT_WIDTH   = 5,
    parameter INPUT_HEIGHT  = 5,
    parameter WEIGHT_BITS   = 16,
    parameter WEIGHT_WIDTH  = 3,
    parameter WEIGHT_HEIGHT = 3,
    parameter OUTPUT_BITS   = 32,
    parameter OUTPUT_WIDTH  = 3,
    parameter OUTPUT_HEIGHT = 3,
    parameter LINE_WIDTH    = 5,
    parameter LINE_HEIGHT   = 3,
    parameter PATCH_WIDTH   = 3,
    parameter PATCH_HEIGHT  = 3,

    localparam FMAP_AREA   = FMAP_HEIGHT * FMAP_WIDTH,
    localparam PATCH_SIZE  = INPUT_BITS * PATCH_WIDTH * PATCH_HEIGHT,
    localparam WEIGHT_ADDR = $clog2(WEIGHT_WIDTH * WEIGHT_HEIGHT * CHANNEL_NUM),
    localparam INPUT_ADDR  = $clog2(INPUT_WIDTH * INPUT_HEIGHT * CHANNEL_NUM),
    localparam OUTPUT_ADDR = $clog2(OUTPUT_WIDTH * OUTPUT_HEIGHT * CHANNEL_NUM)
) (
    input                                     i_clk,
    input                                     i_rstn,
    // ipt
    input  [                  INPUT_BITS-1:0] i_ipt_din,
    input                                     i_ipt_vld,
    output                                    o_ipt_rdy,
    // opt
    input                                     i_opt_rdy,
    output                                    o_opt_vld,
    output [INPUT_BITS * PATCH_HEIGHT  - 1:0] o_opt_dout,
    // etc
    output                                    o_ptch_en
);
  // ------------------- parmeter -------------------  
  // FSM
  localparam LB_IDLE = 3'd0;
  localparam LB_ENTER_LINEx2 = 3'd1;
  localparam LB_ENTER_LINE = 3'd2;
  localparam LB_WAIT = 3'd3;
  // delay
  localparam PATCH_EN_DLY = 3;
  localparam PROW_DLY = 3;

  integer i, j;
  genvar g, h;
  // ------------------ hand shake ------------------- 
  // --------------------- wire ---------------------    

  // debug
  wire                               dbg_stv = o_ipt_rdy && (!i_ipt_vld);
  wire                               dbg_bpss = !i_opt_rdy && o_opt_vld;
  // hand shake
  wire                               w_act;
  // ipt
  wire [             INPUT_BITS-1:0] w_ipt_dat;
  // feature map
  wire                               w_pad_en;
  // line buffer
  wire                               w_lbuf_we                                [ 0:LINE_HEIGHT-1];
  wire                               w_lbuf_vld                               [ 0:LINE_HEIGHT-1];
  wire [             INPUT_BITS-1:0] w_lbuf_dat                               [ 0:LINE_HEIGHT-1];
  // skid buffer
  wire                               w_sbuf_vld                               [ 0:LINE_HEIGHT-1];
  wire [             INPUT_BITS-1:0] w_sbuf_dat                               [ 0:LINE_HEIGHT-1];
  // patch
  wire                               w_prow_en;  // patch row cycle enable
  wire                               w_ptch_en;  // is 3x3 valid  // ? 
  // ------------------------- reg -------------------------  
  // opt
  reg  [            0:LINE_HEIGHT-1] r_opt_vld;
  reg  [             INPUT_BITS-1:0] r_opt_dat                                [ 0:LINE_HEIGHT-1];
  // feature map
  reg                                r_fmap_dn;
  reg  [$clog2(FMAP_HEIGHT) - 1 : 0] r_frow;  // feature row
  reg  [ $clog2(FMAP_WIDTH) - 1 : 0] r_fcol;  // feature col 
  // patch
  reg  [           PATCH_EN_DLY-1:0] r_ptch_edly;
  reg  [               PROW_DLY-1:0] r_prow_edly;
  reg  [$clog2(LINE_HEIGHT) - 1 : 0] r_prow                                   [0:PATCH_HEIGHT-1];
  reg  [ $clog2(LINE_WIDTH) - 1 : 0] r_pcol;  // patch col   
  // line buffer
  reg  [                        1:0] r_lbuf_cstat;
  reg  [                        1:0] r_lbuf_nstat;
  reg                                r_lbuf_re;  // 라인버퍼 읽기 신호
  reg  [$clog2(LINE_HEIGHT) - 1 : 0] r_lrow;  // line row
  reg  [ $clog2(LINE_WIDTH) - 1 : 0] r_lcol;  // line col  
  // ------------------------ assign -----------------------   
  assign o_ipt_rdy = (i_opt_rdy || !o_opt_vld) && !w_pad_en;  // 받을 준비 조건
  assign w_act = (o_ipt_rdy && i_ipt_vld) || w_pad_en;
  // ipt
  assign w_ipt_dat = (w_pad_en || (RELU_EN && i_ipt_din[INPUT_BITS-1])) ? 'd0 : i_ipt_din;
  assign o_opt_vld = &r_opt_vld;
  // feature map  
  assign w_pad_en = (PADDING_EN) && (r_frow == 0 || r_frow == FMAP_HEIGHT - 1  || r_fcol == 0 || r_fcol == FMAP_WIDTH - 1);
  // patch
  assign o_ptch_en = o_opt_vld && r_ptch_edly[PATCH_EN_DLY-1];
  assign w_prow_en = (r_pcol == LINE_WIDTH - 1);
  assign w_ptch_en = (PATCH_WIDTH - 1 <= r_pcol);

  // ------------------------ always ----------------------- 
  // output
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      for (i = 0; i < LINE_HEIGHT; i = i + 1) begin
        r_opt_vld[i] <= 'd0;
        r_opt_dat[i] <= 'd0;
      end
    end else if (o_ipt_rdy || w_pad_en) begin  // 내가 받을 준비가 되었거나 패딩 넣을때
      for (i = 0; i < LINE_HEIGHT; i = i + 1) begin
        r_opt_vld[i] <= w_sbuf_vld[i];
        if (w_sbuf_vld[i]) begin
          r_opt_dat[i] <= w_sbuf_dat[i];
        end
      end
    end
  end
  // feature map update
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_frow    <= 'd0;
      r_fcol    <= 'd0;
      r_fmap_dn <= 'd0;
    end else if (w_act) begin  // 최적화 필요  
      if (r_fcol < FMAP_WIDTH - 1) begin
        r_fcol <= r_fcol + 'd1;
      end else begin
        r_fcol <= 'd0;
        if (r_frow < FMAP_HEIGHT - 1) r_frow <= r_frow + 'd1;
        else begin
          r_frow    <= 'd0;
          r_fmap_dn <= 'd1;
        end
      end
    end
  end

  // line buffer update
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_lrow <= 'd0;
      r_lcol <= 'd0;
    end else if (w_act) begin
      // 라인 행/열 업데이트
      if (r_lcol < LINE_WIDTH - 1) begin
        r_lcol <= r_lcol + 'd1;
      end else begin
        r_lcol <= 'd0;
        if (r_lrow < LINE_HEIGHT - 1) r_lrow <= r_lrow + 'd1;
        else r_lrow <= 'd0;
      end
    end
  end
  // ------------------------- FSM -------------------------    
  //  initialize and update state register
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_lbuf_cstat <= LB_IDLE;
    end else if (w_act) begin
      r_lbuf_cstat <= r_lbuf_nstat;
    end
  end
  // compute next state 
  always @(*) begin
    r_lbuf_nstat = r_lbuf_cstat;
    case (r_lbuf_cstat)
      LB_IDLE: begin
        if (i_ipt_vld) r_lbuf_nstat = LB_ENTER_LINEx2;
      end
      LB_ENTER_LINEx2: begin
        if (1 < r_lrow) begin
          r_lbuf_nstat = LB_ENTER_LINE;
        end
      end
      LB_ENTER_LINE: begin
        if (r_fmap_dn) r_lbuf_nstat = LB_WAIT;
      end
      LB_WAIT: ;
      default: ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_lbuf_re <= 'd0;
      r_pcol    <= 'd0;
      r_prow[0] <= 'd0;
      r_prow[1] <= 'd1;
      r_prow[2] <= 'd2;
    end else begin
      if (w_act) begin
        case (r_lbuf_nstat)
          LB_IDLE:;
          LB_ENTER_LINEx2: ;
          LB_ENTER_LINE: begin  // 패치 데이터가 나가기 까지 2클럭 타이밍 주의
            r_lbuf_re <= 1'b1;  // 3번쨰 라인버퍼부터는 항상 읽기 
            r_pcol    <= r_lcol;  // 패치 열은 라인버퍼 열 뒤에 따라옴   
            if (r_prow_edly[PROW_DLY-1]) begin
              r_prow[0] <= r_prow[1];
              r_prow[1] <= r_prow[2];
              r_prow[2] <= r_prow[0];
            end
          end
          LB_WAIT: begin
            r_pcol <= 'd0;
          end
          default: ;
        endcase
      end else begin  // w_act =0, stall 상태
        r_lbuf_re <= 'd0;  // 메모리 중복 읽기를 방지 읽기 신호는 0
      end
    end
  end
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_ptch_edly <= 'd0;
    end else begin
      if (w_act) begin
        r_prow_edly <= {r_prow_edly[PROW_DLY-2:0], w_prow_en};
      end
    end
  end
  // delay 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_prow_edly <= 'd0;
    end else begin
      // skid buffer 는 출력 방향만 hand shake 이므로, 출력단에 들어오는 ready 신호만 확인한다.
      if (i_opt_rdy) begin
        r_ptch_edly <= {r_ptch_edly[PATCH_EN_DLY-2:0], w_ptch_en};
      end
    end
  end
  // ------------------- Unpack / Pack -------------------  
  generate
    for (g = 0; g < LINE_HEIGHT; g = g + 1) begin
      assign o_opt_dout[g*INPUT_BITS+:INPUT_BITS] = r_opt_dat[r_prow[g]];
    end
  endgenerate
  // ------------------------- module ----------------------  
  generate
    for (g = 0; g < PATCH_HEIGHT; g = g + 1) begin : line_buf
      assign w_lbuf_we[g] = (w_act && (g == r_lrow));
      simple_dual_port_bram #(
          .WIDTH(INPUT_BITS),
          .DEPTH(LINE_WIDTH)
      ) inst_line_buf (
          .i_clk  (i_clk),
          .i_rstn (i_rstn),
          .i_re   (r_lbuf_re),
          .i_raddr(r_pcol),
          .i_we   (w_lbuf_we[g]),
          .i_waddr(r_lcol), // 주소 0부터 
          .i_wdin (w_ipt_dat),
          .o_vld  (w_lbuf_vld[g]),
          .o_dout (w_lbuf_dat[g])
      );
      skid_buffer #(
          .INPUT_BITS(INPUT_BITS),
          .CHANNEL_NUM(1),  // 채널 안이므로
          .MEM_LATENCY(1)
      ) inst_skid_buffer (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .i_ipt_vld (w_lbuf_vld[g]),
          .i_ipt_din (w_lbuf_dat[g]),
          .o_ipt_rdy (),
          .i_opt_rdy (i_opt_rdy),
          .o_opt_dout(w_sbuf_dat[g]),
          .o_opt_vld (w_sbuf_vld[g])
      );
    end
  endgenerate


endmodule

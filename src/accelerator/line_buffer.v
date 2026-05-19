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
    parameter PADDING_EN   = 0,
    parameter FMAP_WIDTH   = 5,
    parameter FMAP_HEIGHT  = 5,
    parameter FMAP_DEPTH   = 7 * 7 * 3,
    parameter INPUT_BITS   = 16,
    parameter INPUT_WIDTH  = 5,
    parameter INPUT_HEIGHT = 5,
    parameter LINE_WIDTH   = 5,
    parameter LINE_HEIGHT  = 3,
    parameter PATCH_WIDTH  = 3,
    parameter PATCH_HEIGHT = 3,

    localparam FMAP_AREA  = FMAP_HEIGHT * FMAP_WIDTH,
    localparam PATCH_SIZE = INPUT_BITS * PATCH_WIDTH * PATCH_HEIGHT
) (
    input                                            i_clk,
    input                                            i_rstn,
    // ipt
    input  signed [                  INPUT_BITS-1:0] i_ipt_din,
    input                                            i_ipt_vld,
    output                                           o_ipt_rdy,
    // opt
    input                                            i_opt_rdy,
    output                                           o_opt_vld,
    output        [INPUT_BITS * PATCH_HEIGHT  - 1:0] o_opt_dout
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
  // hand shake
  wire                                      w_dat_vld;
  wire                                      w_act;
  // ipt
  wire signed [             INPUT_BITS-1:0] w_ipt_dat;
  // feature map
  wire                                      w_pad_en;
  // line buffer
  wire                                      w_lbuf_we        [0:LINE_HEIGHT-1];
  wire                                      w_lbuf_vld       [0:LINE_HEIGHT-1];
  wire signed [             INPUT_BITS-1:0] w_lbuf_dat       [0:LINE_HEIGHT-1];
  // skid buffer
  wire        [            LINE_HEIGHT-1:0] w_sbuf_rdy_pck;
  wire                                      w_sbuf_all_rdy;
  wire                                      w_sbuf_vld       [0:LINE_HEIGHT-1];
  wire        [            LINE_HEIGHT-1:0] w_sbuf_vld_pck;
  wire signed [             INPUT_BITS-1:0] w_sbuf_dat       [0:LINE_HEIGHT-1];
  // patch
  wire                                      w_prow_en;  //   
  // opt 
  // ------------------------- reg -------------------------   
  // feature map
  reg                                       r_fmap_dn;
  reg         [$clog2(FMAP_HEIGHT) - 1 : 0] r_frow;
  reg         [ $clog2(FMAP_WIDTH) - 1 : 0] r_fcol;
  // patch      
  reg         [ $clog2(LINE_WIDTH) - 1 : 0] r_pcol;
  // line buffer
  reg         [                        1:0] r_lbuf_cstat;
  reg         [                        1:0] r_lbuf_nstat;
  reg                                       r_lbuf_re;
  reg         [$clog2(LINE_HEIGHT) - 1 : 0] r_lrow;
  reg         [ $clog2(LINE_WIDTH) - 1 : 0] r_lcol;
  // ---------------------- hand shake --------------------- 
  assign o_ipt_rdy = (w_sbuf_all_rdy) && !w_pad_en;
  assign w_act = w_sbuf_all_rdy && w_dat_vld;
  // ------------------------ assign -----------------------   
  assign w_sbuf_all_rdy = &w_sbuf_rdy_pck;
  assign w_dat_vld = i_ipt_vld || w_pad_en;
  // ipt
  assign w_ipt_dat = (w_pad_en) ? 'd0 : i_ipt_din;
  // feature map  
  assign w_pad_en = !r_fmap_dn
                 && (PADDING_EN) 
                 && (r_frow == 0 || r_frow == FMAP_HEIGHT - 1  
                 || r_fcol == 0 || r_fcol == FMAP_WIDTH - 1);
  // patch
  assign w_prow_en = (r_pcol == LINE_WIDTH - 1);
  // ------------------------ always -----------------------  
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
        if (r_lrow == 'd1 && (r_lcol == LINE_WIDTH - 1) && w_act) begin
          r_lbuf_nstat = LB_ENTER_LINE;
        end
      end
      LB_ENTER_LINE: begin
        if (r_fmap_dn) r_lbuf_nstat = LB_WAIT;
      end
      LB_WAIT: begin
        r_lbuf_nstat = LB_IDLE;
      end
      default: ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_frow    <= 'd0;
      r_fcol    <= 'd0;
      r_fmap_dn <= 'd0;
      r_lbuf_re <= 'd0;
      r_lrow    <= 'd0;
      r_lcol    <= 'd0;
      r_pcol    <= 'd0;
    end else begin
      if (w_act) begin
        case (r_lbuf_cstat)
          LB_IDLE: ;
          LB_ENTER_LINEx2, LB_ENTER_LINE: begin
            if (r_lbuf_cstat == LB_ENTER_LINE) begin
              r_lbuf_re <= 1'b1;
              r_pcol    <= r_lcol; // 읽기 주소 쓰기 주소를 1클럭 뒤 따라감
            end
            // 특징맵(패딩넣은 맵) 업데이트
            if (r_fcol < FMAP_WIDTH - 1) begin
              r_fcol <= r_fcol + 'd1;
            end else begin
              r_fcol <= 'd0;
              if (r_frow < FMAP_HEIGHT - 1) begin
                r_frow <= r_frow + 'd1;
              end else begin
                r_frow    <= 'd0;
                r_fmap_dn <= 'd1;
              end
            end
            // 라인버퍼 업데이트
            if (r_lcol < LINE_WIDTH - 1) begin
              r_lcol <= r_lcol + 'd1;
            end else begin
              r_lcol <= 'd0;
              if (r_lrow < LINE_HEIGHT - 1) r_lrow <= r_lrow + 'd1;
              else r_lrow <= 'd0;
            end

          end
          LB_WAIT: begin
            r_lbuf_re <= 'b0;
            r_pcol    <= 'd0;
          end
          default: ;
        endcase
      end else begin  // w_act =0, stall 상태
        r_lbuf_re <= 'd0;  // 메모리 중복 읽기를 방지 읽기 신호는 0
      end
    end
  end
  // ------------------- Unpack / Pack -------------------  
  generate
    for (g = 0; g < LINE_HEIGHT; g = g + 1) begin
      assign w_sbuf_vld_pck[g] = w_sbuf_vld[g];
    end
  endgenerate
  // ------------------------- module ----------------------  
  generate
    for (g = 0; g < LINE_HEIGHT; g = g + 1) begin : line_buf
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
          .BITS   (INPUT_BITS),
          .LATENCY(3),
          .MEM_SKID(1)
      ) inst_skid_buffer (
          .i_clk     (i_clk),
          .i_rstn    (i_rstn),
          .i_ipt_vld (w_lbuf_vld[g]),
          .i_ipt_din (w_lbuf_dat[g]),
          .o_ipt_rdy (w_sbuf_rdy_pck[g]),
          .i_opt_rdy (i_opt_rdy),
          .o_opt_dout(w_sbuf_dat[g]),
          .o_opt_vld (w_sbuf_vld[g])
      );
    end
  endgenerate

  // ------------------------- output ----------------------  
  for (g = 0; g < LINE_HEIGHT; g = g + 1) begin
    assign o_opt_dout[g*INPUT_BITS+:INPUT_BITS] = w_sbuf_dat[g];
  end
  assign o_opt_vld = &w_sbuf_vld_pck;
endmodule

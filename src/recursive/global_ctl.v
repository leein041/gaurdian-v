
`include "defines.vh"
// 글로벌 컨트롤러는 입력 버퍼(이미지) 주소값을 쏴줌. 입력버퍼 데이터값은 바로 첫번째 레이어로 들어감 
module stline_global_ctrl #(
    parameter  MAX_CHANNEL = 8,
    parameter  BITS        = 16,
    parameter  ACT_DEPTH   = 150 * 150,
    parameter  IMAGE_DEPTH = 150 * 150 * 3,
    localparam ACT_ADDR    = $clog2(ACT_DEPTH),
    localparam IMAGE_ADDR  = $clog2(IMAGE_DEPTH)
) (
    input                         i_clk,
    input                         i_rstn,
    input                         i_st,
    output                        o_ctrl_rdy,
    // input mem  
    output                        o_ibuf_re,
    output [      IMAGE_ADDR-1:0] o_ibuf_raddr,
    // act buffer  
    output                        o_abuf_re,
    output [        ACT_ADDR-1:0] o_abuf_raddr,
    output                        o_abuf_we,
    output [        ACT_ADDR-1:0] o_abuf_waddr,
    output [BITS*MAX_CHANNEL-1:0] o_abuf_wdout,
    // skid buffer
    input                         i_skid_rdy,
    // layer   
    input                         i_lyr_wrdn,
    input                         i_lyr_vld,
    input  [BITS*MAX_CHANNEL-1:0] i_lyr_din,
    output                        o_lyr_wst,
    output                        o_lyr_relu_en,
    // opt mem  
    output                        o_obuf_we,
    output [      IMAGE_ADDR-1:0] o_obuf_addr,
    output [              BITS:0] o_obuf_dout,
    output                        o_done          // what is this
);
// ====================== parmeter ======================= 
  localparam IDLE = 4'd0;
  localparam LOAD_WEIGHT_1 = 4'd1;
  localparam ACT_1 = 4'd2;  // load image and write layer 1 output at act buffer
  localparam LOAD_WEIGHT_2 = 4'd3;
  localparam ACT_2 = 4'd4;  // load layer 1 output and write layer 2 output at act buffer
  localparam LOAD_WEIGHT_3 = 4'd5;
  localparam ACT_3 = 4'd6;  // load layer 2 output and layer 3 output(end) 
  localparam DONE = 4'd7;
// ====================== wire ===========================
  wire                        w_all_wgtdn;
// ====================== reg ============================ 
  reg  [                 3:0] r_lp_cstat;  // current state
  reg  [                 3:0] r_lp_nstat;  // next state   
  // ctrl
  reg                         r_ctrl_rdy;
  // ipt 
  reg                         r_ibuf_re;
  reg  [      IMAGE_ADDR-1:0] r_ibuf_raddr;
  reg  [      IMAGE_ADDR-1:0] r_ibuf_cnt;
  // act
  reg                         r_abuf_re;
  reg  [        ACT_ADDR-1:0] r_abuf_raddr;
  reg  [        ACT_ADDR-1:0] r_abuf_rcnt;
  reg  [        ACT_ADDR-1:0] r_abuf_wcnt;
  reg                         r_abuf_we;
  reg  [        ACT_ADDR-1:0] r_abuf_waddr;
  reg  [BITS*MAX_CHANNEL-1:0] r_abuf_wdat;
  // layer
  reg                         r_lyr_wst;
  reg                         r_lyr_relu_en;
  // opt  
  reg                         r_o_done;
  reg                         r_obuf_we;
  reg  [      IMAGE_ADDR-1:0] r_obuf_wcnt;
  reg  [      IMAGE_ADDR-1:0] r_obuf_waddr;
  reg  [              BITS:0] r_obuf_wdat;

// ====================== assign ========================= 
  assign o_ctrl_rdy    = r_ctrl_rdy;
  // ipt
  assign o_ibuf_re     = r_ibuf_re;
  assign o_ibuf_raddr  = r_ibuf_raddr;
  // act
  assign o_abuf_re     = r_abuf_re;
  assign o_abuf_raddr  = r_abuf_raddr;
  assign o_abuf_we     = r_abuf_we;
  assign o_abuf_waddr  = r_abuf_waddr;
  assign o_abuf_wdout  = r_abuf_wdat;
  // layer
  assign o_lyr_wst     = r_lyr_wst;
  assign o_lyr_relu_en = r_lyr_relu_en;
  // opt  
  assign o_obuf_we     = r_obuf_we;
  assign o_obuf_addr   = r_obuf_waddr;
  assign o_obuf_dout   = r_obuf_wdat;
  assign o_done        = r_o_done;
// ====================== always ========================= 

  //  initialize and update state register
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_lp_cstat <= IDLE;
    end else if (i_skid_rdy) begin
      r_lp_cstat <= r_lp_nstat;
    end
  end
  // compute next state 
  always @(*) begin
    r_lp_nstat = r_lp_cstat;
    case (r_lp_cstat)
      IDLE: begin
        if (i_st) begin
          r_lp_nstat <= LOAD_WEIGHT_1;
        end
      end
      LOAD_WEIGHT_1: if (i_lyr_wrdn) r_lp_nstat = ACT_1;
      ACT_1:         if (r_abuf_wcnt == ACT_DEPTH) r_lp_nstat = LOAD_WEIGHT_2;
      LOAD_WEIGHT_2: if (i_lyr_wrdn) r_lp_nstat = ACT_2;
      ACT_2:         if (r_abuf_wcnt == ACT_DEPTH) r_lp_nstat = LOAD_WEIGHT_3;
      LOAD_WEIGHT_3: if (i_lyr_wrdn) r_lp_nstat = ACT_3;
      ACT_3:         if (r_obuf_wcnt == ACT_DEPTH) r_lp_nstat = DONE;
      DONE:          r_lp_nstat = IDLE;
      default:       ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_ctrl_rdy    <= 'b0;
      r_ibuf_re     <= 'd0;
      r_ibuf_raddr  <= {IMAGE_ADDR{1'b1}};
      r_ibuf_cnt    <= 'd0;
      r_abuf_re     <= 'd0;
      r_abuf_raddr  <= {ACT_ADDR{1'b1}};
      r_abuf_we     <= 'd0;
      r_abuf_waddr  <= {ACT_ADDR{1'b1}};
      r_abuf_rcnt   <= 'd0;
      r_abuf_wcnt   <= 'd0;
      r_abuf_wdat   <= 'd0;
      r_lyr_wst     <= 'b0;
      r_lyr_relu_en <= 'b0;
      r_obuf_we     <= 'd0;
      r_obuf_waddr  <= {IMAGE_ADDR{1'b1}};
      r_obuf_wcnt   <= 'd0;
      r_obuf_wdat   <= 'd0;
      r_o_done      <= 'd0;
    end else begin
      r_ctrl_rdy    <= 'b1;  // 일단 항상 받기
      r_lyr_wst     <= 'b0;
      r_lyr_relu_en <= 'b0;
      r_ibuf_re     <= 'b0;
      r_abuf_re     <= 'b0;
      r_abuf_we     <= 'd0;
      r_obuf_we     <= 'b0;
      r_o_done      <= 'd0;
      case (r_lp_cstat)
        IDLE: begin
          r_ibuf_raddr <= {IMAGE_ADDR{1'b1}};
          if (i_st) r_lyr_wst <= 'b1;
        end
        LOAD_WEIGHT_1, LOAD_WEIGHT_2, LOAD_WEIGHT_3: begin
          r_ibuf_cnt   <= 'd0;
          r_abuf_rcnt  <= 'd0;
          r_abuf_wcnt  <= 'd0;
          r_abuf_raddr <= {ACT_ADDR{1'b1}};
          r_abuf_waddr <= {ACT_ADDR{1'b1}};
        end
        ACT_1, ACT_2, ACT_3: begin

          if (r_lp_cstat == ACT_1) begin  // image -> layer 1
            if (i_skid_rdy && (r_ibuf_cnt < IMAGE_DEPTH)) begin
              r_ibuf_re    <= 'd1;
              r_ibuf_cnt   <= r_ibuf_cnt + 'd1;
              r_ibuf_raddr <= r_ibuf_raddr + 'd1;
            end
          end else begin  // act -> layer 2 / layer 3
            if (i_skid_rdy && (r_abuf_rcnt < ACT_DEPTH)) begin
              r_abuf_re    <= 'd1;
              r_abuf_rcnt   <= r_abuf_rcnt + 'd1;
              r_abuf_raddr <= r_abuf_raddr + 'd1;
            end
          end

          if (i_lyr_vld) begin  // layer 1/2 -> act buffer
            r_abuf_we    <= 'd1;
            r_abuf_wcnt  <= r_abuf_wcnt + 'd1;
            r_abuf_waddr <= r_abuf_waddr + 'd1;
            r_abuf_wdat  <= i_lyr_din;
          end
          // weight load start when act buffer write done
          if (r_abuf_waddr == ACT_DEPTH - 1) r_lyr_wst <= 'b1;

          // layer 1/2 relu enable
          if (r_lp_cstat == ACT_1 || r_lp_cstat == ACT_2) begin
            r_lyr_relu_en <= 'b1;
            if (i_lyr_vld) begin
              r_abuf_we    <= 'd1;
              r_abuf_wcnt  <= r_abuf_wcnt + 'd1;
              r_abuf_waddr <= r_abuf_waddr + 'd1;
              r_abuf_wdat  <= i_lyr_din;
            end
          end
          // layer 3 output(end)
          if (r_obuf_waddr == IMAGE_DEPTH - 1) r_o_done <= 1'b1;
          if (r_lp_cstat == ACT_3) begin
            if (i_lyr_vld) begin
              r_obuf_we    <= 'd1;
              r_obuf_wcnt  <= r_obuf_wcnt + 'd1;
              r_obuf_waddr <= r_abuf_waddr + 'd1;
              r_obuf_wdat  <= i_lyr_din;
            end
          end
        end
        DONE:    ;
        default: ;
      endcase
    end
  end

// ====================== module ========================= 
endmodule

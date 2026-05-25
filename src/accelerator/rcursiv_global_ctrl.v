
`include "defines.vh"
// 글로벌 컨트롤러는 입력 버퍼(이미지) 주소값을 쏴줌. 입력버퍼 데이터값은 바로 첫번째 레이어로 들어감 
module rcursiv_global_ctrl #(
    parameter  IMAGE_NUM    = 1,
    parameter  BITS         = 16,
    parameter  INPUT_DEPTH  = 150 * 150 * IMAGE_NUM,
    parameter  IMAGE_DEPTH  = 150 * 150,
    localparam INPUT_ADDR   = $clog2(INPUT_DEPTH),
    localparam IMAGE_ADDR   = $clog2(IMAGE_DEPTH),
    localparam OUTPUT_DEPTH = INPUT_DEPTH,
    localparam OUTPUT_ADDR  = INPUT_ADDR,

    // 
    parameter WEIGHT_BITS     = 16,
    parameter L1_CHANNEL_NUM  = 1,
    parameter L1_FILTER_NUM   = 8,
    parameter L1_WEIGHT_DEPTH = 8 * 9,
    parameter L2_CHANNEL_NUM  = 8,
    parameter L2_FILTER_NUM   = 8,
    parameter L2_WEIGHT_DEPTH = 8 * 9,
    parameter L3_CHANNEL_NUM  = 8,
    parameter L3_FILTER_NUM   = 1,
    parameter L3_WEIGHT_DEPTH = 8 * 1,

    localparam LAYER_NUM = 3,
    localparam MAX_FILTER = `MAX2(L1_FILTER_NUM, `MAX2(L2_FILTER_NUM, L3_FILTER_NUM)),
    localparam MAX_CHANNEL = `MAX2(L1_CHANNEL_NUM, `MAX2(L2_CHANNEL_NUM, L3_CHANNEL_NUM)),
    localparam MAX_WEIGHT_ADDR = $clog2(
        `MAX2(L1_WEIGHT_DEPTH, `MAX2(L2_WEIGHT_DEPTH, L3_WEIGHT_DEPTH))
    )
) (
    input                          i_clk,
    input                          i_rstn,
    input                          i_st,
    output                         o_ctrl_rdy,
    // input buffer
    output                         o_ibuf_re,
    output [       INPUT_ADDR-1:0] o_ibuf_raddr,
    // img buffer  
    output                         o_abuf_re,
    output [       IMAGE_ADDR-1:0] o_abuf_raddr,
    output                         o_abuf_we,
    output [       IMAGE_ADDR-1:0] o_abuf_waddr,
    output [ BITS*MAX_CHANNEL-1:0] o_abuf_wdout,
    // skid buffer
    input                          i_skid_rdy,
    // layer    
    input                          i_lyr_vld,
    input  [ BITS*MAX_CHANNEL-1:0] i_lyr_din,
    output                         o_lyr_wst,
    output                         o_lyr_relu_en,
    // opt mem  
    output                         o_obuf_we,
    output [      OUTPUT_ADDR-1:0] o_obuf_addr,
    output [               BITS:0] o_obuf_dout,
    output                         o_done,
    // temp 
    output [$clog2(MAX_CHANNEL):0] o_ch_num,
    output [ $clog2(MAX_FILTER):0] o_filt_num,
    output [      MAX_CHANNEL-1:0] o_lbuf_st,
    output [                  2:0] o_wgt_re,
    output [  MAX_WEIGHT_ADDR-1:0] o_wgt_raddr,
    output [      MAX_CHANNEL-1:0] o_ipt_mask,
    output [                  2:0] o_bias_sel
);
  // ====================== parmeter ======================= 
  localparam IDLE = 4'd0;
  localparam LOAD_WEIGHT_1 = 4'd1;
  localparam COMPUTE_LAYER_1 = 4'd2;  // load image and write layer 1 output at act buffer
  localparam LOAD_WEIGHT_2 = 4'd3;
  localparam COMPUTE_LAYER_2 = 4'd4;  // load layer 1 output and write layer 2 output at act buffer
  localparam LOAD_WEIGHT_3 = 4'd5;
  localparam COMPUTE_LAYER_3 = 4'd6;  // load layer 2 output and layer 3 output(end) 
  localparam DONE = 4'd7;
  // --------------------- wire ---------------------  
  // ====================== reg ============================ 
  reg [                  3:0] r_cstat;  // current state
  reg [                  3:0] r_nstat;  // next state   
  // ctrl
  reg                         r_ctrl_rdy;
  reg [  $clog2(IMAGE_NUM):0] r_img_cnt;
  // ipt 
  reg                         r_ibuf_re;
  reg [       INPUT_ADDR-1:0] r_ibuf_raddr;
  reg [       INPUT_ADDR-1:0] r_ibuf_rcnt;
  // img
  reg                         r_abuf_re;
  reg [       IMAGE_ADDR-1:0] r_abuf_raddr;
  reg [       IMAGE_ADDR-1:0] r_abuf_rcnt;
  reg [       IMAGE_ADDR-1:0] r_abuf_wcnt;
  reg                         r_abuf_we;
  reg [       IMAGE_ADDR-1:0] r_abuf_waddr;
  reg [ BITS*MAX_CHANNEL-1:0] r_abuf_wdat;
  // layer
  reg                         r_lyr_wst;
  reg                         r_lyr_relu_en;
  // opt  
  reg                         r_o_done;
  reg                         r_obuf_we;
  reg [      OUTPUT_ADDR-1:0] r_obuf_wcnt;
  reg [      OUTPUT_ADDR-1:0] r_obuf_waddr;
  reg [               BITS:0] r_obuf_wdat;

  // new local buffer --------------------------------
  // ipt
  reg [      MAX_CHANNEL-1:0] r_ipt_mask;
  //
  reg [$clog2(MAX_CHANNEL):0] r_cur_ch_num;
  reg [ $clog2(MAX_FILTER):0] r_cur_filt_num;
  reg [    MAX_WEIGHT_ADDR:0] r_cur_wgt_depth;
  reg [      LAYER_NUM-1 : 0] r_wgt_sel;
  // line buffer 
  reg [      MAX_CHANNEL-1:0] r_lbuf_st;
  // wgt
  reg [                  2:0] r_wgt_re;
  reg [  MAX_WEIGHT_ADDR-1:0] r_wgt_raddr;
  reg [  MAX_WEIGHT_ADDR-1:0] r_wgt_rcnt;
  // bias
  reg [                  2:0] r_bias_sel;

  // ipt channel select siganl


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
  // temp
  assign o_ch_num      = r_cur_ch_num;
  assign o_filt_num    = r_cur_filt_num;
  assign o_lbuf_st     = r_lbuf_st;
  assign o_wgt_re      = r_wgt_re;
  assign o_wgt_raddr   = r_wgt_raddr;
  assign o_ipt_mask    = r_ipt_mask;
  assign o_bias_sel    = r_bias_sel;
  // ====================== always ========================= 

  //  initialize and update state register
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_cstat <= IDLE;
    end else begin
      r_cstat <= r_nstat;
    end
  end
  // compute next state 
  always @(*) begin
    r_nstat = r_cstat;
    case (r_cstat)
      IDLE:            if (i_st) r_nstat = LOAD_WEIGHT_1;
      LOAD_WEIGHT_1:   if (L1_WEIGHT_DEPTH <= r_wgt_rcnt && !i_lyr_vld) r_nstat = COMPUTE_LAYER_1;
      COMPUTE_LAYER_1: if (IMAGE_DEPTH <= r_abuf_wcnt) r_nstat = LOAD_WEIGHT_2;
      LOAD_WEIGHT_2:   if (L2_WEIGHT_DEPTH <= r_wgt_rcnt && !i_lyr_vld) r_nstat = COMPUTE_LAYER_2;
      COMPUTE_LAYER_2: if (IMAGE_DEPTH <= r_abuf_wcnt) r_nstat = LOAD_WEIGHT_3;
      LOAD_WEIGHT_3:   if (L3_WEIGHT_DEPTH <= r_wgt_rcnt && !i_lyr_vld) r_nstat = COMPUTE_LAYER_3;
      COMPUTE_LAYER_3: if (IMAGE_DEPTH <= r_obuf_wcnt) r_nstat = DONE;
      DONE: begin
        if (r_img_cnt < IMAGE_NUM - 1) r_nstat = LOAD_WEIGHT_1;
        else r_nstat = IDLE;
      end
      default:         ;
    endcase
  end
  //
  always @(*) begin
    r_cur_ch_num    = 'd0;
    r_cur_filt_num  = 'd0;
    r_cur_wgt_depth = 'd0;
    r_ipt_mask      = 'd0;
    r_wgt_sel       = 3'b000;
    r_bias_sel      = 3'b000;
    case (r_cstat)
      IDLE:    ;
      LOAD_WEIGHT_1, COMPUTE_LAYER_1: begin
        r_cur_ch_num    = L1_CHANNEL_NUM;
        r_cur_filt_num  = L1_FILTER_NUM;
        r_cur_wgt_depth = L1_WEIGHT_DEPTH;
        r_wgt_sel       = 3'b001;
        r_bias_sel      = 3'b001;
        r_ipt_mask <= {{(MAX_CHANNEL - L1_CHANNEL_NUM) {1'b0}}, {L1_CHANNEL_NUM{1'b1}}};
      end
      LOAD_WEIGHT_2, COMPUTE_LAYER_2: begin
        r_cur_ch_num    = L2_CHANNEL_NUM;
        r_cur_filt_num  = L2_FILTER_NUM;
        r_cur_wgt_depth = L2_WEIGHT_DEPTH;
        r_wgt_sel       = 3'b010;
        r_bias_sel      = 3'b010;
        r_ipt_mask <= {{(MAX_CHANNEL - L2_CHANNEL_NUM) {1'b0}}, {L2_CHANNEL_NUM{1'b1}}};

      end
      LOAD_WEIGHT_3, COMPUTE_LAYER_3: begin
        r_cur_ch_num    = L3_CHANNEL_NUM;
        r_cur_filt_num  = L3_FILTER_NUM;
        r_cur_wgt_depth = L3_WEIGHT_DEPTH;
        r_wgt_sel       = 3'b100;
        r_bias_sel      = 3'b100;
        r_ipt_mask <= {{(MAX_CHANNEL - L3_CHANNEL_NUM) {1'b0}}, {L3_CHANNEL_NUM{1'b1}}};
      end
      DONE:    ;
      default: ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_ctrl_rdy    <= 'b0;
      r_img_cnt     <= 'b0;
      r_ibuf_re     <= 'd0;
      r_ibuf_raddr  <= {INPUT_ADDR{1'b1}};
      r_ibuf_rcnt   <= 'd0;
      r_abuf_re     <= 'd0;
      r_abuf_raddr  <= {IMAGE_ADDR{1'b1}};
      r_abuf_we     <= 'd0;
      r_abuf_waddr  <= {IMAGE_ADDR{1'b1}};
      r_abuf_rcnt   <= 'd0;
      r_abuf_wcnt   <= 'd0;
      r_abuf_wdat   <= 'd0;
      r_lyr_wst     <= 'b0;
      r_lyr_relu_en <= 'b0;
      r_obuf_we     <= 'd0;
      r_obuf_waddr  <= {OUTPUT_ADDR{1'b1}};
      r_obuf_wcnt   <= 'd0;
      r_obuf_wdat   <= 'd0;
      r_o_done      <= 'd0;
      // local ctrl
      r_lbuf_st     <= 'd0;
      r_wgt_re      <= 'd0;
      r_wgt_raddr   <= {MAX_WEIGHT_ADDR{1'b1}};
      r_wgt_rcnt    <= 'd0;

    end else begin
      r_ctrl_rdy    <= 'b1;  // 일단 항상 받기 
      r_lyr_wst     <= 'b0;
      r_lyr_relu_en <= 'b0;
      r_ibuf_re     <= 'b0;
      r_abuf_re     <= 'b0;
      r_abuf_we     <= 'd0;
      r_obuf_we     <= 'b0;
      r_o_done      <= 'd0;
      r_lbuf_st     <= 'd0;
      r_wgt_re      <= 'd0;
      case (r_cstat)
        IDLE: begin
          r_ibuf_raddr <= {INPUT_ADDR{1'b1}};
          if (i_st) r_lyr_wst <= 'b1;
        end
        LOAD_WEIGHT_1, LOAD_WEIGHT_2, LOAD_WEIGHT_3: begin
          r_ibuf_rcnt  <= 'd0;
          r_abuf_rcnt  <= 'd0;
          r_abuf_wcnt  <= 'd0;
          r_obuf_wcnt  <= 'd0;
          r_abuf_raddr <= {IMAGE_ADDR{1'b1}};
          r_abuf_waddr <= {IMAGE_ADDR{1'b1}};
          if (r_wgt_rcnt < r_cur_wgt_depth) begin
            r_wgt_re    <= r_wgt_sel;
            r_wgt_rcnt  <= r_wgt_rcnt + 'd1;
            r_wgt_raddr <= r_wgt_raddr + 'd1;
          end else begin
            r_wgt_rcnt  <= 'd0;
            r_wgt_raddr <= {MAX_WEIGHT_ADDR{1'b1}};
            r_lbuf_st   <= {MAX_CHANNEL{1'b1}} >> (MAX_CHANNEL - r_cur_ch_num);
          end
        end

        COMPUTE_LAYER_1, COMPUTE_LAYER_2, COMPUTE_LAYER_3: begin

          if (r_cstat == COMPUTE_LAYER_1) begin  // image -> layer 1
            // 왜 r_ibuf_rcnt < IMAGE_DEPTH ? -> 이미지 3장 나눠서 처리
            if (i_skid_rdy && (r_ibuf_rcnt < IMAGE_DEPTH)) begin
              r_ibuf_re    <= 'd1;
              r_ibuf_rcnt   <= r_ibuf_rcnt + 'd1;
              r_ibuf_raddr <= r_ibuf_raddr + 'd1;
            end
          end else begin  // act -> layer 2 / layer 3
            if (i_skid_rdy && (r_abuf_rcnt < IMAGE_DEPTH)) begin
              r_abuf_re    <= 'd1;
              r_abuf_rcnt  <= r_abuf_rcnt + 'd1;
              r_abuf_raddr <= r_abuf_raddr + 'd1;
            end
          end
          // weight load start when act buffer write done
          if (r_abuf_rcnt == IMAGE_DEPTH) r_lyr_wst <= 'b1;

          // layer 1/2 relu enable
          if (r_cstat == COMPUTE_LAYER_1 || r_cstat == COMPUTE_LAYER_2) begin
            r_lyr_relu_en <= 'b1;
            if (i_lyr_vld) begin
              r_abuf_we    <= 'd1;
              r_abuf_wcnt  <= r_abuf_wcnt + 'd1;
              r_abuf_waddr <= r_abuf_waddr + 'd1;
              r_abuf_wdat  <= i_lyr_din;
            end
          end
          // layer 3 output(end)
          if (r_obuf_wcnt == IMAGE_DEPTH) r_o_done <= 1'b1;
          if (r_cstat == COMPUTE_LAYER_3) begin
            if (i_lyr_vld) begin
              r_obuf_we    <= 'd1;
              r_obuf_wcnt  <= r_obuf_wcnt + 'd1;
              r_obuf_waddr <= r_obuf_waddr + 'd1;
              r_obuf_wdat  <= i_lyr_din;
            end
          end
        end
        DONE: begin
          if (r_img_cnt < IMAGE_NUM) begin
            r_lyr_wst <= 'b1;
            r_img_cnt <= r_img_cnt + 'd1;
          end
        end
        default: ;
      endcase
    end
  end

  // ====================== module ========================= 
endmodule

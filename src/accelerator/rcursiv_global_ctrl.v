
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

    parameter WEIGHT_BITS = 16,

    parameter L1_CHANNEL_NUM      = 1,
    parameter L1_FILTER_NUM       = 8,
    parameter L1_WEIGHT_DEPTH     = 8 * 9,
    parameter L2_CHANNEL_NUM      = 8,
    parameter L2_FILTER_NUM       = 8,
    parameter L2_WEIGHT_DEPTH     = 8 * 9,
    parameter L3_CHANNEL_NUM      = 8,
    parameter L3_FILTER_NUM       = 1,
    parameter L3_WEIGHT_DEPTH     = 8 * 1,
    // 필터 그룹화 개수
    parameter L1_FILTER_GROUP_NUM = 2,
    parameter L2_FILTER_GROUP_NUM = 2,
    parameter L3_FILTER_GROUP_NUM = 1,

    localparam LAYER_NUM = 3,
    localparam MAX_FILTER = `MAX2(L1_FILTER_NUM, `MAX2(L2_FILTER_NUM, L3_FILTER_NUM)),
    localparam MAX_CHANNEL = `MAX2(L1_CHANNEL_NUM, `MAX2(L2_CHANNEL_NUM, L3_CHANNEL_NUM)),
    localparam MAX_WEIGHT_ADDR = $clog2(
        `MAX2(L1_WEIGHT_DEPTH, `MAX2(L2_WEIGHT_DEPTH, L3_WEIGHT_DEPTH))
    ),
    localparam MAX_FILTER_GROUP_NUM =
    `MAX2(L1_FILTER_GROUP_NUM, `MAX2(L2_FILTER_GROUP_NUM, L3_FILTER_GROUP_NUM))
) (
    input                                   i_clk,
    input                                   i_rstn,
    input                                   i_st,
    output                                  o_ctrl_rdy,
    // wegight 
    output                                  o_wgt_re,
    output [           MAX_WEIGHT_ADDR-1:0] o_wgt_raddr,
    output [                 LAYER_NUM-1:0] o_wgt_sel,
    // input buffer
    output                                  o_ibuf_re,
    output [                INPUT_ADDR-1:0] o_ibuf_raddr,
    // img buffer  
    output                                  o_abuf_re,
    output [                IMAGE_ADDR-1:0] o_abuf_raddr,
    output                                  o_abuf_we,
    output [                IMAGE_ADDR-1:0] o_abuf_waddr,
    output [          BITS*MAX_CHANNEL-1:0] o_abuf_wdout,
    // skid buffer
    input                                   i_skid_rdy,
    // layer    
    input                                   i_lyr_vld,
    input  [          BITS*MAX_CHANNEL-1:0] i_lyr_din,
    output                                  o_lyr_relu_en,
    // opt mem  
    output                                  o_obuf_we,
    output [               OUTPUT_ADDR-1:0] o_obuf_addr,
    output [                        BITS:0] o_obuf_dout,
    output                                  o_done,
    // temp 
    output [         $clog2(MAX_CHANNEL):0] o_ch_num,
    output [          $clog2(MAX_FILTER):0] o_filt_num,
    output [               MAX_CHANNEL-1:0] o_lbuf_st,
    output [                           2:0] o_bias_sel,
    // group  
    output [$clog2(MAX_FILTER_GROUP_NUM):0] o_grp_sel,
    output                                  o_abuf_sel,
    //
    output [$clog2(MAX_FILTER_GROUP_NUM):0] o_vld_abuf,     // 유효 이미지 버퍼 개수
    output [          $clog2(MAX_FILTER):0] o_vld_ch        // 이미지 버퍼 내 유효 채널
);
  // ====================== parmeter ======================= 
  localparam IDLE = 4'd0;
  localparam L1_LOAD = 4'd1;
  localparam L1_COMP = 4'd2;  // load image and write layer 1 output at act buffer 

  localparam L2_LOAD = 4'd3;
  localparam L2_COMP = 4'd4;  // load layer 1 output and write layer 2 output at act buffer 

  localparam L3_LOAD = 4'd5;
  localparam L3_COMP = 4'd6;  // load layer 2 output and layer 3 output(end) 

  localparam DONE = 4'd7;

  localparam L1_WGT_DEPTH_GRP = L1_WEIGHT_DEPTH / L1_FILTER_GROUP_NUM;
  localparam L2_WGT_DEPTH_GRP = L2_WEIGHT_DEPTH / L2_FILTER_GROUP_NUM;
  localparam L3_WGT_DEPTH_GRP = L3_WEIGHT_DEPTH / L3_FILTER_GROUP_NUM;
  // --------------------- wire ---------------------  
  // ====================== reg ============================ 
  reg [                           3:0] r_cstat;  // current state
  reg [                           3:0] r_nstat;  // next state   
  // ctrl
  reg                                  r_ctrl_rdy;
  reg [           $clog2(IMAGE_NUM):0] r_img_cnt;
  // weghit
  reg                                  r_wgt_re;
  reg [           MAX_WEIGHT_ADDR-1:0] r_wgt_raddr;
  reg [               LAYER_NUM-1 : 0] r_wgt_sel;
  // ipt 
  reg                                  r_ibuf_re;
  reg [                INPUT_ADDR-1:0] r_ibuf_raddr;
  reg [                INPUT_ADDR-1:0] r_ibuf_rcnt;
  // img
  reg                                  r_abuf_re;
  reg [                IMAGE_ADDR-1:0] r_abuf_raddr;
  reg [                IMAGE_ADDR-1:0] r_abuf_rcnt;
  reg [                IMAGE_ADDR-1:0] r_abuf_wcnt;
  reg                                  r_abuf_we;
  reg [                IMAGE_ADDR-1:0] r_abuf_waddr;
  reg [          BITS*MAX_CHANNEL-1:0] r_abuf_wdat;
  // layer 
  reg                                  r_lyr_relu_en;
  // opt  
  reg                                  r_o_done;
  reg                                  r_obuf_we;
  reg [               OUTPUT_ADDR-1:0] r_obuf_wcnt;
  reg [               OUTPUT_ADDR-1:0] r_obuf_waddr;
  reg [                        BITS:0] r_obuf_wdat;
  //
  reg [         $clog2(MAX_CHANNEL):0] r_cur_ch_num;
  reg [          $clog2(MAX_FILTER):0] r_cur_filt_num;
  reg [             MAX_WEIGHT_ADDR:0] r_cur_wgt_depth;
  // line buffer 
  reg [               MAX_CHANNEL-1:0] r_lbuf_st;
  // wgt  
  reg [           MAX_WEIGHT_ADDR-1:0] r_wgt_rcnt;
  // bias
  reg [                           2:0] r_bias_sel;
  // group 
  reg [$clog2(MAX_FILTER_GROUP_NUM):0] r_grp_cnt;
  reg                                  r_abuf_sel;
  //
  reg [$clog2(MAX_FILTER_GROUP_NUM):0] r_vld_abuf;  // 유효 이미지 버퍼
  reg [          $clog2(MAX_FILTER):0] r_vld_ch;  // 이미지 버퍼 내 유효 채널



  // ====================== assign ========================= 
  assign o_ctrl_rdy    = r_ctrl_rdy;
  assign o_wgt_re      = r_wgt_re;
  assign o_wgt_raddr   = r_wgt_raddr;
  assign o_wgt_sel     = r_wgt_sel;
  assign o_ibuf_re     = r_ibuf_re;
  assign o_ibuf_raddr  = r_ibuf_raddr;
  assign o_abuf_re     = r_abuf_re;
  assign o_abuf_raddr  = r_abuf_raddr;
  assign o_abuf_we     = r_abuf_we;
  assign o_abuf_waddr  = r_abuf_waddr;
  assign o_abuf_wdout  = r_abuf_wdat;
  assign o_lyr_relu_en = r_lyr_relu_en;
  assign o_obuf_we     = r_obuf_we;
  assign o_obuf_addr   = r_obuf_waddr;
  assign o_obuf_dout   = r_obuf_wdat;
  assign o_done        = r_o_done;
  assign o_ch_num      = r_cur_ch_num;
  assign o_filt_num    = r_cur_filt_num;
  assign o_lbuf_st     = r_lbuf_st;
  assign o_bias_sel    = r_bias_sel;
  assign o_grp_sel     = r_grp_cnt;
  assign o_abuf_sel    = r_abuf_sel;
  assign o_vld_abuf    = r_vld_abuf;
  assign o_vld_ch      = r_vld_ch;
  // ====================== FSM ============================ 
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
      IDLE: if (i_st) r_nstat = L1_LOAD;

      L1_LOAD: if (L1_WGT_DEPTH_GRP <= r_wgt_rcnt) r_nstat = L1_COMP;
      L1_COMP:
      if (IMAGE_DEPTH <= r_abuf_wcnt) begin
        if (r_grp_cnt == L1_FILTER_GROUP_NUM - 1) r_nstat = L2_LOAD;
        else r_nstat = L1_LOAD;
      end

      L2_LOAD: if (L2_WGT_DEPTH_GRP <= r_wgt_rcnt) r_nstat = L2_COMP;
      L2_COMP:
      if (IMAGE_DEPTH <= r_abuf_wcnt) begin
        if (r_grp_cnt == L2_FILTER_GROUP_NUM - 1) r_nstat = L3_LOAD;
        else r_nstat = L2_LOAD;
      end

      L3_LOAD: if (L3_WGT_DEPTH_GRP <= r_wgt_rcnt) r_nstat = L3_COMP;
      L3_COMP:
      if (IMAGE_DEPTH <= r_obuf_wcnt) begin
        if (r_grp_cnt == L3_FILTER_GROUP_NUM - 1) r_nstat = DONE;
        else r_nstat = L3_LOAD;
      end

      DONE: begin
        if (r_img_cnt < IMAGE_NUM - 1) r_nstat = L1_LOAD;
        else r_nstat = IDLE;
      end
      default: ;
    endcase
  end
  //
  always @(*) begin
    r_cur_ch_num    = 'd0;
    r_cur_filt_num  = 'd0;
    r_cur_wgt_depth = 'd0;
    r_wgt_sel       = 3'b000;
    r_bias_sel      = 3'b000;
    r_abuf_sel      = 'b0;
    r_vld_abuf      = 'd0;
    r_vld_ch        = 'd0;
    case (r_cstat)
      L1_LOAD, L1_COMP: begin
        r_cur_ch_num    = L1_CHANNEL_NUM;
        r_cur_filt_num  = L1_FILTER_NUM / L1_FILTER_GROUP_NUM;
        r_cur_wgt_depth = L1_WGT_DEPTH_GRP;
        r_wgt_sel       = 3'b001;
        r_bias_sel      = 3'b001;
        r_abuf_sel      = 'b0;
        // 첫레이어 필요한가?
        r_vld_abuf      = 'd0;
        r_vld_ch        = 'd1;
      end
      // Layer 2
      L2_LOAD, L2_COMP: begin
        r_cur_ch_num    = L2_CHANNEL_NUM;
        r_cur_filt_num  = L2_FILTER_NUM / L2_FILTER_GROUP_NUM;
        r_cur_wgt_depth = L2_WGT_DEPTH_GRP;
        r_wgt_sel       = 3'b010;
        r_bias_sel      = 3'b010;
        r_abuf_sel      = 'b1;
        r_vld_abuf      = L1_FILTER_GROUP_NUM;
        r_vld_ch        = L1_FILTER_NUM / L1_FILTER_GROUP_NUM;
      end
      L3_LOAD, L3_COMP: begin
        r_cur_ch_num    = L3_CHANNEL_NUM;
        r_cur_filt_num  = L3_FILTER_NUM / L3_FILTER_GROUP_NUM;
        r_cur_wgt_depth = L3_WGT_DEPTH_GRP;
        r_wgt_sel       = 3'b100;
        r_bias_sel      = 3'b100;
        r_abuf_sel      = 'b0;
        r_vld_abuf      = L2_FILTER_GROUP_NUM;
        r_vld_ch        = L2_FILTER_NUM / L2_FILTER_GROUP_NUM;
      end
      DONE:    ;
      default: ;
    endcase
  end
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_ctrl_rdy    <= 'b0;
      r_grp_cnt     <= 'd0;
      r_img_cnt     <= 'b0;
      r_wgt_re      <= 'b0;
      r_wgt_raddr   <= 'd0;
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
      r_lyr_relu_en <= 'b0;
      r_obuf_we     <= 'd0;
      r_obuf_waddr  <= {OUTPUT_ADDR{1'b1}};
      r_obuf_wcnt   <= 'd0;
      r_obuf_wdat   <= 'd0;
      r_o_done      <= 'd0;
      // local ctrl
      r_lbuf_st     <= 'd0;
      r_wgt_raddr   <= {MAX_WEIGHT_ADDR{1'b1}};
      r_wgt_rcnt    <= 'd0;

    end else begin
      r_ctrl_rdy    <= 'b1;  // 일단 항상 받기  
      r_lyr_relu_en <= 'b0;
      r_wgt_re      <= 'b0;
      r_ibuf_re     <= 'b0;
      r_abuf_re     <= 'b0;
      r_abuf_we     <= 'd0;
      r_obuf_we     <= 'b0;
      r_o_done      <= 'd0;
      r_lbuf_st     <= 'd0;
      case (r_cstat)
        IDLE: begin
          r_ibuf_raddr <= {INPUT_ADDR{1'b1}};
          r_grp_cnt    <= 'd0;
        end
        L1_LOAD, L2_LOAD, L3_LOAD: begin
          r_ibuf_rcnt <= 'd0;
          r_abuf_rcnt <= 'd0;
          r_abuf_wcnt <= 'd0;
          r_obuf_wcnt <= 'd0;
          if (r_img_cnt == 0) r_ibuf_raddr <= {INPUT_ADDR{1'b1}};
          else if (r_img_cnt == 1) r_ibuf_raddr <= IMAGE_DEPTH - 1;
          else r_ibuf_raddr <= IMAGE_DEPTH * 2 - 1;
          r_abuf_raddr <= {IMAGE_ADDR{1'b1}};
          r_abuf_waddr <= {IMAGE_ADDR{1'b1}};

          if (r_wgt_rcnt < r_cur_wgt_depth) begin
            r_wgt_re    <= 'b1;
            r_wgt_rcnt  <= r_wgt_rcnt + 'd1;
            r_wgt_raddr <= r_wgt_raddr + 'd1;
          end else begin
            r_wgt_rcnt <= 'd0;
            r_lbuf_st  <= {MAX_CHANNEL{1'b1}} >> (MAX_CHANNEL - r_cur_ch_num);
          end
        end

        L1_COMP, L2_COMP, L3_COMP: begin

          // 레이어 입력
          if (r_cstat == L1_COMP) begin  // image -> layer 1
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

          // 레이어 필터 그룹 카운트
          if (r_abuf_wcnt == IMAGE_DEPTH || r_obuf_wcnt == IMAGE_DEPTH) begin
            if (r_cstat == L1_COMP && r_grp_cnt < L1_FILTER_GROUP_NUM - 1) begin
              r_grp_cnt <= r_grp_cnt + 'd1;
            end else if (r_cstat == L2_COMP && r_grp_cnt < L2_FILTER_GROUP_NUM - 1) begin
              r_grp_cnt <= r_grp_cnt + 'd1;
            end else if (r_cstat == L3_COMP && r_grp_cnt < L3_FILTER_GROUP_NUM - 1) begin
              r_grp_cnt <= r_grp_cnt + 'd1;
            end else begin
              r_wgt_raddr <= {MAX_WEIGHT_ADDR{1'b1}};
              r_grp_cnt   <= 'd0;
            end
          end

          // 레이어 결과 저장
          if (r_cstat == L1_COMP || r_cstat == L2_COMP) begin
            r_lyr_relu_en <= 'b1;
            if (i_lyr_vld) begin
              r_abuf_we    <= 'd1;
              r_abuf_wcnt  <= r_abuf_wcnt + 'd1;
              r_abuf_waddr <= r_abuf_waddr + 'd1;
              r_abuf_wdat  <= i_lyr_din;
            end
          end
          if (r_cstat == L3_COMP) begin
            if (i_lyr_vld) begin
              r_obuf_we    <= 'd1;
              r_obuf_wcnt  <= r_obuf_wcnt + 'd1;
              r_obuf_waddr <= r_obuf_waddr + 'd1;
              r_obuf_wdat  <= i_lyr_din;
            end
          end

          // done signal
          if (r_obuf_wcnt == IMAGE_DEPTH) r_o_done <= 1'b1;
        end
        DONE: begin
          if (r_img_cnt < IMAGE_NUM - 1) begin
            r_img_cnt <= r_img_cnt + 'd1;
          end
        end
        default: ;
      endcase
    end
  end

  // ====================== module ========================= 
endmodule

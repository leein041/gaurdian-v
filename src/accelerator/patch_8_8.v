`timescale 1ns / 1ps

module patch_8_8 #(
    parameter INPUT_BITS   = 16,
    parameter PATCH_WIDTH  = 3,
    parameter PATCH_HEIGHT = 3,
    parameter LINE_WIDTH   = 5,
    parameter LINE_HEIGHT  = 3,

    localparam PATCH_SIZE = INPUT_BITS * PATCH_WIDTH * PATCH_HEIGHT
) (
    input                                i_clk,
    input                                i_rstn,
    input                                i_clr,
    // Input Handshake (From Line Buffer)
    input  [INPUT_BITS*PATCH_HEIGHT-1:0] i_ipt_din,
    input                                i_ipt_vld,
    output                               o_ipt_rdy,
    // Output Handshake (To Next Module)
    input                                i_opt_rdy,
    output                               o_opt_vld,
    output [INPUT_BITS*PATCH_HEIGHT-1:0] o_opt_dout  // 폭 수정: 3비트 -> 48비트
);

  // FSM 상태 정의
  localparam STATE_INPUT = 1'b0;
  localparam STATE_OUTPUT = 1'b1;
  reg r_state;
  genvar g;
  integer i, j;

  // --------------------- Wires ---------------------     
  wire w_act_in = o_ipt_rdy && i_ipt_vld;
  wire w_act_out = i_opt_rdy && o_opt_vld;

  // --------------------- Registers ---------------------  
  reg [INPUT_BITS-1:0] r_ptch_dat[0:PATCH_HEIGHT-1][0:PATCH_WIDTH-1];
  reg [$clog2(PATCH_WIDTH)-1:0] r_col_cnt;  // 출력 시 몇 번째 열을 보낼지 카운트
  reg [$clog2(
PATCH_WIDTH
):0] r_fill_cnt;  // 현재 패치에 데이터가 몇 열 쌓였는지 (0~3)

  reg [$clog2(LINE_WIDTH)-1:0] r_row_cnt;
  reg [$clog2(LINE_HEIGHT)-1:0] r_prow_0, r_prow_1, r_prow_2;

  // ------------------------ Handshake Assign -----------------------   
  // 데이터를 입력받는 상태(STATE_INPUT)이고, 패치가 다 차지 않았을 때만 준비 완료
  assign o_ipt_rdy = (r_state == STATE_INPUT) && (r_fill_cnt < PATCH_WIDTH);

  // 출력을 내보내는 상태(STATE_OUTPUT)일 때 Valid 활성화
  assign o_opt_vld = (r_state == STATE_OUTPUT);

  // ------------------------ FSM 및 카운터 제어 ----------------------- 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_state    <= STATE_INPUT;
      r_col_cnt  <= 'd0;
      r_fill_cnt <= 'd0;
    end else begin
      if (i_clr) begin
        r_state    <= STATE_INPUT;
        r_col_cnt  <= 'd0;
        r_fill_cnt <= 'd0;
      end else begin
        case (r_state)
          STATE_INPUT: begin
            if (w_act_in) begin
              if (r_fill_cnt < PATCH_WIDTH - 1) begin
                r_fill_cnt <= r_fill_cnt + 1'b1;
              end else begin
                // 3번째 데이터가 들어와서 9개가 다 차는 순간 바로 출력 상태로 전환
                r_fill_cnt <= PATCH_WIDTH; // 다 찼음 표시
                r_state    <= STATE_OUTPUT;
                r_col_cnt  <= 'd0;
              end
            end
          end

          STATE_OUTPUT: begin
            if (w_act_out) begin
              if (r_col_cnt < PATCH_WIDTH - 1) begin
                r_col_cnt <= r_col_cnt + 1'b1; // 3개씩 총 3번 내보내기 위해 카운트 증가
              end else begin
                // 3번 출력을 모두 완료한 경우
                r_col_cnt  <= 'd0;
                r_state    <= STATE_INPUT;

                // [선택] 1보 전진을 위한 쉬프트 방식을 위해 fill_cnt를 2로 떨어뜨림
                // 이렇게 해야 다음 번에는 1개(3픽셀)만 더 받으면 바로 또 9개가 됩니다.
                r_fill_cnt <= PATCH_WIDTH - 1;
              end
            end
          end
        endcase
      end
    end
  end

  // ------------------------ 행 맵핑 로직 (Line Buffer 순환용) ----------------------- 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_row_cnt <= 'd0;
      r_prow_0  <= 'd0;
      r_prow_1  <= 'd1;
      r_prow_2  <= 'd2;
    end else begin
      if (i_clr) begin
        r_row_cnt <= 'd0;
        r_prow_0  <= 'd0;
        r_prow_1  <= 'd1;
        r_prow_2  <= 'd2;
      end else if (w_act_in) begin
        if (r_row_cnt < LINE_WIDTH - 1) begin
          r_row_cnt <= r_row_cnt + 'd1;
        end else begin
          r_row_cnt <= 'd0;
          r_prow_0  <= r_prow_1;
          r_prow_1  <= r_prow_2;
          r_prow_2  <= r_prow_0;
        end
      end
    end
  end

  // ------------------------ 3x3 패치 데이터 쉬프트 저장 ----------------------- 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      for (i = 0; i < PATCH_HEIGHT; i = i + 1) begin
        for (j = 0; j < PATCH_WIDTH; j = j + 1) begin
          r_ptch_dat[i][j] <= 'd0;
        end
      end
    end else begin
      if (w_act_in) begin
        // 가로 방향으로 데이터 쉬프트
        for (i = 0; i < PATCH_HEIGHT; i = i + 1) begin
          for (j = 0; j < PATCH_WIDTH - 1; j = j + 1) begin
            r_ptch_dat[i][j] <= r_ptch_dat[i][j+1];
          end
        end

        // 안전하게 고정 인덱스로 슬라이싱한 뒤, 가변하는 r_prow 값을 기반으로 적절한 레지스터 행에 대입
        // (가변 슬라이싱 에러 해결)
        r_ptch_dat[r_prow_0][PATCH_WIDTH-1] <= i_ipt_din[0*INPUT_BITS+:INPUT_BITS];
        r_ptch_dat[r_prow_1][PATCH_WIDTH-1] <= i_ipt_din[1*INPUT_BITS+:INPUT_BITS];
        r_ptch_dat[r_prow_2][PATCH_WIDTH-1] <= i_ipt_din[2*INPUT_BITS+:INPUT_BITS];
      end
    end
  end

  // ------------------------- 출력 대입 ---------------------- 
  // 현재 출력해야 하는 열(r_col_cnt)의 상/중/하 3개 데이터를 조합하여 출력
  generate
    for (g = 0; g < PATCH_HEIGHT; g = g + 1) begin : pack_height
      assign o_opt_dout[g*INPUT_BITS+:INPUT_BITS] = r_ptch_dat[g][r_col_cnt];
    end
  endgenerate

endmodule

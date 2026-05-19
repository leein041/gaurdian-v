`timescale 1ns / 1ps

module patch #(
    parameter INPUT_BITS   = 16,
    parameter PATCH_WIDTH  = 3,
    parameter PATCH_HEIGHT = 3,
    parameter LINE_WIDTH   = 5,
    parameter LINE_HEIGHT  = 3,

    localparam PATCH_SIZE = INPUT_BITS * PATCH_WIDTH * PATCH_HEIGHT
) (
    input                                        i_clk,
    input                                        i_rstn,
    // Input Handshake (From Line Buffer)
    input        [INPUT_BITS*PATCH_HEIGHT-1:0]   i_ipt_din,
    input                                        i_ipt_vld,
    output                                       o_ipt_rdy,
    // Output Handshake (To Next Module)
    input                                        i_opt_rdy,
    output                                       o_opt_vld,
    output signed [PATCH_SIZE-1:0]               o_opt_dout
);

  integer i, j;
  genvar g, h;

  // --------------------- Wires ---------------------     
  wire w_act = o_ipt_rdy && i_ipt_vld;

  // --------------------- Registers ---------------------  
  reg [$clog2(LINE_WIDTH)-1:0]  r_ptch_cnt;
  reg [INPUT_BITS-1:0]          r_ptch_dat[0:PATCH_HEIGHT-1][0:PATCH_WIDTH-1];
  reg                           r_opt_vld;
 
  reg [$clog2(LINE_HEIGHT)-1:0] r_prow_0, r_prow_1, r_prow_2; 

  // ------------------------ Handshake Assign -----------------------   
  // 출력 데이터가 없거나, 후속단에서 받아줄 준비가 되었을 때 상단 데이터 수락
  assign o_ipt_rdy = i_opt_rdy || !r_opt_vld;
  assign o_opt_vld = r_opt_vld;

  // ------------------------ 열 카운터 및 행 맵핑 로직 ----------------------- 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_ptch_cnt <= 'd0;
      r_prow_0   <= 'd0;
      r_prow_1   <= 'd1;
      r_prow_2   <= 'd2;
    end else if (w_act) begin
      if (r_ptch_cnt < LINE_WIDTH - 1) begin
        r_ptch_cnt <= r_ptch_cnt + 'd1;
      end else begin
        r_ptch_cnt <= 'd0; 
        r_prow_0   <= r_prow_1;
        r_prow_1   <= r_prow_2;
        r_prow_2   <= r_prow_0; 
      end
    end
  end

  // ------------------------ 3x3 패치 레지스터 및 Valid 제어 ----------------------- 
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
 
      if (w_act) begin
        for (i = 0; i < PATCH_HEIGHT; i = i + 1) begin 
          for (j = 0; j < PATCH_WIDTH - 1; j = j + 1) begin
            r_ptch_dat[i][j] <= r_ptch_dat[i][j+1];
          end
        end
         
        r_ptch_dat[0][PATCH_WIDTH-1] <= i_ipt_din[r_prow_0 * INPUT_BITS +: INPUT_BITS];
        r_ptch_dat[1][PATCH_WIDTH-1] <= i_ipt_din[r_prow_1 * INPUT_BITS +: INPUT_BITS];
        r_ptch_dat[2][PATCH_WIDTH-1] <= i_ipt_din[r_prow_2 * INPUT_BITS +: INPUT_BITS];
      end
    end
  end

  // ------------------- Unpack / Pack -------------------  
  generate
    for (g = 0; g < PATCH_HEIGHT; g = g + 1) begin : pack_height
      for (h = 0; h < PATCH_WIDTH; h = h + 1) begin : pack_width
        assign o_opt_dout[(g*PATCH_WIDTH+h)*INPUT_BITS +: INPUT_BITS] = r_ptch_dat[g][h];
      end
    end
  endgenerate

endmodule
// 역할 2가지
// 1. 메모리 읽기 지연에 따른 메모리를 저장하는 완충재 역할
// 2. 길어지는 핸드셰이크 조합로직을 한번 끊어주는 역할
module skid_buffer #(
    parameter BITS     = 16,
    parameter LATENCY  = 2,
    parameter MEM_SKID = 0
) (
    input              i_clk,
    input              i_rstn,
    output             o_ipt_rdy,
    input              i_ipt_vld,
    input  [BITS -1:0] i_ipt_din,
    input              i_opt_rdy,
    output             o_opt_vld,
    output [BITS -1:0] o_opt_dout
);
  // ----------------------- parmeter ---------------------- 
  localparam DEPTH = LATENCY + 2;
  integer i;
  // ------------------------- wire ------------------------
  wire wr_en;
  wire rd_en = o_opt_vld && i_opt_rdy;
  // ------------------------- reg ------------------------- 
  reg [BITS -1:0] r_buf[0:DEPTH-1];
  reg [$clog2(DEPTH):0] r_wr_ptr;
  reg [$clog2(DEPTH):0] r_rd_ptr;
  reg [$clog2(DEPTH):0] r_cnt;
  // ------------------------ assign -----------------------  
  // ipt
  assign o_ipt_rdy  = (r_cnt < (DEPTH - LATENCY));
  // opt
  assign o_opt_dout = r_buf[r_rd_ptr];
  assign o_opt_vld  = (r_cnt > 0);
  generate
    // 전단이 메모리(BRAM,URAM) 읽기 지연을 읽기 위한 조건
    if (MEM_SKID) assign wr_en = i_ipt_vld;
    // 전단과 후단의 핸드셰이크 분리 조건
    else assign wr_en = i_ipt_vld && o_ipt_rdy;
  endgenerate
  // ------------------------ always -----------------------  
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_wr_ptr <= 0;
      r_rd_ptr <= 0;
      r_cnt <= 0;
      for (i = 0; i < DEPTH; i = i + 1) begin
        r_buf[i] <= 'd0;
      end
    end else begin
      case ({
        wr_en, rd_en
      })
        2'b10: begin  // 쓰기만
          r_buf[r_wr_ptr] <= i_ipt_din;
          r_wr_ptr        <= (r_wr_ptr == DEPTH - 1) ? 0 : r_wr_ptr + 1;
          r_cnt           <= r_cnt + 1;
        end
        2'b01: begin  // 읽기만
          r_rd_ptr <= (r_rd_ptr == DEPTH - 1) ? 0 : r_rd_ptr + 1;
          r_cnt    <= r_cnt - 1;
        end
        2'b11: begin  // 동시 발생
          r_buf[r_wr_ptr] <= i_ipt_din;
          r_wr_ptr        <= (r_wr_ptr == DEPTH - 1) ? 0 : r_wr_ptr + 1;
          r_rd_ptr        <= (r_rd_ptr == DEPTH - 1) ? 0 : r_rd_ptr + 1;
          // count 유지
        end
      endcase
    end
  end

  // ------------------- Unpack / Pack ------------------- 
  // ------------------------- module ----------------------  

endmodule

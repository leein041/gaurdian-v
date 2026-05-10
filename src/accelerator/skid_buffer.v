module skid_buffer #(
    parameter INPUT_BITS  = 16,
    parameter CHANNEL_NUM = 1,
    parameter MEM_LATENCY = 2
) (
    input                                 i_clk,
    input                                 i_rstn,
    // Input Handshake (BRAM 쪽)
    input                                 i_ipt_vld,
    input  [INPUT_BITS * CHANNEL_NUM-1:0] i_ipt_din,
    output                                o_ipt_rdy,   // 앞단(BRAM)에 보내는 준비 신호 
    // Output Handshake (뒷단 쪽)
    input                                 i_opt_rdy,   // 뒷단에서 오는 준비 신호
    output [INPUT_BITS * CHANNEL_NUM-1:0] o_opt_dout,
    output                                o_opt_vld    // 뒷단에 보내는 유효 신호
);
  // ----------------------- parmeter ---------------------- 
  localparam DEPTH = MEM_LATENCY + 2;
  // ---------------------- hand shake --------------------- 
  // ------------------------- wire ------------------------
  wire                                wr_en = i_ipt_vld;
  wire                                rd_en = o_opt_vld && i_opt_rdy;
  // ------------------------- reg ------------------------- 
  reg  [INPUT_BITS * CHANNEL_NUM-1:0] r_buf                          [0:DEPTH-1];
  reg  [             $clog2(DEPTH):0] r_wr_ptr;
  reg  [             $clog2(DEPTH):0] r_rd_ptr;
  reg  [             $clog2(DEPTH):0] r_cnt;
  // ------------------------ assign -----------------------  
  // ipt
  assign o_ipt_rdy  = (r_cnt < (DEPTH - MEM_LATENCY));
  // opt
  assign o_opt_dout = r_buf[r_rd_ptr];
  assign o_opt_vld  = (r_cnt > 0);
  // ------------------------ always -----------------------  
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_wr_ptr <= 0;
      r_rd_ptr <= 0;
      r_cnt <= 0;
    end else begin
      case ({
        wr_en, rd_en
      })
        2'b10: begin  // 쓰기만
          r_buf[r_wr_ptr] <= i_ipt_din;
          r_wr_ptr <= (r_wr_ptr == DEPTH - 1) ? 0 : r_wr_ptr + 1;
          r_cnt <= r_cnt + 1;
        end
        2'b01: begin  // 읽기만
          r_rd_ptr <= (r_rd_ptr == DEPTH - 1) ? 0 : r_rd_ptr + 1;
          r_cnt <= r_cnt - 1;
        end
        2'b11: begin  // 동시 발생
          r_buf[r_wr_ptr] <= i_ipt_din;
          r_wr_ptr <= (r_wr_ptr == DEPTH - 1) ? 0 : r_wr_ptr + 1;
          r_rd_ptr <= (r_rd_ptr == DEPTH - 1) ? 0 : r_rd_ptr + 1;
          // count 유지
        end
      endcase
    end
  end

  // ------------------- Unpack / Pack ------------------- 
  // ------------------------- module ----------------------  

endmodule


`include "defines.vh"
`include "network_config.vh"
module fifo #(
    parameter WIDTH = `IPT_BIT * `MAX_GROUP_CHANNEL,
    parameter DEPTH = 0
) (
    input               i_clk,
    input               i_rstn,
    // ipt
    output              o_ipt_rdy,
    input               i_ipt_vld,
    input  [WIDTH -1:0] i_ipt_din,
    // opt
    input               i_opt_rdy,
    output              o_opt_vld,
    output [WIDTH -1:0] o_opt_dout
);
  // ====================== parmeter =======================      
  integer                      i;
  // ====================== wire =========================== 
  wire                         wr_en;
  wire                         rd_en;
  // fifo buffer 
  wire                         w_fbuf_vld;
  wire       [     WIDTH -1:0] w_fbuf_dat;
  // skid buffer
  wire                         w_sbuf_rdy;
  wire                         w_sbuf_vld;
  wire       [     WIDTH -1:0] w_sbuf_dat;
  // ====================== reg ============================  
  reg        [$clog2(DEPTH):0] r_cnt;
  // write
  reg                          r_we;
  reg signed [     WIDTH -1:0] r_wdat;
  reg        [$clog2(DEPTH):0] r_wptr;
  reg        [$clog2(DEPTH):0] r_waddr;
  // read
  reg                          r_re;
  reg        [$clog2(DEPTH):0] r_rptr;
  reg        [$clog2(DEPTH):0] r_raddr;
  // ====================== assign ========================= 
  // ipt
  // why substract 1?
  // : read enable signal is register, so -1
  assign o_ipt_rdy = (r_cnt < (DEPTH - 1));
  assign wr_en     = i_ipt_vld && o_ipt_rdy;
  assign rd_en     = (0 < r_cnt) && w_sbuf_rdy;
  // ====================== always ========================= 
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_we    <= 'b0;
      r_wdat  <= 'd0;
      r_wptr  <= 'd0;
      r_waddr <= 'd0;
      r_re    <= 'b0;
      r_rptr  <= 'd0;
      r_raddr <= 'd0;
      r_cnt   <= 'd0;
    end else begin
      case ({
        wr_en, rd_en
      })
        2'b10: begin  // 쓰기만
          r_cnt   <= r_cnt + 1;
          r_we    <= 'b1;
          r_wdat  <= i_ipt_din;
          r_wptr  <= (r_wptr == DEPTH - 1) ? 0 : r_wptr + 1;
          r_waddr <= r_wptr;
          r_re    <= 'b0;
        end
        2'b01: begin  // 읽기만
          r_cnt   <= r_cnt - 1;
          r_we    <= 'b0;
          r_re    <= 'b1;
          r_rptr  <= (r_rptr == DEPTH - 1) ? 0 : r_rptr + 1;
          r_raddr <= r_rptr;
        end
        2'b11: begin  // 동시 발생
          r_we    <= 'b1;
          r_wdat  <= i_ipt_din;
          r_wptr  <= (r_wptr == DEPTH - 1) ? 0 : r_wptr + 1;
          r_waddr <= r_wptr;
          r_re    <= 'b1;
          r_rptr  <= (r_rptr == DEPTH - 1) ? 0 : r_rptr + 1;
          r_raddr <= r_rptr;
          // count 유지
        end
        default: begin
          r_we <= 'b0;
          r_re <= 'b0;
        end
      endcase
    end
  end

  // ====================== Unpack / Pack ================== 
  // ====================== module ========================= 
  simple_dual_port_ram #(
      .WIDTH(WIDTH),
      .DEPTH(DEPTH),
      .MEM_TYPE(`BRAM_TYPE),
      .INIT_FILE()
  ) inst_fifo_buffer (
      .i_clk  (i_clk),
      .i_rstn (i_rstn),
      //
      .i_re   (r_re),
      .i_raddr(r_raddr),
      .o_rvld (w_fbuf_vld),
      .o_rdout(w_fbuf_dat),
      //
      .i_we   (r_we),
      .i_waddr(r_waddr),
      .i_wdin (r_wdat)
  );
  skid_buffer #(
      .WIDTH   (WIDTH),
      .LATENCY (3),
      .MEM_SKID(1)
  ) inst_skid (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      // ipt
      .o_ipt_rdy (w_sbuf_rdy),
      .i_ipt_vld (w_fbuf_vld),
      .i_ipt_din (w_fbuf_dat),
      // opt
      .i_opt_rdy (i_opt_rdy),
      .o_opt_vld (o_opt_vld),
      .o_opt_dout(o_opt_dout)
  );
endmodule

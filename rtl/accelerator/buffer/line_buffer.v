
`include "defines.vh"
`include "network_config.vh"
module line_buffer #(
    parameter  LINE_BIT    = 16,
    parameter  LINE_HEIGHT = `CONV_3X3_SIDE,
    parameter  LINE_WIDTH  = `MAX_PAD_TILE_SIDE,      // padded
    localparam LINE_AREA   = LINE_WIDTH * LINE_WIDTH
) (
    input                                         i_clk,
    input                                         i_rstn,
    input                                         i_clr,
    // ipt
    input  signed [                 LINE_BIT-1:0] i_ipt_din,
    input                                         i_ipt_vld,
    output                                        o_ipt_rdy,
    // opt
    input                                         i_opt_rdy,
    output                                        o_opt_vld,
    output        [LINE_BIT * LINE_HEIGHT  - 1:0] o_opt_dout,
    //
    output                                        o_window_vld
);
  // ====================== parmeter =======================  

  integer i, j;
  genvar g, h;
  // ====================== hand shake ===================== 
  // ====================== wire ===========================
  // hand shake  
  wire                                      w_act_in;
  wire                                      w_act_out;
  // ipt  
  // line buffer
  wire                                      w_lbuf_we;
  wire                                      w_lbuf_rvld;
  wire        [   LINE_BIT*LINE_HEIGHT-1:0] w_lbuf_rdat;
  // skid buffer
  wire        [            LINE_HEIGHT-1:0] w_sbuf_rdy;
  wire signed [               LINE_BIT-1:0] w_sbuf_dat     [0:LINE_HEIGHT-1];
  // patch 
  // opt 
  // ====================== reg ============================ 
  //ipt data
  reg signed  [               LINE_BIT-1:0] r_lbuf_wdat;
  // line buffer
  reg         [                        1:0] r_lbuf_cstat;
  reg         [                        1:0] r_lbuf_nstat;
  // 
  reg         [ $clog2(LINE_WIDTH) - 1 : 0] r_wpos_row;
  reg         [$clog2(LINE_HEIGHT) - 1 : 0] r_lbuf_row_idx;
  reg         [ $clog2(LINE_WIDTH) - 1 : 0] r_lbuf_col;
  reg         [ $clog2(LINE_WIDTH) - 1 : 0] r_lbuf_rptr;
  // line buffer   

  // read
  reg                                       r_lbuf_re;
  reg         [     $clog2(LINE_WIDTH)-1:0] r_lbuf_raddr;
  reg         [      $clog2(LINE_AREA) : 0] r_lbuf_rcnt;
  // write
  reg                                       r_lbuf_we;
  reg         [    $clog2(LINE_HEIGHT)-1:0] r_lbuf_widx;
  reg         [ $clog2(LINE_WIDTH) - 1 : 0] r_lbuf_waddr;
  reg         [      $clog2(LINE_AREA) : 0] r_lbuf_wcnt;

  //  
  reg         [     $clog2(LINE_WIDTH)-1:0] r_opt_col_idx;
  reg         [    $clog2(LINE_HEIGHT)-1:0] r_ptch_row_idx;
  reg         [   LINE_BIT*LINE_HEIGHT-1:0] r_opt_dat;
  reg         [            LINE_HEIGHT-1:0] r_opt_vld; 
  // ====================== hand shake ===================== 
  assign o_ipt_rdy  = 'b1;  // TODO
  assign o_window_vld = (2 <= r_opt_col_idx);

  assign w_act_in   = (o_ipt_rdy && i_ipt_vld);
  assign w_act_out  = 'b1;  // TODO
  // ====================== assign =========================   
  // ====================== always =========================    
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      r_lbuf_wdat    <= 'd0;
      r_lbuf_rptr    <= 'd0;
      r_wpos_row     <= 'd0;
      r_lbuf_row_idx <= 'd0;
      r_lbuf_col     <= 'd0;
      r_lbuf_we      <= 'd0;
      r_lbuf_widx    <= 'd1;
      r_lbuf_waddr   <= 'd0;
      r_lbuf_wcnt    <= 'd0;
      r_lbuf_re      <= 'd0;
      r_lbuf_raddr   <= 'd0;
      r_lbuf_rcnt    <= 2 * LINE_WIDTH;
      r_ptch_row_idx <= 'd0;
      r_opt_col_idx  <= 'd0; 
    end else if (i_clr) begin
      r_lbuf_wcnt    <= 'd0;
      r_lbuf_rcnt    <= 2 * LINE_WIDTH;
      r_lbuf_row_idx <= 'd0;
      r_ptch_row_idx <= 'd0;
    end else begin

      // act in
      if (w_act_in) begin
        r_lbuf_wdat   <= i_ipt_din;
        r_lbuf_we    <= 'b1;
        r_lbuf_waddr <= r_lbuf_col;
        r_lbuf_widx  <= r_lbuf_row_idx;
        r_lbuf_wcnt  <= r_lbuf_wcnt + 'd1;

        // update write col position
        if (r_lbuf_col < LINE_WIDTH - 1) r_lbuf_col <= r_lbuf_col + 1'b1;
        else begin
          r_lbuf_col <= 'd0;
          // update write row position
          if (r_wpos_row < LINE_WIDTH - 1) begin
            r_wpos_row <= r_wpos_row + 1'b1;
          end else begin
            r_wpos_row <= 'd0;
          end

          // update write position row index
          if (r_lbuf_row_idx < LINE_HEIGHT - 1) begin
            r_lbuf_row_idx <= r_lbuf_row_idx + 1'b1;
          end else begin
            r_lbuf_row_idx <= 'd0;
          end
        end
      end else r_lbuf_we <= 'b0;

      // act out
      if (w_act_out) begin
        // counting line buffer read address  
        if (r_lbuf_rcnt < r_lbuf_wcnt) begin
          r_lbuf_re    <= 1'b1;
          r_lbuf_raddr <= r_lbuf_rptr;
          r_lbuf_rcnt  <= r_lbuf_rcnt + 'd1;

          // update read col position
          if (r_lbuf_rptr < LINE_WIDTH - 1) begin
            r_lbuf_rptr <= r_lbuf_rptr + 1'b1;
          end else begin
            r_lbuf_rptr <= 'd0;
          end
        end else r_lbuf_re <= 1'b0;
      end else r_lbuf_re <= 1'b0;

      // lbuf -> output
      if (w_lbuf_rvld) begin
        if (r_opt_col_idx < LINE_WIDTH - 1) begin
          r_opt_col_idx <= r_opt_col_idx + 'd1;
        end else begin
          r_opt_col_idx <= 'd0;
          // circulate patch row index ( 012 -> 120 -> 201 -> 012 -> ..)
          if (r_ptch_row_idx < LINE_HEIGHT - 1) r_ptch_row_idx <= r_ptch_row_idx + 'd1;
          else r_ptch_row_idx <= 'd0;
        end
      end
    end
  end
  // align data for patch
  always @(*) begin
    case (r_ptch_row_idx)
      'd0: begin
        r_opt_dat[0*LINE_BIT+:LINE_BIT] = w_lbuf_rdat[0*LINE_BIT+:LINE_BIT];
        r_opt_dat[1*LINE_BIT+:LINE_BIT] = w_lbuf_rdat[1*LINE_BIT+:LINE_BIT];
        r_opt_dat[2*LINE_BIT+:LINE_BIT] = w_lbuf_rdat[2*LINE_BIT+:LINE_BIT];
      end
      'd1: begin
        r_opt_dat[0*LINE_BIT+:LINE_BIT] = w_lbuf_rdat[1*LINE_BIT+:LINE_BIT];
        r_opt_dat[1*LINE_BIT+:LINE_BIT] = w_lbuf_rdat[2*LINE_BIT+:LINE_BIT];
        r_opt_dat[2*LINE_BIT+:LINE_BIT] = w_lbuf_rdat[0*LINE_BIT+:LINE_BIT];
      end
      default: begin
        r_opt_dat[0*LINE_BIT+:LINE_BIT] = w_lbuf_rdat[2*LINE_BIT+:LINE_BIT];
        r_opt_dat[1*LINE_BIT+:LINE_BIT] = w_lbuf_rdat[0*LINE_BIT+:LINE_BIT];
        r_opt_dat[2*LINE_BIT+:LINE_BIT] = w_lbuf_rdat[1*LINE_BIT+:LINE_BIT];
      end
    endcase
  end
  // ====================== module =========================  
  bank_buffer #(
      .WIDTH     (LINE_BIT),
      .BANK_DEPTH(LINE_WIDTH),
      .MEM_TYPE  (`LUT_TYPE),
      .BANK_NUM  (LINE_HEIGHT)
  ) inst_line_bank_buf (
      .i_clk     (i_clk),
      .i_rstn    (i_rstn),
      .i_re      (r_lbuf_re),
      .i_raddr   (r_lbuf_raddr),
      .o_rvld    (w_lbuf_rvld),
      .o_rdout   (w_lbuf_rdat),
      .i_bank_idx(r_lbuf_widx),
      .i_we      (r_lbuf_we),
      .i_waddr   (r_lbuf_waddr),
      .i_wdin    (r_lbuf_wdat),
      .o_ipt_rdy (),
      .i_opt_rdy ('b1)            // TODO
  );

  // ====================== output =========================  
  assign o_opt_dout = r_opt_dat;
  assign o_opt_vld  = w_lbuf_rvld;  // 동시 작업이므로 LUT 최소화
endmodule

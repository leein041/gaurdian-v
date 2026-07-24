
`include "defines.vh"
`include "network_config.vh"
module patch #(
    parameter STRIDE     = 0,
    parameter PATCH_SIDE = 0,
    parameter LINE_WIDTH = 0
) (
    input                                                  i_clk,
    input                                                  i_rstn,
    input                                                  i_clr,
    // ipt
    input         [               `IPT_BIT*PATCH_SIDE-1:0] i_ipt_din,
    input                                                  i_ipt_vld,
    output                                                 o_ipt_rdy,
    // opt
    input                                                  i_opt_rdy,
    output                                                 o_opt_vld,
    output signed [`IPT_BIT * PATCH_SIDE * PATCH_SIDE-1:0] o_opt_dout,
    // 
    input         [                  $clog2(LINE_WIDTH):0] i_line_width
);
  // ====================== parmeter =======================   
  genvar g, h;
  integer i, j;

  // ====================== wire =========================== 
  wire w_act_in = o_ipt_rdy && i_ipt_vld;
  wire w_act_out = i_opt_rdy && o_opt_vld;
  // ====================== reg ============================    
  reg signed [`IPT_BIT-1:0] r_opt_dat[0:PATCH_SIDE-1][0:PATCH_SIDE-1];
  reg [$clog2(LINE_WIDTH):0] r_lbuf_col_cnt;
  reg [$clog2(STRIDE):0] r_stride_col_cnt;
  reg [$clog2(STRIDE):0] r_stride_row_cnt;
  reg r_opt_vld;
  // ====================== hand shake =====================     
  assign o_ipt_rdy = w_act_out || !r_opt_vld;
  assign o_opt_vld = r_opt_vld;
  // ====================== always =========================   
  // output valid
  always @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
      r_opt_vld        <= 'b0;
      r_lbuf_col_cnt   <= 'd0;
      r_stride_col_cnt <= 'd0;
      r_stride_row_cnt <= 'd0;
    end else if (i_clr) begin
      r_opt_vld        <= 'b0;
      r_lbuf_col_cnt   <= 'd0;
      r_stride_col_cnt <= 'd0;
      r_stride_row_cnt <= 'd0;
    end else begin
      case ({
        w_act_in, w_act_out
      })
        2'b10, 2'b11: begin
          // count linebuffer position 
          if (r_lbuf_col_cnt < i_line_width) begin
            r_lbuf_col_cnt <= r_lbuf_col_cnt + 'd1;
            if (r_stride_col_cnt < STRIDE - 1) r_stride_col_cnt <= r_stride_col_cnt + 'd1;
            else r_stride_col_cnt <= 'd0;
          end else begin
            r_lbuf_col_cnt <= 'd1;
            if (r_stride_row_cnt < STRIDE - 1) r_stride_row_cnt <= r_stride_row_cnt + 'd1;
            else r_stride_row_cnt <= 'd0;
          end
          //  TODO
          if ((PATCH_SIDE - 1 <= r_lbuf_col_cnt) && (r_lbuf_col_cnt < i_line_width)
              //  && (STRIDE - 1 == r_stride_col_cnt) && (0 == r_stride_row_cnt)
              ) begin
            r_opt_vld <= 'b1;
          end else r_opt_vld <= 'b0;

          for (i = 0; i < PATCH_SIDE; i = i + 1)
          for (j = 0; j < PATCH_SIDE - 1; j = j + 1) r_opt_dat[i][j] <= r_opt_dat[i][j+1];

          for (i = 0; i < PATCH_SIDE; i = i + 1)
          r_opt_dat[i][PATCH_SIDE-1] <= i_ipt_din[i*`IPT_BIT+:`IPT_BIT];
        end
        2'b01: begin
          // 기존 데이터만 나감
          r_opt_vld <= 1'b0;
        end
        default: begin
          // 아무 일 없음
        end
      endcase
    end
  end

  // ====================== Unpack / Pack ==================

  generate
    for (g = 0; g < PATCH_SIDE; g = g + 1) begin
      for (h = 0; h < PATCH_SIDE; h = h + 1) begin
        assign o_opt_dout[(g*PATCH_SIDE+h)*`IPT_BIT+:`IPT_BIT] = r_opt_dat[g][h];
      end
    end
  endgenerate
endmodule

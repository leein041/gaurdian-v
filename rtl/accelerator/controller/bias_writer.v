
`include "defines.vh"
`include "network_config.vh"

module bias_buf_writer #(
    parameter MAX_BIAS_BANK_DEPTH = 0,
    parameter MAX_BIAS_BANK_NUM   = 0
) (
    input                                                                            i_clk,
    input                                                                            i_rstn,
    output reg                                                                       o_dn,
    // 
    output reg                                                                       o_desc_rdy,
    input                                                                            i_desc_vld,
    input      [`CLOG2_SAFE(MAX_BIAS_BANK_DEPTH)+`CLOG2_SAFE(MAX_BIAS_BANK_NUM)+1:0] i_desc_din,
    // ipt (FIFO)
    output                                                                           o_ipt_rdy,
    input                                                                            i_ipt_vld,
    input      [                                  `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] i_ipt_din,
    // write    
    input                                                                            i_buf_wr_rdy,
    output reg [                                 `CLOG2_SAFE(MAX_BIAS_BANK_NUM)-1:0] o_bank_idx,
    output                                                                           o_we,
    output     [                                `CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] o_waddr,
    output     [                                  `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] o_wdat
);
  // ====================== parmeter =======================   
  localparam IDLE = 0;
  localparam RUN = 1;
  localparam DONE = 2;
  localparam WAIT_READY = 3;
  localparam END_STATE = 4;

  // ====================== reg ============================ 
  reg [         `CLOG2_SAFE(END_STATE)-1:0] r_out_cstat;
  reg [         `CLOG2_SAFE(END_STATE)-1:0] r_out_nstat;
  // 
  reg [ `CLOG2_SAFE(MAX_BIAS_BANK_DEPTH):0] r_bank_ptr;
  reg [ `CLOG2_SAFE(MAX_BIAS_BANK_DEPTH):0] r_bank_depth;
  reg [   `CLOG2_SAFE(MAX_BIAS_BANK_NUM):0] r_bank_num;
  // 
  // 
  reg                                       r_we;
  reg [`CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] r_wr_ptr;
  reg [`CLOG2_SAFE(`MAX_PAD_TILE_AREA)-1:0] r_waddr;
  reg [  `IPT_BIT * `MAX_GROUP_CHANNEL-1:0] r_wdat;
  // ====================== wire ===========================       
  // ====================== assign =========================        
  assign o_ipt_rdy   =   r_out_cstat == RUN;
  // 
  assign o_we    = r_we;
  assign o_waddr = r_waddr;
  assign o_wdat  = r_wdat;
  // ====================== FSM ============================
  //       ___        _               _     _____ ____  __  __ 
  //      / _ \ _   _| |_ _ __  _   _| |_  |  ___/ ___||  \/  |
  //     | | | | | | | __| '_ \| | | | __| | |_  \___ \| |\/| |
  //     | |_| | |_| | |_| |_) | |_| | |_  |  _|  ___) | |  | |
  //      \___/ \__,_|\__| .__/ \__,_|\__| |_|   |____/|_|  |_|
  //                     |_|                                   

  //  initialize and update state register    

  //  initialize and update state register    
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) r_out_cstat <= IDLE;
    else r_out_cstat <= r_out_nstat;
  end

  // compute next state 
  always @(*) begin
    r_out_nstat = r_out_cstat;

    case (r_out_cstat)
      IDLE: begin
        if (i_buf_wr_rdy && i_desc_vld) r_out_nstat = RUN;
      end

      RUN: begin
        if (r_wr_ptr == r_bank_depth - 1 && r_bank_ptr == r_bank_num - 1 && i_ipt_vld) begin
          r_out_nstat = DONE;
        end
      end

      DONE: begin
        r_out_nstat = WAIT_READY;
      end

      WAIT_READY: begin
        r_out_nstat = IDLE;
      end


      default: ;
    endcase
  end
  // 
  //  compute RTL operations
  always @(posedge i_clk or negedge i_rstn) begin
    if (~i_rstn) begin
      o_desc_rdy   <= 'b0;
      r_we         <= 'b0;
      r_bank_ptr   <= 'd0;
      r_bank_num   <= 'd0;
      r_bank_depth <= 'd0;
      o_bank_idx   <= 'd0;
      r_wr_ptr     <= 'd0;
      r_waddr      <= 'd0;
      r_wdat       <= 'd0;
      o_dn         <= 'b0;

    end else begin
      case (r_out_cstat)
        IDLE: begin
          o_dn <= 'b0;
          if (i_buf_wr_rdy && i_desc_vld) begin
            {r_bank_depth, r_bank_num} <= i_desc_din;
            o_desc_rdy                 <= 'b1;
          end
        end

        RUN: begin

          o_desc_rdy <= 'b0;

          if (i_ipt_vld) begin  // TOOD : consider o_ipt_rdy
            if (r_bank_ptr < r_bank_num - 1) begin
              r_bank_ptr <= r_bank_ptr + 'd1;
            end else begin
              r_bank_ptr <= 'd0;
              if (r_wr_ptr < r_bank_depth - 1) begin
                r_wr_ptr <= r_wr_ptr + 'd1;
              end else begin
                r_wr_ptr <= 'd0;
              end
            end

            o_bank_idx <= r_bank_ptr;
            r_we       <= 'b1;
            r_waddr    <= r_wr_ptr;
            r_wdat     <= i_ipt_din;

          end else begin
            r_we <= 'b0;
          end
        end
        DONE: begin
          r_bank_ptr <= 'd0;
          r_wr_ptr   <= 'd0;
          o_dn       <= 'b1;
          r_we       <= 'b0;
        end

        WAIT_READY: begin
          o_dn <= 'b0;
        end
        default: ;

      endcase
    end
  end
  // ====================== output =========================  

endmodule

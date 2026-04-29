`timescale 1ns / 1ps
`include "pkg.vh"

module data_memory #(
    parameter MEM_SIZE       = 2 ** 16,       // 64 KB
    parameter MEM_INIT_VALUE = "",
    parameter START_INDEX    = 32'h8000_0000
) (
    input        clk_i,
    input        rst_ni,
    input        mem_en_i,
    input        mem_rw_i,        // 0 - read / 1 - write
    input [ 1:0] mem_addr_lsb_i,  // 메모리 주소 하위 2비트
    input [ 2:0] mem_ld_width_i,  // load  길이 (b, h, w)
    input [ 2:0] mem_st_width_i,  // store 길이 (b, h, w)
    input [31:0] mem_addr_i,
    input [31:0] mem_data_i,

    output reg [31:0] mem_data_o,
    output reg        mem_ready_o,

    // debug
    input      [31:0] tohost_addr_i,
    output reg [31:0] tohost_o,
    output reg        tohost_wen_o
);

  localparam NUM_WORDS = MEM_SIZE / 4;
  wire [13:0] word_index = mem_addr_i[15:2];
  reg [31:0] mem[0 : NUM_WORDS - 1];
  generate
    if (MEM_INIT_VALUE != "") begin : use_init_file
      initial begin
        $readmemh(MEM_INIT_VALUE, mem);
      end
    end
  endgenerate

  reg [1:0] delay_cnt;

  // delay 카운터
  always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      delay_cnt   <= 2'b0;
      mem_ready_o <= 1'b0;
    end else begin
      // 리셋이 아닐 때, mem_en_i가 확실히 1일 때만 카운트
      if (mem_en_i == 1'b1) begin
        if (delay_cnt == 2'd2) begin
          mem_ready_o <= 1'b1;
          delay_cnt   <= 2'b0;
        end else begin
          delay_cnt   <= delay_cnt + 1'b1;
          mem_ready_o <= 1'b0;
        end
      end else begin
        // mem_en_i가 0이거나 'X'여도 기본값(0)으로 유지하여 X 전염 방지
        delay_cnt   <= 2'b0;
        mem_ready_o <= 1'b0;
      end
    end
  end

  // 읽기 / 쓰기
  always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      mem_data_o <= 32'b0;
    end else if (delay_cnt == 2'd2) begin
      if (~mem_rw_i) begin
        // --- LOAD 섹션 ---
        case (mem_ld_width_i)
          `F3_LB: begin  // Sign-extended Byte
            case (mem_addr_lsb_i)
              2'b00: mem_data_o <= {{24{mem[word_index][7]}}, mem[word_index][7:0]};
              2'b01: mem_data_o <= {{24{mem[word_index][15]}}, mem[word_index][15:8]};
              2'b10: mem_data_o <= {{24{mem[word_index][23]}}, mem[word_index][23:16]};
              2'b11: mem_data_o <= {{24{mem[word_index][31]}}, mem[word_index][31:24]};
            endcase
          end
          `F3_LH: begin  // Sign-extended Half-word
            case (mem_addr_lsb_i[1])  // Half-word는 주소가 0 또는 2로 시작
              1'b0: mem_data_o <= {{16{mem[word_index][15]}}, mem[word_index][15:0]};
              1'b1: mem_data_o <= {{16{mem[word_index][31]}}, mem[word_index][31:16]};
            endcase
          end
          `F3_LW:  mem_data_o <= mem[word_index];
          `F3_LBU: begin  // Zero-extended Byte
            case (mem_addr_lsb_i)
              2'b00: mem_data_o <= {24'b0, mem[word_index][7:0]};
              2'b01: mem_data_o <= {24'b0, mem[word_index][15:8]};
              2'b10: mem_data_o <= {24'b0, mem[word_index][23:16]};
              2'b11: mem_data_o <= {24'b0, mem[word_index][31:24]};
            endcase
          end
          `F3_LHU: begin  // Zero-extended Half-word
            case (mem_addr_lsb_i[1])
              1'b0: mem_data_o <= {16'b0, mem[word_index][15:0]};
              1'b1: mem_data_o <= {16'b0, mem[word_index][31:16]};
            endcase
          end
          default: mem_data_o <= 32'b0;
        endcase
      end else begin
        // --- STORE 섹션 ---
        case (mem_st_width_i)
          `F3_SB: begin
            case (mem_addr_lsb_i)
              2'b00: mem[word_index] <= {mem[word_index][31:8], mem_data_i[7:0]};
              2'b01:
              mem[word_index] <= {mem[word_index][31:16], mem_data_i[7:0], mem[word_index][7:0]};
              2'b10:
              mem[word_index] <= {mem[word_index][31:24], mem_data_i[7:0], mem[word_index][15:0]};
              2'b11: mem[word_index] <= {mem_data_i[7:0], mem[word_index][23:0]};
            endcase
          end
          `F3_SH: begin
            case (mem_addr_lsb_i[1])
              1'b0: mem[word_index] <= {mem[word_index][31:16], mem_data_i[15:0]};
              1'b1: mem[word_index] <= {mem_data_i[15:0], mem[word_index][15:0]};
            endcase
          end
          `F3_SW:  mem[word_index] <= mem_data_i;
          default: ;
        endcase
      end
    end
  end


  // debug  
  always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      tohost_o     <= 32'b0;
      tohost_wen_o <= 1'b0;
    end else begin
      tohost_wen_o <= 1'b0;
      if (mem_rw_i && mem_en_i && delay_cnt == 2'd2) begin
        // debug
        $display("STORE addr=0x%08h data=0x%08h", tohost_addr_i, mem_data_i);
        if (tohost_addr_i == 32'h80001000) begin
          tohost_o     <= mem_data_i;
          tohost_wen_o <= 1'b1;
        end
      end
    end
  end
endmodule

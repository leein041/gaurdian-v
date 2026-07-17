`timescale 1ns / 1ps

module memory_stage #(
    parameter MEM_INIT_VALUE = ""
) (
    input clk_i,
    input rst_ni,

    input         is_load_i,
    input         mem_en_i,
    input         mem_rw_i,
    input         reg_we_i,
    input         csr_we_i,
    input         m_sel_i,
    input  [ 2:0] mem_ld_width_i,
    input  [ 2:0] mem_st_width_i,
    input  [ 4:0] dst_i,
    input  [11:0] dst_csr_i,
    input  [31:0] val_m_i,
    input  [31:0] val_csr_i,
    input  [31:0] val_ex_i,
    input  [31:0] pc_i,
    output        reg_we_o,
    output        csr_we_o,
    output [ 4:0] dst_o,
    output [11:0] dst_csr_o,
    output [31:0] val_o,
    output [31:0] val_csr_o,
    output        mem_ready_o,
    output [31:0] pc_o,
    output [31:0] tohost_o,
    output        tohost_wen_o
);
  localparam MEM_SIZE = 2 ** 16;

  //   오른쪽 쉬프트는 왜 하는가 -> 메모리는 word(32bit)로 저장되어있다 -> 4로 나눔으로써 인덱스화(1,2,...)

  wire [ 1:0] mem_addr_lsb = val_ex_i[1:0];
  wire [31:0] mem_addr = {20'b0, val_ex_i[13:2]};  // 비트 슬라이스 
  wire [31:0] mem_data;

  data_memory #(
      .MEM_SIZE      (MEM_SIZE),
      .MEM_INIT_VALUE(MEM_INIT_VALUE)
  ) dm (
      .clk_i         (clk_i),
      .rst_ni        (rst_ni),
      .mem_en_i      (mem_en_i),
      .mem_rw_i      (mem_rw_i),
      .mem_ld_width_i(mem_ld_width_i),
      .mem_st_width_i(mem_st_width_i),
      .mem_addr_lsb_i(mem_addr_lsb),
      .mem_addr_i    (mem_addr),        // word index
      .mem_data_i    (val_m_i),
      .mem_data_o    (mem_data),
      .mem_ready_o   (mem_ready_o),

      .tohost_addr_i(val_ex_i),     // 원본 byte 주소 전달
      .tohost_o     (tohost_o),
      .tohost_wen_o (tohost_wen_o)
  );

  assign reg_we_o  = reg_we_i;
  assign csr_we_o  = csr_we_i;
  assign dst_o     = dst_i;
  assign dst_csr_o = dst_csr_i;
  assign val_o     = m_sel_i ? mem_data : val_ex_i;
  assign val_csr_o = val_csr_i;
  assign pc_o      = pc_i;

endmodule

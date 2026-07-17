`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/26 00:06:38
// Design Name: 
// Module Name: instruction_decoder
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "pkg.vh"

module instruction_decoder (
    input      [               31:0] inst_i,
    output reg                       brc_neg_o,
    output reg                       is_brc_o,
    output reg                       is_jal_o,
    output reg                       is_jalr_o,
    output reg                       is_load_o,
    output reg                       is_ecall_o,
    output reg                       is_ebreak_o,
    output reg                       is_mret_o,
    output reg                       is_wfi_o,
    output reg [                2:0] brc_cond_o,      // branch condition
    output reg [                2:0] mem_ld_width_o,
    output reg [                2:0] mem_st_width_o,
    output reg                       mem_en_o,
    output reg                       mem_rw_o,        // 0 - read / 1 - write
    output reg                       reg_we_o,
    output reg                       csr_we_o,
    output reg [`OPERATER_WIDTH-1:0] alu_operater_o,
    output reg [                1:0] a_sel_o,         // 00-a / 01-pc / 10-reg0 / 11-imm
    output reg [                1:0] b_sel_o,         // 00-b / 01-imm / 10-csr
    output reg                       e_sel_o,         // 0-alu / 1-val B (pass B data)
    output reg                       m_sel_o,         // 0 - ex / 1 - mem
    output reg [                4:0] src_a_o,
    output reg [                4:0] src_b_o,
    output reg [                4:0] dst_o,
    output reg [               11:0] dst_csr_o,
    output reg [               11:0] src_csr_o,
    output reg [               31:0] imm_o
);

  // 31            24   19    14        11          6
  // funct7        rs2  rs1   funct3    rd          opcode R-type
  // imm[11:0]          rs1   funct3    rd          opcode I-type
  // imm[11:5]     rs2  rs1   funct3    imm[4:0]    opcode S-type
  // imm[12|10:5]  rs2  rs1   funct3    imm[4:1|11] opcode B-type
  // imm[31:12]                         rd          opcode U-type
  // imm[20|10:1|11|19:12]              rd          opcode J-type
  // imm[20|10:1|11|19:12]              rd          opcode J-type

  // fm[3:0] pred[3:0] succ[3:0] rs1[4:0] f3[2:0] rd[4:0] opcode[6:0] : fence
  // 0000    0000      0000      00000    000     00000   0001111 

  // fm[3:0] pred[3:0] succ[3:0] rs1[4:0] f3[2:0] rd[4:0] opcode[6:0] : fence_tso
  // 1000    0011      0011      00000    000     00000   0001111 

  // fm[3:0] pred[3:0] succ[3:0] rs1[4:0] f3[2:0] rd[4:0] opcode[6:0]
  // 0000    0001      0000      00000    000     00000   0001111 

  // imm[11:0]               rs1[4:0] f3[2:0] rd[4:0] opcode[6:0]
  // 000000000000            00000    000     00000   1110011 

  // imm[11:0]               rs1[4:0] f3[2:0] rd[4:0] opcode[6:0]
  // 000000000001            00000    000     00000   1110011 

  wire [31:0] imm_i = {{20{inst_i[31]}}, inst_i[31:20]};
  wire [31:0] imm_s = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
  wire [31:0] imm_b = {{19{inst_i[31]}}, inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
  wire [31:0] imm_u = {inst_i[31:12], 12'b0};
  wire [31:0] imm_j = {
    {11{inst_i[31]}}, inst_i[31], inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0
  };
  wire [31:0] imm_sys = {{20'b0}, inst_i[31:20]};
  wire [31:0] imm_sys_u = {27'b0, inst_i[19:15]};

  wire [6:0] opc;

  always @(*) begin
    if (is_mret_o) begin
      src_csr_o = `MEPC;
    end else if (is_ecall_o) begin
      src_csr_o = `MTVEC;
    end else begin
      src_csr_o = inst_i[31:20];
    end
  end

  always @(*) begin
    brc_neg_o      = 1'b0;
    is_brc_o       = 1'b0;
    is_jal_o       = 1'b0;
    is_jalr_o      = 1'b0;
    is_load_o      = 1'b0;
    is_ecall_o     = 1'b0;
    is_ebreak_o    = 1'b0;
    is_mret_o      = 1'b0;
    is_wfi_o       = 1'b0;
    brc_cond_o     = 3'b0;
    mem_ld_width_o = 3'b0;
    mem_st_width_o = 3'b0;
    mem_en_o       = 1'b0;
    mem_rw_o       = 1'b0;
    reg_we_o       = 1'b0;
    csr_we_o       = 1'b0;
    alu_operater_o = `ALU_MOVA;
    a_sel_o        = 2'b00;
    b_sel_o        = 1'b0;
    e_sel_o        = 1'b0;
    m_sel_o        = 1'b0;
    imm_o          = 32'b0;
    src_a_o        = inst_i[19:15];
    src_b_o        = inst_i[24:20];
    dst_o          = inst_i[11:7];
    dst_csr_o      = inst_i[31:20];

    case (opc)
      `OPC_R: begin
        reg_we_o = 1'b1;
        a_sel_o  = 2'b0;
        b_sel_o  = 2'b0;

        case (inst_i[14:12])
          `F3_ADD_SUB: alu_operater_o = (inst_i[30]) ? `ALU_SUB : `ALU_ADD;
          `F3_SLL:     alu_operater_o = `ALU_SLL;
          `F3_SLT:     alu_operater_o = `ALU_SLT;
          `F3_SLTU:    alu_operater_o = `ALU_SLTU;
          `F3_XOR:     alu_operater_o = `ALU_XOR;
          `F3_SR:      alu_operater_o = (inst_i[30]) ? `ALU_SRA : `ALU_SRL;
          `F3_OR:      alu_operater_o = `ALU_OR;
          `F3_AND:     alu_operater_o = `ALU_AND;
          default:     ;
        endcase
      end
      `OPC_I: begin
        reg_we_o = 1'b1;
        b_sel_o  = 2'b01;
        a_sel_o  = 2'b00;
        imm_o    = imm_i;

        case (inst_i[14:12])
          `F3_ADDI:  alu_operater_o = `ALU_ADD;
          `F3_SLTI:  alu_operater_o = `ALU_SLT;
          `F3_SLTIU: alu_operater_o = `ALU_SLTU;
          `F3_XORI:  alu_operater_o = `ALU_XOR;
          `F3_ORI:   alu_operater_o = `ALU_OR;
          `F3_ANDI:  alu_operater_o = `ALU_AND;
          `F3_SLLI:  alu_operater_o = `ALU_SLL;
          `F3_SRI:   alu_operater_o = (inst_i[30]) ? `ALU_SRA : `ALU_SRL;
          default:   ;
        endcase
      end

      `OPC_S_LOAD: begin  //  lw rd, offset(rs1)
        alu_operater_o = `ALU_ADD;
        is_load_o      = 1'b1;
        imm_o          = imm_i;
        a_sel_o        = 2'b00;  // select a
        b_sel_o        = 2'b01;  // select IMM
        m_sel_o        = 1'b1;  // select mem
        reg_we_o       = 1'b1;
        mem_ld_width_o = inst_i[14:12];
        mem_en_o       = 1'b1;
        mem_rw_o       = 1'b0;
      end

      `OPC_S_STORE: begin
        alu_operater_o = `ALU_ADD;
        imm_o          = imm_s;
        mem_en_o       = 1'b1;
        mem_rw_o       = 1'b1;
        b_sel_o        = 2'b01;  // imm -> offset
        mem_st_width_o = inst_i[14:12];
      end

      `OPC_B_TYPE: begin
        is_brc_o = 1'b1;
        imm_o = imm_b;
        brc_cond_o = inst_i[14:12];

        case (inst_i[14:12])
          `F3_BEQ, `F3_BNE:   alu_operater_o = `ALU_SUB;  // 같음 비교는 뺄셈으로 충분
          `F3_BLT, `F3_BGE:   alu_operater_o = `ALU_SLT;  // 부호 있는 비교
          `F3_BLTU, `F3_BGEU: alu_operater_o = `ALU_SLTU;  // 부호 없는 비교
          default:            alu_operater_o = `ALU_SUB;
        endcase

        case (inst_i[14:12])
          `F3_BNE, `F3_BGE, `F3_BGEU: brc_neg_o = 1'b1;
          default:                    brc_neg_o = 1'b0;
        endcase
      end
      `OPC_U_LUI: begin
        alu_operater_o = `ALU_ADD;
        imm_o          = imm_u;
        b_sel_o        = 2'b01;
        a_sel_o        = 2'b10;
        reg_we_o       = 1'b1;
      end
      `OPC_U_AUIPC: begin
        alu_operater_o = `ALU_ADD;
        imm_o          = imm_u;
        b_sel_o        = 2'b01;
        a_sel_o        = 2'b01;
        reg_we_o       = 1'b1;
      end
      `OPC_J_JAL: begin
        alu_operater_o = `ALU_ADD;
        reg_we_o       = 1'b1;
        a_sel_o        = 2'b01;  // select PC
        b_sel_o        = 2'b01;  // select IMM
        dst_o          = inst_i[11:7];
        imm_o          = imm_j;
        is_jal_o       = 1'b1;
      end
      `OPC_J_JALR: begin
        alu_operater_o = `ALU_ADD;
        reg_we_o       = 1'b1;
        a_sel_o        = 2'b00;  // select reg A
        b_sel_o        = 2'b01;  // select IMM
        dst_o          = inst_i[11:7];
        imm_o          = imm_i;
        is_jalr_o      = 1'b1;
      end

      `OPC_SYS: begin
        case (inst_i[14:12])
          `F3_PRIV: begin
            case (inst_i[31:20])
              `F12_ECALL: begin
                is_ecall_o     = 1'b1;
                alu_operater_o = `ALU_MOVB;
                b_sel_o        = 2'b10;  // select csr
              end
              `F12_EBREAK: is_ebreak_o = 1'b1;
              `F12_MRET: begin
                is_mret_o      = 1'b1;
                alu_operater_o = `ALU_MOVB;
                b_sel_o        = 2'b10;  // select csr
              end
              `F12_SRET:   ;
              `F12_WFI:    is_wfi_o = 1'b1;
              default:     ;
            endcase
          end
          `F3_CSRRW: begin  // csrrw rd, csr, rs1
            alu_operater_o = `ALU_MOVA;
            a_sel_o = 2'b00;  // rs1
            b_sel_o = 2'b10;  // csr
            e_sel_o = 1'b1;  // csr
            reg_we_o = 1'b1;
            csr_we_o = 1'b1;
          end
          `F3_CSRRS: begin  // csrrs rd, csr, rs1
            alu_operater_o = `ALU_OR;
            a_sel_o = 2'b00;  // rs1
            b_sel_o = 2'b10;  // csr
            e_sel_o = 1'b1;  // csr
            reg_we_o = 1'b1;
            csr_we_o = 1'b1;
          end
          `F3_CSRRC: begin
            alu_operater_o = `ALU_AND_NOT;
            a_sel_o = 2'b00;  // rs1
            b_sel_o = 2'b10;  // csr
            e_sel_o = 1'b1;  // csr
            reg_we_o = 1'b1;
            csr_we_o = 1'b1;
          end
          `F3_CSRRWI: begin
            alu_operater_o = `ALU_MOVA;
            imm_o          = imm_sys_u;
            a_sel_o        = 2'b11;  // imm
            b_sel_o        = 2'b10;  // csr
            e_sel_o        = 1'b1;  // csr
            reg_we_o       = 1'b1;
            csr_we_o       = 1'b1;
          end
          `F3_CSRRSI: begin
            alu_operater_o = `ALU_OR;
            imm_o          = imm_sys_u;
            a_sel_o        = 2'b11;  // imm
            b_sel_o        = 2'b10;  // csr
            e_sel_o        = 1'b1;  // csr
            reg_we_o       = 1'b1;
            csr_we_o       = 1'b1;
          end
          `F3_CSRRCI: begin
            alu_operater_o = `ALU_AND_NOT;
            imm_o          = imm_sys_u;
            a_sel_o        = 2'b11;  // imm
            b_sel_o        = 2'b10;  // csr
            e_sel_o        = 1'b1;  // csr
            reg_we_o       = 1'b1;
            csr_we_o       = 1'b1;
          end
          default: ;
        endcase
      end

      `OPC_MISC_MEM: begin
        alu_operater_o = `ALU_ADD; 
        imm_o          = imm_i; 
      end


      default: ;
    endcase
  end

  assign opc = inst_i[6:0];
endmodule

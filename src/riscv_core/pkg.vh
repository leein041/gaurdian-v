    

    //       ____            _             _  __        __            _ 
    //      / ___|___  _ __ | |_ _ __ ___ | | \ \      / /__  _ __ __| |
    //     | |   / _ \| '_ \| __| '__/ _ \| |  \ \ /\ / / _ \| '__/ _` |
    //     | |__| (_) | | | | |_| | | (_) | |   \ V  V / (_) | | | (_| |
    //      \____\___/|_| |_|\__|_|  \___/|_|    \_/\_/ \___/|_|  \__,_|
    //                                                                  
    `define BC_IDX   0
    `define JB_IDX   1
    `define PL_IDX   2
    `define MW_IDX   3
    `define RW_IDX   4
    `define MD_IDX   5
    `define FS_IDX   9
    `define MB_IDX   10
    `define BA_IDX   15
    `define AA_IDX   20
    `define DA_IDX   25

    `define CW_WIDTH 26

    //       ___                   _        
    //      / _ \ _ __  __ ___  __| |___ ___
    //     | (_) | '_ \/ _/ _ \/ _` / -_|_-<
    //      \___/| .__/\__\___/\__,_\___/__/
    //           |_|                                        
        `define OP_WIDTH 7

        `define OPC_R         7'b0110011
        `define OPC_I         7'b0010011
        `define OPC_S_LOAD    7'b0000011
        `define OPC_S_STORE   7'b0100011
        `define OPC_B_TYPE    7'b1100011
        `define OPC_U_LUI     7'b0110111 
        `define OPC_U_AUIPC   7'b0010111
        `define OPC_J_JAL     7'b1101111
        `define OPC_J_JALR    7'b1100111
        `define OPC_SYS       7'b1110011
        `define OPC_MISC_MEM     7'b0001111

        // U_TYPE
        `define LUI           7'b0110111
        `define AUIPC         7'b0010111

        // J_TYPE   
        `define JAL           7'b1101111 
        `define JALR          7'b1100111

        // B_TYPE  
        `define F3_BEQ           3'b000
        `define F3_BNE           3'b001
        `define F3_BLT           3'b100
        `define F3_BGE           3'b101
        `define F3_BLTU          3'b110
        `define F3_BGEU          3'b111

        // LOAD   
        `define F3_LB            3'b000
        `define F3_LH            3'b001
        `define F3_LW            3'b010
        `define F3_LBU           3'b100
        `define F3_LHU           3'b101

        // STORE    
        `define F3_SB            3'b000 
        `define F3_SH            3'b001 
        `define F3_SW            3'b010 

        // I_TYPE    
        `define F3_ADDI       3'b000
        `define F3_SLTI       3'b010
        `define F3_SLTIU      3'b011
        `define F3_XORI       3'b100
        `define F3_ORI        3'b110
        `define F3_ANDI       3'b111
        `define F3_SLLI       3'b001
        `define F3_SRI        3'b101
        `define F7_SRLI       7'b0000000
        `define F7_SRAI       7'b0100000

        // R_TYPE   
        `define F3_ADD_SUB    3'b000
        `define F3_SLL        3'b001
        `define F3_SLT        3'b010
        `define F3_SLTU       3'b011
        `define F3_XOR        3'b100
        `define F3_SR         3'b101
        `define F3_OR         3'b110
        `define F3_AND        3'b111
        `define F7_ADD        7'b0000000
        `define F7_SUB        7'b0100000 
        `define F7_SRL        7'b0000000 
        `define F7_SRA        7'b0100000 

        // System
        `define F3_PRIV      3'b000
        `define F12_ECALL    12'h000
        `define F12_EBREAK   12'h001
        `define F12_MRET     12'h302
        `define F12_SRET     12'h102
        `define F12_WFI      12'h105

        `define F3_CSRRW     3'b001
        `define F3_CSRRS     3'b010
        `define F3_CSRRC     3'b011
        `define F3_CSRRWI    3'b101
        `define F3_CSRRSI    3'b110
        `define F3_CSRRCI    3'b111

        // MISC_MEM
        `define F3_FENCE     3'b000
        `define F3_FENCE_I   3'b001
    //        _   _   _   _    ___                     _   _             
    //       /_\ | | | | | |  / _ \ _ __  ___ _ _ __ _| |_(_)___ _ _  ___
    //      / _ \| |_| |_| | | (_) | '_ \/ -_) '_/ _` |  _| / _ \ ' \(_-<
    //     /_/ \_\____\___/   \___/| .__/\___|_| \__,_|\__|_\___/_||_/__/
    //                             |_|           
    `define OPERATER_WIDTH 5


    `define ALU_MOVA     5'b00000
    `define ALU_INC      5'b00001
    `define ALU_ADD      5'b00010
    `define ALU_SUB      5'b00101
    `define ALU_DEC      5'b00110
    `define ALU_AND      5'b01000
    `define ALU_OR       5'b01001
    `define ALU_XOR      5'b01010
    `define ALU_NOT      5'b01011
    `define ALU_MOVB     5'b01100
    `define ALU_SRL      5'b01101
    `define ALU_SRA      5'b01110
    `define ALU_SLL      5'b01111
    `define ALU_SLT      5'b10101
    `define ALU_SLTU     5'b11101
    // custom
    `define ALU_AND_NOT  5'b11110 

    //       ____ ____  ____       _       _     _                   
    //      / ___/ ___||  _ \     / \   __| | __| |_ __ ___  ___ ___ 
    //     | |   \___ \| |_) |   / _ \ / _` |/ _` | '__/ _ \/ __/ __|
    //     | |___ ___) |  _ <   / ___ \ (_| | (_| | | |  __/\__ \__ \
    //      \____|____/|_| \_\ /_/   \_\__,_|\__,_|_|  \___||___/___/
    //                                                               
    `define MSTATUS    12'h300	// 머신 상태 제어
    `define MIE        12'h304	// 인터럽트 허용 마스크
    `define MTVEC      12'h305	// 트랩 핸들러 베이스 주소
    `define MSCRATCH   12'h340	// 임시 보관용 레지스터
    `define MEPC       12'h341	// 예외 복귀 주소
    `define MCAUSE     12'h342	// 트랩 발생 원인 코드
    `define MTVAL      12'h343	// 트랩 부가 정보 (나쁜 주소 등)
    `define MIP        12'h344	// 인터럽트 대기 상태 (Pending)
 
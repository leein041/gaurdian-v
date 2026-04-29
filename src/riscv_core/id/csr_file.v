`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/05 16:10:41
// Design Name: 
// Module Name: csr_file
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


module csr_file (
    input             clk_i,
    input             rst_ni,
    input      [11:0] src_i,          // CSR 주소
    input      [11:0] dst_i,          // CSR 주소
    input      [31:0] val_d_i,        // 쓸 데이터
    input      [31:0] pc_i,           // 현재 pc 
    input             csr_we_i,       // Write Enable
    input             is_ecall_i,
    input             is_ebreak_i,
    input             is_mret_i,
    output            mstatus_mie_o,
    output     [31:0] mie_o,          // signal for system halt 
    output     [31:0] mip_o,
    output reg [31:0] val_o
);

  // mstatus Bit Indices
  localparam UIE = 0;
  localparam SIE = 1;
  localparam MIE = 3;
  localparam UPIE = 4;
  localparam SPIE = 5;
  localparam MPIE = 7;
  localparam SPP = 8;
  localparam MPP_L = 11;
  localparam MPP_H = 12;
  localparam FS_L = 13;
  localparam FS_H = 14;
  localparam XS_L = 15;
  localparam XS_H = 16;
  localparam MPRV = 17;
  localparam SUM = 18;
  localparam MXR = 19;
  localparam TVM = 20;
  localparam TW = 21;
  localparam TSR = 22;
  localparam SD = 31;




  // 실제 필요한 레지스터만 선언
  reg [31:0] mstatus;
  reg [31:0] mie;
  reg [31:0] mtvec;
  reg [31:0] mscratch;
  reg [31:0] mepc;
  reg [31:0] mcause;
  reg [31:0] mtval;
  reg [31:0] mip;

  // --------- mstatus bit info --------- 
  // 0      UIE         User Interrupt Enable (사용자 모드 인터럽트 허용 - 거의 안 씀)
  // 1      SIE         Supervisor Interrupt Enable (S-모드 인터럽트 허용)
  // 2      Reserved    (예약됨)
  // 3      MIE         Machine Interrupt Enable (머신 모드 전체 인터럽트 허용)
  // 4      UPIE        User Previous Interrupt Enable (트랩 전 UIE 상태 보관)
  // 5      SPIE        Supervisor Previous IE (트랩 전 SIE 상태 보관)
  // 6      Reserved    (예약됨)
  // 7      MPIE        Machine Previous IE (트랩 전 MIE 상태 보관)
  // 8      SPP         Supervisor Previous Privilege (S-모드 트랩 전 권한: 0=U, 1=S)
  // 9:10   Reserved    (예약됨)
  // 12:11  MPP         Machine Previous Privilege (M-모드 트랩 전 권한: 00=U, 01=S, 11=M)
  // 14:13  FS          Floating-point Status (FPU 상태: 00:Off, 01:Init, 10:Clean, 11:Dirty)
  // 16:15  XS          User Extension Status (사용자 확장 유닛 상태)
  // 17	    MPRV        Modify Privilege (M-모드에서 MPP 권한으로 메모리 접근)
  // 18	    SUM         permit Supervisor User Memory (S-모드에서 U-모드 메모리 접근 허용)
  // 19	    MXR         Make Executable Readable (실행 전용 페이지 읽기 허용)
  // 20	    TVM         Trap Virtual Memory (S-모드에서 페이지 테이블 수정 시 M-트랩 발생)
  // 21	    TW          Timeout Wait (S-모드에서 WFI 실행 시 타임아웃/M-트랩 발생)
  // 22	    TSR         Trap SRET (S-모드에서 SRET 실행 시 M-트랩 발생)
  // 23:30  Reserved    (예약됨)
  // 31     SD          State Dirty (FS나 XS 중 하나라도 Dirty(11)이면 1 - 읽기 전용)
  
  // MPP (Machine Previous Privilege) 값 정의
  localparam PRIV_U = 2'b00;
  localparam PRIV_S = 2'b01;
  localparam PRIV_M = 2'b11;

  // --------- mie bit info --------- 
  localparam MSIE = 3;  // Machine Software Interrupt Enable (코어 간 통신 등)
  localparam MTIE = 7;  // Machine Timer Interrupt Enable (타이머: OS 스케줄링 등)
  localparam MEIE = 11;  // Machine External Interrupt Enable (외부 장치: 버튼, 센서 등
  // 기타 : S-mode 나 U-mode 인터럽트 비트들
  // 16 이상 : 커스텀
 
  // --------- mscratch bit info --------- 
  
 
  // --------- mcause bit info ---------  
  // [31] = 0 예외 코드
  // 0	| Instruction address misaligned    분기 주소가 4바이트 정렬이 아닐 때		
  // 2	| Illegal instruction	              정의되지 않은 명령어나 권한 밖의 명령어 실행		
  // 3	| Breakpoint	EBREAK                명령어 실행 시		
  // 4	| Load address misaligned	          데이터 읽기 주소가 정렬되지 않았을 때		
  // 6	| Store/AMO address misaligned	    데이터 쓰기 주소가 정렬되지 않았을 때		
  // 8	| Environment call from U-mode	    User 모드에서 ECALL 호출		
  // 11	| Environment call from M-mode	    현재 작성하신 mcause <= 32'd11에 해당		

  // [31] = 1 외부 인터럽트
  // 3	| Machine software interrupt	      코어 간 통신용 소프트웨어 인터럽트		
  // 7	| Machine timer interrupt	          타이머 만료 시 발생 (가장 많이 구현함)		
  // 11	| Machine external interrupt	      외부 장치(UART, GPIO 등)에서 발생		'
  
  // --------- mip bit info ---------   


  //read
  always @(*) begin
    val_o = 32'b0;
    case (src_i)
      `MSTATUS:  val_o = mstatus;
      `MIE:      val_o = mie;
      `MTVEC:    val_o = mtvec;
      `MSCRATCH: val_o = mscratch;
      `MEPC:     val_o = mepc;
      `MCAUSE:   val_o = mcause;
      `MTVAL:    val_o = mtval;
      `MIP:      val_o = mip;
      default:   ;
    endcase
  end

  // write
  always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      mstatus  <= 32'h00001800;  // M-mode
      mie      <= 32'b0;
      mtvec    <= 32'b0;
      mscratch <= 32'b0;
      mepc     <= 32'b0;
      mcause   <= 32'b0;
      mtval    <= 32'b0;
      mip      <= 32'b0;
    end else if (is_ecall_i | is_ebreak_i) begin
      mstatus[MIE]         <= 1'b0;
      mstatus[MPIE]        <= mstatus[MIE];
      mstatus[MPP_H:MPP_L] <= PRIV_M;
      mepc                 <= pc_i;
      mcause               <= (is_ecall_i) ? 32'd11 : 32'd3;
    end else if (is_mret_i) begin
      mstatus[MIE]         <= mstatus[MPIE];
      mstatus[MPIE]        <= 1'b1;
      mstatus[MPP_H:MPP_L] <= PRIV_M;
    end else if (csr_we_i) begin
      case (dst_i)
        `MSTATUS:  mstatus <= val_d_i;
        `MIE:      mie <= val_d_i;
        `MTVEC:    mtvec <= val_d_i;
        `MSCRATCH: mscratch <= val_d_i;
        `MEPC:     mepc <= val_d_i;
        `MCAUSE:   mcause <= val_d_i;
        `MTVAL:    mtval <= val_d_i;
        `MIP:      mip <= val_d_i;
        default:   ;
      endcase
    end
  end

  assign mstatus_mie_o = mstatus[MIE];
  assign mie_o = mie;
  assign mip_o = mip;

endmodule

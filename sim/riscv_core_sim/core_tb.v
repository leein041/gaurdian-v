`timescale 1ns / 1ps

module tb_core_all;

  reg clk, rst_n;
  initial clk = 0;
  always #5 clk = ~clk;

  wire    [  31:0] wb_pc;
  wire    [  31:0] tohost;
  wire             tohost_wen;

  // 테스트 파일 리스트를 저장할 변수
  reg     [1023:0] test_file;  // 파일 경로 저장용
  integer          list_file;  // test_list.txt 파일 핸들
  integer          status;

  // core 모듈 (MACHINE_CODE 파라미터 대신 내부 메모리를 직접 초기화할 수 있는 인터페이스가 있다면 좋습니다)
  // 여기서는 편의상 매번 리셋 시점에 새로운 hex를 로드한다고 가정하겠습니다.
  core dut (
      .clk_i       (clk),
      .rst_ni      (rst_n),
      .wb_pc_o     (wb_pc),
      .tohost_o    (tohost),
      .tohost_wen_o(tohost_wen)
  );

  initial begin
    // // 1. 테스트 리스트 파일 열기
    // list_file =
    //     $fopen("//wsl.localhost/Ubuntu/home/leein/riscv-tests/test_list.txt", "r");
    // if (list_file == 0) begin
    //   $display("Error: test_list.txt not found!");
    //   $finish;
    // end

    // // // 모든 테스트
    // while (!$feof(
    //     list_file
    // )) begin
    //   status = $fscanf(list_file, "%s\n", test_file);
    //   if (status == 1) begin
    //     run_test(test_file);
    //   end
    // end

    // 개별 테스트
    // run_test("//wsl.localhost/Ubuntu/home/leein/riscv-tests/build_rv32/ld_st.hex");

    $display("\n==== ALL TESTS COMPLETED ====");
    $finish;
  end

  // 하나의 테스트를 실행하는 task
  task run_test(input [1023:0] filename);
    integer cycle_cnt;
    reg done;  // 루프 종료 플래그
    begin
      $display("\n[TEST START] %s", filename);
      $readmemh(filename, dut.fs.im.inst_mem);
      $readmemh(filename, dut.ms.dm.mem);

      rst_n = 0;
      cycle_cnt = 0;
      done = 0;
      repeat (10) @(posedge clk);
      rst_n = 1;

      // 플래그를 이용한 루프 제어
      while (!done) begin
        @(posedge clk);
        cycle_cnt = cycle_cnt + 1;

        if (tohost_wen) begin
          if (tohost == 32'h1) $display(">>> PASS: %s (cycles=%0d)", filename, cycle_cnt);
          else $display(">>> FAIL: %s (test_num=%0d, pc=0x%08h)", filename, tohost >> 1, wb_pc);
          done = 1;  // 루프 종료 조건 충족
        end

        if (cycle_cnt >= 30000) begin
          $display(">>> TIMEOUT: %s", filename);
          done = 1;
        end
      end
    end
  endtask

endmodule

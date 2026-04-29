# See LICENSE for license details.

#*****************************************************************************
# slli.S
#-----------------------------------------------------------------------------
#
# Test slli instruction.
#

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN

  #-------------------------------------------------------------
  # Arithmetic tests
  #-------------------------------------------------------------

  TEST_IMM_OP( 2,  slli, 0x0000000000000001, 0x0000000000000001, 0  );
  TEST_IMM_OP( 3,  slli, 0x0000000000000002, 0x0000000000000001, 1  );
  TEST_IMM_OP( 4,  slli, 0x0000000000000080, 0x0000000000000001, 7  );
  TEST_IMM_OP( 5,  slli, 0x0000000000004000, 0x0000000000000001, 14 );
  TEST_IMM_OP( 6,  slli, 0xffffffff80000000, 0x0000000000000001, 31 );

  TEST_IMM_OP( 7,  slli, 0xffffffffffffffff, 0xffffffffffffffff, 0  );
  TEST_IMM_OP( 8,  slli, 0xfffffffffffffffe, 0xffffffffffffffff, 1  );
  TEST_IMM_OP( 9,  slli, 0xffffffffffffff80, 0xffffffffffffffff, 7  );
  TEST_IMM_OP( 10, slli, 0xffffffffffffc000, 0xffffffffffffffff, 14 );
  TEST_IMM_OP( 11, slli, 0xffffffff80000000, 0xffffffffffffffff, 31 );

  TEST_IMM_OP( 12, slli, 0x0000000021212121, 0x0000000021212121, 0  );
  TEST_IMM_OP( 13, slli, 0x0000000042424242, 0x0000000021212121, 1  );
  TEST_IMM_OP( 14, slli, 0xffffffff90909080, 0x0000000021212121, 7  );
  TEST_IMM_OP( 15, slli, 0x0000000048484000, 0x0000000021212121, 14 );
  TEST_IMM_OP( 16, slli, 0xffffffff80000000, 0x0000000021212121, 31 );

  # Verify that shifts ignore top 32 (using true 64-bit values)

  TEST_IMM_OP( 44, slli, 0x0000000012345678, 0xffffffff12345678, 0 );
  TEST_IMM_OP( 45, slli, 0x0000000023456780, 0xffffffff12345678, 4 );
  TEST_IMM_OP( 46, slli, 0xffffffff92345678, 0x0000000092345678, 0 );
  TEST_IMM_OP( 47, slli, 0xffffffff93456780, 0x0000000099345678, 4 );

  #-------------------------------------------------------------
  # Source/Destination tests
  #-------------------------------------------------------------

  TEST_IMM_SRC1_EQ_DEST( 17, slli, 0x00000080, 0x00000001, 7 );

  #-------------------------------------------------------------
  # Bypassing tests
  #-------------------------------------------------------------

  TEST_IMM_DEST_BYPASS( 18, 0, slli, 0x0000000000000080, 0x0000000000000001, 7  );
  TEST_IMM_DEST_BYPASS( 19, 1, slli, 0x0000000000004000, 0x0000000000000001, 14 );
  TEST_IMM_DEST_BYPASS( 20, 2, slli, 0xffffffff80000000, 0x0000000000000001, 31 );

  TEST_IMM_SRC1_BYPASS( 21, 0, slli, 0x0000000000000080, 0x0000000000000001, 7  );
  TEST_IMM_SRC1_BYPASS( 22, 1, slli, 0x0000000000004000, 0x0000000000000001, 14 );
  TEST_IMM_SRC1_BYPASS( 23, 2, slli, 0xffffffff80000000, 0x0000000000000001, 31 );

  TEST_IMM_ZEROSRC1( 24, slli, 0, 31 );
  TEST_IMM_ZERODEST( 25, slli, 31, 28 );

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END

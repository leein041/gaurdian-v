`ifndef DEFINES_VH
`define DEFINES_VH 
// ==================================================
// 테스트 / 성능 / 이미지 -> 항목당 하나만 주석 해제하여 테스트
// ==================================================
// select (O: 테스트 통과 X: 테스트 실패)
 `define RELEASE_4_2  // (RESCOURCE:- ,BALANCE:- , PERFORMANCE:- )
// `define RELEASE_8_4  // (RESCOURCE:- ,BALANCE:- , PERFORMANCE:- )
// `define RELEASE_8_8  // (RESCOURCE:- ,BALANCE:- , PERFORMANCE:- )
// `define DEBUG_4_2 // (RESCOURCE:O ,BALANCE:O, PERFORMANCE: O)
// `define DEBUG_8_4 // (RESCOURCE:O ,BALANCE:O, PERFORMANCE: O)
// `define DEBUG_8_8  // (RESCOURCE:O ,BALANCE:O, PERFORMANCE: O)

// select
// `define RESOURCE  
 `define BALANCE 
// `define PERFORMANCE  

// select
 `define IMAGE_1
// `define IMAGE_3

// ==================================================
// debug mode
// ==================================================
`ifdef DEBUG_4_2
    `define DEBUG
`elsif DEBUG_8_4
    `define DEBUG
`elsif DEBUG_8_8
    `define DEBUG
`endif
 
// ==================================================
// recursive 4_2
// ==================================================
`ifdef RELEASE_4_2  
    `define RECURSIVE
    `define RECURSIVE_4_2
`elsif DEBUG_4_2
    `define RECURSIVE
    `define RECURSIVE_4_2
`elsif RELEASE_8_8
    `define RECURSIVE
    `define RECURSIVE_8_8
`elsif DEBUG_8_8
    `define RECURSIVE
    `define RECURSIVE_8_8
`endif 

// ==================================================
// streamline 
// ==================================================
`ifdef RELEASE_8_4
    `define STREAMLINE 
`elsif DEBUG_8_4
    `define STREAMLINE 
`endif 

//
`define MAX2(A, B) (((A) > (B)) ? (A) : (B))

`define BRAM_TYPE 0
`define URAM_TYPE 1

`endif // DEFINES_VH
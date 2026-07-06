`ifndef DEFINES_VH
`define DEFINES_VH 

`define MAX2(A, B) (((A) > (B)) ? (A) : (B))
// ==================================================
// 테스트 / 성능 / 이미지 -> 항목당 하나만 주석 해제하여 테스트
// ==================================================
// select (O: 테스트 통과 X: 테스트 실패)
// `define RELEASE_4_2  // (RESCOURCE:O ,BALANCE:O , PERFORMANCE:O )
// `define RELEASE_8_4  // (RESCOURCE:O ,BALANCE:O , PERFORMANCE:O )
// `define RELEASE_8_8  // (RESCOURCE:O ,BALANCE:O , PERFORMANCE:O )
// `define DEBUG_4_2 // (RESCOURCE:O ,BALANCE:O, PERFORMANCE: O)
// `define DEBUG_8_4 // (RESCOURCE:O ,BALANCE:O, PERFORMANCE: O)
 `define DEBUG_8_8  // (RESCOURCE:O ,BALANCE:O, PERFORMANCE: O)

// select
// `define RESOURCE  
// `define BALANCE 
 `define PERFORMANCE  

// select
// `define IMAGE_1
 `define IMAGE_3

 // input
 // 8_8 : 2 or 1
 `define L1_FILTER_GROUP_NUM 1
 `define L2_FILTER_GROUP_NUM 1
 `define L3_FILTER_GROUP_NUM 1


 `define MAX_FILTER_GROUP `MAX2(`L1_FILTER_GROUP_NUM,`MAX2(`L2_FILTER_GROUP_NUM,`L3_FILTER_GROUP_NUM))
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
 

`define BRAM_TYPE 0
`define URAM_TYPE 1
`define LUT_TYPE 2

`endif // DEFINES_VH
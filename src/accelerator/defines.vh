`ifndef DEFINES_VH
`define DEFINES_VH 
// ==================================================
//  **** select **** 
// ==================================================
// select
// `define RELEASE_4_2 
 `define RELEASE_8_4 
// `define RELEASE_8_8  
// `define DEBUG_4_2 
// `define DEBUG_8_4 
// `define DEBUG_8_8    

// select
// `define RESOURCE  
 `define BALANCE 
// `define PERFORMANCE  

// select
// `define IMAGE_1
 `define IMAGE_3

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
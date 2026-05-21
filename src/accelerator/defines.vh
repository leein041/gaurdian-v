`ifndef DEFINES_VH
`define DEFINES_VH 
// --------------- select architecture --------------- 
// select
// `define RELEASE_4_2 
// `define RELEASE_8_4 
// `define RELEASE_8_8  
 `define DEBUG_4_2 
// `define DEBUG_8_4 
// `define DEBUG_8_8    

// select
//`define IMAGE_1
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
// recursive select
// ==================================================
`ifdef RELEASE_4_2  
    `define RECURSIVE
`elsif DEBUG_4_2
    `define RECURSIVE
`elsif RELEASE_8_8
    `define RECURSIVE
`elsif DEBUG_8_8
    `define RECURSIVE
`endif 

// ==================================================
// streamline select
// ==================================================
`ifdef RELEASE_8_4
    `define STREAMLINE 
`elsif DEBUG_8_4
    `define STREAMLINE 
`endif 

//
`define MAX2(A, B) (((A) > (B)) ? (A) : (B))

`endif // DEFINES_VH
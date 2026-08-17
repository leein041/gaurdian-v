`ifndef DEFINES_VH
`define DEFINES_VH   
 
 `define DEBUG 
 // `define RELEASE

 // filter
 `define CONV_3X3_SIDE       3
 `define CONV_3X3_AREA       9
 `define CONV_3X3_STRIDE     1
 `define POOL_2X2_SIDE       2
 `define POOL_2X2_STRIDE     2
 `define MAX_POOL_SIDE       2 
 // layer 
 `define DDR_DEPTH           'h1000_0000 

`define LAYER_TYPE_CONV      0
`define LAYER_TYPE_MAXPOOL   1
`define LAYER_TYPE_UPSAMPLE  2
`define LAYER_TYPE_ROUTE     3
`define LAYER_TYPE_SHORTCUT  4
`define LAYER_TYPE_YOLO      5 
`define MAX_LAYER_TYPE       6 

`define BRAM_TYPE 0
`define URAM_TYPE 1
`define LUT_TYPE 2
`define REG_TYPE 3
 
`define CLOG2_SAFE(x) (((x) <= 1) ? 1 : $clog2(x))
`define MAX(x, y) ((x) < (y) ? (y) : (x))

`endif // DEFINES_VH
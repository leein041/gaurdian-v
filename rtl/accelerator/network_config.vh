`ifndef NETWORK_CONFIG_VH
`define NETWORK_CONFIG_VH

`define IPT_BIT   16
`define WGT_BIT   16
`define OPT_BIT   16
`define PSUM_BIT  48

`define LAYER_NUM 3

`define L0_TYPE       0
`define L0_IPT_SIDE           64
`define L0_IPT_AREA           4096
`define L0_OPT_SIDE           64
`define L0_OPT_AREA           4096
`define L0_TILE_OPT_SIDE      32
`define L0_TILE_OPT_AREA      1024
`define L0_CHANNEL            1
`define L0_FILTER             16
`define L0_KERNEL             3
`define L0_STRIDE             1
`define L0_PAD                1
`define L0_RELU               1
`define L0_WGT_DEPTH          144
`define L0_BIAS_DEPTH         16
`define L0_CHANNEL_GROUP_NUM  1
`define L0_FILTER_GROUP_NUM   2

`define L1_TYPE       0
`define L1_IPT_SIDE           64
`define L1_IPT_AREA           4096
`define L1_OPT_SIDE           64
`define L1_OPT_AREA           4096
`define L1_TILE_OPT_SIDE      32
`define L1_TILE_OPT_AREA      1024
`define L1_CHANNEL            16
`define L1_FILTER             32
`define L1_KERNEL             3
`define L1_STRIDE             1
`define L1_PAD                1
`define L1_RELU               1
`define L1_WGT_DEPTH          4608
`define L1_BIAS_DEPTH         32
`define L1_CHANNEL_GROUP_NUM  2
`define L1_FILTER_GROUP_NUM   4

`define L2_TYPE       0
`define L2_IPT_SIDE           64
`define L2_IPT_AREA           4096
`define L2_OPT_SIDE           64
`define L2_OPT_AREA           4096
`define L2_TILE_OPT_SIDE      32
`define L2_TILE_OPT_AREA      1024
`define L2_CHANNEL            32
`define L2_FILTER             1
`define L2_KERNEL             3
`define L2_STRIDE             1
`define L2_PAD                1
`define L2_RELU               0
`define L2_WGT_DEPTH          288
`define L2_BIAS_DEPTH         1
`define L2_CHANNEL_GROUP_NUM  4
`define L2_FILTER_GROUP_NUM   1

`define MAX_IPT_SIDE           64
`define MAX_IPT_AREA           4096
`define MAX_OPT_SIDE           64
`define MAX_OPT_AREA           4096
`define MAX_TILE_SIDE          32
`define MAX_TILE_AREA          1024
`define MAX_PAD_TILE_SIDE      34
`define MAX_PAD_TILE_AREA      1156
`define MAX_CHANNEL            32
`define MAX_FILTER             32
`define MAX_WGT_DEPTH          4608
`define MAX_BIAS_DEPTH         32
`define MAX_GROUP_FILTER       8
`define MAX_GROUP_CHANNEL      8
`define MAX_CHANNEL_GROUP_NUM  4
`define MAX_FILTER_GROUP_NUM   4

`endif
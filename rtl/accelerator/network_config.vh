`ifndef NETWORK_CONFIG_VH
`define NETWORK_CONFIG_VH

`define IPT_BIT   16
`define WGT_BIT   16
`define OPT_BIT   16
`define PSUM_BIT  48

`define LAYER_NUM 3

`define L0_TYPE       0
`define L0_IPT_SIDE           16
`define L0_IPT_AREA           256
`define L0_OPT_SIDE           16
`define L0_OPT_AREA           256
`define L0_TILE_OPT_SIDE      8
`define L0_TILE_OPT_AREA      64
`define L0_CHANNEL            1
`define L0_FILTER             8
`define L0_KERNEL             3
`define L0_STRIDE             1
`define L0_PAD                1
`define L0_RELU               1
`define L0_WGT_DEPTH          72
`define L0_BIAS_DEPTH         8
`define L0_CHANNEL_GROUP_NUM  1
`define L0_FILTER_GROUP_NUM   4

`define L1_TYPE       0
`define L1_IPT_SIDE           16
`define L1_IPT_AREA           256
`define L1_OPT_SIDE           16
`define L1_OPT_AREA           256
`define L1_TILE_OPT_SIDE      8
`define L1_TILE_OPT_AREA      64
`define L1_CHANNEL            8
`define L1_FILTER             4
`define L1_KERNEL             3
`define L1_STRIDE             1
`define L1_PAD                1
`define L1_RELU               1
`define L1_WGT_DEPTH          288
`define L1_BIAS_DEPTH         4
`define L1_CHANNEL_GROUP_NUM  4
`define L1_FILTER_GROUP_NUM   2

`define L2_TYPE       0
`define L2_IPT_SIDE           16
`define L2_IPT_AREA           256
`define L2_OPT_SIDE           16
`define L2_OPT_AREA           256
`define L2_TILE_OPT_SIDE      8
`define L2_TILE_OPT_AREA      64
`define L2_CHANNEL            4
`define L2_FILTER             1
`define L2_KERNEL             3
`define L2_STRIDE             1
`define L2_PAD                1
`define L2_RELU               0
`define L2_WGT_DEPTH          36
`define L2_BIAS_DEPTH         1
`define L2_CHANNEL_GROUP_NUM  2
`define L2_FILTER_GROUP_NUM   1

`define MAX_IPT_SIDE           16
`define MAX_IPT_AREA           256
`define MAX_OPT_SIDE           16
`define MAX_OPT_AREA           256
`define MAX_TILE_SIDE          8
`define MAX_TILE_AREA          64
`define MAX_PAD_TILE_SIDE      10
`define MAX_PAD_TILE_AREA      100
`define MAX_CHANNEL            8
`define MAX_FILTER             8
`define MAX_WGT_DEPTH          288
`define MAX_BIAS_DEPTH         8
`define MAX_GROUP_FILTER       2
`define MAX_GROUP_CHANNEL      2
`define MAX_CHANNEL_GROUP_NUM  4
`define MAX_FILTER_GROUP_NUM   4

`endif
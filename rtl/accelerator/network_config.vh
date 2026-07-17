`ifndef NETWORK_CONFIG_VH
`define NETWORK_CONFIG_VH

`define IPT_BIT   16
`define WGT_BIT   16
`define OPT_BIT   16

`define LAYER_NUM 3

`define L1_TYPE       0
`define L1_IPT_SIDE           8
`define L1_OPT_SIDE           8
`define L1_CHANNEL            1
`define L1_FILTER             4
`define L1_KERNEL             3
`define L1_STRIDE             1
`define L1_PAD                1
`define L1_RELU               1
`define L1_WGT_DEPTH          36
`define L1_BIAS_DEPTH         4
`define L1_CHANNEL_GROUP_NUM  1
`define L1_FILTER_GROUP_NUM   2

`define L2_TYPE       0
`define L2_IPT_SIDE           8
`define L2_OPT_SIDE           8
`define L2_CHANNEL            4
`define L2_FILTER             4
`define L2_KERNEL             3
`define L2_STRIDE             1
`define L2_PAD                1
`define L2_RELU               1
`define L2_WGT_DEPTH          144
`define L2_BIAS_DEPTH         4
`define L2_CHANNEL_GROUP_NUM  2
`define L2_FILTER_GROUP_NUM   2

`define L3_TYPE       0
`define L3_IPT_SIDE           8
`define L3_OPT_SIDE           8
`define L3_CHANNEL            4
`define L3_FILTER             1
`define L3_KERNEL             3
`define L3_STRIDE             1
`define L3_PAD                1
`define L3_RELU               0
`define L3_WGT_DEPTH          36
`define L3_BIAS_DEPTH         1
`define L3_CHANNEL_GROUP_NUM  2
`define L3_FILTER_GROUP_NUM   1

`define MAX_IPT_SIDE       8
`define MAX_IPT_AREA       64
`define MAX_TILE_SIDE      4
`define MAX_TILE_AREA      16
`define MAX_ACT_DPETH      128
`define MAX_CHANNEL        4
`define MAX_FILTER         4
`define MAX_WGT_DEPTH      144
`define MAX_BIAS_DEPTH     4
`define MAX_GROUP_FILTER   2
`define MAX_GROUP_CHANNEL  2

`endif
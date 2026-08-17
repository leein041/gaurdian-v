  
import json
import math
from generate_golden import generate_golden

CFG_PATH = "config/network.json"
OUT_PATH = "rtl/accelerator/config/network_config.vh"

TYPE = {
    "conv": 0,
    "maxpool": 1,
    "upsample": 2,
    "route": 3,
    "shortcut": 4,
    "yolo": 5,
}

# ----------------------------------------------------------------------
# 사용자 설정값 (HW 파라미터)
# ----------------------------------------------------------------------
MAX_GROUP_FILTER  = 2
MAX_GROUP_CHANNEL = 2
MAX_TILE_SIDE     = 8

NAME_COL_WIDTH = 28  # `define NAME` 정렬 폭


def emit(lines, name, value):
    """`define NAME VALUE` 한 줄을 정렬해서 추가한다."""
    lines.append(f"`define {name.ljust(NAME_COL_WIDTH)} {value}")


# ----------------------------------------------------------------------
# 레이어별 define 생성
# ----------------------------------------------------------------------
def emit_conv_layer(lines, idx, layer, ipt_side, ipt_channel):
    """conv 레이어의 `define들을 기록하고 (opt_side, opt_channel) 을 반환한다."""
    kernel  = layer["kernel"]
    stride  = layer["stride"]
    channel = layer["channel"]
    filt    = layer["filter"]
    pad_len = kernel // 2 if layer["pad"] else 0

    opt_side  = (ipt_side + 2 * pad_len - kernel) // stride + 1
    tile_ipt_side = MAX_TILE_SIDE
    tile_opt_side = MAX_TILE_SIDE // stride

    emit(lines, f"L{idx}_CONV_IDX",             idx) 
    emit(lines, f"L{idx}_IPT_SIDE",             ipt_side) 
    emit(lines, f"L{idx}_OPT_SIDE",             opt_side)
    emit(lines, f"L{idx}_OPT_AREA",             opt_side ** 2)
    emit(lines, f"L{idx}_TILE_IPT_SIDE",        tile_ipt_side)
    emit(lines, f"L{idx}_TILE_IPT_AREA",        tile_ipt_side ** 2)
    emit(lines, f"L{idx}_TILE_OPT_SIDE",        tile_opt_side)
    emit(lines, f"L{idx}_TILE_OPT_AREA",        tile_opt_side ** 2)
    emit(lines, f"L{idx}_TILE_NUM",             (ipt_side ** 2) // (tile_ipt_side ** 2))
    emit(lines, f"L{idx}_TILE_NUM_X",           ipt_side // tile_ipt_side)
    emit(lines, f"L{idx}_TILE_NUM_Y",           ipt_side // tile_ipt_side)
    emit(lines, f"L{idx}_CHANNEL",              channel)
    emit(lines, f"L{idx}_FILTER",               filt)
    emit(lines, f"L{idx}_KERNEL",               kernel)
    emit(lines, f"L{idx}_KERNEL_STRIDE",        stride)
    emit(lines, f"L{idx}_PAD",                  int(layer["pad"]))
    emit(lines, f"L{idx}_RELU",                 int(layer["relu"]))
    emit(lines, f"L{idx}_WGT_DEPTH",            (kernel ** 2) * channel * filt)
    emit(lines, f"L{idx}_BIAS_DEPTH",           filt)
    emit(lines, f"L{idx}_CHANNEL_GROUP_NUM",    math.ceil(channel / MAX_GROUP_CHANNEL))
    emit(lines, f"L{idx}_FILTER_GROUP_NUM",     math.ceil(filt / MAX_GROUP_FILTER))
    emit(lines, f"L{idx}_BL_REQ_LEN",           min(filt, MAX_GROUP_FILTER))
    emit(lines, f"L{idx}_BR_READ_LEN",          1)
    emit(lines, f"L{idx}_WL_REQ_LEN",           (kernel ** 2) * channel * min(filt, MAX_GROUP_FILTER))
    emit(lines, f"L{idx}_WR_READ_LEN",          (kernel ** 2) * min(channel, MAX_GROUP_CHANNEL))
    emit(lines, f"L{idx}_TR_READ_LEN",          (tile_ipt_side + 2 * pad_len) * (tile_ipt_side + 2 * pad_len))
    emit(lines, f"L{idx}_BL_BANK_DEPTH",        1)
    emit(lines, f"L{idx}_WL_BANK_DEPTH",        (kernel ** 2) * channel)
    emit(lines, f"L{idx}_BL_STRIDE",            min(filt, MAX_GROUP_FILTER))
    emit(lines, f"L{idx}_BR_STRIDE",            1)
    emit(lines, f"L{idx}_WL_FILT_GRP_STRIDE",   (kernel ** 2) * channel * min(filt, MAX_GROUP_FILTER))
    emit(lines, f"L{idx}_WR_CH_GRP_STRIDE",     (kernel ** 2) * min(channel, MAX_GROUP_CHANNEL))
    emit(lines, f"L{idx}_TL_ROW_STRIDE",        ipt_side * tile_ipt_side)
    emit(lines, f"L{idx}_TL_COL_STRIDE",        tile_ipt_side)
    emit(lines, f"L{idx}_TL_CH_GRP_STRIDE",     ipt_side ** 2)
    emit(lines, f"L{idx}_TS_ROW_STRIDE",        opt_side * tile_opt_side)
    emit(lines, f"L{idx}_TS_COL_STRIDE",        tile_opt_side)
    emit(lines, f"L{idx}_TS_CH_GRP_STRIDE",     opt_side ** 2)
    emit(lines, f"L{idx}_OBUF_TILE_ROW_STRIDE", opt_side * tile_opt_side)
    emit(lines, f"L{idx}_OBUF_TILE_CH_STRIDE",  opt_side ** 2)
    emit(lines, f"L{idx}_PSC_SUM_NUM",          math.ceil(channel / MAX_GROUP_CHANNEL))

    return opt_side, filt


def emit_maxpool_layer(lines, idx, layer, ipt_side, ipt_channel):
    """maxpool 레이어의 `define들을 기록하고 (opt_side, opt_channel) 을 반환한다.

    maxpool 은 가중치가 없고 채널 수를 바꾸지 않으므로,
    conv 레이어 대비 기하 정보(IPT/OPT SIDE·AREA, TILE, KERNEL, STRIDE)만 정의한다.
    실제 maxpool 컨트롤러 RTL 에서 추가 파라미터(예: TILE 단위 read/stride 정보)가
    필요하면 이 함수에 이어서 채워 넣으면 된다.
    """
    kernel = layer["kernel"]
    stride = layer["stride"]

    opt_side  = (ipt_side - kernel) // stride + 1
    tile_ipt_side = MAX_TILE_SIDE

    emit(lines, f"L{idx}_IPT_SIDE",      ipt_side)
    emit(lines, f"L{idx}_IPT_AREA",      ipt_side ** 2)
    emit(lines, f"L{idx}_OPT_SIDE",      opt_side)
    emit(lines, f"L{idx}_OPT_AREA",      opt_side * opt_side)
    emit(lines, f"L{idx}_TILE_IPT_SIDE", tile_ipt_side)
    emit(lines, f"L{idx}_TILE_IPT_AREA", tile_ipt_side ** 2)
    emit(lines, f"L{idx}_TILE_OPT_SIDE", tile_ipt_side)
    emit(lines, f"L{idx}_TILE_OPT_AREA", tile_ipt_side ** 2)
    emit(lines, f"L{idx}_CHANNEL",       ipt_channel)
    emit(lines, f"L{idx}_KERNEL",        kernel)
    emit(lines, f"L{idx}_STRIDE",        stride)

    return opt_side, ipt_channel


LAYER_EMITTERS = {
    "conv": emit_conv_layer,
    "maxpool": emit_maxpool_layer,
}


# ----------------------------------------------------------------------
# main
# ----------------------------------------------------------------------
def main():
    generate_golden()

    cfg = json.load(open(CFG_PATH))
    layers = cfg["layers"]

    conv_layer_num = 0
    for  layer in  layers: 
        if layer["type"] == "conv":
            conv_layer_num += 1
            

    lines = ["`ifndef NETWORK_CONFIG_VH", "`define NETWORK_CONFIG_VH", ""]

    emit(lines, "IPT_BIT", cfg["bitwidth"]["ipt"])
    emit(lines, "WGT_BIT", cfg["bitwidth"]["wgt"])
    emit(lines, "OPT_BIT", cfg["bitwidth"]["opt"])
    emit(lines, "PSUM_BIT", 48)
    lines.append("")
    emit(lines, "CONV_LAYER_NUM",  conv_layer_num)
    lines.append("")

    max_bias_depth = 0
    max_wgt_depth  = 0
    max_filter     = 0
    max_channel    = 0
    max_ipt_side   = 0

    # 레이어를 지나며 실제 입력 side/channel 을 이어서 추적한다.
    # (기존 코드는 모든 레이어에 최초 입력 side 를 그대로 재사용하는 버그가 있었음)
    cur_side    = cfg["input"]["side"]
    cur_channel = cfg["input"]["channel"]

    conv_idx = 0

    for idx, layer in enumerate(layers): 

        max_ipt_side = max(max_ipt_side, cur_side)

        emitter = LAYER_EMITTERS.get(layer["type"])
        if emitter is not None:
            cur_side, cur_channel = emitter(lines, conv_idx, layer, cur_side, cur_channel)

        if layer["type"] == "conv":
            max_channel    = max(max_channel, layer["channel"])
            max_filter     = max(max_filter, layer["filter"])
            max_wgt_depth  = max(max_wgt_depth, layer["kernel"] ** 2 * layer["channel"] * layer["filter"])
            max_bias_depth = max(max_bias_depth, layer["filter"])
            conv_idx += 1
        
        lines.append("")

    emit(lines, "MAX_BIAS_DEPTH",        int(max_bias_depth))
    emit(lines, "MAX_WGT_DEPTH",         int(max_wgt_depth))
    emit(lines, "MAX_FILTER",            int(max_filter))
    emit(lines, "MAX_GROUP_FILTER",      MAX_GROUP_FILTER)
    emit(lines, "MAX_FILTER_GROUP_NUM",  int(max_filter / MAX_GROUP_FILTER))
    emit(lines, "MAX_TILE_SIDE",         MAX_TILE_SIDE)
    emit(lines, "MAX_TILE_AREA",         MAX_TILE_SIDE ** 2)
    emit(lines, "MAX_TILE_NUM",          int((max_ipt_side ** 2) / (MAX_TILE_SIDE ** 2)))
    emit(lines, "MAX_CHANNEL",           int(max_channel))
    emit(lines, "MAX_GROUP_CHANNEL",     MAX_GROUP_CHANNEL)
    emit(lines, "MAX_CHANNEL_GROUP_NUM", int(max_channel / MAX_GROUP_CHANNEL))
    emit(lines, "MAX_IPT_SIDE",          int(max_ipt_side))
    emit(lines, "MAX_IPT_AREA",          int(max_ipt_side ** 2))
    emit(lines, "MAX_OPT_SIDE",          int(max_ipt_side))
    emit(lines, "MAX_OPT_AREA",          int(max_ipt_side ** 2))
    emit(lines, "MAX_PAD_TILE_SIDE",     int(MAX_TILE_SIDE + 2))
    emit(lines, "MAX_PAD_TILE_AREA",     int((MAX_TILE_SIDE + 2) ** 2))

    lines.append("")
    lines.append("`endif")

    with open(OUT_PATH, "w") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    main()
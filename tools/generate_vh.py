import json
import math
from generate_golden import generate_golden

def emit_define(f, name, value, width=20):
    f.write(f"`define {name.ljust(width)} {value}\n")

generate_golden()

cfg = json.load(open("config/network.json"))
layers = cfg["layers"] 
TYPE = {
    "conv":0,
    "maxpool":1,
    "upsample":2,
    "route":3,
    "shortcut":4,
    "yolo":5
}

# user define
max_group_filter        = 2
max_group_channel       = 2
max_tile_side           = 8
# 
max_bias_depth          = 0
max_wgt_depth           = 0
max_filter              = 0
max_filter_group_num    = 0 
max_tile_num            = 0
max_channel             = 0
max_channel_group_num   = 0
max_ipt_side            = 0

 
text=[]

text.append("`ifndef NETWORK_CONFIG_VH")
text.append("`define NETWORK_CONFIG_VH")
text.append("")
 
text.append(f"`define IPT_BIT   { cfg["bitwidth"]["ipt"]}")
text.append(f"`define WGT_BIT   { cfg["bitwidth"]["wgt"]}")
text.append(f"`define OPT_BIT   { cfg["bitwidth"]["opt"]}")
text.append(f"`define PSUM_BIT  { 48}")
text.append("") 
text.append(f"`define LAYER_NUM {int(len(layers))}") 
text.append("") 
    
# layer config
ipt_side = cfg["input"]["side"]    
for i,l in enumerate(layers):

    idx=i

    text.append(f"`define L{idx}_TYPE       {TYPE[l['type']]}")

    if l["type"]=="conv": 
        text.append(f"`define L{idx}_IPT_SIDE               {ipt_side}")
        text.append(f"`define L{idx}_IPT_AREA               {ipt_side*ipt_side}")
        text.append(f"`define L{idx}_OPT_SIDE               {ipt_side}")
        text.append(f"`define L{idx}_OPT_AREA               {ipt_side*ipt_side}")
        text.append(f"`define L{idx}_TILE_IPT_SIDE          {max_tile_side}")
        text.append(f"`define L{idx}_TILE_IPT_AREA          {max_tile_side*max_tile_side}")
        text.append(f"`define L{idx}_TILE_OPT_SIDE          {max_tile_side}")
        text.append(f"`define L{idx}_TILE_OPT_AREA          {max_tile_side*max_tile_side}")
        text.append(f"`define L{idx}_TILE_NUM               {int((ipt_side*ipt_side)/(max_tile_side*max_tile_side))}")
        text.append(f"`define L{idx}_TILE_NUM_X             {int(ipt_side/max_tile_side)}")
        text.append(f"`define L{idx}_TILE_NUM_Y             {int(ipt_side/max_tile_side)}")
        text.append(f"`define L{idx}_CHANNEL                {l['channel']}")
        text.append(f"`define L{idx}_FILTER                 {l['filter']}")
        text.append(f"`define L{idx}_KERNEL                 {l['kernel']}")
        text.append(f"`define L{idx}_STRIDE                 {l['stride']}")
        text.append(f"`define L{idx}_PAD                    {int(l['pad'])}")
        text.append(f"`define L{idx}_RELU                   {int(l['relu'])}") 
        text.append(f"`define L{idx}_WGT_DEPTH              {l['kernel'] * l['kernel'] * l['channel'] * l['filter']}")
        text.append(f"`define L{idx}_BIAS_DEPTH             { l['filter']}")
        text.append(f"`define L{idx}_CHANNEL_GROUP_NUM      { math.ceil(l['channel'] / max_group_channel)}")
        text.append(f"`define L{idx}_FILTER_GROUP_NUM       { math.ceil(l['filter'] / max_group_filter)}")
        text.append(f"`define L{idx}_BL_REQ_LEN             {min(l['filter'],max_group_filter)}")
        text.append(f"`define L{idx}_BR_READ_LEN            {1}") 
        text.append(f"`define L{idx}_WL_REQ_LEN             {l['kernel'] * l['kernel'] * l['channel'] * min(l['filter'],max_group_filter)}")
        text.append(f"`define L{idx}_WR_READ_LEN            {l['kernel'] * l['kernel'] * min(l['channel'],max_group_channel)}")
        text.append(f"`define L{idx}_TR_READ_LEN            {(max_tile_side+2*int(l['pad']))*(max_tile_side+2*int(l['pad']))}")
        text.append(f"`define L{idx}_BL_BANK_DEPTH          {1}")
        text.append(f"`define L{idx}_WL_BANK_DEPTH          {l['kernel'] * l['kernel'] * l['channel']}")
        text.append(f"`define L{idx}_BL_STRIDE              {min(l['filter'],max_group_filter)}")
        text.append(f"`define L{idx}_BR_STRIDE              {1}")
        text.append(f"`define L{idx}_WL_FILT_GRP_STRIDE     {l['kernel'] * l['kernel'] * l['channel'] * min(l['filter'],max_group_filter)}")
        text.append(f"`define L{idx}_WR_CH_GRP_STRIDE       {l['kernel'] * l['kernel'] * min(l['channel'],max_group_channel)}")
        text.append(f"`define L{idx}_TL_ROW_STRIDE          {ipt_side * max_tile_side}")
        text.append(f"`define L{idx}_TL_COL_STRIDE          {max_tile_side}")
        text.append(f"`define L{idx}_TL_CH_GRP_STRIDE       {ipt_side * ipt_side}")
        text.append(f"`define L{idx}_TS_ROW_STRIDE          {ipt_side * max_tile_side}")
        text.append(f"`define L{idx}_TS_COL_STRIDE          {max_tile_side}")
        text.append(f"`define L{idx}_TS_CH_GRP_STRIDE       {ipt_side * ipt_side}")
        text.append(f"`define L{idx}_OBUF_TILE_ROW_STRIDE   {ipt_side * max_tile_side}")
        text.append(f"`define L{idx}_OBUF_TILE_CH_STRIDE    {ipt_side * ipt_side}")
        text.append(f"`define L{idx}_PSC_SUM_NUM            { math.ceil(l['channel'] / max_group_channel)}")
     
    text.append("")

# create MAX DATA
for layer in layers: 
    if layer["type"] == "conv":
        max_channel = max(max_channel, layer["channel"])
        max_filter = max(max_filter, layer["filter"])

        wgt_depth = layer["channel"] * layer["filter"] * 9
        bias_depth = layer["filter"]

        max_wgt_depth = max(max_wgt_depth, wgt_depth)
        max_bias_depth = max(max_bias_depth, bias_depth)
 

cur_side = cfg["input"]["side"]
cur_act_depth = 0
cur_channel = cfg["input"]["channel"]

for layer in cfg["layers"]:

    layer["input_side"] = cur_side
    layer["input_channel"] = cur_channel
    
    max_ipt_side = max(max_ipt_side, cur_side) 


    if layer["type"] == "conv":

        pad = layer["kernel"]//2 if layer["pad"] else 0

        out_side = (cur_side + 2*pad - layer["kernel"])//layer["stride"] + 1

        cur_side = out_side
        cur_channel = layer["filter"]

    elif layer["type"] == "maxpool":

        out_side = (cur_side-layer["kernel"])//layer["stride"] + 1

        cur_side = out_side
        
        
text.append(f"`define MAX_BIAS_DEPTH         {int(max_bias_depth)}")
text.append(f"`define MAX_WGT_DEPTH          {int(max_wgt_depth)}")
text.append(f"`define MAX_FILTER             {int(max_filter)}")
text.append(f"`define MAX_GROUP_FILTER       {int(max_group_filter)}")
text.append(f"`define MAX_FILTER_GROUP_NUM   {int(max_filter/max_group_filter)}")
text.append(f"`define MAX_TILE_SIDE          {int(max_tile_side)}")
text.append(f"`define MAX_TILE_AREA          {int(max_tile_side*max_tile_side)}")  
text.append(f"`define MAX_TILE_NUM           {int((max_ipt_side*max_ipt_side)/(max_tile_side*max_tile_side))}")
text.append(f"`define MAX_CHANNEL            {int(max_channel)}")
text.append(f"`define MAX_GROUP_CHANNEL      {int(max_group_channel)}")
text.append(f"`define MAX_CHANNEL_GROUP_NUM  {int(max_channel/max_group_channel)}")
text.append(f"`define MAX_IPT_SIDE           {int(max_ipt_side)}")
text.append(f"`define MAX_IPT_AREA           {int(max_ipt_side*max_ipt_side)}") 
text.append(f"`define MAX_OPT_SIDE           {int(max_ipt_side)}")
text.append(f"`define MAX_OPT_AREA           {int(max_ipt_side*max_ipt_side)}") 
text.append(f"`define MAX_PAD_TILE_SIDE      {int(max_tile_side+2)}")
text.append(f"`define MAX_PAD_TILE_AREA      {int((max_tile_side+2)*(max_tile_side+2))}")  

text.append("")

text.append("`endif")

open("rtl/accelerator/config/network_config.vh","w").write("\n".join(text))
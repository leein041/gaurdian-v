import numpy as np
import json


FRAC = 8

def float_to_q88(x):
    return np.int16(np.round(x * (1 << FRAC)))

def q88_to_hex(x):
    return f"{np.uint16(x):04X}"

def random_weight(shape): 
    w = np.random.uniform(-1.0, 1.0, size=shape)
    return float_to_q88(w)       

def random_bias(ch): 
    b = np.random.uniform(-1.0, 1.0, size=ch)
    return float_to_q88(b)

def conv2d(inp,w,b):

    cin,h,wid=inp.shape

    cout,_,kh,kw=w.shape

    pad=1

    out=np.zeros((cout,h,wid),dtype=np.int32)

    padded=np.pad(inp,
                  ((0,0),(pad,pad),(pad,pad)),
                  mode='constant')

    for oc in range(cout):
        for y in range(h):
            for x in range(wid):
                s=0
                for ic in range(cin):
                    for ky in range(3):
                        for kx in range(3):
                            s+=int(padded[ic,y+ky,x+kx])*int(w[oc,ic,ky,kx])

                s>>=8              #Q8.8 x Q8.8
                s+=int(b[oc])
                out[oc,y,x]=s
    return out
  
def relu(x):
  x=np.maximum(x,0)
  x=np.clip(x,-32768,32767)
  return x.astype(np.int16)

def save_tensor(fname,t): 
    with open(fname,"w") as f: 
        for v in t.flatten(): 
            f.write(q88_to_hex(v)+"\n")
            
def maxpool2d(inp):
    cin, h, w = inp.shape

    out_h = h // 2
    out_w = w // 2

    out = np.zeros((cin, out_h, out_w), dtype=np.int16)

    for c in range(cin):
        for y in range(out_h):
            for x in range(out_w):
                patch = inp[c,
                            y*2:y*2+2,
                            x*2:x*2+2]
                out[c, y, x] = np.max(patch)

    return out
# ============================================================
# ================= Layer Setting ============================
# ============================================================
def generate_golden(): 
    
    cfg=json.load(open("config/network.json"))

    layers=cfg["layers"]

    for i, layer in enumerate(layers):
        print(i, layer["type"])

    side=cfg["input"]["side"]

    inp = (np.arange(side * side) / 256.0).reshape(1, side, side)
    #inp=np.random.uniform(0,1,size=(1,side,side)) 
    inp=float_to_q88(inp)

    x=inp

    weights=[]
    bias=[]
    conv_output=[]

    for layer in layers:

        if layer["type"]=="conv":

            w=random_weight(
                (
                    layer["filter"],
                    layer["channel"],
                    3,
                    3
                )
            )

            b=random_bias(layer["filter"])

            weights.append(w)
            bias.append(b) 
            x=conv2d(x,w,b)
            print("after conv", x.shape)

            if layer["relu"]:
                x=relu(x)
                
            conv_output.append(x)

        elif layer["type"]=="maxpool":

            x=maxpool2d(x)
            print("after pool", x.shape)



    save_tensor("sim/accelerator_sim/golden/input.txt",inp) 

    print(conv_output[0].shape)
    print(conv_output[1].shape)

    conv_num = len(weights)
    conv_idx=1

    for layer in layers:

        if layer["type"] == "conv": 
            save_tensor(
                f"sim/accelerator_sim/golden/layer{conv_idx}_weight.txt",
                weights[conv_idx-1]
            )

            save_tensor(
                f"sim/accelerator_sim/golden/layer{conv_idx}_bias.txt",
                bias[conv_idx-1]
            )

            if conv_num == conv_idx:
                save_tensor(
                    f"sim/accelerator_sim/golden/result.txt",
                    conv_output[conv_idx-1]
                )
            else:
                save_tensor(
                    f"sim/accelerator_sim/golden/layer{conv_idx}_output.txt",
                    conv_output[conv_idx-1]
                )
            conv_idx+=1 

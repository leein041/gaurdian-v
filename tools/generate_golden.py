"""
golden reference model 생성 스크립트

가속기(RTL) 검증용 골든 데이터(입력, 가중치, bias, 각 레이어 출력)를
Q8.8 고정소수점(fixed-point) 형식으로 만들어서 sim/accelerator_sim/golden/ 에 저장한다.
"""

import numpy as np
import json

# Q8.8 포맷: 정수부 8bit + 소수부 8bit -> 실수값에 2^8(=256)을 곱해서 정수(int16)로 표현
FRAC = 8


def float_to_q88(x):
    """실수(float) -> Q8.8 정수(int16) 로 변환. (x * 256 을 반올림)"""
    return np.int16(np.round(x * (1 << FRAC)))


def q88_to_hex(x):
    """Q8.8 정수(int16) -> 4자리 hex 문자열로 변환 (파일에 저장할 때 사용, 2의 보수 표현을 위해 uint16으로 캐스팅)"""
    return f"{np.uint16(x):04X}"


def random_weight(shape):
    """-1.0 ~ 1.0 사이 랜덤 가중치를 생성해서 Q8.8로 변환"""
    w = np.random.uniform(-1.0, 1.0, size=shape)
    return float_to_q88(w)


def random_bias(ch):
    """-1.0 ~ 1.0 사이 랜덤 bias(채널 개수만큼)를 생성해서 Q8.8로 변환"""
    b = np.random.uniform(-1.0, 1.0, size=ch)
    return float_to_q88(b)


def saturate_int16(x):
    """int16 표현 범위(-32768 ~ 32767)를 벗어나지 않도록 클리핑 (HW의 saturation 동작 흉내)"""
    return np.clip(x, -32768, 32767)


def conv2d(inp, w, b, stride=1, pad=None):
    """
    3x3 컨볼루션 연산 (Q8.8 고정소수점, RTL 동작과 동일한 방식으로 소프트웨어 계산)

    inp    : (Cin, H, W)          입력 특징맵 (Q8.8, int16)
    w      : (Cout, Cin, Kh, Kw)  가중치 (Q8.8, int16)
    b      : (Cout,)              bias (Q8.8, int16)
    stride : 컨볼루션 stride (1 또는 2 지원)
    pad    : 패딩 크기. None이면 커널 크기로부터 자동 계산 (3x3 kernel -> pad=1, "same" 기준)

    반환값 : (Cout, Hout, Wout) 출력 특징맵 (Q8.8, int16, saturate 적용됨)
    """
    cin, h, wid = inp.shape
    cout, _, kh, kw = w.shape

    if pad is None:
        pad = kh // 2  # 3x3 커널 기준 pad=1 (stride=1일 때 입출력 크기가 같아지는 "same" 패딩)

    # 출력 크기 공식: (입력크기 + 2*pad - 커널크기) / stride + 1
    out_h = (h + 2 * pad - kh) // stride + 1
    out_w = (wid + 2 * pad - kw) // stride + 1

    out = np.zeros((cout, out_h, out_w), dtype=np.int32)

    # 가장자리(edge) 계산을 위해 입력 주변을 0으로 채움 (zero padding)
    padded = np.pad(inp,
                     ((0, 0), (pad, pad), (pad, pad)),
                     mode='constant')

    for oc in range(cout):            # 출력 채널 방향으로 순회
        for y in range(out_h):        # 출력 세로 위치
            for x in range(out_w):    # 출력 가로 위치

                # stride만큼 건너뛰며 입력에서의 시작 좌표를 구함
                # stride=1 -> 한 칸씩, stride=2 -> 두 칸씩 이동
                iy = y * stride
                ix = x * stride

                s = 0
                for ic in range(cin):        # 입력 채널 방향으로 누적합
                    for ky in range(kh):      # 커널 세로
                        for kx in range(kw):  # 커널 가로
                            s += int(padded[ic, iy + ky, ix + kx]) * int(w[oc, ic, ky, kx])

                s >>= FRAC            # Q8.8 x Q8.8 = Q16.16 이므로 다시 Q8.8로 맞추기 위해 8bit shift
                s += int(b[oc])       # bias 더하기 (Q8.8)
                out[oc, y, x] = saturate_int16(s)  # int16 범위로 saturate

    return out


def relu(x):
    """ReLU 활성화 함수: 음수는 0으로, 양수는 그대로"""
    x = np.maximum(x, 0)
    return x


def save_tensor(fname, t):
    """텐서(다차원 배열)를 1차원으로 펼쳐서(flatten) 한 줄에 hex 값 하나씩 텍스트 파일로 저장 (RTL testbench에서 읽기 위함)"""
    with open(fname, "w") as f:
        for v in t.flatten():
            f.write(q88_to_hex(v) + "\n")


def maxpool2d(inp, kernel=2, stride=2):
    """
    2D max pooling.

    inp    : (Cin, H, W) 입력 특징맵
    kernel : 풀링 윈도우 크기 (기본 2x2)
    stride : 풀링 stride (기본 2)

    반환값 : (Cin, Hout, Wout) 로, 각 kernel x kernel 영역에서 최댓값만 뽑아낸 결과
    """
    cin, h, w = inp.shape

    out_h = (h - kernel) // stride + 1
    out_w = (w - kernel) // stride + 1

    out = np.zeros((cin, out_h, out_w), dtype=np.int16)

    for c in range(cin):              # 채널별로 독립적으로 수행
        for y in range(out_h):
            for x in range(out_w):
                # 현재 위치에서 kernel x kernel 크기만큼 잘라낸 뒤 그 중 최댓값 사용
                patch = inp[c,
                            y * stride: y * stride + kernel,
                            x * stride: x * stride + kernel]
                out[c, y, x] = np.max(patch)

    return out


def route_half(x, groups=2, group_id=1):
    """
    Darknet 스타일 "route half" 기능.

    입력 x: (C, H, W)
    채널(C)을 groups개로 등분한 뒤, group_id번째 조각만 잘라서 반환한다.
    YOLOv3-tiny 등에서 흔히 쓰이는 route half는 groups=2, group_id=1 로,
    채널의 "뒷 절반"만 다음 레이어로 넘기는 동작이다.

    groups=2, group_id=0 -> 앞 절반
    groups=2, group_id=1 -> 뒷 절반 (일반적인 "route half")
    """
    c, h, w = x.shape
    assert c % groups == 0, f"channel {c} 는 groups={groups} 로 나누어 떨어지지 않습니다"

    chunk = c // groups
    start = group_id * chunk
    end = start + chunk

    return x[start:end, :, :].copy()


def concat_channels(tensors):
    """
    Darknet 스타일 route의 "concat" 기능.

    여러 레이어의 출력을 채널(axis=0) 방향으로 이어붙인다.
    tensors: (Cin_i, H, W) 모양의 텐서 리스트. 모든 텐서의 H, W는 동일해야 한다.

    반환값 : (sum(Cin_i), H, W)
    """
    hs = {t.shape[1] for t in tensors}
    ws = {t.shape[2] for t in tensors}
    assert len(hs) == 1 and len(ws) == 1, \
        "concat 대상 텐서들의 H, W가 서로 달라서 이어붙일 수 없습니다"

    return np.concatenate(tensors, axis=0)


def resolve_route_index(layer_idx, ref_idx):
    """
    route에서 참조하는 레이어 인덱스를 실제 all_outputs 리스트 인덱스로 변환.

    darknet 컨벤션과 동일하게:
      - ref_idx < 0 이면 현재 레이어(layer_idx) 기준 상대 인덱스 (-1 = 바로 이전 레이어)
      - ref_idx >= 0 이면 0번째 레이어부터 센 절대 인덱스
    """
    return layer_idx + ref_idx if ref_idx < 0 else ref_idx


# ============================================================
# ================= Layer Setting ===========================
# ============================================================
def generate_golden():
    """
    config/network.json 에 정의된 레이어 순서대로
    입력 -> conv(+relu) / maxpool / route(half, concat) 을 실제로 계산해서
    골든 입력/가중치/bias/각 레이어 출력을 파일로 저장한다.

    지원하는 route 설정 (config/network.json 내 layer 항목 예시):
      # route half (channel 절반만 사용)
      {"type": "route", "layers": [-1], "groups": 2, "group_id": 1}

      # concat (여러 레이어 출력을 채널 방향으로 이어붙임)
      {"type": "route", "layers": [-1, 8]}
    """

    cfg = json.load(open("config/network.json"))
    layers = cfg["layers"]

    for i, layer in enumerate(layers):
        print(i, layer["type"])

    side = cfg["input"]["side"]

    # 0~1 사이 랜덤 입력을 만들어서 Q8.8로 변환 (실제로는 이미지 등 실제 데이터가 들어갈 자리)
    inp = np.random.uniform(0, 1, size=(1, side, side))
    inp = float_to_q88(inp)

    x = inp

    weights = []       # 레이어별 가중치 저장 (conv 레이어만)
    bias = []           # 레이어별 bias 저장 (conv 레이어만)
    conv_output = []    # 레이어별 conv(+relu) 출력 저장 (conv 레이어만)

    all_outputs = []    # 전체 레이어 순서대로 출력을 저장 (route/concat이 참조하기 위함)

    for layer_idx, layer in enumerate(layers):

        if layer["type"] == "conv":

            w = random_weight(
                (
                    layer["filter"],
                    layer["channel"],
                    3,
                    3,
                )
            )
            b = random_bias(layer["filter"])

            weights.append(w)
            bias.append(b)

            # config에 stride가 없으면 기본값 1, pad 옵션이 없으면 기본적으로 패딩 적용(True)
            stride = layer.get("stride", 1)
            pad = (3 // 2) if layer.get("pad", True) else 0

            x = conv2d(x, w, b, stride=stride, pad=pad)
            print("after conv", x.shape)

            if layer["relu"]:
                x = relu(x)

            conv_output.append(x)

        elif layer["type"] == "maxpool":

            x = maxpool2d(x)
            print("after pool", x.shape)

        elif layer["type"] == "route":

            # layers: 참조할 레이어 인덱스 리스트 (darknet 컨벤션, resolve_route_index 참고)
            ref_idxs = layer["layers"]
            resolved = [all_outputs[resolve_route_index(layer_idx, r)] for r in ref_idxs]

            if len(resolved) == 1 and "groups" in layer:
                # route half (혹은 groups개로 나눈 조각 중 하나를 선택하는 일반형)
                x = route_half(
                    resolved[0],
                    groups=layer["groups"],
                    group_id=layer.get("group_id", 0),
                )
                print("after route(half)", x.shape,
                      "from layer", ref_idxs[0],
                      "groups", layer["groups"],
                      "group_id", layer.get("group_id", 0))
            elif len(resolved) == 1:
                # 단일 참조인데 groups가 없으면 그냥 해당 레이어 출력을 그대로 전달
                x = resolved[0].copy()
                print("after route(passthrough)", x.shape, "from layer", ref_idxs[0])
            else:
                # 참조 레이어가 여러 개면 concat
                x = concat_channels(resolved)
                print("after route(concat)", x.shape, "from layers", ref_idxs)

            # route 결과도 RTL 검증용 골든 파일로 저장
            save_tensor(f"sim/accelerator_sim/golden/layer{layer_idx}_route.txt", x)

        all_outputs.append(x)

    save_tensor("sim/accelerator_sim/golden/input.txt", inp)

    for idx, out in enumerate(conv_output):
        print(f"conv_output[{idx}].shape =", out.shape)

    conv_num = len(weights)
    layer_num = len(layers)
    conv_idx = 0
    layer_idx = 0

    for layer in layers: 
        if layer["type"] == "conv":

            save_tensor(
                f"sim/accelerator_sim/golden/layer{layer_idx}_weight.txt",
                weights[conv_idx]
            )

            save_tensor(
                f"sim/accelerator_sim/golden/layer{layer_idx}_bias.txt",
                bias[conv_idx]
            )

            # 마지막 conv 레이어의 출력은 result.txt 로, 나머지는 layer{N}_output.txt 로 저장
            if layer_idx == layer_num - 1 :
                save_tensor(
                    "sim/accelerator_sim/golden/result.txt",
                    conv_output[conv_idx]
                )
            else:
                save_tensor(
                    f"sim/accelerator_sim/golden/layer{layer_idx}_output.txt",
                    conv_output[conv_idx]
                ) 
            conv_idx += 1 
        layer_idx += 1
"""Bake a Flux.2 LoRA (mixed diffusers/BFL key names) into a ComfyUI fp8mixed UNET.

Streams one tensor at a time. fp8 layers are dequantized with their scalar
weight_scale, patched, then requantized with a fresh scale (absmax / 448).
Peak RSS is ~60 GB for the 35 GB Flux.2 dev UNET (~3.5 min on CPU):

    nix-shell -p 'python3.withPackages(p: [p.torch p.safetensors p.numpy])' --run \
      'python merge_flux2_lora.py flux2_dev_fp8mixed.safetensors \
         Flux_2-Turbo-LoRA_comfyui.safetensors flux2_dev_turbo_fp8mixed.safetensors'
"""
import re, sys, torch
from safetensors import safe_open
from safetensors.torch import save_file

unet_p, lora_p, out_p = sys.argv[1:4]
strength = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
FP8_MAX = torch.finfo(torch.float8_e4m3fn).max
QKV = {"to_q": ("img_attn.qkv", 0), "to_k": ("img_attn.qkv", 1), "to_v": ("img_attn.qkv", 2),
       "add_q_proj": ("txt_attn.qkv", 0), "add_k_proj": ("txt_attn.qkv", 1), "add_v_proj": ("txt_attn.qkv", 2),
       "to_out.0": ("img_attn.proj", None), "to_add_out": ("txt_attn.proj", None)}

lora = safe_open(lora_p, "pt")
patches = {}  # unet weight key -> list of (slice_index|None, A, B)
for k in lora.keys():
    if not k.endswith(".lora_A.weight"):
        continue
    mod = k[:-len(".lora_A.weight")].removeprefix("diffusion_model.")
    m = re.fullmatch(r"transformer\.transformer_blocks\.(\d+)\.attn\.(.+)", mod)
    if m:
        target, idx = QKV[m.group(2)]
        target = "double_blocks.%s.%s" % (m.group(1), target)
    else:
        target, idx = mod, None
    patches.setdefault(target + ".weight", []).append(
        (idx, lora.get_tensor(k), lora.get_tensor(k.replace("lora_A", "lora_B"))))

out, applied = {}, 0
with safe_open(unet_p, "pt") as u:
    meta = u.metadata()
    keys = list(u.keys())
    for k in keys:
        t = u.get_tensor(k)
        if k in patches:
            scale_k = k[:-len("weight")] + "weight_scale"
            if t.dtype == torch.float8_e4m3fn:
                w = t.float() * u.get_tensor(scale_k).float()
            else:
                w = t.float()
            for idx, A, B in patches.pop(k):
                d = (B.float() @ A.float()) * strength
                if idx is None:
                    assert d.shape == w.shape, (k, d.shape, w.shape)
                    w += d
                else:
                    n = w.shape[0] // 3
                    w[idx * n:(idx + 1) * n] += d
                applied += 1
            if t.dtype == torch.float8_e4m3fn:
                s = (w.abs().max() / FP8_MAX).clamp(min=1e-12)
                t = (w / s).clamp(-FP8_MAX, FP8_MAX).to(torch.float8_e4m3fn)
                out[scale_k] = s.reshape(u.get_tensor(scale_k).shape).to(torch.float32)
            else:
                t = w.to(t.dtype)
            del w
        if k not in out:
            out[k] = t
assert not patches, "unmatched LoRA targets: %s" % sorted(patches)[:5]
print("applied", applied, "lora pairs to", len(keys), "tensors", flush=True)
save_file(out, out_p, metadata=meta)
print("wrote", out_p)

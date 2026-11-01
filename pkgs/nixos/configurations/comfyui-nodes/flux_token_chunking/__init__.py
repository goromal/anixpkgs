"""FluxTokenChunking: run Flux(.2) transformer blocks in token chunks.

Every per-token op in a Flux block (QKV projection, MLP, output projection) is
computed CHUNK tokens at a time instead of across the whole sequence at once, so
the activation peak no longer scales with resolution. Attention still sees the
full sequence. The math is unchanged; only the memory peak drops, at the cost
of re-running SingleStreamBlock.linear1 (its QKV half is gathered in a first
pass, its MLP half recomputed per chunk in a second).

Installed as "dit" block-replace patches, so only models routed through this
node are affected and ComfyUI's weight management sees the untouched module
tree. Sequences of at most `chunk_tokens` tokens, and the per-token-range
modulation path (timestep_zero_index), use the stock block.
"""
import torch

from comfy.ldm.flux.layers import apply_mod, modulated_norm
from comfy.ldm.modules.attention import AttentionTensorContainer
from comfy.ldm.flux.math import apply_rope1, attention
from comfy.ldm.modules.attention import optimized_attention


def _spans(n, chunk):
    return [(s, min(s + chunk, n)) for s in range(0, n, chunk)]


def _attention(q, k, v, pe, mask, transformer_options, preferred, chunk):
    """flux.math.attention, but RoPE is applied slice by slice in place and the
    queries attend in chunks against the full keys/values, so neither the
    full-size fp32 RoPE temporaries nor a full-length query pass are needed."""
    if mask is not None:
        q, k, v = AttentionTensorContainer(q), AttentionTensorContainer(k), AttentionTensorContainer(v)
        return attention(q, k, v, pe=pe, mask=mask, transformer_options=transformer_options,
                         preferred_attention=preferred)
    n = q.shape[2]
    spans = _spans(n, chunk)
    if pe is not None:
        for s, e in spans:
            q[:, :, s:e] = apply_rope1(q[:, :, s:e], pe[:, :, s:e])
            k[:, :, s:e] = apply_rope1(k[:, :, s:e], pe[:, :, s:e])
    heads = q.shape[1]
    out = None
    for s, e in spans:
        part = optimized_attention(q[:, :, s:e].contiguous(), k, v, heads, skip_reshape=True,
                                   transformer_options=transformer_options, preferred_attention=preferred)
        if out is None:
            out = torch.empty(q.shape[0], n, part.shape[-1], dtype=part.dtype, device=part.device)
        out[:, s:e] = part
        del part
    return out


def _mixed_batch(vec, x):
    """True when the modulation batch differs from the token batch: the
    timestep_zero reference path, whose per-token-range modulation_dims are not
    passed to dit replace patches. Such calls use the stock block."""
    m = vec[0][0] if isinstance(vec, tuple) else vec
    m = m.scale if hasattr(m, "scale") else m
    return m.shape[0] != x.shape[0]


class ChunkedDouble:
    def __init__(self, block, chunk):
        self.block = block
        self.chunk = chunk

    def __call__(self, args, extra):
        img, txt, vec = args["img"], args["txt"], args["vec"]
        if img.shape[1] <= self.chunk:
            return extra["original_block"](args)
        if self.block.modulation:
            if img.shape[0] != vec.shape[0]:
                return extra["original_block"](args)
        elif _mixed_batch(vec, img):
            return extra["original_block"](args)
        topts = args.get("transformer_options") or {}
        img, txt = self.forward(img, txt, vec, args["pe"], attn_mask=args.get("attn_mask"), transformer_options=topts)
        return {"img": img, "txt": txt}

    def _qkv(self, x, norm, attn, mod):
        b = self.block
        qkv = None
        for s, e in _spans(x.shape[1], self.chunk):
            part = attn.qkv(modulated_norm(x[:, s:e], norm, mod.scale, mod.shift))
            if qkv is None:
                qkv = torch.empty(x.shape[0], x.shape[1], part.shape[-1], dtype=part.dtype, device=part.device)
            qkv[:, s:e] = part
            del part
        q, k, v = qkv.view(qkv.shape[0], qkv.shape[1], 3, b.num_heads, -1).permute(2, 0, 3, 1, 4)
        del qkv
        # norm() returns fresh q/k; a contiguous v lets the fused buffer go.
        v = v.contiguous()
        q, k = attn.norm(q, k, v)
        return q, k, v

    def _tail(self, x, attn_out, proj, mlp, norm2, mod1, mod2):
        for s, e in _spans(x.shape[1], self.chunk):
            x[:, s:e] += apply_mod(proj(attn_out[:, s:e]), mod1.gate)
            x[:, s:e] += apply_mod(mlp(modulated_norm(x[:, s:e], norm2, mod2.scale, mod2.shift)), mod2.gate)
        return x

    def forward(self, img, txt, vec, pe, attn_mask=None, modulation_dims_img=None, modulation_dims_txt=None, transformer_options={}):
        b = self.block
        patches = transformer_options.get("patches", {})
        if (img.shape[1] <= self.chunk or modulation_dims_img is not None or modulation_dims_txt is not None
                or "attn1_patch" in patches or "attn1_output_patch" in patches):
            return b(img, txt, vec, pe, attn_mask=attn_mask, modulation_dims_img=modulation_dims_img,
                     modulation_dims_txt=modulation_dims_txt, transformer_options=transformer_options)
        if b.modulation:
            img_mod1, img_mod2 = b.img_mod(vec)
            txt_mod1, txt_mod2 = b.txt_mod(vec)
        else:
            (img_mod1, img_mod2), (txt_mod1, txt_mod2) = vec

        img_q, img_k, img_v = self._qkv(img, b.img_norm1, b.img_attn, img_mod1)
        txt_q, txt_k, txt_v = self._qkv(txt, b.txt_norm1, b.txt_attn, txt_mod1)
        q = torch.cat((txt_q, img_q), dim=2)
        del txt_q, img_q
        k = torch.cat((txt_k, img_k), dim=2)
        del txt_k, img_k
        v = torch.cat((txt_v, img_v), dim=2)
        del txt_v, img_v
        attn = _attention(q, k, v, pe, attn_mask, transformer_options, b.comfy_attention, self.chunk)
        del q, k, v
        txt_attn, img_attn = attn[:, :txt.shape[1]], attn[:, txt.shape[1]:]

        img = self._tail(img, img_attn, b.img_attn.proj, b.img_mlp, b.img_norm2, img_mod1, img_mod2)
        del img_attn
        txt = self._tail(txt, txt_attn, b.txt_attn.proj, b.txt_mlp, b.txt_norm2, txt_mod1, txt_mod2)
        if txt.dtype == torch.float16:
            txt = torch.nan_to_num(txt, nan=0.0, posinf=65504, neginf=-65504)
        return img, txt


class ChunkedSingle:
    def __init__(self, block, chunk):
        self.block = block
        self.chunk = chunk

    def __call__(self, args, extra):
        x, vec = args["img"], args["vec"]
        if x.shape[1] <= self.chunk:
            return extra["original_block"](args)
        if self.block.modulation:
            if x.shape[0] != vec.shape[0]:
                return extra["original_block"](args)
        elif _mixed_batch(vec, x):
            return extra["original_block"](args)
        topts = args.get("transformer_options") or {}
        return {"img": self.forward(x, vec, args["pe"], attn_mask=args.get("attn_mask"), transformer_options=topts)}

    def forward(self, x, vec, pe, attn_mask=None, modulation_dims=None, transformer_options={}):
        b = self.block
        patches = transformer_options.get("patches", {})
        if (x.shape[1] <= self.chunk or modulation_dims is not None
                or "attn1_patch" in patches or "attn1_output_patch" in patches):
            return b(x, vec, pe, attn_mask=attn_mask, modulation_dims=modulation_dims,
                     transformer_options=transformer_options)
        mod = b.modulation(vec)[0] if b.modulation else vec
        h3 = 3 * b.hidden_size
        spans = _spans(x.shape[1], self.chunk)

        # Pass 1: gather the QKV half of linear1 for the whole sequence.
        qkv = None
        for s, e in spans:
            part = b.linear1(modulated_norm(x[:, s:e], b.pre_norm, mod.scale, mod.shift))[..., :h3]
            if qkv is None:
                qkv = torch.empty(x.shape[0], x.shape[1], h3, dtype=part.dtype, device=part.device)
            qkv[:, s:e] = part
            del part
        q, k, v = qkv.view(qkv.shape[0], qkv.shape[1], 3, b.num_heads, -1).permute(2, 0, 3, 1, 4)
        del qkv
        v = v.contiguous()
        q, k = b.norm(q, k, v)
        attn = _attention(q, k, v, pe, attn_mask, transformer_options, b.comfy_attention, self.chunk)
        del q, k, v

        # Pass 2: recompute the MLP half per chunk and finish the block. x is
        # updated in place chunk by chunk; each chunk reads only its own rows,
        # which are still the block's input when it is processed.
        for s, e in spans:
            mlp = b.linear1(modulated_norm(x[:, s:e], b.pre_norm, mod.scale, mod.shift))[..., h3:]
            if b.yak_mlp:
                mlp = b.mlp_act(mlp[..., b.mlp_hidden_dim_first // 2:]) * mlp[..., :b.mlp_hidden_dim_first // 2]
            else:
                mlp = b.mlp_act(mlp)
            out = b.linear2(torch.cat((attn[:, s:e], mlp), 2))
            del mlp
            x[:, s:e] += apply_mod(out, mod.gate)
            del out
        if x.dtype == torch.float16:
            x = torch.nan_to_num(x, nan=0.0, posinf=65504, neginf=-65504)
        return x


class FluxTokenChunking:
    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {
            "model": ("MODEL",),
            "chunk_tokens": ("INT", {"default": 4096, "min": 256, "max": 65536, "step": 256}),
        }}

    RETURN_TYPES = ("MODEL",)
    FUNCTION = "patch"
    CATEGORY = "advanced/model"

    def patch(self, model, chunk_tokens):
        m = model.clone()
        dm = m.get_model_object("diffusion_model")
        for i, block in enumerate(dm.double_blocks):
            m.set_model_patch_replace(ChunkedDouble(block, chunk_tokens), "dit", "double_block", i)
        for i, block in enumerate(dm.single_blocks):
            m.set_model_patch_replace(ChunkedSingle(block, chunk_tokens), "dit", "single_block", i)
        return (m,)


NODE_CLASS_MAPPINGS = {"FluxTokenChunking": FluxTokenChunking}
NODE_DISPLAY_NAME_MAPPINGS = {"FluxTokenChunking": "Flux Token Chunking"}

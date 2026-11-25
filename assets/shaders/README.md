# Upscaling shaders (spec-13)

These are mpv user shaders (`glsl-shaders`). Most are shipped **unmodified** from upstream; exceptions are called out
below (currently `custom/grain.glsl`, adapted for GLES/ESSL). To update, change the pin below, re-download the files,
and update the checksums. The `.hook` extension is upstream's; mpv loads these files the same way as `.glsl`.

## Sources (pinned)

Two families ship: **Anime4K** and an experimental **custom** detail/sharpen/grain chain. FSRCNNX, RAVU and NNEDI3
were evaluated in spec-13 U0 field testing and dropped because they made no noticeable difference; their folders were
removed.

| Folder | Upstream | Pin |
|--------|----------|-----|
| `anime4k/` | [bloc97/Anime4K](https://github.com/bloc97/Anime4K) | release `v4.0.1` (commit `4029bf701ecaa15f163cdc49cffe5501c1acf410`), asset `Anime4K_v4.0.zip` |
| `custom/` SSimSuperRes | [igv gist](https://gist.github.com/igv/2364ffa6e81540f29cb7ab4c9bc05b6b) (SSimSuperRes by Shiandow) | gist `2364ffa6e81540f29cb7ab4c9bc05b6b`, fetched 2026-11-25 |
| `custom/` CAS-scaled | [agyild gist](https://gist.github.com/agyild/bbb4e58298b2f86aa24da3032a0d2ee6) (AMD FidelityFX CAS, mpv port) | gist revision `10e4ca1b6ef173b64391ce2c81b9a95fcd095931` (v1.0.2, classic `gpu` build — the current v1.2 needs `gpu-next`/libplacebo, which media_kit's libmpv OpenGL render API does not provide) |
| `custom/` grain | [butterw/bShaders](https://github.com/butterw/bShaders) (`FilmGrain_Noise/mpv/grain.glsl`) | branch `master`, v1.01, fetched 2026-11-25, **adapted for GLES/ESSL** (brace-init → `vec4(...)`, int→float literals/conversions, precomputed const factors) |

Notes:
- Anime4K ships **Mode A (fast)** and the HQ modes **A/B/C** (chains listed below).
- The `custom/` folder is an **experimental test chain** (`custom_detail_cas_grain`): SSimSuperRes luma detail
  recovery → AMD CAS sharpening → film grain, applied in that order. The three files keep their upstream names; the
  user-facing chain references them in `data/mpv_shaders.dart`. All three are fragment shaders (no compute), as
  required on GLES (spec-13 F4).
- ArtCNN was evaluated and dropped in spec-13 U0. Its shaders are compute-only and failed to compile on the
  Linux/Mesa GLES 3.2 context, the failure crashed the app inside mpv, and it was too heavy anyway.
- FSRCNNX, RAVU and NNEDI3 were evaluated in spec-13 U0 field testing and dropped because they made no noticeable
  difference; their folders were removed.
- Anime4K mode chains follow upstream's mpv templates (`md/Template/GLSL_Mac_Linux_{High,Low}-end/input.conf`
  at commit `7684e9586f8dcc738af08a1cdceb024cc184f426`):
  - Mode A (Fast): Clamp_Highlights, Restore_CNN_M, Upscale_CNN_x2_M, AutoDownscalePre_x2, AutoDownscalePre_x4, Upscale_CNN_x2_S
  - Mode A (HQ): Clamp_Highlights, Restore_CNN_VL, Upscale_CNN_x2_VL, AutoDownscalePre_x2, AutoDownscalePre_x4, Upscale_CNN_x2_M
  - Mode B (HQ): Clamp_Highlights, Restore_CNN_Soft_VL, Upscale_CNN_x2_VL, AutoDownscalePre_x2, AutoDownscalePre_x4, Upscale_CNN_x2_M
  - Mode C (HQ): Clamp_Highlights, Upscale_Denoise_CNN_x2_VL, AutoDownscalePre_x2, AutoDownscalePre_x4, Upscale_CNN_x2_M

## Checksums (sha256)

```
9141668ced0b26512253e6396e805820716f35b57c92950d9da489f8b96a7ba4  anime4k/Anime4K_AutoDownscalePre_x2.glsl
dadb7b713cfa1d810c55b5deff616072f3390e546fed1e6a54f80ea555f7b95d  anime4k/Anime4K_AutoDownscalePre_x4.glsl
8c5fb67c76bed3021f8a27b050c3b97a6ac1b284f9ce91c04189015c354c0217  anime4k/Anime4K_Clamp_Highlights.glsl
67ea3ed26539e8de3b7d307688535d2ff17e8d147e11dda0247da7770dbecf41  anime4k/Anime4K_Restore_CNN_M.glsl
094334b0e20c1a201fe4941c7c68de72451e5aee9efb5524d7fb82b12dca64b9  anime4k/Anime4K_Restore_CNN_Soft_VL.glsl
35036722733305cd4d4e57660b883bbe2569ba2914033c254327107d7b77e35e  anime4k/Anime4K_Restore_CNN_VL.glsl
716e02098a68f0d648761f2b96b4dd139e1cb09b174bb369fca3aa34328fff7e  anime4k/Anime4K_Upscale_CNN_x2_M.glsl
4c53ec2e287908f7ee7bcb266b0170421626d663576468b7d7dafc62962649a4  anime4k/Anime4K_Upscale_CNN_x2_S.glsl
5638fe31c37c151a3443fea3451a3ef91af073f4dbb9615f6c0d1e29db11493d  anime4k/Anime4K_Upscale_CNN_x2_VL.glsl
359c48fe5a317fbc6b706ce368401eef496e84ed98abac7a43efebca2b65d79b  anime4k/Anime4K_Upscale_Denoise_CNN_x2_VL.glsl
a8b27115840c60045250411b375e0188000217258ad776eeb51724c97815460f  custom/SSimSuperRes.glsl
fe678abb821e72f839f3f3a6af0105c543a1a9d9ae6c927185cfd400cebab217  custom/CAS-scaled.glsl
73d6c7e337befd520b6902ae121a03180946e9337f7e746907c109382b2e6f79  custom/grain.glsl
```

Check with `cd assets/shaders && sha256sum -c` on the block above.

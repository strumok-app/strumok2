# Upscaling shaders (spec-13)

These are mpv user shaders (`glsl-shaders`), shipped **unmodified** from upstream. Do not edit them. To update, change
the pin below, re-download the files, and update the checksums. The `.hook` extension is upstream's; mpv loads these
files the same way as `.glsl`.

## Sources (pinned)

| Folder | Upstream | Pin | License |
|--------|----------|-----|---------|
| `anime4k/` | [bloc97/Anime4K](https://github.com/bloc97/Anime4K) | release `v4.0.1` (commit `4029bf701ecaa15f163cdc49cffe5501c1acf410`), asset `Anime4K_v4.0.zip` | MIT — `anime4k/LICENSE` |
| `fsrcnnx/` | [igv/FSRCNN-TensorFlow](https://github.com/igv/FSRCNN-TensorFlow) | release `1.1`, release assets | LGPL-3.0-or-later (file headers) — `fsrcnnx/LICENSE` + `GPL-3.0.txt` |
| `ravu/` | [bjin/mpv-prescalers](https://github.com/bjin/mpv-prescalers) | commit `b3f0a59d68f33b7162051ea5970a5169558f0ea2` (repo root = fragment variants) | LGPL-3.0-or-later — `ravu/LICENSE` + `GPL-3.0.txt` |
| `nnedi3/` | [bjin/mpv-prescalers](https://github.com/bjin/mpv-prescalers) | commit `b3f0a59d68f33b7162051ea5970a5169558f0ea2` | LGPL-3.0-or-later — `nnedi3/LICENSE` + `GPL-3.0.txt` |

Notes:
- The FSRCNN-TensorFlow *repository* is GPL-3.0, but the released `.glsl` files say LGPL v3.0 or later in their
  headers. LGPL-3.0 is a set of additional permissions on top of GPL-3.0, so the GPL text ships too (`GPL-3.0.txt`).
- ArtCNN was evaluated and dropped in spec-13 U0. Its shaders are compute-only and failed to compile on the
  Linux/Mesa GLES 3.2 context, the failure crashed the app inside mpv, and it was too heavy anyway.
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
d5a24a271e5d9a3f7f7a053b150c460a44c25b3cf7f770857d57cc3a2e1c9965  fsrcnnx/FSRCNNX_x2_16-0-4-1.glsl
e800dbc5c1c95185cc82216c597724533ff5f2880179f256eef600f03e8dc2ae  fsrcnnx/FSRCNNX_x2_8-0-4-1.glsl
8997ce2e9a6be381e6865233a81c97ef4fdb741818f8258283ee78ffa371eec6  nnedi3/nnedi3-nns128-win8x6.hook
d015128cca7efaf408748bae282f024bb21a902542704a9eab4773a7dcc1b364  nnedi3/nnedi3-nns64-win8x6.hook
2e7c9beb79be10c57c85eede7a4b6ba1f031a97a26170d88450fc4330a5e8408  ravu/ravu-lite-ar-r4.hook
eb0c3744af3615c99281a6ff74d1276a5cc7527a30a0bd54984aeb43d0cb2eea  ravu/ravu-zoom-ar-r3.hook
```

Check with `cd assets/shaders && sha256sum -c` on the block above.

import '../domain/upscaling.dart';

/// Bump whenever a shader file is added, removed or replaced: extracted copies live in a folder per version
/// (spec-13 §13.4).
const shaderCatalogVersion = 1;

const _root = 'assets/shaders';

List<String> _anime4k(List<String> names) => [for (final name in names) '$_root/anime4k/Anime4K_$name.glsl'];

const _autoDownscale = ['AutoDownscalePre_x2', 'AutoDownscalePre_x4'];

/// Asset paths per upscaler id, in mpv hook order (spec-13 §13.3; Anime4K chains follow upstream's mpv templates).
final Map<String, List<String>> shaderAssets = {
  'fsrcnnx_8': ['$_root/fsrcnnx/FSRCNNX_x2_8-0-4-1.glsl'],
  'fsrcnnx_16': ['$_root/fsrcnnx/FSRCNNX_x2_16-0-4-1.glsl'],
  'ravu_lite_r4': ['$_root/ravu/ravu-lite-ar-r4.hook'],
  'ravu_zoom_r3': ['$_root/ravu/ravu-zoom-ar-r3.hook'],
  'nnedi3_64': ['$_root/nnedi3/nnedi3-nns64-win8x6.hook'],
  'nnedi3_128': ['$_root/nnedi3/nnedi3-nns128-win8x6.hook'],
  'anime4k_a_fast': _anime4k([
    'Clamp_Highlights',
    'Restore_CNN_M',
    'Upscale_CNN_x2_M',
    ..._autoDownscale,
    'Upscale_CNN_x2_S',
  ]),
  'anime4k_a_hq': _anime4k([
    'Clamp_Highlights',
    'Restore_CNN_VL',
    'Upscale_CNN_x2_VL',
    ..._autoDownscale,
    'Upscale_CNN_x2_M',
  ]),
  'anime4k_b_hq': _anime4k([
    'Clamp_Highlights',
    'Restore_CNN_Soft_VL',
    'Upscale_CNN_x2_VL',
    ..._autoDownscale,
    'Upscale_CNN_x2_M',
  ]),
  'anime4k_c_hq': _anime4k(['Clamp_Highlights', 'Upscale_Denoise_CNN_x2_VL', ..._autoDownscale, 'Upscale_CNN_x2_M']),
};

List<String> shaderAssetsOf(Upscaler upscaler) => shaderAssets[upscaler.id] ?? const [];

/// License text per family folder, shown on the licenses page (spec-13 §13.3).
const shaderLicenses = <({String package, List<String> assets})>[
  (package: 'Anime4K (shaders)', assets: ['$_root/anime4k/LICENSE']),
  (package: 'FSRCNNX (shaders)', assets: ['$_root/fsrcnnx/LICENSE', '$_root/GPL-3.0.txt']),
  (package: 'RAVU (shaders)', assets: ['$_root/ravu/LICENSE', '$_root/GPL-3.0.txt']),
  (package: 'NNEDI3 (shaders)', assets: ['$_root/nnedi3/LICENSE', '$_root/GPL-3.0.txt']),
];

/// mpv commands that replace the user shaders with [paths]; empty [paths] clears them.
/// One `append` per file: a joined path list would split on `:` (Unix) / `;` (Windows) and break on `C:\`.
List<List<String>> mpvShaderCommands(List<String> paths) => [
  ['change-list', 'glsl-shaders', 'clr', ''],
  for (final path in paths) ['change-list', 'glsl-shaders', 'append', path],
];

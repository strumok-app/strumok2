import '../domain/upscaling.dart';

/// Bump whenever a shader file is added, removed or replaced: extracted copies live in a folder per version
/// (spec-13 §13.4).
const shaderCatalogVersion = 4;

const _root = 'assets/shaders';

List<String> _anime4k(List<String> names) => [for (final name in names) '$_root/anime4k/Anime4K_$name.glsl'];

const _autoDownscale = ['AutoDownscalePre_x2', 'AutoDownscalePre_x4'];

/// Asset paths per upscaler id, in mpv hook order (spec-13 §13.3; Anime4K chains follow upstream's mpv templates).
/// FSRCNNX/RAVU/NNEDI3 were dropped; the LUMA/CAS/FILM GRAIN chain was added.
final Map<String, List<String>> shaderAssets = {
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
  // SSimSuperRes (luma detail) → AMD CAS (sharpen) → film grain, in this order (upstream file names kept).
  'luma_cas_grain': ['$_root/custom/SSimSuperRes.glsl', '$_root/custom/CAS-scaled.glsl', '$_root/custom/grain.glsl'],
};

List<String> shaderAssetsOf(Upscaler upscaler) => shaderAssets[upscaler.id] ?? const [];

/// mpv commands that replace the user shaders with [paths]; empty [paths] clears them.
/// One `append` per file: a joined path list would split on `:` (Unix) / `;` (Windows) and break on `C:\`.
List<List<String>> mpvShaderCommands(List<String> paths) => [
  ['change-list', 'glsl-shaders', 'clr', ''],
  for (final path in paths) ['change-list', 'glsl-shaders', 'append', path],
];

/// An mpv log line reporting that a user shader failed (compile/link/parse); spec-13 §13.4. Compile failures start
/// with e.g. `[libmpv_render] compute shader source:` before the source dump.
bool isShaderFailureLog(String prefix, String level, String text) {
  if (level != 'error' && level != 'fatal') return false;
  if (!prefix.startsWith('vo') && !prefix.startsWith('libmpv')) return false;
  return text.toLowerCase().contains('shader');
}

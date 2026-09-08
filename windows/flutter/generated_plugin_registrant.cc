//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_video_thumbnail_plus/flutter_video_thumbnail_plus_plugin_c_api.h>
#include <fvp/fvp_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterVideoThumbnailPlusPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterVideoThumbnailPlusPluginCApi"));
  FvpPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FvpPluginCApi"));
}

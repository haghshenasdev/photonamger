//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_onnxruntime/flutter_onnxruntime_plugin.h>
#include <flutter_video_thumbnail_plus/flutter_video_thumbnail_plus_plugin_c_api.h>
#include <fvp/fvp_plugin_c_api.h>
#include <url_launcher_windows/url_launcher_windows.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterOnnxruntimePluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterOnnxruntimePlugin"));
  FlutterVideoThumbnailPlusPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterVideoThumbnailPlusPluginCApi"));
  FvpPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FvpPluginCApi"));
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
}

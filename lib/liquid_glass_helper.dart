/// A helper library for checking support for the native glass effect.
library liquid_glass_helper;

import 'dart:io';
import 'package:flutter/services.dart';

/// A helper class to check if the device supports the native glass effect.
class LiquidGlassHelper {
  LiquidGlassHelper._();

  static const MethodChannel _channel = MethodChannel('native_liquid_tab_bar');

  /// Checks if the current device supports the liquid glass effect.
  ///
  /// Returns `true` if the platform is iOS and the native check returns true.
  /// Returns `false` if unsupported or on non-iOS platforms.
  /// Throws [PlatformException] when the native channel is not ready yet.
  static Future<bool> isLiquidGlassSupported() async {
    if (!Platform.isIOS) return false;
    final bool supported = await _channel.invokeMethod(
      'isLiquidGlassSupported',
    );
    return supported;
  }
}

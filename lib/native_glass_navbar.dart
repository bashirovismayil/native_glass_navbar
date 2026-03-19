/// Forked: hide/show method channel desteği eklendi.
///
/// Orijinal: https://pub.dev/packages/native_glass_navbar
/// Değişiklikler:
///   - NativeGlassNavBarState artık public (GlobalKey erişimi için)
///   - hide() ve show() metotları eklendi
///   - FutureBuilder waiting durumunda fallback gösteriliyor

library native_glass_navbar;

export 'liquid_glass_helper.dart';

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_glass_navbar/liquid_glass_helper.dart';

class NativeGlassNavBarItem {
  final String label;
  final String symbol;
  const NativeGlassNavBarItem({required this.label, required this.symbol});
}

class TabBarActionButton {
  final String symbol;
  final VoidCallback onTap;
  const TabBarActionButton({required this.symbol, required this.onTap});
}

class NativeGlassNavBar extends StatefulWidget {
  final List<NativeGlassNavBarItem> tabs;
  final TabBarActionButton? actionButton;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color? tintColor;
  final Widget? fallback;

  const NativeGlassNavBar({
    super.key,
    required this.tabs,
    this.actionButton,
    required this.currentIndex,
    required this.onTap,
    this.tintColor,
    this.fallback,
  }) : assert(
         tabs.length <= (actionButton == null ? 5 : 4),
         actionButton == null
             ? 'NativeGlassNavBar supports a maximum of 5 tabs.'
             : 'NativeGlassNavBar with an action button supports a maximum of 4 tabs.',
       );

  @override
  // ignore: library_private_types_in_public_api — intentional for GlobalKey access
  NativeGlassNavBarState createState() => NativeGlassNavBarState();
}

/// Public state — GlobalKey<NativeGlassNavBarState> ile dışarıdan erişilebilir.
class NativeGlassNavBarState extends State<NativeGlassNavBar> {
  MethodChannel? _channel;
  late Future<bool> _supportLiquidGlassFuture;
  bool _isHidden = false;

  // ========================
  // PUBLIC API — hide / show
  // ========================

  /// Native navbar'ı anında gizler.
  /// Başka bir sayfaya push yapmadan hemen önce çağır.
  Future<void> hide() async {
    if (_channel != null && !_isHidden) {
      _isHidden = true;
      try {
        await _channel!.invokeMethod('hide');
      } catch (_) {}
    }
  }

  /// Native navbar'ı yumuşak fade-in ile gösterir.
  /// Pop ile geri döndükten sonra çağır.
  Future<void> show() async {
    if (_channel != null && _isHidden) {
      _isHidden = false;
      try {
        await _channel!.invokeMethod('show');
      } catch (_) {}
    }
  }

  // ========================
  // INTERNAL
  // ========================

  void _updateNativeView() {
    if (_channel != null) {
      _channel!.invokeMethod('update', _createParams());
    }
  }

  Future<bool> checkLiquidGlassSupport() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    return await LiquidGlassHelper.isLiquidGlassSupported();
  }

  Map<String, dynamic> _createParams() {
    return {
      'labels': widget.tabs.map((e) => e.label).toList(),
      'symbols': widget.tabs.map((e) => e.symbol).toList(),
      'actionButtonSymbol': widget.actionButton?.symbol,
      'selectedIndex': widget.currentIndex,
      'isDark': Theme.of(context).brightness == Brightness.dark,
      'tintColor': widget.tintColor != null
          ? widget.tintColor!.toARGB32()
          : Theme.of(context).colorScheme.primary.toARGB32(),
    };
  }

  @override
  void initState() {
    super.initState();
    _supportLiquidGlassFuture = checkLiquidGlassSupport();
  }

  @override
  void didUpdateWidget(NativeGlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateNativeView();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _supportLiquidGlassFuture,
      builder: (context, snapshot) {
        // FIX: Bekleme sırasında fallback göster — gecikme hissedilmez
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (widget.fallback != null) {
            return widget.fallback!;
          }
          return const SizedBox.shrink();
        }

        if (snapshot.data != true) {
          if (widget.fallback != null) {
            return widget.fallback!;
          }
          if (kDebugMode) {
            developer.log(
              'Liquid glass effect is not supported on this device. '
              'Falling back to an empty widget. Provide a `fallback` widget to handle this case.',
              name: 'NativeGlassNavBar',
              level: 900,
            );
          }
          return const SizedBox.shrink();
        }

        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final height = 40.0 + bottomPadding;

        return SizedBox(
          height: height,
          child: UiKitView(
            viewType: 'NativeTabBar',
            creationParams: _createParams(),
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: (id) {
              _channel = MethodChannel('NativeTabBar_$id');
              _channel!.setMethodCallHandler((call) async {
                if (call.method == 'valueChanged') {
                  final index = call.arguments['index'] as int;
                  widget.onTap(index);
                }
                if (call.method == 'actionButtonPressed') {
                  widget.actionButton?.onTap();
                }
              });
            },
          ),
        );
      },
    );
  }
}
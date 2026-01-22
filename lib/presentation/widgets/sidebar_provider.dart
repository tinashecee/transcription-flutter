import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to manage the sidebar's collapsed state globally.
/// Defaults to false (expanded).
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

/// Provider to manage whether the sidebar is visible at all.
/// Useful for fullscreen modes or specialized screens.
final sidebarHiddenProvider = StateProvider<bool>((ref) => false);

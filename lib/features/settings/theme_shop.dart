import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/theme_controller.dart';
import '../../data/providers.dart';

final themeShopProvider = Provider(ThemeShop.new);

/// Themes are bought with reward tokens only. There is no path from coins to
/// tokens anywhere, here or in the UI.
class ThemeShop {
  ThemeShop(this._ref);

  final Ref _ref;

  /// Returns false when the user cannot afford it yet; nothing is spent.
  Future<bool> unlock(AppTheme theme) async {
    final wallet = _ref.read(walletRepositoryProvider);
    if ((await wallet.read()).tokens < theme.price) return false;

    await wallet.update((w) => w.copyWith(tokens: w.tokens - theme.price));
    final settings = _ref.read(settingsProvider.notifier);
    await settings.unlockTheme(theme.id);
    await settings.selectTheme(theme.id);
    return true;
  }
}

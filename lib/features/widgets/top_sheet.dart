import 'package:flutter/material.dart';

/// Drops [child] over whatever is on screen, from the top.
///
/// On the root navigator and non-opaque, so the tab underneath keeps painting
/// and the bottom bar stays where it was — this covers the app, it does not
/// navigate away from it.
///
/// One route for every top sheet, so プロフィール and オプション cannot drift apart:
/// the same curve, the same barrier, the same way out.
Future<void> showTopSheet(
  BuildContext context, {
  required String barrierLabel,
  required WidgetBuilder builder,
}) => Navigator.of(context, rootNavigator: true).push<void>(
  PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black54,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        SlideTransition(
          position: Tween(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
  ),
);

/// How fast a downward flick has to be before it counts as "put it away".
/// Below this the sheet stays: scrolling the rows inside must not dismiss.
const _dismissVelocity = 300.0;

/// The sheet itself: a grab bar, a scrolling body, and a 閉じる button that is
/// never inside the scroll.
class TopSheetOverlay extends StatelessWidget {
  const TopSheetOverlay({
    super.key,
    required this.scaffoldKey,
    required this.handleKey,
    required this.closeKey,
    required this.children,
    this.header,
  });

  /// Identifies this sheet to the tests and to anything looking for its
  /// scrollable — 'profileOverlay', 'optionsOverlay'.
  final Key scaffoldKey;
  final Key handleKey;
  final Key closeKey;

  /// The rows of the list inside.
  final List<Widget> children;

  /// Pinned between the grab bar and the list: it does not scroll away.
  ///
  /// Null for a sheet that is nothing but rows — オプション — so adding this
  /// could not change what that sheet does. It scrolls nothing, so a downward
  /// flick on it reaches the detector below and still puts the sheet away.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        // Only vertical: a horizontal drag belongs to the pickers inside.
        // The list below wins the arena wherever it can actually scroll, so
        // this catches the drag on the parts of the sheet that do not — the
        // grab bar above all.
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > _dismissVelocity) {
            Navigator.of(context).maybePop();
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Material(
              color: theme.colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _GrabBar(handleKey: handleKey),
                  if (header != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: header,
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: children,
                    ),
                  ),
                  // Outside the list on purpose: the way out must not be
                  // something you have to scroll to find.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: FilledButton.tonal(
                      key: closeKey,
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('閉じる'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar you pull down on. It scrolls nothing, so the drag reaches the
/// detector above instead of the list.
class _GrabBar extends StatelessWidget {
  const _GrabBar({required this.handleKey});

  final Key handleKey;

  @override
  Widget build(BuildContext context) => Container(
    key: handleKey,
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 10),
    color: Colors.transparent,
    child: Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}

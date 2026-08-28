import 'package:flutter/material.dart';

/// The iPhone alarm list's delete gesture: swipe the row to the left and a red
/// 削除 appears behind it; the row is only actually deleted when that is
/// pressed.
///
/// Deliberately not a [Dismissible]. A dismissible row is gone the instant the
/// swipe completes, which for an alarm means losing a pledge to a pocket swipe;
/// the reveal makes the second, deliberate tap the thing that destroys
/// something. There is no undo, so the confirmation has to come first.
class SwipeToDelete extends StatefulWidget {
  const SwipeToDelete({
    super.key,
    required this.child,
    required this.onDelete,
    this.label = '削除',
  });

  final Widget child;
  final VoidCallback onDelete;
  final String label;

  static const actionWidth = 96.0;
  static const _snapDuration = Duration(milliseconds: 150);

  @override
  State<SwipeToDelete> createState() => SwipeToDeleteState();
}

class SwipeToDeleteState extends State<SwipeToDelete> {
  /// 0 = closed, -[SwipeToDelete.actionWidth] = fully revealed. Never positive:
  /// there is nothing to reveal on the right.
  double _offset = 0;

  bool get _isOpen => _offset < 0;

  /// Whether the row is swiped aside with its 削除 showing. Tests assert on it
  /// because a row that inherits another row's open state is exactly the bug
  /// the per-alarm [ValueKey] on the tile exists to prevent.
  @visibleForTesting
  bool get isRevealed => _isOpen;

  void _drag(DragUpdateDetails d) => setState(
    () => _offset = (_offset + d.delta.dx).clamp(-SwipeToDelete.actionWidth, 0),
  );

  void _settle(DragEndDetails _) => setState(
    () => _offset = _offset < -SwipeToDelete.actionWidth / 2
        ? -SwipeToDelete.actionWidth
        : 0,
  );

  void _close() => setState(() => _offset = 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onHorizontalDragUpdate: _drag,
      onHorizontalDragEnd: _settle,
      child: Stack(
        children: [
          // Only built once the row has actually started to move: a closed row
          // has no delete button, on screen or in the tree.
          if (_isOpen)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: SwipeToDelete.actionWidth,
                  child: Material(
                    color: theme.colorScheme.error,
                    child: InkWell(
                      onTap: widget.onDelete,
                      child: Center(
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            color: theme.colorScheme.onError,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          AnimatedContainer(
            duration: SwipeToDelete._snapDuration,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_offset, 0, 0),
            // Opaque, or the red behind would show straight through the row as
            // soon as it slid over it.
            child: Material(
              color: theme.colorScheme.surface,
              child: Stack(
                children: [
                  widget.child,
                  // While the row is open, tapping it closes it instead of
                  // opening the alarm — the same as on iOS, and it keeps a tap
                  // aimed at 削除 that lands slightly short from navigating away.
                  if (_isOpen)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _close,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

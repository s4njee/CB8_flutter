import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a reader so desktop keyboard keys drive page navigation.
///
/// Right/Down/PageDown/Space = next, Left/Up/PageUp = previous,
/// Home/End = first/last, Escape = back. The touch tap-zones still work; this
/// just adds the keys desktop users expect.
///
/// Uses a [HardwareKeyboard] handler rather than a [Focus]/[Shortcuts] wrapper
/// because the readers embed a `Scrollable` (PhotoView's PageView, pdfrx) that
/// grabs focus and consumes the arrow keys before an ancestor would see them.
/// The hardware handler runs ahead of the focus system, so the keys reach us
/// regardless of which inner widget currently holds focus.
class ReaderKeyboard extends StatefulWidget {
  const ReaderKeyboard({
    super.key,
    required this.child,
    required this.onNext,
    required this.onPrev,
    this.onFirst,
    this.onLast,
  });

  final Widget child;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback? onFirst;
  final VoidCallback? onLast;

  @override
  State<ReaderKeyboard> createState() => _ReaderKeyboardState();
}

class _ReaderKeyboardState extends State<ReaderKeyboard> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.space) {
      widget.onNext();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp) {
      widget.onPrev();
      return true;
    }
    if (key == LogicalKeyboardKey.home && widget.onFirst != null) {
      widget.onFirst!();
      return true;
    }
    if (key == LogicalKeyboardKey.end && widget.onLast != null) {
      widget.onLast!();
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

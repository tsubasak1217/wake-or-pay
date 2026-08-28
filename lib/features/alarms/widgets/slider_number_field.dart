import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A slider and a text field over the same integer, used by every numeric
/// sub-screen of the alarm editor.
///
/// The field *is* the value display: a centred, boxed number with its unit
/// beside it, and the slider spanning the full width underneath. There is no
/// second, larger copy of the number anywhere — one number, editable where it
/// is read.
///
/// The rules are the spec's:
///
/// * text that is not a number is ignored — the previous value stands, and the
///   half typed text is left alone so backspacing through a number does not
///   snap the slider to the minimum;
/// * a number outside `[min, max]` is clamped rather than rejected;
/// * the field is only rewritten from [value] when it does not have focus, so
///   typing "10" on the way to "100" never fights the caret.
///
/// The *decision* is committed by whoever hosts this widget when its sub-screen
/// closes; this widget only reports the live value.
class SliderNumberField extends StatefulWidget {
  const SliderNumberField({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix,
    this.semanticLabel,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  /// Shown beside the field, e.g. `分` or `コイン/分`. Deliberately *not* the
  /// field's `suffixText`: a long unit wraps inside the input and pushes the
  /// number out of sight, which is exactly what a numeric field must never do.
  final String? suffix;
  final String? semanticLabel;

  /// Tick marks are only legible on a short range; a long one slides freely and
  /// is rounded to an integer.
  static const maxDivisions = 30;

  @override
  State<SliderNumberField> createState() => _SliderNumberFieldState();
}

class _SliderNumberFieldState extends State<SliderNumberField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focus = FocusNode()..addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(SliderNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_focus.hasFocus) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Leaving the field tidies whatever is in it back to the value that was
  /// actually accepted — including the clamp.
  void _onFocusChanged() {
    if (!_focus.hasFocus) _controller.text = '${widget.value}';
  }

  void _onTextChanged(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) return;
    _report(parsed);
  }

  void _report(int candidate) {
    final clamped = candidate.clamp(widget.min, widget.max);
    if (clamped != widget.value) widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final span = widget.max - widget.min;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 112,
              child: TextField(
                key: const ValueKey('sliderNumberInput'),
                controller: _controller,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: _onTextChanged,
              ),
            ),
            if (widget.suffix != null) ...[
              const SizedBox(width: 12),
              Text(widget.suffix!, style: theme.textTheme.titleMedium),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: widget.value.toDouble().clamp(
            widget.min.toDouble(),
            widget.max.toDouble(),
          ),
          min: widget.min.toDouble(),
          max: widget.max.toDouble(),
          divisions: span <= SliderNumberField.maxDivisions ? span : null,
          label: '${widget.value}',
          semanticFormatterCallback: (v) =>
              '${widget.semanticLabel ?? ''} ${v.round()}',
          onChanged: (v) => _report(v.round()),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../services/voice_recorder.dart';
import 'widgets/slider_number_field.dart';

/// 寝坊時連絡先: who is told when the oversleeping runs long, and what they are
/// told.
///
/// Like every other editor sub-screen the value is local while the screen is
/// open and handed back exactly once, when it closes — which covers the app
/// bar's back button and the system back gesture alike, because both go through
/// [PopScope].
///
/// A contact with no name is not a contact, so an empty 名前 commits null: that
/// is how the user removes one.
class ContactSubScreen extends ConsumerStatefulWidget {
  const ContactSubScreen({
    super.key,
    required this.initial,
    required this.onCommit,
    this.alarmId,
  });

  final OversleepContact? initial;
  final ValueChanged<OversleepContact?> onCommit;

  /// Only used to name the recording file, so it is optional.
  final String? alarmId;

  @override
  ConsumerState<ContactSubScreen> createState() => _ContactSubScreenState();
}

class _ContactSubScreenState extends ConsumerState<ContactSubScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.initial?.phone ?? '',
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.initial?.email ?? '',
  );
  late final TextEditingController _message = TextEditingController(
    text: widget.initial?.message ?? '',
  );

  late int _trigger = normalizeContactTriggerMinutes(
    widget.initial?.triggerMinutesAfterGrace ?? minContactTriggerMinutes,
  );

  late String? _recordingPath = widget.initial?.recordingPath;

  bool _recording = false;
  bool _playing = false;
  StreamSubscription<bool>? _playbackSubscription;

  /// Shown in place of the buttons' result when the microphone was refused.
  String? _error;

  @override
  void initState() {
    super.initState();
    _playbackSubscription = ref
        .read(voicePlayerProvider)
        .playing
        .listen((on) {
          if (mounted) setState(() => _playing = on);
        });
  }

  @override
  void dispose() {
    _playbackSubscription?.cancel();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  /// Empty is null throughout: a blank field means "not given", never "".
  String? _trimmedOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  OversleepContact? get _value {
    final name = _name.text.trim();
    if (name.isEmpty) return null;
    return OversleepContact(
      name: name,
      phone: _trimmedOrNull(_phone),
      email: _trimmedOrNull(_email),
      triggerMinutesAfterGrace: normalizeContactTriggerMinutes(_trigger),
      message: _trimmedOrNull(_message),
      recordingPath: _recordingPath,
    );
  }

  void _showError(String message) {
    setState(() => _error = message);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startRecording() async {
    final recorder = ref.read(voiceRecorderProvider);
    if (!await recorder.hasPermission()) {
      if (!mounted) return;
      _showError('マイクの使用が許可されていないため録音できません。端末の設定から許可してください。');
      return;
    }
    // Allocating the file and opening the microphone are the two places this
    // can fail on a real device — no storage, or the mic already held by a
    // call. Either way the screen says so instead of throwing under the tap.
    try {
      final path = await ref.read(contactRecordingPathProvider)(widget.alarmId);
      await recorder.start(path);
    } catch (_) {
      if (!mounted) return;
      _showError('録音を開始できませんでした。ほかのアプリがマイクを使っていないか確認してください。');
      return;
    }
    if (!mounted) return;
    setState(() {
      _recording = true;
      _error = null;
    });
  }

  Future<void> _stopRecording() async {
    final path = await ref.read(voiceRecorderProvider).stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      // A stop that produced nothing leaves the previous recording alone: the
      // user has not asked for it to be thrown away, 削除 is how that is said.
      if (path != null) _recordingPath = path;
    });
  }

  Future<void> _play() async {
    final path = _recordingPath;
    if (path == null) return;
    await ref.read(voicePlayerProvider).play(path);
  }

  Future<void> _deleteRecording() async {
    final path = _recordingPath;
    setState(() => _recordingPath = null);
    if (path == null) return;
    await ref.read(voicePlayerProvider).stop();
    // The file is the app's own, inside app storage, so deleting it here is
    // the whole deletion. A file that is already gone is not an error.
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  String get _recordingStatus {
    if (_recording) return '録音中';
    if (_recordingPath != null) return _playing ? '再生中' : '録音あり';
    return '録音なし';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRecording = _recordingPath != null;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // Leaving mid-recording discards it: the file is still being written
        // and there is nothing to await it on the way out, so committing a
        // path that may never be finished would be worse than dropping it.
        if (_recording) unawaited(ref.read(voiceRecorderProvider).stop());
        unawaited(ref.read(voicePlayerProvider).stop());
        widget.onCommit(_value);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('寝坊時連絡先')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextField(
              key: const ValueKey('contactName'),
              controller: _name,
              decoration: const InputDecoration(
                labelText: '名前',
                helperText: '名前を消すと連絡先そのものが外れます',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('contactPhone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '電話番号',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('contactEmail'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text('連絡するタイミング', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '起床猶予が切れてから何分後に連絡するかです。鳴り始めからではありません。',
              style: theme.textTheme.bodyMedium,
            ),
            SliderNumberField(
              value: _trigger,
              min: minContactTriggerMinutes,
              max: maxContactTriggerMinutes,
              suffix: '分',
              semanticLabel: '連絡するタイミング',
              onChanged: (v) => setState(() => _trigger = v),
            ),
            Text(
              '$minContactTriggerMinutes〜$maxContactTriggerMinutes分',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            TextField(
              key: const ValueKey('contactMessage'),
              controller: _message,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'メッセージ',
                helperText: 'メールの本文、そして自動音声で読み上げる原稿になります',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text('録音', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '自分の声で伝えたいときに録音します。文章の代わりにこの音声が流れます。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _recording ? Icons.fiber_manual_record : Icons.mic_none,
                  color: _recording ? theme.colorScheme.error : null,
                ),
                const SizedBox(width: 8),
                Text(
                  _recordingStatus,
                  key: const ValueKey('contactRecordingStatus'),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: _recording ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('contactRecordStart'),
                  onPressed: _recording ? null : _startRecording,
                  icon: const Icon(Icons.mic),
                  label: const Text('録音開始'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('contactRecordStop'),
                  onPressed: _recording ? _stopRecording : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('停止'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('contactRecordPlay'),
                  onPressed: hasRecording && !_recording ? _play : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('再生'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('contactRecordDelete'),
                  onPressed: hasRecording && !_recording
                      ? _deleteRecording
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('削除'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 32),
            Text(
              '現在は実際の送信は行いません。発火した記録がアプリ内に残るだけです'
              '（次のフェーズでサーバー送信に対応予定）。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/sound_library.dart';
import '../../services/sound_file_importer.dart';
import '../../services/sound_preview_player.dart';

/// サウンド: which sound this alarm rings with.
///
/// Like the other sub-screens, the choice is handed back when the screen
/// closes. Preview plays at the ordinary media volume — the alarm's own volume
/// is not something to inflict on someone browsing a list.
class SoundSubScreen extends ConsumerStatefulWidget {
  const SoundSubScreen({
    super.key,
    required this.initial,
    required this.onCommit,
  });

  final String initial;
  final ValueChanged<String> onCommit;

  @override
  ConsumerState<SoundSubScreen> createState() => _SoundSubScreenState();
}

class _SoundSubScreenState extends ConsumerState<SoundSubScreen> {
  late String _selected = widget.initial;
  String? _playing;
  bool _importing = false;

  /// Held rather than looked up on demand: `ref` is unusable once the element
  /// is disposed, and disposal is exactly when the preview has to be silenced.
  late final SoundPreviewPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = ref.read(soundPreviewPlayerProvider);
  }

  @override
  void dispose() {
    // Leaving the screen must not leave a sound playing behind it.
    unawaited(_player.stop());
    super.dispose();
  }

  Future<void> _togglePreview(String soundId) async {
    if (_playing == soundId) {
      await _player.stop();
      if (mounted) setState(() => _playing = null);
      return;
    }
    setState(() => _playing = soundId);
    await _player.play(soundId);
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final soundId = await ref.read(soundFileImporterProvider).pickAndImport();
      if (!mounted) return;
      // A cancelled picker leaves the current choice exactly as it was.
      if (soundId != null) setState(() => _selected = soundId);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Widget _previewButton(String soundId) => IconButton(
    key: ValueKey('preview-$soundId'),
    tooltip: _playing == soundId ? '停止' : '再生',
    onPressed: () => _togglePreview(soundId),
    icon: Icon(_playing == soundId ? Icons.stop : Icons.play_arrow),
  );

  @override
  Widget build(BuildContext context) {
    final device = isDeviceSound(_selected) ? _selected : null;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) widget.onCommit(_selected);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('サウンド')),
        body: ListView(
          children: [
            for (final sound in soundLibrary)
              ListTile(
                key: ValueKey('sound-${sound.id}'),
                onTap: () => setState(() => _selected = sound.id),
                leading: _previewButton(sound.id),
                title: Text(sound.label),
                trailing: _selected == sound.id
                    ? const Icon(Icons.check)
                    : null,
              ),
            if (device != null)
              ListTile(
                key: const ValueKey('sound-device'),
                leading: _previewButton(device),
                title: Text(soundLabel(device)),
                subtitle: const Text('この端末から選んだ音'),
                trailing: const Icon(Icons.check),
              ),
            const Divider(),
            ListTile(
              key: const ValueKey('pickDeviceSound'),
              onTap: _importing ? null : _import,
              leading: const Icon(Icons.folder_open),
              title: const Text('端末内のファイルから選ぶ'),
              subtitle: const Text('アプリの中にコピーするので、元のファイルを消しても鳴ります'),
              trailing: _importing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

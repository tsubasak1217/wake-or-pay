import 'package:flutter/material.dart';

import '../../domain/sound_library.dart';

/// サウンド: which sound this alarm rings with.
///
/// Like the other sub-screens, the choice is handed back when the screen
/// closes.
class SoundSubScreen extends StatefulWidget {
  const SoundSubScreen({
    super.key,
    required this.initial,
    required this.onCommit,
  });

  final String initial;
  final ValueChanged<String> onCommit;

  @override
  State<SoundSubScreen> createState() => SoundSubScreenState();
}

class SoundSubScreenState extends State<SoundSubScreen> {
  late String _selected = widget.initial;

  /// Set when the current selection is a file picked off the device, so it
  /// keeps a row of its own at the bottom of the list.
  String? get _deviceSoundId => isDeviceSound(_selected) ? _selected : null;

  void select(String soundId) => setState(() => _selected = soundId);

  @override
  Widget build(BuildContext context) {
    final device = _deviceSoundId;
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
                onTap: () => select(sound.id),
                title: Text(sound.label),
                trailing: _selected == sound.id
                    ? const Icon(Icons.check)
                    : null,
              ),
            if (device != null)
              ListTile(
                key: const ValueKey('sound-device'),
                title: Text(soundLabel(device)),
                subtitle: const Text('この端末から選んだ音'),
                trailing: const Icon(Icons.check),
              ),
          ],
        ),
      ),
    );
  }
}

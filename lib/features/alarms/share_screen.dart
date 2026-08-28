import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/oversleep_contact_rules.dart';
import '../../services/voice_recorder.dart';
import '../widgets/discord_icon.dart';
import 'discord_webhooks_screen.dart';
import 'edit_sub_screens.dart';
import 'widgets/mode_tile.dart';
import 'widgets/recording_bar.dart';
import 'widgets/settings_island.dart';

/// 寝坊共有設定: where an overslept alarm is announced, per spec 11.6.
///
/// The group half of the notification, next to 寝坊時の連絡設定's personal half.
/// The difference is who is on the other end: a contact is one person being
/// asked to go and wake somebody, a 共有先 is a room being told what happened.
///
/// Three islands: the destinations, the message, and the recording that goes
/// with it. Committed on pop like every other editor sub-screen.
class ShareSubScreen extends ConsumerStatefulWidget {
  const ShareSubScreen({
    super.key,
    required this.initial,
    required this.onCommit,
    this.alarmId,
  });

  final OversleepShare? initial;
  final ValueChanged<OversleepShare?> onCommit;

  /// Only used to name the recording file, so it is optional.
  final String? alarmId;

  @override
  ConsumerState<ShareSubScreen> createState() => _ShareSubScreenState();
}

class _ShareSubScreenState extends ConsumerState<ShareSubScreen> {
  late Set<String> _webhookIds = {...?widget.initial?.webhookIds};
  late MessageMode _messageMode =
      widget.initial?.messageMode ?? MessageMode.standard;
  late final TextEditingController _message = TextEditingController(
    text: widget.initial?.message ?? '',
  );
  late String? _recordingPath = widget.initial?.recordingPath;
  late List<double> _waveform = widget.initial?.recordingWaveform ?? const [];

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  /// What this screen hands back, or null when it would announce nothing.
  ///
  /// A share with no destination is not a share: it would carry a message and
  /// a recording to nowhere, and reading it back as a live one would put
  /// 「設定済み」 on the editor row over an alarm that announces itself nowhere.
  OversleepShare? get _value {
    if (_webhookIds.isEmpty) return null;
    final message = _message.text.trim();
    return OversleepShare(
      webhookIds: {..._webhookIds},
      messageMode: _messageMode,
      message: message.isEmpty ? null : message,
      recordingPath: _recordingPath,
      recordingWaveform: _waveform,
    );
  }

  /// Throws the recording away. Called by the panel once the user has said
  /// yes to the confirmation, so there is nothing left to ask here.
  Future<void> _deleteRecording() async {
    final path = _recordingPath;
    setState(() {
      _recordingPath = null;
      _waveform = const [];
    });
    if (path == null) return;
    // The file is the app's own, inside app storage, so deleting it here is
    // the whole deletion. A file that is already gone is not an error.
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// The example the preview is drawn against: a fixed 07:00, so the text does
  /// not move under the user while they read it.
  static final _previewAt = DateTime(2026, 1, 1, 7);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watched: registering or deleting a 共有先 happens on a screen pushed over
    // this one, and the count has to be right the moment it pops. Ids with no
    // row behind them are not counted — see [DiscordWebhookRepository].
    final live = liveShareTargetCount(
      OversleepShare(webhookIds: _webhookIds),
      ref.watch(discordWebhookListProvider),
    );

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // Leaving mid-recording discards it: the file is still being written
        // and there is nothing to await it on the way out, so committing a
        // path that may never be finished would be worse than dropping it.
        // Unconditional because the panel below owns whether it is recording,
        // and stopping a recorder that is not running is not an error.
        unawaited(ref.read(voiceRecorderProvider).stop());
        unawaited(ref.read(voicePlayerProvider).stop());
        widget.onCommit(_value);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('寝坊共有設定')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            SettingsIsland(
              title: '寝坊共有設定',
              children: [
                SettingRow(
                  key: const ValueKey('shareDiscordRow'),
                  leading: const DiscordIcon(),
                  label: 'Discord',
                  value: live == 0 ? 'なし' : '$live件',
                  onTap: () => pushEditorSubScreen(
                    context,
                    DiscordWebhooksSubScreen(
                      initial: _webhookIds,
                      onCommit: (ids) => setState(() => _webhookIds = ids),
                    ),
                  ),
                ),
                const SettingSwitchRow(
                  key: ValueKey('shareXRow'),
                  label: 'X に投稿',
                  value: false,
                  enabled: false,
                  subtitle: 'まだ実装しない',
                  onChanged: _ignoreToggle,
                ),
              ],
            ),
            SettingsIsland(
              title: '共有メッセージ設定',
              children: [
                ModeTile(
                  key: const ValueKey('shareModeStandard'),
                  label: 'デフォルト',
                  description: 'アプリが用意した文面を投稿します。',
                  selected: _messageMode == MessageMode.standard,
                  onTap: () =>
                      setState(() => _messageMode = MessageMode.standard),
                ),
                ModeTile(
                  key: const ValueKey('shareModeCustom'),
                  label: 'カスタムメッセージ',
                  description: '自分の言葉で書いた文面を投稿します。',
                  selected: _messageMode == MessageMode.custom,
                  onTap: () =>
                      setState(() => _messageMode = MessageMode.custom),
                ),
                if (_messageMode == MessageMode.custom)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: TextField(
                      key: const ValueKey('shareMessage'),
                      controller: _message,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'メッセージ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(
                      '例：${defaultOversleepShareMessage(at: _previewAt)}',
                      key: const ValueKey('shareMessagePreview'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
            SettingsIsland(
              title: '共有音声の録音',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: ContactRecorderPanel(
                    alarmId: widget.alarmId,
                    recordingPath: _recordingPath,
                    waveform: _waveform,
                    onRecorded: (path, waveform) => setState(() {
                      _recordingPath = path;
                      _waveform = waveform;
                    }),
                    onDeleted: _deleteRecording,
                  ),
                ),
              ],
            ),
            Text(
              '録音があれば、投稿に音声ファイルとして添付します。'
              'Discord へは実際に投稿します。共有先を長押しすると、'
              'テスト送信で URL を確かめられます。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// A disabled switch still needs a callback to name; it is never reached.
void _ignoreToggle(bool _) {}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where a Discord flow currently is.
///
/// The whole point of this enum is that the previous version had none: the
/// button spun, the browser opened, and whatever happened next happened off
/// screen. A user whose flow failed had no sentence to report and no way to
/// tell 「まだ待っている」 from 「もう終わっている」.
enum DiscordFlowPhase {
  /// Nothing in the air. The row shows its normal self.
  idle,

  /// Between the button and the authorize page being on screen.
  opening,

  /// The authorize page is up, somewhere else, and the callback has not
  /// arrived. This is the long one — up to [discordFlowTimeout].
  waiting,

  /// The callback arrived and the app is finishing the job: `/users/@me`, or
  /// the 連携サーバー exchange.
  working,

  done,

  failed,
}

/// A phase and the sentence that goes with it.
@immutable
class DiscordFlowStatus {
  const DiscordFlowStatus(this.phase, this.message);

  const DiscordFlowStatus.idle() : this(DiscordFlowPhase.idle, '');

  final DiscordFlowPhase phase;

  /// Japanese, and specific. 「うまくいきませんでした」 is not a message, it is a
  /// shrug — every failure here names what failed and what to do about it.
  final String message;

  bool get busy =>
      phase == DiscordFlowPhase.opening ||
      phase == DiscordFlowPhase.waiting ||
      phase == DiscordFlowPhase.working;

  @override
  bool operator ==(Object other) =>
      other is DiscordFlowStatus &&
      other.phase == phase &&
      other.message == message;

  @override
  int get hashCode => Object.hash(phase, message);

  @override
  String toString() => 'DiscordFlowStatus($phase, $message)';
}

/// One line of 連携ログ.
@immutable
class DiscordLogEntry {
  const DiscordLogEntry(this.at, this.message);

  final DateTime at;
  final String message;

  /// `03:28:41` — the wall clock, because the only thing anybody compares this
  /// against is "when I pressed the button".
  String get clock {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }

  @override
  bool operator ==(Object other) =>
      other is DiscordLogEntry && other.at == at && other.message == message;

  @override
  int get hashCode => Object.hash(at, message);

  @override
  String toString() => '$clock $message';
}

/// How many lines 連携ログ keeps. Enough for a handful of attempts, few enough
/// to fit on a phone without scrolling being the point of the screen.
const kDiscordLogLength = 20;

/// The last [kDiscordLogLength] things that happened, newest first.
///
/// In memory only, deliberately. This is a diagnostic for the attempt the user
/// just made, not a record — and the URLs that pass through a Discord flow are
/// exactly the values (a `state`, once an `access_token`) that must not be
/// written to storage. Nothing here is persisted, and nothing here contains a
/// token: the log records *that* a token arrived, never the token.
class DiscordLinkLog extends Notifier<List<DiscordLogEntry>> {
  @override
  List<DiscordLogEntry> build() => const [];

  /// [now] is injectable so a test can assert on the timestamps it renders.
  void add(String message, {DateTime? now}) {
    final entry = DiscordLogEntry(now ?? DateTime.now(), message);
    state = [entry, ...state].take(kDiscordLogLength).toList(growable: false);
  }

  void clear() => state = const [];
}

final discordLinkLogProvider =
    NotifierProvider<DiscordLinkLog, List<DiscordLogEntry>>(
      DiscordLinkLog.new,
    );

/// The status line under 「Discord で連携」 and on the 共有先 screen.
class DiscordFlowStatusController extends Notifier<DiscordFlowStatus> {
  @override
  DiscordFlowStatus build() => const DiscordFlowStatus.idle();

  /// Every status change is also a log line. Keeping the two in one call is
  /// what stops them drifting — a phase the log never mentions is a phase
  /// nobody can debug afterwards.
  void set(DiscordFlowPhase phase, String message) {
    state = DiscordFlowStatus(phase, message);
    if (message.isNotEmpty) {
      ref.read(discordLinkLogProvider.notifier).add(message);
    }
  }

  void reset() => state = const DiscordFlowStatus.idle();
}

final discordFlowStatusProvider =
    NotifierProvider<DiscordFlowStatusController, DiscordFlowStatus>(
      DiscordFlowStatusController.new,
    );

/// What a service is handed so it can narrate itself without knowing about
/// Riverpod, a widget tree, or a clock.
///
/// A plain pair of callbacks rather than an interface: there is one
/// implementation and one no-op, and the no-op is what every unit test wants.
@immutable
class DiscordFlowReporter {
  const DiscordFlowReporter({this.onPhase, this.onLog});

  /// The no-op. Services default to this so they stay constructible from a
  /// test with nothing wired up.
  static const silent = DiscordFlowReporter();

  final void Function(DiscordFlowPhase phase, String message)? onPhase;
  final void Function(String message)? onLog;

  void phase(DiscordFlowPhase phase, String message) =>
      onPhase?.call(phase, message);

  /// A line that is worth recording but is not a status the user is waiting
  /// on — 「ブラウザで Discord を開きました」 while the phase stays 承認待ち.
  void log(String message) => onLog?.call(message);
}

/// Wires the reporter to the two notifiers above.
final discordFlowReporterProvider = Provider<DiscordFlowReporter>(
  (ref) => DiscordFlowReporter(
    onPhase: (phase, message) =>
        ref.read(discordFlowStatusProvider.notifier).set(phase, message),
    onLog: (message) => ref.read(discordLinkLogProvider.notifier).add(message),
  ),
);

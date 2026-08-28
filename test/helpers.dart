import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wake_or_pay/data/database.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/data/repositories/mail_settings_repository.dart';
import 'package:wake_or_pay/domain/discord_post.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/send_result.dart';
import 'package:wake_or_pay/services/alarm_service.dart';
import 'package:wake_or_pay/services/app_notifier.dart';
import 'package:wake_or_pay/services/discord_auth_launcher.dart';
import 'package:wake_or_pay/services/discord_callback_router.dart';
import 'package:wake_or_pay/services/discord_sender.dart';
import 'package:wake_or_pay/services/mail_sender.dart';
import 'package:wake_or_pay/services/phone_caller.dart';
import 'package:wake_or_pay/services/route_permissions.dart';
import 'package:wake_or_pay/services/secret_store.dart';
import 'package:wake_or_pay/services/sms_sender.dart';
import 'package:wake_or_pay/services/voice_recorder.dart';

/// Overrides backing the app with an in-memory database and in-memory
/// preferences. The database is closed when the owning container is disposed.
Future<List<Override>> testOverrides({
  Map<String, Object> prefs = const {},
  List<Override> extra = const [],
}) async {
  SharedPreferences.setMockInitialValues({...prefs});
  final preferences = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(preferences),
    appDatabaseProvider.overrideWith((ref) {
      final db = AppDatabase.memory();
      ref.onDispose(db.close);
      return db;
    }),
    ...extra,
  ];
}

Future<ProviderContainer> testContainer({
  Map<String, Object> prefs = const {},
  List<Override> extra = const [],
}) async {
  final container = ProviderContainer(
    overrides: await testOverrides(prefs: prefs, extra: extra),
  );
  addTearDown(container.dispose);
  return container;
}

/// Replaces every call that would reach the `alarm` plugin, so widget tests can
/// drive the real controllers without a platform underneath.
class FakeAlarmService extends AlarmService {
  FakeAlarmService(super.ref);

  final scheduled = <String>[];
  final cancelled = <String>[];

  /// Every re-ring armed by a snooze, in order.
  final rearmed = <({String alarmId, DateTime ringAt})>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> schedule(Alarm alarm, {DateTime? from}) async {
    scheduled.add(alarm.id);
  }

  @override
  Future<void> cancel(Alarm alarm) async {
    cancelled.add(alarm.id);
  }

  @override
  Future<void> setRingAt(Alarm alarm, DateTime ringAt) async {
    rearmed.add((alarmId: alarm.id, ringAt: ringAt));
  }
}

Override fakeAlarmServiceOverride() =>
    alarmServiceProvider.overrideWith((ref) => FakeAlarmService(ref));

/// The notifications a test's container posted. The provider's default is
/// already a [RecordingNotifier]; this just reads it back with a type.
RecordingNotifier notifierOf(ProviderContainer container) =>
    container.read(appNotifierProvider) as RecordingNotifier;

/// A recorder that never touches a microphone: it remembers the path it was
/// asked to write, hands the same one back from [stop], and lets the test push
/// microphone levels in by hand.
class FakeVoiceRecorder implements VoiceRecorder {
  FakeVoiceRecorder({this.permitted = true});

  final bool permitted;
  final started = <String>[];
  int permissionAsked = 0;
  int stopped = 0;

  final _amplitude = StreamController<double>.broadcast();

  String? _current;

  /// One microphone reading, as the plugin's stream would have delivered it.
  void emitAmplitude(double level) => _amplitude.add(level);

  @override
  Future<bool> hasPermission() async {
    permissionAsked++;
    return permitted;
  }

  @override
  Future<void> start(String path) async {
    started.add(path);
    _current = path;
  }

  @override
  Future<String?> stop() async {
    stopped++;
    final path = _current;
    _current = null;
    return path;
  }

  @override
  Stream<double> get amplitude => _amplitude.stream;

  @override
  Future<void> dispose() async => _amplitude.close();
}

/// A recorder whose microphone level the platform will not report — the
/// ordinary case on an emulator, and never a reason not to record.
class SilentAmplitudeRecorder extends FakeVoiceRecorder {
  @override
  Stream<double> get amplitude => const Stream<double>.empty();
}

class FakeVoicePlayer implements VoicePlayer {
  final played = <String>[];
  final _playing = StreamController<bool>.broadcast();
  final _position = StreamController<Duration>.broadcast();

  /// The knob following playback, as the platform's position stream would.
  void emitPosition(Duration at) => _position.add(at);

  void finish() => _playing.add(false);

  @override
  Future<void> play(String path) async {
    played.add(path);
    _playing.add(true);
  }

  @override
  Future<void> stop() async => _playing.add(false);

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Future<void> dispose() async {
    await _playing.close();
    await _position.close();
  }
}

/// An HTTP client that never reaches the network.
///
/// Every registration form in this app talks to Discord, and a test that
/// actually posted to a webhook would post into somebody's real channel. This
/// answers from a table instead, and remembers what was asked for.
class FakeHttpClient extends http.BaseClient {
  FakeHttpClient({
    this.responses = const {},
    this.throws = false,
    this.postStatus = 204,
    this.postBody,
  });

  /// URL → the body to answer a **GET** with. A URL that is not in here
  /// answers 404. Only the name lookup reads this.
  final Map<String, String> responses;

  /// True makes every request throw, which is what being offline looks like.
  final bool throws;

  /// What a **POST** answers with. Discord's own webhook answer is a 204 with
  /// no body; a revoked webhook is a 404.
  final int postStatus;

  /// The body a **POST** answers with. Null is an empty body, which is what
  /// Discord's webhook endpoint sends; the 連携サーバー answers with JSON.
  final String? postBody;

  final requested = <String>[];

  /// The headers of every request, in the same order as [requested]. The
  /// `Authorization: Bearer …` on `/users/@me` is only checkable here.
  final headers = <Map<String, String>>[];

  /// Every POST, with its multipart body already decoded — the fields as
  /// Discord would have parsed them, and the filenames of the parts.
  final posted = <FakePost>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    requested.add(url);
    headers.add(Map.of(request.headers));
    if (request.method == 'POST') {
      posted.add(
        FakePost(
          url: url,
          fields: request is http.MultipartRequest
              ? Map.of(request.fields)
              : const {},
          filenames: request is http.MultipartRequest
              ? [for (final f in request.files) f.filename ?? '']
              : const [],
          // A plain (non-multipart) POST — the 連携サーバー's JSON body.
          body: request is http.Request ? request.body : '',
        ),
      );
      if (throws) throw const SocketException('offline');
      return http.StreamedResponse(
        postBody == null
            ? const Stream<List<int>>.empty()
            : Stream.value(utf8.encode(postBody!)),
        postStatus,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (throws) throw const SocketException('offline');
    final body = responses[url];
    return http.StreamedResponse(
      Stream.value(utf8.encode(body ?? '{}')),
      body == null ? 404 : 200,
      // Discord sends this, and without it `http` falls back to latin1 and
      // turns a Japanese webhook name into mojibake — a fault in the fake, not
      // in the code under test.
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

/// One POST as [FakeHttpClient] saw it.
class FakePost {
  FakePost({
    required this.url,
    required this.fields,
    required this.filenames,
    this.body = '',
  });

  final String url;
  final Map<String, String> fields;
  final List<String> filenames;

  /// The raw request body, for the POSTs that are not multipart.
  final String body;

  /// The `content` Discord would have posted, dug back out of `payload_json`.
  String get content =>
      (jsonDecode(fields['payload_json'] ?? '{}') as Map)['content'] as String? ??
      '';
}

Override fakeHttpClientOverride(FakeHttpClient client) =>
    httpClientProvider.overrideWithValue(client);

/// A sender that posts nowhere and remembers everything it was asked to post.
///
/// [failFor] keys a canned result by webhook URL, so a test can make one 共有先
/// refuse while the other one works — which is the case that matters, because
/// a dead webhook must never stop a live one.
class FakeDiscordWebhookSender implements DiscordWebhookSender {
  FakeDiscordWebhookSender({this.failFor = const {}});

  final Map<String, DiscordPostResult> failFor;

  final posts = <({String url, String content, String? recordingPath})>[];

  @override
  Future<DiscordPostResult> post({
    required String url,
    required String content,
    String? recordingPath,
  }) async {
    posts.add((url: url, content: content, recordingPath: recordingPath));
    return failFor[url] ?? const DiscordPostResult.success(204);
  }
}

Override fakeDiscordSenderOverride(FakeDiscordWebhookSender sender) =>
    discordWebhookSenderProvider.overrideWithValue(sender);

/// A mail sender that reaches no SMTP server and remembers what it was asked
/// to send.
///
/// The default [mailSenderProvider] is the real one, which is safe in a test
/// only because an unconfigured account refuses before it opens a socket.
/// Anything that *does* configure an account must hand this in instead — the
/// 送信元アドレス in a test is somebody's real inbox.
class FakeMailSender implements MailSender {
  FakeMailSender({this.result = const SendResult.success()});

  final SendResult result;
  final sent = <({String to, String subject, String body})>[];

  @override
  Future<SendResult> send({
    required String to,
    required String subject,
    required String body,
  }) async {
    sent.add((to: to, subject: subject, body: body));
    return result;
  }
}

Override fakeMailSenderOverride(FakeMailSender sender) =>
    mailSenderProvider.overrideWithValue(sender);

/// The prefs a fully configured メール送信設定 leaves behind, so a test can start
/// from 「設定済み」 without walking the screen.
///
/// The password itself is deliberately **not** here — it never goes in prefs.
/// Pair this with [seededSecretStoreOverride] for anything that sends.
Map<String, Object> configuredMailPrefs({
  String from = 'me@example.com',
  String host = 'smtp.example.com',
}) => {
  'mail.presetId': 'custom',
  'mail.host': host,
  'mail.port': defaultSmtpPort,
  'mail.useSsl': false,
  'mail.fromAddress': from,
  'mail.username': from,
  'mail.passwordSaved': true,
};

/// A secret store that already holds [mailPassword], for a test that starts
/// from a configured account.
Override seededSecretStoreOverride({String mailPassword = 'app-password'}) =>
    secretStoreProvider.overrideWithValue(
      InMemorySecretStore()
        ..values[MailSettingsRepository.passwordSecretKey] = mailPassword,
    );

/// An SMS sender that reaches no radio and remembers what it was asked to
/// send. The provider's default is already a [RecordingSmsSender]; this reads
/// it back with a type.
RecordingSmsSender smsSenderOf(ProviderContainer container) =>
    container.read(smsSenderProvider) as RecordingSmsSender;

Override recordingSmsSenderOverride(RecordingSmsSender sender) =>
    smsSenderProvider.overrideWithValue(sender);

/// Permissions that answer [granted] without a platform. The provider's
/// default already grants; this is for the refusal case.
Override routePermissionsOverride({bool granted = true}) =>
    routePermissionsProvider.overrideWithValue(
      AlwaysGrantRoutePermissions(granted: granted),
    );

/// A caller that dials nobody and remembers the numbers it was handed. The
/// provider's default is already a [RecordingPhoneCaller]; this reads it back
/// with a type so a test can also push call states in.
RecordingPhoneCaller phoneCallerOf(ProviderContainer container) =>
    container.read(phoneCallerProvider) as RecordingPhoneCaller;

Override recordingPhoneCallerOverride(RecordingPhoneCaller caller) =>
    phoneCallerProvider.overrideWithValue(caller);

/// A launcher that opens nothing.
///
/// [replyWith] is handed the authorize URL and answers with the callback URL
/// the Discord app or the browser would have come back on — pushed into
/// [FakeDeepLinks] so it travels the **real** route, through the router that
/// production uses. A test can therefore echo the real `state` back, echo a
/// wrong one, or answer with nothing at all and let the timeout fire.
class FakeDiscordAuthLauncher implements DiscordAuthLauncher {
  FakeDiscordAuthLauncher(this._links, {this.channel, this.replyWith});

  /// Nothing on the device could open the URL.
  FakeDiscordAuthLauncher.noApp(this._links)
    : channel = DiscordAuthChannel.none,
      replyWith = null;

  /// Opens, and then nothing ever comes back — the abandoned flow.
  FakeDiscordAuthLauncher.silent(this._links)
    : channel = DiscordAuthChannel.browser,
      replyWith = null;

  final FakeDeepLinks _links;

  /// Where the URL was opened. Defaults to the Discord app, which is the path
  /// the rework is about.
  final DiscordAuthChannel? channel;

  final String? Function(String authorizeUrl)? replyWith;

  /// Every authorize URL this was asked to open, in order.
  final opened = <String>[];

  @override
  Future<DiscordAuthChannel> open(String url) async {
    opened.add(url);
    final reply = replyWith?.call(url);
    if (reply != null) {
      // After the await, as a real redirect is: the flow must already be
      // registered, and a callback delivered synchronously here would hide a
      // listener registered too late.
      scheduleMicrotask(() => _links.emit(reply));
    }
    return channel ?? DiscordAuthChannel.discordApp;
  }
}

/// Stands in for `app_links` — the OS handing the app a `wakeorpay://` intent.
class FakeDeepLinks {
  final _controller = StreamController<Uri>.broadcast();

  Stream<Uri> get stream => _controller.stream;

  void emit(String uri) => _controller.add(Uri.parse(uri));

  void dispose() => _controller.close();
}

/// The `state` the app put in an authorize URL, read back out of it.
String stateOf(String authorizeUrl) =>
    Uri.parse(authorizeUrl).queryParameters['state']!;

/// Wires both halves of the Discord flow to fakes: nothing opens, and the
/// callback arrives over a stream a test controls.
List<Override> fakeDiscordFlowOverrides(
  FakeDeepLinks links,
  FakeDiscordAuthLauncher launcher,
) => [
  discordDeepLinkStreamProvider.overrideWithValue(links.stream),
  discordAuthLauncherProvider.overrideWithValue(launcher),
];

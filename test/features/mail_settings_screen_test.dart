import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/send_result.dart';
import 'package:wake_or_pay/features/profile/mail_settings_screen.dart';
import 'package:wake_or_pay/services/mail_settings.dart';
import 'package:wake_or_pay/services/secret_store.dart';

import '../helpers.dart';

/// Records the URLs the 「アプリパスワードを取得」 button asked to open, so no test
/// reaches a browser.
class _RecordingOpener {
  final opened = <Uri>[];
  bool result = true;

  Override get override =>
      mailUrlOpenerProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return result;
      });
}

Future<({ProviderContainer container, FakeMailSender mail})> openScreen(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  SendResult testResult = const SendResult.success(),
  List<Override> extra = const [],
}) async {
  final mail = FakeMailSender(result: testResult);
  final container = await testContainer(
    prefs: prefs,
    extra: [fakeMailSenderOverride(mail), ...extra],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MailSettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return (container: container, mail: mail);
}

/// The screen is one lazy ListView, and most of it is below a test viewport —
/// a widget that has never been scrolled to has not been built, so nothing can
/// be read off it or tapped. Every helper below goes through here.
///
/// scrollUntilVisible only scrolls one way, so it starts from the top each
/// time: a target already above the fold would otherwise be scrolled further
/// away.
Future<Finder> show(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  final list = find.byType(Scrollable).first;
  tester.state<ScrollableState>(list).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(target, 120, scrollable: list);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  return target;
}

Future<void> tap(WidgetTester tester, String key) async {
  await tester.tap(await show(tester, key));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(await show(tester, key), text);
  await tester.pumpAndSettle();
}

/// Reads a field that may be below the fold.
Future<TextField> field(WidgetTester tester, String key) async =>
    tester.widget<TextField>(await show(tester, key));

/// Fills a complete Gmail account — just the two fields now, the server is
/// derived from the address.
Future<void> fillGmail(WidgetTester tester) async {
  await enter(tester, 'mailFromField', 'me@gmail.com');
  await enter(tester, 'mailPasswordField', 'abcd efgh ijkl mnop');
}

void main() {
  testWidgets('a known address shows its provider and needs only two fields', (
    tester,
  ) async {
    await openScreen(tester);

    await enter(tester, 'mailFromField', 'me@gmail.com');

    expect(
      tester.widget<Text>(await show(tester, 'mailProviderHint')).data,
      'Gmail として送信します',
    );
    // The server fields are not on the screen for a known provider.
    expect(find.byKey(const ValueKey('mailHostField')), findsNothing);
    expect(find.byKey(const ValueKey('mailPortField')), findsNothing);
    // And the app-password button is offered.
    await show(tester, 'mailAppPasswordButton');
    expect(find.byKey(const ValueKey('mailAppPasswordButton')), findsOneWidget);
  });

  testWidgets('an unknown domain reveals 詳細設定', (tester) async {
    await openScreen(tester);

    // A plausible address on a domain no preset covers.
    await enter(tester, 'mailFromField', 'me@mycompany.co.jp');

    expect(find.byKey(const ValueKey('mailProviderHint')), findsNothing);
    await show(tester, 'mailUnknownDomainHint');
    // The server fields appear for manual entry.
    await show(tester, 'mailHostField');
    expect(find.byKey(const ValueKey('mailHostField')), findsOneWidget);
    expect(
      (await field(tester, 'mailHostField')).controller!.text,
      isEmpty,
      reason: '詳細設定 starts blank for manual entry',
    );
  });

  testWidgets('テスト送信 is refused until the account is complete', (tester) async {
    await openScreen(tester);

    Future<VoidCallback?> testButton() async => tester
        .widget<OutlinedButton>(await show(tester, 'mailTestButton'))
        .onPressed;

    expect(await testButton(), isNull);
    expect(find.byKey(const ValueKey('mailMissingNote')), findsOneWidget);

    await fillGmail(tester);
    await show(tester, 'mailTestButton');
    expect(find.byKey(const ValueKey('mailMissingNote')), findsNothing);
    expect(await testButton(), isNotNull);
  });

  testWidgets('保存 derives the server and puts the password out of prefs', (
    tester,
  ) async {
    final r = await openScreen(tester);
    await fillGmail(tester);

    await tap(tester, 'mailSaveButton');

    final stored = r.container.read(mailSettingsProvider);
    expect(stored.isConfigured, isTrue);
    expect(
      stored.host,
      'smtp.gmail.com',
      reason: 'the server is derived from the gmail.com domain, not typed',
    );
    expect(stored.port, defaultSmtpPort);
    expect(stored.useSsl, isFalse);
    expect(stored.fromAddress, 'me@gmail.com');
    expect(stored.username, 'me@gmail.com');
    expect(stored.presetId, 'Gmail');
    expect(
      r.container.read(mailSendingConfiguredProvider),
      isTrue,
      reason: 'this is the one flag the メール toggle reads',
    );

    final prefs = r.container.read(sharedPreferencesProvider);
    final dump = [
      for (final key in prefs.getKeys()) '$key=${prefs.get(key)}',
    ].join('\n');
    expect(dump, isNot(contains('abcd efgh')));
    expect(
      await r.container.read(mailSettingsRepositoryProvider).password(),
      'abcd efgh ijkl mnop',
    );

    // The field is gone entirely, and the screen says a password is held.
    expect(find.byKey(const ValueKey('mailPasswordField')), findsNothing);
    await show(tester, 'mailPasswordSavedNote');
    expect(find.byKey(const ValueKey('mailPasswordSavedNote')), findsOneWidget);
    expect(find.byKey(const ValueKey('mailPasswordUpdate')), findsOneWidget);
  });

  testWidgets('a saved password hides the field behind アプリパスワードを更新', (
    tester,
  ) async {
    await openScreen(
      tester,
      // Gmail, so the 「アプリパスワードを取得」 button has a page to offer:
      // it must be hidden with the field and come back with it.
      prefs: configuredMailPrefs(from: 'me@gmail.com', host: 'smtp.gmail.com'),
      extra: [seededSecretStoreOverride()],
    );

    // Nothing to type and nothing to fetch: the account is set up.
    expect(find.byKey(const ValueKey('mailPasswordField')), findsNothing);
    expect(find.byKey(const ValueKey('mailAppPasswordButton')), findsNothing);
    await show(tester, 'mailPasswordSavedNote');
    await show(tester, 'mailPasswordUpdate');
    // And 削除 is still right there, next to the note.
    expect(find.byKey(const ValueKey('mailPasswordClear')), findsOneWidget);

    await tap(tester, 'mailPasswordUpdate');

    // The field is back — empty, focused, with the 取得 button beside it.
    final revealed = await field(tester, 'mailPasswordField');
    expect(revealed.controller!.text, isEmpty);
    expect(revealed.focusNode!.hasFocus, isTrue);
    expect(find.byKey(const ValueKey('mailAppPasswordButton')), findsOneWidget);
    expect(find.byKey(const ValueKey('mailPasswordUpdate')), findsNothing);
  });

  testWidgets('アプリパスワードを更新 → 入力 → 保存 stores the new password', (
    tester,
  ) async {
    final r = await openScreen(
      tester,
      prefs: configuredMailPrefs(),
      extra: [seededSecretStoreOverride()],
    );

    await tap(tester, 'mailPasswordUpdate');
    await enter(tester, 'mailPasswordField', 'brand new secret');
    await tap(tester, 'mailSaveButton');

    expect(
      await r.container.read(mailSettingsRepositoryProvider).password(),
      'brand new secret',
    );
    // And the field folds away again: what was typed is in the keystore.
    expect(find.byKey(const ValueKey('mailPasswordField')), findsNothing);
    await show(tester, 'mailPasswordUpdate');
  });

  testWidgets('with nothing stored the field is on screen from the start', (
    tester,
  ) async {
    await openScreen(tester);
    await show(tester, 'mailPasswordField');
    expect(find.byKey(const ValueKey('mailPasswordUpdate')), findsNothing);
    expect(find.byKey(const ValueKey('mailPasswordSavedNote')), findsNothing);
  });

  testWidgets('an unknown domain saves the hand-entered server', (tester) async {
    final r = await openScreen(tester);

    await enter(tester, 'mailFromField', 'me@mycompany.co.jp');
    await enter(tester, 'mailHostField', 'smtp.mycompany.co.jp');
    await enter(tester, 'mailPortField', '465');
    await tap(tester, 'mailSslRow');
    await enter(tester, 'mailPasswordField', 'secretsecret');

    await tap(tester, 'mailSaveButton');

    final stored = r.container.read(mailSettingsProvider);
    expect(stored.host, 'smtp.mycompany.co.jp');
    expect(stored.port, 465);
    expect(stored.useSsl, isTrue);
    expect(stored.fromAddress, 'me@mycompany.co.jp');
    expect(stored.username, 'me@mycompany.co.jp');
    expect(stored.presetId, MailPreset.customId);
    expect(stored.isConfigured, isTrue);
  });

  testWidgets('the password field is masked until the eye is pressed', (
    tester,
  ) async {
    await openScreen(tester);

    expect((await field(tester, 'mailPasswordField')).obscureText, isTrue);
    await tap(tester, 'mailPasswordReveal');
    expect((await field(tester, 'mailPasswordField')).obscureText, isFalse);
  });

  testWidgets('the 「アプリパスワードを取得」 button opens the provider page', (
    tester,
  ) async {
    final opener = _RecordingOpener();
    await openScreen(tester, extra: [opener.override]);
    await enter(tester, 'mailFromField', 'me@gmail.com');

    await tap(tester, 'mailAppPasswordButton');

    expect(opener.opened, hasLength(1));
    expect(
      opener.opened.single.toString(),
      'https://myaccount.google.com/apppasswords',
    );
  });

  testWidgets('テスト送信 goes to the user themselves and reports the outcome', (
    tester,
  ) async {
    final r = await openScreen(tester);
    await fillGmail(tester);

    await tap(tester, 'mailTestButton');

    expect(r.mail.sent, hasLength(1));
    expect(
      r.mail.sent.single.to,
      'me@gmail.com',
      reason: 'nobody else may be mailed by pressing a test button',
    );
    expect(r.mail.sent.single.subject, mailTestSubject);
    expect(
      tester.widget<Text>(await show(tester, 'mailTestResult')).data,
      contains('me@gmail.com'),
    );
    // Pressing テスト送信 also stores the form, so the account it proved is the
    // one an alarm would use.
    expect(r.container.read(mailSendingConfiguredProvider), isTrue);
  });

  testWidgets('a failed テスト送信 says why, in words', (tester) async {
    final r = await openScreen(
      tester,
      testResult: const SendResult.failure(SendFailure.auth),
    );
    await fillGmail(tester);

    await tap(tester, 'mailTestButton');

    expect(
      tester.widget<Text>(await show(tester, 'mailTestResult')).data,
      contains(SendFailure.auth),
    );
    expect(r.mail.sent, hasLength(1));
  });

  testWidgets('削除 takes the password and the 設定済み state away', (tester) async {
    final r = await openScreen(
      tester,
      prefs: configuredMailPrefs(),
      extra: [seededSecretStoreOverride()],
    );
    expect(r.container.read(mailSendingConfiguredProvider), isTrue);

    await tap(tester, 'mailPasswordClear');

    expect(r.container.read(mailSendingConfiguredProvider), isFalse);
    expect(
      await r.container.read(mailSettingsRepositoryProvider).password(),
      isNull,
    );
    expect(
      (r.container.read(secretStoreProvider) as InMemorySecretStore).values,
      isEmpty,
    );
    // Nothing saved any more, so the field comes back on its own.
    await show(tester, 'mailPasswordField');
    expect(find.byKey(const ValueKey('mailPasswordUpdate')), findsNothing);
  });

  testWidgets('the provider note is on the screen', (tester) async {
    await openScreen(tester);
    await enter(tester, 'mailFromField', 'me@gmail.com');
    await show(tester, 'mailProviderNote');

    expect(find.textContaining('2段階認証'), findsOneWidget);
    expect(find.textContaining('アプリパスワード'), findsWidgets);
  });

  testWidgets('a Japanese ISP domain configures itself, SSL and all', (
    tester,
  ) async {
    final r = await openScreen(tester);

    await enter(tester, 'mailFromField', 'me@ocn.ne.jp');

    expect(
      tester.widget<Text>(await show(tester, 'mailProviderHint')).data,
      'OCN として送信します',
    );
    // A known provider needs no hand-entered server.
    expect(find.byKey(const ValueKey('mailHostField')), findsNothing);
    expect(find.byKey(const ValueKey('mailPortField')), findsNothing);
    await show(tester, 'mailProviderNote');
    expect(find.byKey(const ValueKey('mailProviderNote')), findsOneWidget);

    await enter(tester, 'mailPasswordField', 'ocnpassword');
    await tap(tester, 'mailSaveButton');

    final stored = r.container.read(mailSettingsProvider);
    expect(stored.host, 'smtp.ocn.ne.jp');
    expect(stored.port, 465);
    expect(stored.useSsl, isTrue);
    expect(stored.username, 'me@ocn.ne.jp');
    expect(stored.isConfigured, isTrue);
  });
}

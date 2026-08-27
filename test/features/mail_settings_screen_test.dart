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

/// Fills a complete Gmail account, password included, without saving.
Future<void> fillGmail(WidgetTester tester) async {
  await tap(tester, 'mailPreset-gmail');
  await enter(tester, 'mailFromField', 'me@gmail.com');
  await enter(tester, 'mailUsernameField', 'me@gmail.com');
  await enter(tester, 'mailPasswordField', 'abcd efgh ijkl mnop');
}

void main() {
  testWidgets('a preset fills the server fields and locks them', (
    tester,
  ) async {
    await openScreen(tester);

    await tap(tester, 'mailPreset-gmail');

    final host = await field(tester, 'mailHostField');
    expect(host.controller!.text, 'smtp.gmail.com');
    expect(host.enabled, isFalse, reason: 'the preset owns this field');
    expect(
      (await field(tester, 'mailPortField')).controller!.text,
      '$defaultSmtpPort',
    );

    await tap(tester, 'mailPreset-custom');
    expect(
      (await field(tester, 'mailHostField')).enabled,
      isTrue,
      reason: 'カスタム unlocks the fields rather than blanking them',
    );
    expect(
      (await field(tester, 'mailHostField')).controller!.text,
      'smtp.gmail.com',
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

  testWidgets('保存 stores the account and puts the password out of prefs', (
    tester,
  ) async {
    final r = await openScreen(tester);
    await fillGmail(tester);

    await tap(tester, 'mailSaveButton');

    final stored = r.container.read(mailSettingsProvider);
    expect(stored.isConfigured, isTrue);
    expect(stored.host, 'smtp.gmail.com');
    expect(stored.fromAddress, 'me@gmail.com');
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

    // The field goes back to empty, and the screen says a password is held.
    expect(
      (await field(tester, 'mailPasswordField')).controller!.text,
      isEmpty,
    );
    await show(tester, 'mailPasswordSavedNote');
    expect(find.byKey(const ValueKey('mailPasswordSavedNote')), findsOneWidget);
  });

  testWidgets('the password field is masked until the eye is pressed', (
    tester,
  ) async {
    await openScreen(tester);

    expect((await field(tester, 'mailPasswordField')).obscureText, isTrue);
    await tap(tester, 'mailPasswordReveal');
    expect((await field(tester, 'mailPasswordField')).obscureText, isFalse);
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
  });

  testWidgets('the Gmail app password steps are on the screen', (tester) async {
    await openScreen(tester);
    await show(tester, 'mailGmailHelp');

    expect(find.textContaining('2段階認証'), findsOneWidget);
    expect(find.textContaining('アプリパスワード'), findsWidgets);
  });
}

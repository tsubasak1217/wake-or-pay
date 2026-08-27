import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/oversleep_contact_rules.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/mail_settings.dart';
import 'package:wake_or_pay/services/oversleep_notifier.dart';

import '../helpers.dart';

/// Renaming somebody in the 連絡帳 has to reach the alarms that point at them.
///
/// The alarm keeps a *snapshot* of the entry so that deleting the person never
/// leaves it with nobody to call — and that snapshot used to be the only thing
/// anything ever read, so an edited name showed up nowhere until the person was
/// picked all over again.
ContactEntry taro({
  String name = '田中太郎',
  String? phone = '090-1234-5678',
  String? email = 'taro@example.com',
}) => ContactEntry(
  id: 'c1',
  name: name,
  reading: 'たなかたろう',
  phone: phone,
  email: email,
  createdAt: DateTime(2026),
);

/// An alarm already carrying the snapshot taken when 田中太郎 was picked.
const seededAlarm = Alarm(
  id: 'a1',
  hour: 7,
  minute: 0,
  kakugo: Kakugo(ratePerMinute: 100, cap: 1000),
  contact: OversleepContact(
    contactId: 'c1',
    name: '田中太郎',
    phone: '090-1234-5678',
    email: 'taro@example.com',
    phoneEnabled: true,
    emailEnabled: true,
  ),
);

Finder get editorScrollable => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

Future<void> scrollTo(WidgetTester tester, Finder target) async {
  tester.state<ScrollableState>(editorScrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(target, 120, scrollable: editorScrollable);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

/// 覚悟の設定 → 寝坊時連絡・共有. The caller walks back out itself.
Future<void> openContactShare(WidgetTester tester) async {
  await scrollTo(tester, find.byKey(const ValueKey('contactShareRow')));
  await tester.tap(find.byKey(const ValueKey('contactShareRow')));
  await tester.pumpAndSettle();
}

Future<ProviderContainer> openEditor(WidgetTester tester) async {
  final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
  await container.read(contactBookRepositoryProvider).save(taro());
  await container.read(alarmRepositoryProvider).save(seededAlarm);
  // Enough to cover the pledge, so saving does not stop on the 残高 warning.
  await container
      .read(walletRepositoryProvider)
      .write(const Wallet(coins: 100000));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('07:00'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1000, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  testWidgets('renaming a book entry renames it on the alarm that uses it', (
    tester,
  ) async {
    final container = await openEditor(tester);

    // The edit the 連絡帳 form would make.
    await container
        .read(contactBookRepositoryProvider)
        .save(taro(name: '田中太郎（部長）'));
    await tester.pumpAndSettle();

    // The 覚悟 row stands for the whole notification now, so the name shows up
    // one screen in — on the 寝坊時連絡先 row of 寝坊時連絡・共有.
    await openContactShare(tester);
    expect(
      find.text('田中太郎（部長）'),
      findsOneWidget,
      reason: 'the row reads the book, not the snapshot',
    );
    expect(find.text('田中太郎'), findsNothing);

    // And one deeper again, on the 連絡先 row of 寝坊時の連絡設定.
    await tester.tap(find.byKey(const ValueKey('contactRow')));
    await tester.pumpAndSettle();
    expect(find.text('田中太郎（部長）'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('the refreshed name is written back onto the alarm on save', (
    tester,
  ) async {
    final container = await openEditor(tester);
    await container
        .read(contactBookRepositoryProvider)
        .save(taro(name: '田中太郎（部長）', email: 'bucho@example.com'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final saved = (await container.read(alarmRepositoryProvider).getAll())
        .single
        .contact!;
    expect(saved.name, '田中太郎（部長）', reason: 'the snapshot must not drift');
    expect(saved.email, 'bucho@example.com');
    expect(saved.contactId, 'c1');
  });

  testWidgets('editing the entry from inside the book updates the toggles', (
    tester,
  ) async {
    final container = await openEditor(tester);
    await openContactShare(tester);
    await tester.tap(find.byKey(const ValueKey('contactRow')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '電話'))
          .onChanged,
      isNotNull,
      reason: 'there is a number to call',
    );

    // 連絡先 row → 連絡帳 → menu → 編集, and take the number away.
    await tester.tap(find.byKey(const ValueKey('contactPickRow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('contactBookMenu-c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('contactEntryPhone')), '');
    await tester.tap(find.byKey(const ValueKey('contactEntrySave')));
    await tester.pumpAndSettle();
    // Out of the 連絡帳 without picking anybody: nothing was re-selected.
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Both routes that ride on the number die with it.
    for (final label in const ['電話', 'SMS']) {
      final row = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, label),
      );
      expect(row.onChanged, isNull, reason: '$label: the number is gone');
      expect(row.value, isFalse);
    }
    expect(find.text('この連絡先には電話番号がありません'), findsNWidgets(2));
    // メール is untouched by the edit: it is greyed for the app-wide reason,
    // not because this contact lost anything.
    expect(
      find.text(mailSendingUnconfiguredNote),
      findsOneWidget,
      reason: 'the address is still there; sending is what is unbuilt',
    );
    expect(find.text('この連絡先にはメールアドレスがありません'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final saved = (await container.read(alarmRepositoryProvider).getAll())
        .single
        .contact!;
    expect(saved.phone, isNull);
    expect(saved.phoneEnabled, isFalse);
    expect(saved.emailEnabled, isTrue);
  });

  test('the dispatcher mails the address the book has now', () async {
    final container = await testContainer();
    await container.read(contactBookRepositoryProvider).save(taro());
    final events = container.read(contactEventRepositoryProvider);
    final session = AlarmSession(
      id: 's1',
      alarmId: 'a1',
      firedAt: DateTime(2026, 8, 27, 7),
      graceMinutes: 1,
      kakugoSnapshot: seededAlarm.kakugo,
    );
    await container.read(alarmSessionRepositoryProvider).save(session);

    await container
        .read(contactBookRepositoryProvider)
        .save(taro(name: '田中太郎（部長）'));

    final event = await container
        .read(contactDispatcherProvider)
        .fireIfDue(
          alarm: seededAlarm,
          session: session,
          now: DateTime(2026, 8, 27, 7, 30),
        );
    expect(event, isNotNull);
    expect(
      event!.contactName,
      oversleepTargetLabel(contactName: '田中太郎（部長）'),
      reason: 'the log names the recipient with the phrase everything uses',
    );
    expect(await events.forSession('s1'), hasLength(1));
  });
}

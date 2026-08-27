import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/alarms/contact_book_screen.dart';

import '../helpers.dart';

/// The book on its own, with whatever the test picked handed back.
Future<({ProviderContainer container, List<ContactEntry?> picked})> openBook(
  WidgetTester tester, {
  String? selectedId,
}) async {
  final container = await testContainer();
  final picked = <ContactEntry?>[];
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked.add(
              await Navigator.of(context).push<ContactEntry>(
                MaterialPageRoute(
                  builder: (_) => ContactBookScreen(selectedId: selectedId),
                ),
              ),
            ),
            child: const Text('ひらく'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ひらく'));
  await tester.pumpAndSettle();
  return (container: container, picked: picked);
}

Future<void> add(
  WidgetTester tester, {
  required String name,
  String? reading,
  String? phone,
  String? email,
}) async {
  await tester.tap(find.byKey(const ValueKey('contactBookAdd')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('contactEntryName')), name);
  if (reading != null) {
    await tester.enterText(
      find.byKey(const ValueKey('contactEntryReading')),
      reading,
    );
  }
  if (phone != null) {
    await tester.enterText(
      find.byKey(const ValueKey('contactEntryPhone')),
      phone,
    );
  }
  if (email != null) {
    await tester.enterText(
      find.byKey(const ValueKey('contactEntryEmail')),
      email,
    );
  }
  await tester.tap(find.byKey(const ValueKey('contactEntrySave')));
  await tester.pumpAndSettle();
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

  testWidgets('an empty book says so and offers ＋', (tester) async {
    await openBook(tester);
    expect(find.text('連絡帳'), findsOneWidget);
    expect(find.textContaining('まだ誰も登録されていません'), findsOneWidget);
    expect(find.byKey(const ValueKey('contactBookAdd')), findsOneWidget);
  });

  testWidgets('＋ adds people and the list is in よみがな order', (tester) async {
    final book = await openBook(tester);

    await add(tester, name: '田中太郎', reading: 'たなかたろう', phone: '090-1111-2222');
    await add(tester, name: '佐藤花子', reading: 'さとうはなこ', email: 'h@example.com');
    await add(tester, name: '阿部一郎', reading: 'あべいちろう', phone: '080-0000-0000');

    final names = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title! as Text).data)
        .toList();
    expect(names, ['阿部一郎', '佐藤花子', '田中太郎']);
    expect(find.text('090-1111-2222'), findsOneWidget);
    expect(find.text('h@example.com'), findsOneWidget);
    expect(
      await book.container.read(contactBookRepositoryProvider).getAll(),
      hasLength(3),
    );
  });

  testWidgets('a nameless or unreachable entry is refused, not saved', (
    tester,
  ) async {
    final book = await openBook(tester);

    await tester.tap(find.byKey(const ValueKey('contactBookAdd')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('contactEntrySave')));
    await tester.pumpAndSettle();
    expect(find.text('名前を入力してください。'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('contactEntryName')),
      '田中太郎',
    );
    await tester.tap(find.byKey(const ValueKey('contactEntrySave')));
    await tester.pumpAndSettle();
    expect(find.text('電話番号かメールアドレスのどちらかは必要です。'), findsOneWidget);

    // Still on the form, and nothing was written.
    expect(find.byKey(const ValueKey('contactEntryName')), findsOneWidget);
    expect(
      await book.container.read(contactBookRepositoryProvider).getAll(),
      isEmpty,
    );
  });

  testWidgets('よみがな is optional', (tester) async {
    final book = await openBook(tester);
    await add(tester, name: '母', phone: '090-0000-0000');

    final saved =
        (await book.container.read(contactBookRepositoryProvider).getAll())
            .single;
    expect(saved.reading, isNull);
    expect(saved.sortKey, '母');
  });

  testWidgets('tapping a row picks that person and closes the book', (
    tester,
  ) async {
    final book = await openBook(tester);
    await add(tester, name: '田中太郎', reading: 'たなかたろう', phone: '090-1111-2222');

    await tester.tap(find.text('田中太郎'));
    await tester.pumpAndSettle();

    expect(find.text('連絡帳'), findsNothing, reason: 'the book closed');
    expect(book.picked.single!.name, '田中太郎');
    expect(book.picked.single!.phone, '090-1111-2222');
  });

  testWidgets('the row menu edits an entry in place', (tester) async {
    final book = await openBook(tester);
    await add(tester, name: '田中', reading: 'たなか', phone: '090-1111-2222');

    final id =
        (await book.container.read(contactBookRepositoryProvider).getAll())
            .single
            .id;
    await tester.tap(find.byKey(ValueKey('contactBookMenu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('contactEntryName')),
      '田中太郎',
    );
    await tester.tap(find.byKey(const ValueKey('contactEntrySave')));
    await tester.pumpAndSettle();

    expect(find.text('田中太郎'), findsOneWidget);
    final saved =
        (await book.container.read(contactBookRepositoryProvider).getAll())
            .single;
    expect(saved.id, id, reason: 'edited, not replaced');
    expect(saved.name, '田中太郎');
    expect(saved.phone, '090-1111-2222', reason: 'the rest is untouched');
  });

  testWidgets('a long press offers the same two actions', (tester) async {
    await openBook(tester);
    await add(tester, name: '母', phone: '090-0000-0000');

    await tester.longPress(find.text('母'));
    await tester.pumpAndSettle();
    expect(find.text('編集'), findsOneWidget);
    expect(find.text('削除'), findsOneWidget);
  });

  testWidgets('削除 asks first, and says the alarms keep working', (
    tester,
  ) async {
    final book = await openBook(tester);
    await add(tester, name: '母', phone: '090-0000-0000');
    final repo = book.container.read(contactBookRepositoryProvider);
    final id = (await repo.getAll()).single.id;

    await tester.tap(find.byKey(ValueKey('contactBookMenu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    expect(find.text('母 を削除しますか'), findsOneWidget);
    expect(find.textContaining('そのまま同じ相手に連絡します'), findsOneWidget);

    await tester.tap(find.text('やめる'));
    await tester.pumpAndSettle();
    expect(await repo.getAll(), hasLength(1), reason: 'nothing was deleted');

    await tester.tap(find.byKey(ValueKey('contactBookMenu-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('contactBookDeleteConfirm')));
    await tester.pumpAndSettle();

    expect(await repo.getAll(), isEmpty);
    expect(find.textContaining('まだ誰も登録されていません'), findsOneWidget);
  });

  testWidgets('the entry the alarm already uses is ticked', (tester) async {
    final container = await testContainer();
    await container
        .read(contactBookRepositoryProvider)
        .save(
          ContactEntry(
            id: 'c1',
            name: '母',
            phone: '090-0000-0000',
            createdAt: DateTime(2026, 1, 1),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: const ContactBookScreen(selectedId: 'c1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('contactBookSelected')), findsOneWidget);
  });
}

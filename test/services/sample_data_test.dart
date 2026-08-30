import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/activity_stats.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/services/sample_data.dart';

import '../helpers.dart';

/// 開発用サンプルデータ — the made-up year behind the アクティビティ charts.

final _now = DateTime(2026, 8, 30, 9, 0);

void main() {
  group('SampleDataGenerator', () {
    test('the same seed and the same now make the same history', () {
      final a = const SampleDataGenerator(seed: 7).generate(_now);
      final b = const SampleDataGenerator(seed: 7).generate(_now);

      expect(a.sessions, b.sessions);
      expect(a.charges, b.charges);
      expect(a.events, b.events);
    });

    test('a different seed makes a different history', () {
      final a = const SampleDataGenerator(seed: 7).generate(_now);
      final b = const SampleDataGenerator(seed: 8).generate(_now);

      expect(a.sessions, isNot(b.sessions));
    });

    test('it covers the last 365 days densely, and stops there', () {
      final data = const SampleDataGenerator().generate(_now);

      expect(
        data.sessions.length,
        greaterThanOrEqualTo(250),
        reason: '~85% of 365 days, plus the double mornings',
      );

      final today = dayOf(_now);
      final oldest = today.subtract(const Duration(days: sampleDays - 1));
      for (final session in data.sessions) {
        final day = dayOf(session.firedAt);
        expect(day.isBefore(oldest), isFalse, reason: session.id);
        expect(day.isAfter(today), isFalse, reason: session.id);
      }

      // Gaps are real gaps: the chart has 「記録なし」 columns to draw.
      final days = data.sessions.map((s) => dayOf(s.firedAt)).toSet();
      expect(days.length, lessThan(sampleDays));
    });

    test('both outcomes are there, in roughly the stated mix', () {
      final data = const SampleDataGenerator().generate(_now);
      final failed = data.sessions
          .where((s) => s.status == SessionStatus.failed)
          .length;
      final success = data.sessions
          .where((s) => s.status == SessionStatus.success)
          .length;

      expect(failed, greaterThan(30));
      expect(success, greaterThan(failed));
      expect(
        failed + success,
        data.sessions.length,
        reason: 'nothing is left ringing — a sample morning is over',
      );
      expect(
        data.sessions.any((s) => s.wasSnoozed),
        isTrue,
        reason: 'some overslept mornings were snoozed through',
      );
    });

    test('every morning fires between 06:00 and 08:30 and is dismissed', () {
      final data = const SampleDataGenerator().generate(_now);

      for (final session in data.sessions) {
        final minutes = session.firedAt.hour * 60 + session.firedAt.minute;
        expect(minutes, inInclusiveRange(6 * 60, 8 * 60 + 30), reason: session.id);
        expect(session.dismissedAt, isNotNull, reason: session.id);
        expect(
          session.dismissedAt!.isAfter(session.firedAt),
          isTrue,
          reason: session.id,
        );
        for (final press in session.snoozes) {
          expect(press.isBefore(session.firedAt), isFalse, reason: session.id);
          expect(
            press.isAfter(session.dismissedAt!),
            isFalse,
            reason: session.id,
          );
        }
      }
    });

    test('a loss only ever comes with a stake, and never exceeds the cap', () {
      final data = const SampleDataGenerator().generate(_now);

      for (final session in data.sessions) {
        final kakugo = session.kakugoSnapshot!;
        if (session.status == SessionStatus.success) {
          expect(session.loss, 0, reason: session.id);
        }
        if (kakugo.hostage == HostageType.none) {
          expect(session.loss, 0, reason: session.id);
        }
        expect(session.loss, lessThanOrEqualTo(kakugo.cap), reason: session.id);
        if (kakugo.hostage == HostageType.coin) {
          expect(
            session.loss,
            lessThanOrEqualTo(session.coinsAtFire),
            reason: 'a coin pledge never burns more than was there',
          );
        }
        expect(session.coinsAtFire, inInclusiveRange(500, 10000));
        expect(session.graceMinutes, inInclusiveRange(1, 3));
      }

      // All three 人質 kinds are represented.
      final hostages = data.sessions
          .map((s) => s.kakugoSnapshot!.hostage)
          .toSet();
      expect(hostages, containsAll(HostageType.values));
    });

    test('every カード人質 loss has a matching charge, and nothing else does', () {
      final data = const SampleDataGenerator().generate(_now);
      final charged = {for (final c in data.charges) c.sessionId: c};
      final byId = {for (final s in data.sessions) s.id: s};

      final expected = data.sessions
          .where((s) => s.loss > 0 && isCardHostage(s))
          .toList();
      expect(expected, isNotEmpty);
      expect(charged.length, expected.length);

      for (final session in expected) {
        final charge = charged[session.id];
        expect(charge, isNotNull, reason: session.id);
        expect(charge!.amount, session.loss);
        expect(charge.createdAt, session.dismissedAt);
        expect(charge.alarmId, sampleAlarmId);
      }
      for (final charge in data.charges) {
        expect(isCardHostage(byId[charge.sessionId]!), isTrue);
      }
    });

    test('contact events hang off overslept mornings only', () {
      final data = const SampleDataGenerator().generate(_now);
      final byId = {for (final s in data.sessions) s.id: s};

      expect(data.events, isNotEmpty);
      final channels = <ContactChannel>{};
      for (final event in data.events) {
        final session = byId[event.sessionId]!;
        expect(session.status, SessionStatus.failed, reason: event.id);
        expect(
          event.firedAt.isBefore(session.dismissedAt!),
          isFalse,
          reason: 'triggered after the morning was over',
        );
        channels.add(event.channel);
      }
      expect(channels, {
        ContactChannel.sms,
        ContactChannel.email,
        ContactChannel.discord,
      });
      // Both outcomes are represented in the log.
      final details = data.events.map((e) => e.detail).toSet();
      expect(details, contains('サンプル: 送信しました'));
      expect(details, contains('サンプル: 送信できませんでした'));
    });

    test('every id is identifiable as a sample', () {
      final data = const SampleDataGenerator().generate(_now);

      for (final session in data.sessions) {
        expect(session.id, startsWith(sampleIdPrefix), reason: session.id);
        expect(session.alarmId, sampleAlarmId);
      }
      for (final charge in data.charges) {
        expect(charge.sessionId, startsWith(sampleIdPrefix));
        expect(charge.alarmId, startsWith(sampleIdPrefix));
      }
      for (final event in data.events) {
        expect(event.id, startsWith(sampleIdPrefix), reason: event.id);
        expect(event.sessionId, startsWith(sampleIdPrefix));
      }
      // The ids are unique — two rows with one id would silently overwrite.
      expect(
        data.sessions.map((s) => s.id).toSet().length,
        data.sessions.length,
      );
      expect(data.events.map((e) => e.id).toSet().length, data.events.length);
    });
  });

  group('SampleDataService', () {
    /// A real morning, written before any sample is. Nothing the generator or
    /// the delete does may touch it.
    final realSession = AlarmSession(
      id: 'real-1',
      alarmId: 'a1',
      firedAt: DateTime(2026, 8, 20, 7),
      dismissedAt: DateTime(2026, 8, 20, 7, 30),
      status: SessionStatus.failed,
      loss: 900,
      kakugoSnapshot: const Kakugo(
        hostage: HostageType.card,
        ratePerMinute: 50,
        cap: 3000,
      ),
      coinsAtFire: 2000,
    );
    final realCharge = PendingCharge(
      sessionId: 'real-1',
      alarmId: 'a1',
      amount: 900,
      createdAt: DateTime(2026, 8, 20, 7, 30),
    );
    final realEvent = ContactEvent(
      id: 'real-event-1',
      sessionId: 'real-1',
      firedAt: DateTime(2026, 8, 20, 7, 35),
      contactName: '本物 太郎',
      channel: ContactChannel.sms,
    );

    test('generate writes, delete takes back exactly what it wrote', () async {
      final container = await testContainer();
      final sessions = container.read(alarmSessionRepositoryProvider);
      final charges = container.read(pendingChargeRepositoryProvider);
      final events = container.read(contactEventRepositoryProvider);

      await sessions.save(realSession);
      await charges.insertIfAbsent(realCharge);
      await events.save(realEvent);

      final service = container.read(sampleDataServiceProvider);
      final written = await service.generate();
      expect(written, greaterThan(250));

      final afterWrite = await sessions.getRecent(limit: 100000);
      expect(afterWrite.length, greaterThan(250));
      expect(afterWrite.map((s) => s.id), contains('real-1'));

      await service.delete();

      expect(
        (await sessions.getRecent(limit: 100000)).map((s) => s.id),
        ['real-1'],
      );
      expect((await charges.getAll()).map((c) => c.sessionId), ['real-1']);
      expect(
        (await events.getRecent(limit: 100000)).map((e) => e.id),
        ['real-event-1'],
      );
    });

    test('generate twice leaves one history, not two', () async {
      final container = await testContainer();
      final sessions = container.read(alarmSessionRepositoryProvider);
      final service = container.read(sampleDataServiceProvider);

      final first = await service.generate();
      final afterFirst = (await sessions.getRecent(limit: 100000)).length;
      final second = await service.generate();
      final afterSecond = (await sessions.getRecent(limit: 100000)).length;

      expect(second, first);
      expect(afterSecond, afterFirst);
    });

    test('samples never touch the wallet, the ojisan or 歩み', () async {
      final container = await testContainer();
      await container
          .read(walletRepositoryProvider)
          .write(const Wallet(coins: 1234, tokens: 56));
      final before = await container.read(ojisanRepositoryProvider).read();


      await container.read(sampleDataServiceProvider).generate();

      final wallet = await container.read(walletRepositoryProvider).read();
      expect(wallet.coins, 1234);
      expect(wallet.tokens, 56);
      final after = await container.read(ojisanRepositoryProvider).read();
      expect(after.totalOversleeps, before.totalOversleeps);
      expect(after.totalEarned, before.totalEarned);
    });
  });
}

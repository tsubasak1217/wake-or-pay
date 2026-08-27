import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/send_result.dart';
import 'package:wake_or_pay/services/sms_sender.dart';
import 'package:wop_platform/wop_platform.dart';

/// Stands in for the Android side of `wop_platform`: records the call and
/// answers with whatever the real handler would.
class FakeSmsChannel {
  FakeSmsChannel({this.error});

  /// The `PlatformException` code to fail with, or null to succeed.
  final String? error;

  final calls = <Map<Object?, Object?>>[];

  MethodChannel install() {
    const channel = MethodChannel(wopSmsChannel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.arguments as Map<Object?, Object?>);
      final code = error;
      if (code != null) {
        throw PlatformException(code: code, message: 'from the fake');
      }
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    return channel;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a message goes across the channel as {to, body}', () async {
    final fake = FakeSmsChannel();
    final result = await PlatformSmsSender(fake.install())
        .send(to: '09012345678', body: '起きてください');

    expect(result.ok, isTrue);
    expect(fake.calls.single, {'to': '09012345678', 'body': '起きてください'});
  });

  test('an empty number never reaches the platform', () async {
    final fake = FakeSmsChannel();
    final result =
        await PlatformSmsSender(fake.install()).send(to: '  ', body: 'x');

    expect(result.reason, SendFailure.noAddress);
    expect(fake.calls, isEmpty);
  });

  test('an empty body never reaches the platform', () async {
    final fake = FakeSmsChannel();
    final result = await PlatformSmsSender(fake.install())
        .send(to: '09012345678', body: '   ');

    expect(result.ok, isFalse);
    expect(fake.calls, isEmpty);
  });

  test('every platform error code becomes a phrase, never a throw', () async {
    Future<SendResult> failWith(String code) =>
        PlatformSmsSender(FakeSmsChannel(error: code).install())
            .send(to: '09012345678', body: 'x');

    expect(
      (await failWith(WopErrorCode.permission)).reason,
      SendFailure.permission,
    );
    expect(
      (await failWith(WopErrorCode.unavailable)).reason,
      SendFailure.platform,
    );
    expect(
      (await failWith(WopErrorCode.invalid)).reason,
      SendFailure.noAddress,
    );
    expect((await failWith(WopErrorCode.failed)).reason, SendFailure.unknown);
    expect(
      (await failWith('something-new')).reason,
      SendFailure.unknown,
      reason: 'a code from a future Android side must not crash an old Dart '
          'side',
    );
  });

  test('no plugin under the build is a value too', () async {
    // Nothing installed: the messenger answers a missing plugin, which is what
    // a desktop debug run looks like.
    const channel = MethodChannel('com.wakeorpay.platform/sms-does-not-exist');
    final result =
        await const PlatformSmsSender(channel).send(to: '090', body: 'x');

    expect(result.ok, isFalse);
    expect(result.reason, SendFailure.platform);
  });

  test('the label is one short phrase for the log row', () async {
    final result = await PlatformSmsSender(
      FakeSmsChannel(error: WopErrorCode.permission).install(),
    ).send(to: '09012345678', body: 'x');

    expect(result.label, '失敗（権限がありません）');
    expect(result.detail, contains(WopErrorCode.permission));
  });
}

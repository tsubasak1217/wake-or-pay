import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/send_result.dart';
import 'package:wake_or_pay/services/phone_caller.dart';
import 'package:wop_platform/wop_platform.dart';

/// Stands in for the Android side of `wop_platform`.
class FakePhoneChannel {
  FakePhoneChannel({this.error});

  final String? error;
  final calls = <Map<Object?, Object?>>[];

  MethodChannel install() {
    const channel = MethodChannel(wopPhoneChannel);
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

  test('the number goes across the channel', () async {
    final fake = FakePhoneChannel();
    final result = await PlatformPhoneCaller(fake.install()).call('09012345678');

    expect(result.ok, isTrue);
    expect(fake.calls.single, {'to': '09012345678'});
  });

  test('an empty number never reaches the platform', () async {
    final fake = FakePhoneChannel();
    final result = await PlatformPhoneCaller(fake.install()).call('  ');

    expect(result.reason, SendFailure.noAddress);
    expect(fake.calls, isEmpty);
  });

  test('a refused CALL_PHONE is a value, never a throw', () async {
    final result = await PlatformPhoneCaller(
      FakePhoneChannel(error: WopErrorCode.permission).install(),
    ).call('09012345678');

    expect(result.ok, isFalse);
    expect(result.reason, SendFailure.permission);
    expect(result.label, '失敗（権限がありません）');
  });

  test('a device with no telephony is a value too', () async {
    final result = await PlatformPhoneCaller(
      FakePhoneChannel(error: WopErrorCode.unavailable).install(),
    ).call('09012345678');

    expect(result.reason, SendFailure.platform);
  });

  test('no plugin under the build is a value too', () async {
    const channel = MethodChannel('com.wakeorpay.platform/phone-nope');
    final result = await const PlatformPhoneCaller(channel).call('090');

    expect(result.reason, SendFailure.platform);
  });

  test('the background caller refuses and says why', () async {
    const caller = UnavailablePhoneCaller();
    final result = await caller.call('09012345678');

    expect(result.ok, isFalse);
    expect(result.reason, UnavailablePhoneCaller.backgroundReason);
    expect(
      await caller.inCall.toList(),
      isEmpty,
      reason: 'a call that was never placed never ends either',
    );
  });
}

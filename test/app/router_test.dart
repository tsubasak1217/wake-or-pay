import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/router.dart';

void main() {
  group('initialLocationFor', () {
    test('nothing ringing opens the alarm tab', () {
      expect(initialLocationFor(), AppRoute.home);
      expect(initialLocationFor(ringingSessionId: null), AppRoute.home);
    });

    test('a live ring is the route the app is built on', () {
      expect(initialLocationFor(ringingSessionId: 's1'), '/ringing/s1');
      expect(
        initialLocationFor(ringingSessionId: 's1'),
        AppRoute.ringing('s1'),
        reason: 'the same string the runtime jump uses',
      );
    });

    test('an empty id is no id: never /ringing/', () {
      expect(initialLocationFor(ringingSessionId: ''), AppRoute.home);
    });
  });

  group('createAppRouter', () {
    // The delegate's configuration is empty until a Router attaches to it, so
    // what is asserted here is the route information the router was *built*
    // with — which is exactly the thing that decides the first frame.
    test('defaults to home', () {
      final router = createAppRouter();
      addTearDown(router.dispose);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        AppRoute.home,
      );
    });

    test('opens on the location it is given, before any navigation', () {
      final router = createAppRouter(
        initialLocation: initialLocationFor(ringingSessionId: 's9'),
      );
      addTearDown(router.dispose);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/ringing/s9',
      );
    });
  });
}

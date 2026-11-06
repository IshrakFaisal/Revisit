import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revisit/platform/external_links.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final result in [true, false]) {
    test(
      'external adapter preserves resource bytes and returns $result',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return result;
        });
        expect(
          await openExternalLink(' HTTPS://Example.org/a/../b?x=%2f#Notes '),
          result,
        );
        expect(calls, hasLength(1));
        expect(calls.single.method, 'launch');
        final arguments = calls.single.arguments as Map;
        expect(arguments['url'], 'https://Example.org/a/../b?x=%2f#Notes');
        expect(arguments['useWebView'], isFalse);
        expect(arguments['useSafariVC'], isFalse);
      },
    );
  }

  test(
    'external adapter exposes platform failure for presentation to handle',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        throw PlatformException(code: 'launch_failed');
      });
      await expectLater(
        openExternalLink('https://example.org/'),
        throwsA(isA<PlatformException>()),
      );
      expect(calls, hasLength(1));
    },
  );

  test('unsafe and malformed links never reach the platform launcher', () {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    for (final input in [
      'javascript:alert(1)',
      'file:///secret',
      'data:text/plain,test',
      'https:///missing-host',
    ]) {
      expect(() => openExternalLink(input), throwsFormatException);
    }
    expect(calls, isEmpty);
  });
}

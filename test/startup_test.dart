import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:revisit/application/startup.dart';

void main() {
  test('production startup enables native integration only on Windows', () {
    expect(createRevisitApp().enableWindowsIntegration, Platform.isWindows);
  });
}

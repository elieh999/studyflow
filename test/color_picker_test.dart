import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/widgets/color_picker_dialog.dart';

void main() {
  test('colorToHex renders #RRGGBB uppercase', () {
    expect(colorToHex(const Color(0xFF4F86C6)), '#4F86C6');
    expect(colorToHex(const Color(0xFF000000)), '#000000');
    expect(colorToHex(const Color(0xFFFFFFFF)), '#FFFFFF');
  });

  test('hexToColor accepts hash, no hash and shorthand', () {
    expect(hexToColor('#4F86C6'), const Color(0xFF4F86C6));
    expect(hexToColor('4f86c6'), const Color(0xFF4F86C6));
    expect(hexToColor('#0af'), const Color(0xFF00AAFF));
  });

  test('hexToColor rejects rubbish', () {
    expect(hexToColor(''), isNull);
    expect(hexToColor('#12'), isNull);
    expect(hexToColor('nothex!'), isNull);
    expect(hexToColor('#1234567'), isNull);
  });

  test('round trips through hex', () {
    for (final c in [0xFF123456, 0xFFABCDEF, 0xFF00FF80]) {
      final color = Color(c);
      expect(hexToColor(colorToHex(color)), color);
    }
  });
}

import 'package:flutter_test/flutter_test.dart';

import '../launcher/path_safety.dart';

void main() {
  test('maps normal asset paths to Windows relative paths', () {
    expect(safeAssetRelativePath(Uri.parse('/assets/app.js')), r'assets\app.js');
    expect(safeAssetRelativePath(Uri.parse('/')), 'index.html');
  });

  test('rejects parent directory traversal', () {
    expect(safeAssetRelativePath(Uri.parse('/../secret.txt')), isNull);
    expect(safeAssetRelativePath(Uri.parse('/%2e%2e/secret.txt')), isNull);
  });

  test('rejects encoded Windows separators and drive paths', () {
    expect(
      safeAssetRelativePath(Uri.parse('/assets%5c..%5csecret.txt')),
      isNull,
    );
    expect(safeAssetRelativePath(Uri.parse('/C:/secret.txt')), isNull);
  });
}


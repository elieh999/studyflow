import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

// Browser-side helpers to save a file to the user's Downloads folder and to let
// them pick a file back for restore. The app is served in a browser, so these
// use the DOM directly.

void _download(String filename, Uint8List bytes, String mime) {
  final blob =
      web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

void downloadText(String filename, String content, String mime) {
  _download(filename, Uint8List.fromList(utf8.encode(content)), mime);
}

// Show a file picker and return the chosen file's text, or null if cancelled.
Future<String?> pickTextFile() {
  final completer = Completer<String?>();
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = '.json,application/json,text/plain';

  input.onchange = ((web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      completer.complete(null);
      return;
    }
    final reader = web.FileReader();
    reader.onload = ((web.Event _) {
      final result = reader.result;
      completer.complete(result.isA<JSString>()
          ? (result as JSString).toDart
          : null);
    }).toJS;
    reader.onerror = ((web.Event _) => completer.complete(null)).toJS;
    reader.readAsText(files.item(0)!);
  }).toJS;

  input.click();
  return completer.future;
}

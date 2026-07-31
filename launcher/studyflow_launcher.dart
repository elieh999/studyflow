// A tiny native launcher for StudyFlow.
//
// StudyFlow's UI is a Flutter build. On this machine the native `flutter build
// windows` target is unavailable (it needs the Visual Studio C++ workload and
// Developer Mode, both of which require admin rights we don't have), so the app
// is served locally instead. This launcher is a real compiled executable
// (built with `dart compile exe`) â€” not a batch file â€” that:
//   1. hides its own console window,
//   2. serves the bundled offline app from a fixed local port, and
//   3. opens it in an app-style browser window.
//
// The fixed port keeps the browser-storage origin stable, so everything you
// enter is still there next time you open the app.

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'path_safety.dart';

const int _port = 51789;
const String _url = 'http://127.0.0.1:$_port/';
const String _ollama = 'http://127.0.0.1:11434';

Future<void> main() async {
  _hideConsoleWindow();

  final appDir = _findAppDir();
  if (appDir == null) {
    // No app files found; open anyway in case another instance is serving.
    _openBrowser();
    return;
  }

  HttpServer? server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
  } on SocketException {
    // Port busy -> StudyFlow is probably already running. Just open a window.
    _openBrowser();
    return;
  }

  _openBrowser();

  await for (final request in server) {
    _serve(request, appDir);
  }
}

Directory? _findAppDir() {
  final exeDir = File(Platform.resolvedExecutable).parent;
  final candidates = <String>[
    '${exeDir.path}\\app',
    '${exeDir.path}\\Launch StudyFlow\\app',
    '${exeDir.parent.path}\\Launch StudyFlow\\app',
  ];
  for (final c in candidates) {
    final dir = Directory(c);
    if (File('${dir.path}\\index.html').existsSync()) return dir;
  }
  return null;
}

Future<void> _serve(HttpRequest request, Directory appDir) async {
  try {
    if (request.uri.path.startsWith('/ai/')) {
      await _proxyAi(request);
      return;
    }
    final relativePath = safeAssetRelativePath(request.uri);
    if (relativePath == null) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    final file = File('${appDir.path}\\$relativePath');

    if (!file.existsSync()) {
      // Single-page app fallback.
      final index = File('${appDir.path}\\index.html');
      await _writeFile(request, index, 'text/html');
      return;
    }
    await _writeFile(request, file, _contentType(relativePath));
  } catch (_) {
    request.response.statusCode = HttpStatus.internalServerError;
    await request.response.close();
  }
}

// Only requests from the app's own local origin may use the AI proxy. This
// stops another website open in the browser from quietly driving Ollama.
const int _maxAiRequestBytes = 64 * 1024;
const int _maxAiResponseBytes = 4 * 1024 * 1024;

bool _originAllowed(HttpRequest request) {
  final origin = request.headers.value('origin');
  if (origin == null) return true; // same-origin navigations / non-browser
  return origin.startsWith('http://127.0.0.1:') ||
      origin.startsWith('http://localhost:');
}

Future<List<int>?> _readCapped(Stream<List<int>> stream, int cap) async {
  final bytes = <int>[];
  await for (final chunk in stream) {
    bytes.addAll(chunk);
    if (bytes.length > cap) return null;
  }
  return bytes;
}

// Forward /ai/* to the local Ollama server so the browser page can use it
// without tripping cross-origin rules.
Future<void> _proxyAi(HttpRequest request) async {
  final res = request.response;
  res.headers.set('Content-Type', 'application/json');

  if (!_originAllowed(request)) {
    res.statusCode = HttpStatus.forbidden;
    res.write(jsonEncode({'error': 'origin not allowed'}));
    await res.close();
    return;
  }

  final client = HttpClient();
  try {
    if (request.uri.path.startsWith('/ai/health')) {
      try {
        final req = await client.getUrl(Uri.parse('$_ollama/api/tags'));
        final r = await req.close();
        final raw = await _readCapped(r, _maxAiResponseBytes);
        final tags = raw == null ? null : jsonDecode(utf8.decode(raw));
        res.write(jsonEncode(
            {'ok': tags != null, 'models': (tags is Map) ? tags['models'] : []}));
      } catch (e) {
        res.write(jsonEncode({'ok': false, 'error': '$e'}));
      }
      await res.close();
      return;
    }

    if (request.uri.path.startsWith('/ai/generate')) {
      final rawBody = await _readCapped(request, _maxAiRequestBytes);
      if (rawBody == null) {
        res.statusCode = HttpStatus.requestEntityTooLarge;
        res.write(jsonEncode({'error': 'request too large'}));
        await res.close();
        return;
      }
      final body = utf8.decode(rawBody, allowMalformed: true);
      final payload = (jsonDecode(body.isEmpty ? '{}' : body) as Map)
        ..['stream'] = false;
      try {
        final req = await client.postUrl(Uri.parse('$_ollama/api/generate'));
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(payload));
        final r = await req.close();
        final out = await _readCapped(r, _maxAiResponseBytes);
        if (out == null) {
          res.statusCode = HttpStatus.badGateway;
          res.write(jsonEncode({'error': 'model response too large'}));
        } else {
          res.statusCode = r.statusCode;
          res.add(out);
        }
      } catch (e) {
        res.statusCode = HttpStatus.badGateway;
        res.write(jsonEncode({'error': '$e'}));
      }
      await res.close();
      return;
    }

    res.statusCode = HttpStatus.notFound;
    await res.close();
  } finally {
    client.close(force: true);
  }
}

Future<void> _writeFile(HttpRequest request, File file, String type) async {
  final res = request.response;
  res.headers.set('Content-Type', type);
  // Cross-origin isolation lets the app use the faster storage backend.
  res.headers.set('Cross-Origin-Opener-Policy', 'same-origin');
  res.headers.set('Cross-Origin-Embedder-Policy', 'require-corp');
  res.headers.set('Cross-Origin-Resource-Policy', 'cross-origin');
  await res.addStream(file.openRead());
  await res.close();
}

String _contentType(String path) {
  if (path.endsWith('.html')) return 'text/html';
  if (path.endsWith('.js') || path.endsWith('.mjs')) return 'text/javascript';
  if (path.endsWith('.wasm')) return 'application/wasm';
  if (path.endsWith('.json')) return 'application/json';
  if (path.endsWith('.css')) return 'text/css';
  if (path.endsWith('.png')) return 'image/png';
  if (path.endsWith('.ico')) return 'image/x-icon';
  if (path.endsWith('.svg')) return 'image/svg+xml';
  if (path.endsWith('.ttf')) return 'font/ttf';
  if (path.endsWith('.otf')) return 'font/otf';
  if (path.endsWith('.woff2')) return 'font/woff2';
  return 'application/octet-stream';
}

void _openBrowser() {
  final edge = <String>[
    r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
  ];
  final chrome = <String>[
    r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    '${Platform.environment['LOCALAPPDATA']}\\Google\\Chrome\\Application\\chrome.exe',
  ];

  for (final path in [...edge, ...chrome]) {
    if (File(path).existsSync()) {
      // App mode = its own window, using the default profile so data persists.
      Process.start(path, ['--app=$_url', '--window-size=1400,900'],
          mode: ProcessStartMode.detached);
      return;
    }
  }
  // Fall back to whatever the system uses for http links.
  Process.start('cmd', ['/c', 'start', '', _url],
      mode: ProcessStartMode.detached, runInShell: true);
}

// Hide the console window this executable opens by default.
void _hideConsoleWindow() {
  try {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final user32 = DynamicLibrary.open('user32.dll');
    final getConsoleWindow = kernel32
        .lookupFunction<IntPtr Function(), int Function()>('GetConsoleWindow');
    final showWindow = user32.lookupFunction<
        Int32 Function(IntPtr, Int32),
        int Function(int, int)>('ShowWindow');
    final hwnd = getConsoleWindow();
    if (hwnd != 0) showWindow(hwnd, 0); // 0 = SW_HIDE
  } catch (_) {
    // Not fatal â€” worst case a console window stays visible.
  }
}


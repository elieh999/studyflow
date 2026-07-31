String? safeAssetRelativePath(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.isEmpty) return 'index.html';

  for (final segment in segments) {
    if (segment.isEmpty ||
        segment == '.' ||
        segment == '..' ||
        segment.contains(r'\') ||
        segment.contains('/') ||
        segment.contains('\u0000') ||
        RegExp(r'^[A-Za-z]:').hasMatch(segment)) {
      return null;
    }
  }

  return segments.join(r'\');
}


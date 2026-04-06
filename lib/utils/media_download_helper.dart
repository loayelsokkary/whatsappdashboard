import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MediaDownloadResult {
  final Uint8List bytes;
  final String filename;
  final String mimeType;

  MediaDownloadResult({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });
}

const Map<String, String> _mimeToExtension = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/gif': '.gif',
  'image/webp': '.webp',
  'image/svg+xml': '.svg',
  'video/mp4': '.mp4',
  'video/quicktime': '.mov',
  'audio/ogg': '.ogg',
  'audio/opus': '.opus',
  'audio/mpeg': '.mp3',
  'audio/mp4': '.m4a',
  'audio/wav': '.wav',
  'application/pdf': '.pdf',
  'application/msword': '.doc',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': '.docx',
  'application/vnd.ms-excel': '.xls',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '.xlsx',
};

const Map<String, String> _extensionToMime = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.mp4': 'video/mp4',
  '.mov': 'video/quicktime',
  '.ogg': 'audio/ogg',
  '.opus': 'audio/opus',
  '.mp3': 'audio/mpeg',
  '.m4a': 'audio/mp4',
  '.wav': 'audio/wav',
  '.pdf': 'application/pdf',
  '.doc': 'application/msword',
  '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  '.xls': 'application/vnd.ms-excel',
  '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

/// Downloads media from [fileUrl] and returns bytes + correct filename + MIME.
///
/// MIME detection priority:
///   1. HTTP Content-Type response header (most reliable)
///   2. File extension from URL path (fallback)
///   3. application/octet-stream (last resort)
///
/// Filename priority:
///   1. URL path segment if it already has a recognized extension
///   2. Generated: {type}_{timestamp}.{ext} from MIME-derived extension
///   3. Last resort — raw URL path segment or generic fallback
Future<MediaDownloadResult> downloadMedia(String fileUrl) async {
  final response = await http.get(Uri.parse(fileUrl));
  if (response.statusCode != 200) {
    throw Exception('Download failed with status ${response.statusCode}');
  }

  // --- Extract URL path info ---
  final uri = Uri.parse(fileUrl);
  final pathSegment = uri.pathSegments.isNotEmpty
      ? uri.pathSegments.last.split('?').first
      : '';
  final dotIndex = pathSegment.lastIndexOf('.');
  final urlExtension = dotIndex != -1 && dotIndex < pathSegment.length - 1
      ? pathSegment.substring(dotIndex).toLowerCase()
      : null;

  // --- Determine MIME type ---
  String? contentType = response.headers['content-type'];
  if (contentType != null && contentType.contains(';')) {
    contentType = contentType.split(';').first.trim();
  }

  String mimeType;
  if (contentType != null &&
      contentType != 'application/octet-stream' &&
      _mimeToExtension.containsKey(contentType)) {
    mimeType = contentType;
  } else if (urlExtension != null && _extensionToMime.containsKey(urlExtension)) {
    mimeType = _extensionToMime[urlExtension]!;
  } else if (contentType != null && contentType != 'application/octet-stream') {
    mimeType = contentType;
  } else {
    mimeType = 'application/octet-stream';
  }

  // --- Determine filename ---
  final resolvedExtension = _mimeToExtension[mimeType] ?? '';
  String filename;

  // If URL already has a recognized extension, keep original filename
  if (urlExtension != null && _extensionToMime.containsKey(urlExtension)) {
    filename = pathSegment;
  }
  // If we resolved a MIME type, generate a clean name with correct extension
  else if (resolvedExtension.isNotEmpty) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final prefix = mimeType.startsWith('image/')
        ? 'photo'
        : mimeType.startsWith('video/')
            ? 'video'
            : mimeType.startsWith('audio/')
                ? 'audio'
                : 'file';
    filename = '${prefix}_$timestamp$resolvedExtension';
  }
  // Last resort — use whatever the URL gave us
  else {
    filename = pathSegment.isNotEmpty
        ? pathSegment
        : 'download_${DateTime.now().millisecondsSinceEpoch}';
  }

  debugPrint('[downloadMedia] URL: $fileUrl');
  debugPrint('[downloadMedia] Content-Type header: $contentType');
  debugPrint('[downloadMedia] Resolved MIME: $mimeType | Filename: $filename');

  return MediaDownloadResult(
    bytes: response.bodyBytes,
    filename: filename,
    mimeType: mimeType,
  );
}

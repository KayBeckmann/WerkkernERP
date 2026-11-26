import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

/// Bounded, decoded raster only. Reject malformed or merely spoofed magic bytes.
void validatePdfLogo(String encoded) {
  const maxBytes = 1024 * 1024;
  if (encoded.isEmpty || encoded.length > ((maxBytes + 2) ~/ 3) * 4 ||
      !RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(encoded)) {
    throw const FormatException('Invalid image encoding');
  }
  late Uint8List bytes;
  try {
    bytes = base64Decode(encoded);
  } on FormatException {
    throw const FormatException('Invalid image encoding');
  }
  if (bytes.isEmpty || bytes.length > maxBytes) throw const FormatException('Image too large');
  final png = bytes.length >= 24 &&
      const [137, 80, 78, 71, 13, 10, 26, 10].asMap().entries.every((e) => bytes[e.key] == e.value);
  final jpeg = bytes.length >= 4 && bytes[0] == 0xff && bytes[1] == 0xd8 &&
      bytes[bytes.length - 2] == 0xff && bytes.last == 0xd9;
  if (!png && !jpeg) throw const FormatException('Only PNG/JPEG supported');
  if (png) {
    // No trailing payload after the mandatory final IEND chunk.
    const end = [0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130];
    if (bytes.length < 45 || !end.asMap().entries.every((e) => bytes[bytes.length - end.length + e.key] == e.value)) {
      throw const FormatException('Invalid PNG ending');
    }
    final width = ByteData.sublistView(bytes).getUint32(16);
    final height = ByteData.sublistView(bytes).getUint32(20);
    if (width == 0 || height == 0 || width > 2048 || height > 2048 || width * height > 2048 * 2048) {
      throw const FormatException('Image dimensions too large');
    }
  }
  // Bound JPEG allocation before decoding; both decoders enforce a pixel cap.
  try {
    final decoder = png
        ? image.PngDecoder(maxPixels: 2048 * 2048)
        : image.JpegDecoder(maxPixels: 2048 * 2048);
    final info = decoder.startDecode(bytes);
    if (info == null || info.width < 1 || info.height < 1 ||
        info.width > 2048 || info.height > 2048) {
      throw const FormatException('Invalid image dimensions or content');
    }
    final decoded = decoder.decodeFrame(0);
    if (decoded == null) throw const FormatException('Invalid image content');
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Invalid image content');
  }
}

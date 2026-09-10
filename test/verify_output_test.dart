import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jpg_slimming/services/jpg_compressor.dart';

void main() {
  test('A.jpg compresses to genuine JPEG output (not AVIF)', () async {
    final input = await File('A.jpg').readAsBytes();

    // Manual compress A.jpg
    final result = await JpgCompressor.manualCompress(
      input: Uint8List.fromList(input),
      quality: 80,
      resolutionPercent: 100,
    );

    // Verify output starts with JPEG SOI marker ffd8
    expect(result.data[0], 0xFF);
    expect(result.data[1], 0xD8);
    expect(result.data[2], 0xFF);

    // Verify it's NOT an AVIF (AVIF starts with 000000xx ftyp avif)
    final firstBytes = result.data.sublist(0, 12);
    expect(String.fromCharCodes(firstBytes).contains('ftyp'), isFalse);
    expect(String.fromCharCodes(firstBytes).contains('avif'), isFalse);

    // Output extension remains .jpg
    expect(result.outputSizeBytes, greaterThan(0));
    // ignore: avoid_print
    print('A.jpg compressed: ${input.length} -> ${result.data.length} bytes, '
        'quality=${result.quality}, output=JPG');
  });

  test('B.jpg compresses to genuine JPEG output (not AVIF)', () async {
    final input = await File('B.jpg').readAsBytes();

    // Auto compress B.jpg toward 10MB target
    final result = await JpgCompressor.autoCompress(
      input: Uint8List.fromList(input),
      targetBytes: 10 * 1024 * 1024,
      minQuality: 80,
      minResolutionPercent: 75,
    );

    // Verify output starts with JPEG SOI marker ffd8
    expect(result.data[0], 0xFF);
    expect(result.data[1], 0xD8);
    expect(result.data[2], 0xFF);

    // Verify it's NOT an AVIF
    final firstBytes = result.data.sublist(0, 12);
    expect(String.fromCharCodes(firstBytes).contains('ftyp'), isFalse);
    expect(String.fromCharCodes(firstBytes).contains('avif'), isFalse);

    // ignore: avoid_print
    print('B.jpg compressed: ${input.length} -> ${result.data.length} bytes, '
        'quality=${result.quality}, scale=${result.resolutionScale}, output=JPG');
  });
}

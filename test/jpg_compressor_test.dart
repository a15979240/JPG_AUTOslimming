import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:jpg_slimming/services/jpg_compressor.dart';

void main() {
  Uint8List makeJpg() {
    final image = img.Image(width: 160, height: 120);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, (x * 2) % 256, (y * 2) % 256, (x + y) % 256);
      }
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 100));
  }

  test('auto mode stays under 10 MB while honouring configured limits', () async {
    final result = await JpgCompressor.autoCompress(
      input: makeJpg(),
      targetBytes: 10 * 1024 * 1024,
      minQuality: 80,
      minResolutionPercent: 75,
    );

    expect(result.outputSizeBytes, lessThanOrEqualTo(10 * 1024 * 1024));
    expect(result.quality, greaterThanOrEqualTo(80));
    expect(result.resolutionScale, greaterThanOrEqualTo(0.75));
  });
}


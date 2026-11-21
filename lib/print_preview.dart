import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

import 'label_pair.dart';

/// Inspect the SDK-rendered page on white paper before submitting the job.
String? checkPrintPreview(
  Uint8List png, {
  required bool rotated,
  List<String> expected = sampleCodes,
}) {
  if (expected.isEmpty || expected.length > 2) return '待核对的编号数量异常';
  final decoded = img.decodePng(png);
  if (decoded == null || decoded.width < 2 || decoded.height < 2) {
    return '无法读取打印预览';
  }
  final page = decoded.convert(format: img.Format.uint8, numChannels: 4);
  final luma = Int8List(page.width * page.height);
  for (final pixel in page) {
    final light = 255 - (255 - pixel.luminance) * pixel.a / 255;
    luma[pixel.y * page.width + pixel.x] = light.round();
  }
  final source = RGBLuminanceSource.crop(
    luma,
    page.width,
    page.height,
    0,
    0,
    page.width,
    page.height,
  );

  String? checkHalves({required bool across}) {
    final width = across ? page.width ~/ 2 : page.width;
    final height = across ? page.height : page.height ~/ 2;
    final codes = <String?>[];
    for (var i = 0; i < 2; i++) {
      final half = source.crop(
        across ? i * (page.width - width) : 0,
        across ? 0 : i * (page.height - height),
        width,
        height,
      );
      final dark = half.getMatrix().where((v) => (v & 255) < 128).length;
      final coverage = dark / (width * height);
      if (coverage > 0.55) return '有一枚标签的预览大面积发黑';
      if (coverage < 0.01) {
        if (expected.length == 2 || coverage > 0.001) return '有一枚标签的预览接近空白';
        codes.add(null);
        continue;
      }
      try {
        codes.add(
          QRCodeReader().decode(BinaryBitmap(HybridBinarizer(half))).text,
        );
      } on ReaderException {
        return '预览中有二维码无法识别';
      }
    }
    final second = expected.length == 2 ? expected[1] : null;
    final ordered = codes[0] == expected.first && codes[1] == second;
    final reversed = across && codes[0] == second && codes[1] == expected.first;
    return ordered || reversed ? null : '预览中的编号与本次标签不符';
  }

  // The SDK may return the logical canvas or the rotated physical page.
  if (rotated && checkHalves(across: true) == null) return null;
  return checkHalves(across: false);
}

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:niimbot_print/niimbot_print.dart';

const sampleCodes = ['090001', '090002'];

/// The image frames use the editor's top/bottom orientation. The physical
/// canvas axes swap when the pair runs across the thermal head.
class LabelPair {
  const LabelPair({this.gap = 0, this.rotate = false});
  final double gap;
  final bool rotate;
  static const double width = 30, height = 15;

  NiimbotLabelLayout get layout => NiimbotLabelLayout(
    size: NiimbotLabelSize(
      width: rotate ? 2 * height + gap : width,
      height: rotate ? width : 2 * height + gap,
    ),
    orientation: rotate
        ? NiimbotLabelOrientation.landscape
        : NiimbotLabelOrientation.portrait,
    padding: 0,
    usePrinterProfiles: false,
  );

  Future<List<NiimbotPrintElement>> elements() async {
    final elements = <NiimbotPrintElement>[];
    for (var row = 0; row < sampleCodes.length; row++) {
      final data = await rootBundle.load('assets/${sampleCodes[row]}.png');
      elements.add(
        NiimbotImageElement.bytes(
          bytes: Uint8List.sublistView(data),
          frame: NiimbotRect(
            x: 0,
            y: row * (height + gap),
            width: width,
            height: height,
          ),
        ),
      );
    }
    return elements;
  }
}

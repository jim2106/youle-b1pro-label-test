import 'package:niimbot_print/niimbot_print.dart';

const sampleCodes = ['090001', '090002'];
const sampleArtists = ['测试作家甲', '测试作家乙'];
const samplePrices = ['¥128', '¥168'];

/// The element frames use the editor's top/bottom orientation. The physical
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

  List<NiimbotPrintElement> elements() {
    final items = <NiimbotPrintElement>[];
    for (var row = 0; row < sampleCodes.length; row++) {
      final top = row * (height + gap);
      PrintLabelModel line(
        String text,
        double y,
        double size, {
        bool bold = false,
      }) => PrintLabelModel(
        text: text,
        fontSize: size,
        style: bold ? NiimbotFontStyle.bold : NiimbotFontStyle.normal,
        alignment: NiimbotTextAlignment.left,
        frame: NiimbotRect(x: 1, y: top + y, width: 15, height: 4),
      );
      items.addAll([
        line(sampleArtists[row], 0.6, 10),
        line(samplePrices[row], 5, 13, bold: true),
        line(sampleCodes[row], 10, 10),
        PrintQrCodeModel(
          data: sampleCodes[row],
          frame: NiimbotRect(x: 18, y: top + 2.5, width: 10, height: 10),
        ),
      ]);
    }
    return items;
  }
}

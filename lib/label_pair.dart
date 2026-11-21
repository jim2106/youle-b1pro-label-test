import 'package:niimbot_print/niimbot_print.dart';

const sampleCodes = ['090001', '090002'];
const sampleArtists = ['测试作家甲', '测试作家乙'];
const samplePrices = ['¥128', '¥168'];
const sampleLabels = [
  VesselLabel('090001', '测试作家甲', '¥128'),
  VesselLabel('090002', '测试作家乙', '¥168'),
];

class VesselLabel {
  const VesselLabel(this.code, this.artist, this.price);
  final String code, artist, price;

  static List<VesselLabel> parseJob(Object? job) {
    if (job is! Map || job['version'] != 1 || job['items'] is! List) {
      throw const FormatException('标签数据版本不匹配');
    }
    final rows = job['items'] as List;
    if (rows.isEmpty) throw const FormatException('没有要打印的器物');
    final seen = <String>{};
    return rows
        .map((row) {
          if (row is! Map) throw const FormatException('标签格式异常');
          final code = row['code'],
              artist = row['artist'],
              price = row['price'];
          if (code is! String ||
              !RegExp(r'^[0-9]{4,}$').hasMatch(code) ||
              artist is! String ||
              artist.trim().isEmpty ||
              price is! String ||
              price.trim().isEmpty ||
              !seen.add(code)) {
            throw const FormatException('编号重复或标签资料不完整');
          }
          return VesselLabel(code, artist, price);
        })
        .toList(growable: false);
  }
}

/// The element frames use the editor's top/bottom orientation. The physical
/// canvas axes swap when the pair runs across the thermal head.
class LabelPair {
  const LabelPair({
    this.gap = 0,
    this.rotate = false,
    this.labels = sampleLabels,
  });
  final List<VesselLabel> labels;
  final double gap;
  final bool rotate;
  static const double width = 30, height = 15;
  bool get rotatePair => labels.length == 2 && rotate;
  double get feedLength => labels.length == 1 ? height : 2 * height + gap;

  NiimbotLabelLayout get layout => NiimbotLabelLayout(
    size: NiimbotLabelSize(
      width: rotatePair ? feedLength : width,
      height: rotatePair ? width : feedLength,
    ),
    orientation: rotatePair
        ? NiimbotLabelOrientation.landscape
        : NiimbotLabelOrientation.portrait,
    padding: 0,
    usePrinterProfiles: false,
  );

  List<NiimbotPrintElement> elements() {
    final items = <NiimbotPrintElement>[];
    if (labels.isEmpty || labels.length > 2) throw ArgumentError('每组限一至两张');
    for (var row = 0; row < labels.length; row++) {
      final top = row * (height + gap);
      PrintLabelModel line(
        String text,
        double y,
        double size, {
        bool bold = false,
      }) => PrintLabelModel(
        text: text,
        fontSize: size,
        sizing: text.runes.length > 6
            ? NiimbotTextSizing.autoFit(
                maxFontSize: size,
                minFontSize: 5,
                maxLines: 1,
              )
            : null,
        style: bold ? NiimbotFontStyle.bold : NiimbotFontStyle.normal,
        alignment: NiimbotTextAlignment.left,
        frame: NiimbotRect(x: 1, y: top + y, width: 15, height: 4),
      );
      items.addAll([
        line(labels[row].artist, 0.6, 10),
        line(labels[row].price, 5, 13, bold: true),
        line(labels[row].code, 10, 10),
        PrintQrCodeModel(
          data: labels[row].code,
          frame: NiimbotRect(x: 18, y: top + 2.5, width: 10, height: 10),
        ),
      ]);
    }
    return items;
  }
}

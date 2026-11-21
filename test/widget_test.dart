import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:b1pro_test/label_pair.dart';
import 'package:b1pro_test/main.dart';
import 'package:b1pro_test/print_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niimbot_print/niimbot_print.dart';

img.Image samplePage({String second = '090002'}) {
  img.Image load(String code) => img
      .decodePng(File('assets/$code.png').readAsBytesSync())!
      .convert(format: img.Format.uint8, numChannels: 3);
  final first = load('090001');
  final page = img.Image(width: first.width, height: first.height * 2);
  img.compositeImage(page, first);
  img.compositeImage(page, load(second), dstY: first.height);
  return page;
}

class FakePrinter extends NiimbotPrint {
  final pending = Completer<void>();
  int jobs = 0;
  bool online = true;
  Uint8List preview = img.encodePng(samplePage());
  List<NiimbotPrintElement>? checkedItems;
  NiimbotLabelLayout? checkedLayout;

  @override
  Future<Uint8List> generatePreview({
    required List<NiimbotPrintElement> elements,
    NiimbotLabelLayout layout = const NiimbotLabelLayout(),
  }) async {
    checkedItems = elements;
    checkedLayout = layout;
    return preview;
  }

  @override
  Future<List<BlueDeviceInfoModel>> onStartScan({
    Duration? scanDuration,
    List<NiimbotModelEnum>? whiteListDevices,
    NiimbotErrorCallback? onError,
  }) async {
    expect(whiteListDevices, isNull);
    return [BlueDeviceInfoModel(deviceName: 'B1-TEST')];
  }

  @override
  Future<void> onStartConnect({
    required BlueDeviceInfoModel model,
    required NiimbotResultCallback onResult,
  }) async {
    onResult(true, '');
  }

  @override
  Future<bool> isConnected() async => online;
  @override
  Future<void> onStartPrint({
    required List<NiimbotPrintElement> elements,
    NiimbotLabelLayout layout = const NiimbotLabelLayout(),
    NiimbotPrintErrorCallback? onError,
    required NiimbotResultCallback onResult,
  }) async {
    jobs++;
    expect(elements, same(checkedItems));
    expect(layout, same(checkedLayout));
    expect(layout.size.height, 30);
    await pending.future;
    onResult(true, '');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each native QR and its three text fields sit in its own row', () {
    const pair = LabelPair(gap: 2);
    final elements = pair.elements();
    expect(elements, hasLength(8));
    for (var i = 0; i < 2; i++) {
      final row = elements.skip(4 * i).take(4);
      final qr = row.whereType<PrintQrCodeModel>().single;
      expect(qr.data, sampleCodes[i]);
      expect(row.whereType<PrintLabelModel>().map((v) => v.text), [
        sampleArtists[i],
        samplePrices[i],
        sampleCodes[i],
      ]);
      for (final item in row) {
        final frame = NiimbotRect.fromJson(item.toJson()['frame']);
        expect(frame.x, greaterThanOrEqualTo(0));
        expect(frame.x + frame.width, lessThanOrEqualTo(30));
        expect(frame.y, greaterThanOrEqualTo(i * 17));
        expect(frame.y + frame.height, lessThanOrEqualTo(i * 17 + 15));
      }
    }
    expect(pair.layout.size.height, 32);
    const rotated = LabelPair(gap: 2, rotate: true);
    expect(rotated.layout.size.width, 32);
    expect(rotated.layout.size.height, 30);
    expect(rotated.layout.orientation, NiimbotLabelOrientation.landscape);
  });

  test(
    'check actual preview pixels and both decoded numbers before printing',
    () {
      final page = samplePage();
      expect(checkPrintPreview(img.encodePng(page), rotated: false), isNull);
      expect(
        checkPrintPreview(
          img.encodePng(img.copyRotate(page, angle: 90)),
          rotated: true,
        ),
        isNull,
      );
      expect(
        checkPrintPreview(
          img.encodePng(samplePage(second: '090001')),
          rotated: false,
        ),
        isNotNull,
      );
      img.fillRect(
        page,
        x1: 0,
        y1: 0,
        x2: page.width - 1,
        y2: page.height ~/ 2 - 1,
        color: img.ColorRgb8(0, 0, 0),
      );
      expect(
        checkPrintPreview(img.encodePng(page), rotated: false),
        contains('发黑'),
      );
      final transparent = img.Image(width: 65, height: 65, numChannels: 4);
      expect(
        checkPrintPreview(img.encodePng(transparent), rotated: false),
        contains('空白'),
      );
    },
  );

  testWidgets('one tap sends one pair, double taps do not duplicate it', (
    tester,
  ) async {
    final printer = FakePrinter();
    final goodPreview = printer.preview;
    printer.preview = img.encodePng(img.Image(width: 64, height: 64));
    await tester.pumpWidget(TestApp(printer: printer));
    final printButton = find.widgetWithText(FilledButton, '打印两张测试标签');
    expect(tester.widget<FilledButton>(printButton).onPressed, isNull);
    await tester.tap(find.text('搜索打印机'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B1-TEST'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(printButton);
    await tester.tap(printButton);
    await tester.pumpAndSettle();
    expect(printer.jobs, 0);
    expect(find.textContaining('发黑，已停止送纸'), findsOneWidget);
    printer.preview = goodPreview;
    await tester.ensureVisible(printButton);
    await tester.tap(printButton);
    await tester.tap(printButton);
    await tester.pumpAndSettle();
    expect(printer.jobs, 1);
    expect(tester.widget<FilledButton>(printButton).onPressed, isNull);
    printer.pending.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('打印机已回报完成'), findsOneWidget);
    printer.online = false;
    await tester.tap(printButton);
    await tester.pumpAndSettle();
    expect(printer.jobs, 1);
    expect(find.textContaining('蓝牙连接已断开'), findsOneWidget);
  });
}

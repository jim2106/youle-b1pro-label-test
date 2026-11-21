import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:b1pro_test/label_pair.dart';
import 'package:b1pro_test/label_print_page.dart';
import 'package:b1pro_test/print_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niimbot_print/niimbot_print.dart';
import 'package:zxing2/qrcode.dart' as qr;

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
  bool allowConnect = true;
  final opened = <String?>[];
  final connectionPayloads = <Map<String, dynamic>>[];
  Uint8List preview = img.encodePng(samplePage());
  final nextPreviews = <Uint8List>[];
  final sentCodes = <List<String>>[];
  List<NiimbotPrintElement>? checkedItems;
  NiimbotLabelLayout? checkedLayout;

  @override
  Future<Uint8List> generatePreview({
    required List<NiimbotPrintElement> elements,
    NiimbotLabelLayout layout = const NiimbotLabelLayout(),
  }) async {
    checkedItems = elements;
    checkedLayout = layout;
    return nextPreviews.isEmpty ? preview : nextPreviews.removeAt(0);
  }

  @override
  Future<List<BlueDeviceInfoModel>> onStartScan({
    Duration? scanDuration,
    List<NiimbotModelEnum>? whiteListDevices,
    NiimbotErrorCallback? onError,
  }) async {
    expect(whiteListDevices, isNull);
    return [
      'B1-TEST',
      'B1 Pro-TEST',
      'B1 Pro-',
      'Headphones',
      'B1 Pro Max-TEST',
    ].map((name) => BlueDeviceInfoModel(deviceName: name)).toList();
  }

  @override
  Future<void> onStartConnect({
    required BlueDeviceInfoModel model,
    required NiimbotResultCallback onResult,
  }) async {
    opened.add(model.deviceName);
    connectionPayloads.add(
      jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>,
    );
    onResult(allowConnect, '');
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
    sentCodes.add(
      elements.whereType<PrintQrCodeModel>().map((q) => q.data).toList(),
    );
    expect(elements, same(checkedItems));
    expect(layout, same(checkedLayout));
    expect(layout.size.height, 30);
    await pending.future;
    onResult(true, '');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'login restores only the bound printer and an offline printer allows manual recovery',
    () async {
      final printer = FakePrinter();
      final session = PrinterSession(printer: printer);
      String? bound;
      String? current;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        PrinterSession.binding,
        (MethodCall call) async => call.method == 'boundName' ? bound : current,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(PrinterSession.binding, null),
      );
      await session.prepare(atLogin: true);
      bound = 'B1-OTHER';
      await session.prepare(atLogin: true);
      expect(printer.opened, isEmpty);
      bound = 'B1 Pro-A1';
      await Future.wait([session.prepare(atLogin: true), session.prepare()]);
      expect(printer.opened, [bound]);
      expect(printer.connectionPayloads.single, {
        'deviceName': bound,
        'deviceHardwareAddress': '',
        'connectionState': 0,
      });
      final decoder = Platform.environment['YOULE_NATIVE_MODEL_CHECK'];
      if (decoder != null) {
        final result = await Process.run(decoder, [
          jsonEncode(printer.connectionPayloads.single),
        ]);
        expect(result.exitCode, 0, reason: result.stderr.toString());
      }
      current = bound;
      await session.prepare(atLogin: true);
      expect(printer.opened, [bound]);
      current = null;
      printer.allowConnect = false;
      await session.prepare(atLogin: true);
      expect(session.connected, isNull);
      expect(session.connectionHint, isNotNull);
      await session.prepare();
      expect(printer.opened, [bound, bound]);
      printer.allowConnect = true;
      await session.open(
        BlueDeviceInfoModel(
          deviceName: 'B1 Pro-NEW',
          deviceHardwareAddress: 'test-address',
          connectionState: 1,
        ),
      );
      expect(session.connected, 'B1 Pro-NEW');
      expect(printer.connectionPayloads.last, {
        'deviceName': 'B1 Pro-NEW',
        'deviceHardwareAddress': 'test-address',
        'connectionState': 1,
      });
      expect(printer.jobs, 0);
    },
  );

  test('ERP labels preserve the exact code and printed currency', () {
    final payload = {
      'version': 1,
      'items': [
        {'code': '0017', 'artist': '甲', 'price': '¥1,280.50'},
        {'code': '0018', 'artist': '乙', 'price': '¥0'},
      ],
    };
    final rows = VesselLabel.parseJob(payload);
    final items = LabelPair(labels: rows).elements();
    expect(items.whereType<PrintQrCodeModel>().map((q) => q.data), [
      '0017',
      '0018',
    ]);
    expect(items.whereType<PrintLabelModel>().first.text, '甲');
    expect(items.whereType<PrintLabelModel>().elementAt(1).text, '¥1,280.50');
    expect(
      () => VesselLabel.parseJob({
        'version': 1,
        'items': [payload['items'], null],
      }),
      throwsFormatException,
    );
    final same = {'code': '0017', 'artist': '甲', 'price': '¥0'};
    expect(
      () => VesselLabel.parseJob({
        'version': 1,
        'items': [same, same],
      }),
      throwsFormatException,
    );
  });

  test(
    'odd last label requires an empty second slot and checks the requested code',
    () {
      final page = samplePage();
      const one = [VesselLabel('090001', '测试作家甲', '¥128')];
      expect(LabelPair(labels: one).elements(), hasLength(4));
      String? check(img.Image input, {bool rotated = false}) =>
          checkPrintPreview(
            img.encodePng(input),
            rotated: rotated,
            expected: ['090001'],
          );
      expect(check(page), isNotNull);
      img.fillRect(
        page,
        x1: 0,
        y1: page.height ~/ 2,
        x2: page.width - 1,
        y2: page.height - 1,
        color: img.ColorRgb8(255, 255, 255),
      );
      expect(check(page), isNull);
      expect(check(img.copyRotate(page, angle: 90), rotated: true), isNull);
      expect(
        checkPrintPreview(
          img.encodePng(page),
          rotated: false,
          expected: ['0017'],
        ),
        isNotNull,
      );
    },
  );

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
    await tester.pumpWidget(
      MaterialApp(
        home: LabelPrintPage(
          session: PrinterSession(printer: printer),
          job: PrintJob(sampleLabels),
        ),
      ),
    );
    final printButton = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(printButton).onPressed, isNull);
    await tester.tap(find.text('搜索打印机'));
    await tester.pumpAndSettle();
    expect(find.text('B1-TEST'), findsNothing);
    expect(find.text('B1 Pro-'), findsNothing);
    expect(find.text('Headphones'), findsNothing);
    expect(find.text('B1 Pro Max-TEST'), findsNothing);
    await tester.tap(find.text('B1 Pro-TEST'));
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
    expect(tester.widget<FilledButton>(printButton).onPressed, isNull);
  });

  testWidgets('resume an odd job at its first unconfirmed code', (
    tester,
  ) async {
    final last = img.Image(width: 240, height: 240);
    img.fill(last, color: img.ColorRgb8(255, 255, 255));
    final matrix = qr.Encoder.encode('0017', qr.ErrorCorrectionLevel.m).matrix!;
    for (var y = 0; y < matrix.height; y++) {
      for (var x = 0; x < matrix.width; x++) {
        if (matrix.get(x, y) == 1) {
          img.fillRect(
            last,
            x1: 120 + x * 3,
            y1: 20 + y * 3,
            x2: 122 + x * 3,
            y2: 22 + y * 3,
            color: img.ColorRgb8(0, 0, 0),
          );
        }
      }
    }
    final printer = FakePrinter();
    printer.pending.complete();
    printer.nextPreviews.addAll([
      printer.preview,
      img.encodePng(img.Image(width: 64, height: 64)),
      img.encodePng(last),
    ]);
    final job = PrintJob([
      ...sampleLabels,
      const VesselLabel('0017', '测试', '¥17'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: LabelPrintPage(
          session: PrinterSession(printer: printer)..connected = 'B1',
          job: job,
        ),
      ),
    );
    final button = find.byType(FilledButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(job.confirmed, 2);
    expect(printer.sentCodes, [
      ['090001', '090002'],
    ]);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(job.confirmed, 3);
    expect(printer.sentCodes, [
      ['090001', '090002'],
      ['0017'],
    ]);
  });
}

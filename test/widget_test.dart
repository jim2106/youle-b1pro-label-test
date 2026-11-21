import 'dart:async';
import 'package:b1pro_test/label_pair.dart';
import 'package:b1pro_test/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niimbot_print/niimbot_print.dart';

class FakePrinter extends NiimbotPrint {
  final pending = Completer<void>();
  int jobs = 0;
  bool online = true;

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
    expect(elements.length, 2);
    expect(layout.size.height, 30);
    await pending.future;
    onResult(true, '');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('both original images fill distinct 30 x 15 mm rows', () async {
    const pair = LabelPair(gap: 2);
    final elements = await pair.elements();
    final first = elements.first as NiimbotImageElement;
    final last = elements.last as NiimbotImageElement;
    expect(first.frame.toJson(), {'x': 0, 'y': 0, 'width': 30, 'height': 15});
    expect(last.frame.toJson(), {'x': 0, 'y': 17, 'width': 30, 'height': 15});
    expect(
      first.toJson(),
      isNot(equals(last.toJson()..['frame'] = first.frame.toJson())),
    );
    expect(pair.layout.size.height, 32);
    const rotated = LabelPair(gap: 2, rotate: true);
    expect(rotated.layout.size.width, 32);
    expect(rotated.layout.size.height, 30);
    expect(rotated.layout.orientation, NiimbotLabelOrientation.landscape);
  });

  testWidgets('one tap sends one pair, double taps do not duplicate it', (
    tester,
  ) async {
    final printer = FakePrinter();
    await tester.pumpWidget(TestApp(printer: printer));
    final printButton = find.widgetWithText(FilledButton, '打印两张测试标签');
    expect(tester.widget<FilledButton>(printButton).onPressed, isNull);
    await tester.tap(find.text('搜索打印机'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B1-TEST'));
    await tester.pumpAndSettle();
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

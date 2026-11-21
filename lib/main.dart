import 'dart:async';
import 'package:flutter/material.dart';
import 'package:niimbot_print/niimbot_print.dart';
import 'label_pair.dart';

void main() => runApp(const TestApp());

class TestApp extends StatelessWidget {
  const TestApp({super.key, this.printer});
  final NiimbotPrint? printer;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '有乐试印',
    theme: ThemeData(
      colorSchemeSeed: const Color(0xff986249),
      scaffoldBackgroundColor: const Color(0xfffaf7f2),
      useMaterial3: true,
    ),
    home: TestPage(printer: printer),
  );
}

class TestPage extends StatefulWidget {
  const TestPage({super.key, this.printer});
  final NiimbotPrint? printer;
  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  late final printer = widget.printer ?? NiimbotPrint();
  List<BlueDeviceInfoModel> devices = [];
  String? connected;
  String status = '装入双排纸，打开 B1 Pro 电源后搜索。';
  bool busy = false, uncertain = false, rotate = false;
  double gap = 0;

  void update(void Function() change) {
    if (mounted) setState(change);
  }

  Future<void> scan() async {
    if (busy || uncertain) return;
    update(() {
      busy = true;
      devices = [];
      status = '正在搜索精臣打印机…';
    });
    try {
      if (connected != null)
        await printer.onDisconnect().timeout(const Duration(seconds: 8));
      update(() {
        connected = null;
      });
      String? failure;
      final found = await printer
          .onStartScan(onError: (msg) => failure = msg)
          .timeout(const Duration(seconds: 30));
      update(() {
        devices = found.where((d) => d.deviceName?.isNotEmpty == true).toList();
        status =
            failure ??
            (devices.isEmpty
                ? '未发现打印机。请核对蓝牙权限和电源，再点搜索。'
                : '点选你身边的 B1 Pro，名称可能以 B1 开头。');
      });
    } catch (e) {
      update(() {
        connected = null;
        status = '搜索未完成：$e';
      });
    } finally {
      update(() {
        busy = false;
      });
    }
  }

  Future<void> connect(BlueDeviceInfoModel device) async {
    if (busy || uncertain) return;
    update(() {
      busy = true;
      connected = null;
      status = '正在连接 ${device.deviceName}…';
    });
    try {
      bool success = false;
      String message = '';
      await printer
          .onStartConnect(
            model: device,
            onResult: (ok, msg) {
              success = ok;
              message = msg;
            },
          )
          .timeout(const Duration(seconds: 25));
      update(() {
        if (success) {
          connected = device.deviceName;
          devices = [];
          status = '已连接 $connected';
        } else {
          status = '连接失败：$message';
        }
      });
    } on TimeoutException {
      // The native request can still finish later. Ignore this instance
      // instead of letting a late callback select a different printer.
      update(() {
        uncertain = true;
        status = '连接超时，请重新打开测试版后再连接。';
      });
    } catch (e) {
      update(() {
        status = '连接失败：$e';
      });
    } finally {
      update(() {
        busy = false;
      });
    }
  }

  Future<void> printPair() async {
    if (busy || uncertain || connected == null) return;
    update(() {
      busy = true;
      status = '正在准备两张测试标签…';
    });
    var submitted = false;
    try {
      if (!await printer.isConnected().timeout(const Duration(seconds: 8))) {
        update(() {
          connected = null;
          status = '蓝牙连接已断开，请重新搜索。';
        });
        return;
      }
      final pair = LabelPair(gap: gap, rotate: rotate);
      final elements = await pair.elements();
      update(() {
        status = '正在发送一组双排标签…';
      });
      submitted = true;
      bool ok = false;
      String message = '';
      await printer
          .onStartPrint(
            elements: elements,
            layout: pair.layout,
            onResult: (result, detail) {
              ok = result;
              message = detail;
            },
          )
          .timeout(const Duration(seconds: 75));
      update(() {
        status = ok
            ? '打印机已回报完成。请核对上下两张的边缘和扫码结果。'
            : '打印机返回失败：$message。请先检查出纸情况。';
      });
    } catch (e) {
      update(() {
        uncertain = submitted;
        status = submitted ? '设备未确认完成。请查看出纸，重新打开测试版后再试。\n$e' : '准备标签失败：$e';
      });
    } finally {
      update(() {
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = !busy && !uncertain;
    return Scaffold(
      appBar: AppBar(title: const Text('有乐 · 双排试印')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              '30 × 15 毫米 · 上下双排',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('每个二维码只含下方的六位编号，请保留开头的 0。'),
            const SizedBox(height: 12),
            for (final code in sampleCodes)
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                height: 91,
                alignment: Alignment.center,
                color: Colors.white,
                child: Image.asset(
                  'assets/$code.png',
                  semanticLabel: '测试标签 $code',
                  filterQuality: FilterQuality.none,
                ),
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('纸卷对位设置'),
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('两排标签之间的净间距')),
                    DropdownButton<double>(
                      value: gap,
                      items: [
                        for (var i = 0; i <= 10; i++)
                          DropdownMenuItem(
                            value: i / 2,
                            child: Text('${i / 2} mm'),
                          ),
                      ],
                      onChanged: available
                          ? (v) => setState(() => gap = v!)
                          : null,
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: rotate,
                  title: const Text('整组旋转 90°'),
                  onChanged: available
                      ? (v) => setState(() => rotate = v)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: available ? scan : null,
              child: Text(connected == null ? '搜索打印机' : '重新搜索打印机'),
            ),
            for (final d in devices)
              ListTile(
                title: Text(d.deviceName!),
                trailing: const Icon(Icons.chevron_right),
                enabled: available,
                onTap: available ? () => connect(d) : null,
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: available && connected != null ? printPair : null,
              child: const Text('打印两张测试标签'),
            ),
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(status)),
          ],
        ),
      ),
    );
  }
}

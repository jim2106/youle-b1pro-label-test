import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:niimbot_print/niimbot_print.dart';
import 'label_pair.dart';
import 'print_preview.dart';

class PrinterSession {
  PrinterSession({NiimbotPrint? printer}) : printer = printer ?? NiimbotPrint();
  final NiimbotPrint printer;
  String? connected;
  bool uncertain = false, rotate = false;
  double gap = 0;
}

class PrintJob {
  PrintJob(this.labels);
  final List<VesselLabel> labels;
  int confirmed = 0;
  String detail = '';
  String get summary => '已确认打印 $confirmed / ${labels.length} 张。$detail';
}

class LabelPrintPage extends StatefulWidget {
  const LabelPrintPage({super.key, required this.session, required this.job});
  final PrinterSession session;
  final PrintJob job;
  @override
  State<LabelPrintPage> createState() => _LabelPrintPageState();
}

class _LabelPrintPageState extends State<LabelPrintPage> {
  NiimbotPrint get printer => widget.session.printer;
  String? get connected => widget.session.connected;
  set connected(String? value) => widget.session.connected = value;
  bool get uncertain => widget.session.uncertain;
  set uncertain(bool value) => widget.session.uncertain = value;
  bool get rotate => widget.session.rotate;
  set rotate(bool value) => widget.session.rotate = value;
  double get gap => widget.session.gap;
  set gap(double value) => widget.session.gap = value;
  List<BlueDeviceInfoModel> devices = [];
  String status = '';
  bool busy = false, stopAfterPage = false;
  Uint8List? sdkPreview;

  void update(void Function() change) {
    if (mounted) setState(change);
  }

  Future<void> scan() async {
    if (busy || uncertain) return;
    update(() {
      busy = true;
      devices = [];
      sdkPreview = null;
      status = '正在搜索精臣打印机…';
    });
    try {
      if (connected != null) {
        await printer.onDisconnect().timeout(const Duration(seconds: 8));
      }
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
        status = '连接超时，请退出并重新打开 App 后再连接。';
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
      sdkPreview = null;
      status = '正在核对本组二维码…';
    });
    final job = widget.job;
    var submitted = false;
    stopAfterPage = false;
    try {
      while (job.confirmed < job.labels.length && !stopAfterPage) {
        if (!await printer.isConnected().timeout(const Duration(seconds: 8))) {
          connected = null;
          job.detail = '蓝牙连接已断开，请重新搜索。';
          break;
        }
        final rows = job.labels.skip(job.confirmed).take(2).toList();
        final codes = rows.map((row) => row.code).toList();
        final pair = LabelPair(gap: gap, rotate: rotate, labels: rows);
        final elements = pair.elements();
        final layout = pair.layout;
        final preview = await printer
            .generatePreview(elements: elements, layout: layout)
            .timeout(const Duration(seconds: 15));
        if (!mounted) return;
        final problem = checkPrintPreview(
          preview,
          rotated: rotate,
          expected: codes,
        );
        update(() {
          sdkPreview = preview;
        });
        if (problem != null) {
          job.detail = '$problem，已停止送纸。编号 ${codes.join("、")}。';
          break;
        }
        if (stopAfterPage) break;
        update(() {
          status = '正在打印 ${codes.join("、")}';
        });
        submitted = true;
        bool ok = false;
        String message = '';
        await printer
            .onStartPrint(
              elements: elements,
              layout: layout,
              onResult: (result, detail) {
                ok = result;
                message = detail;
              },
            )
            .timeout(const Duration(seconds: 75));
        if (!ok) throw StateError(message);
        submitted = false;
        job.confirmed += rows.length;
        job.detail = '';
        update(() {
          status = job.summary;
        });
      }
      if (stopAfterPage && job.confirmed < job.labels.length) {
        job.detail = '已暂停。';
      }
      if (job.confirmed == job.labels.length) job.detail = '打印机已回报完成。';
    } catch (e) {
      uncertain = submitted;
      job.detail = submitted
          ? '编号 ${job.labels.skip(job.confirmed).take(2).map((r) => r.code).join("、")} 的出纸结果未确认，请核对实物后再补打。'
          : '准备标签失败：$e';
    } finally {
      update(() {
        busy = false;
        status = job.summary;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = !busy && !uncertain;
    final job = widget.job;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('B1 Pro 打印贴纸'),
          automaticallyImplyLeading: !busy,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                '30 × 15 毫米 · 上下双排',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('共 ${job.labels.length} 张 · 已确认 ${job.confirmed} 张'),
              Text(
                '编号 ${job.labels.first.code}${job.labels.length == 1 ? "" : " … ${job.labels.last.code}"}',
              ),
              if (job.labels.length.isOdd) const Text('最后一组只印一枚，另一枚留白。'),
              if (connected != null) Text('打印机：$connected'),
              if (uncertain) const Text('上次设备状态未确认，请核对出纸并重新打开 App。'),
              if (sdkPreview != null) ...[
                const Text('本组打印预览'),
                ColoredBox(
                  color: Colors.white,
                  child: Image.memory(
                    sdkPreview!,
                    height: 182,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ],
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
                            ? (v) => setState(() {
                                gap = v!;
                                sdkPreview = null;
                              })
                            : null,
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: rotate,
                    title: const Text('整组旋转 90°'),
                    onChanged: available
                        ? (v) => setState(() {
                            rotate = v;
                            sdkPreview = null;
                          })
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
                onPressed:
                    available &&
                        connected != null &&
                        job.confirmed < job.labels.length
                    ? printPair
                    : null,
                child: Text(
                  job.confirmed == job.labels.length
                      ? '打印完成'
                      : '打印剩余 ${job.labels.length - job.confirmed} 张',
                ),
              ),
              const SizedBox(height: 12),
              if (busy && (job.labels.length - job.confirmed > 2))
                TextButton(
                  onPressed: stopAfterPage
                      ? null
                      : () => setState(() => stopAfterPage = true),
                  child: Text(stopAfterPage ? '正在暂停' : '暂停后续打印'),
                ),
              Semantics(liveRegion: true, child: Text(status)),
              if (!busy && (job.confirmed > 0 || uncertain))
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('返回 ERP'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

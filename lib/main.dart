import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'label_pair.dart';
import 'label_print_page.dart';

void main() => runApp(
  MaterialApp(
    title: '有乐 ERP',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xff986249),
      useMaterial3: true,
    ),
    home: const ErpHome(),
  ),
);

class ErpHome extends StatefulWidget {
  const ErpHome({super.key});
  @override
  State<ErpHome> createState() => _ErpHomeState();
}

class _ErpHomeState extends State<ErpHome> {
  final session = PrinterSession();
  static const channel = MethodChannel('youle/erp');
  bool printing = false;

  @override
  void initState() {
    super.initState();
    channel.setMethodCallHandler(onRequest);
  }

  Future<Object?> onRequest(MethodCall call) async {
    if (call.method == 'sessionReady') {
      if (!printing) await session.prepare(atLogin: true);
      return null;
    }
    if (call.method != 'printLabels') throw MissingPluginException();
    if (printing) throw PlatformException(code: 'busy', message: '已有打印任务');
    final job = PrintJob(VesselLabel.parseJob(call.arguments));
    printing = true;
    try {
      await session.prepare();
      if (!mounted) return job.summary;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => LabelPrintPage(session: session, job: job),
        ),
      );
      return job.summary;
    } finally {
      printing = false;
    }
  }

  @override
  void dispose() {
    channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xfff7f5f0),
    body: SafeArea(child: UiKitView(viewType: 'youle/erp-web')),
  );
}

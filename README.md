# 有乐 ERP iPhone 客户端

App 从有乐站点加载网页。账号和会话由站点处理。首次连接打印机时，在 ERP 标签页选择 30 × 15 毫米，点「用 B1 Pro 打印贴纸」，选本机蓝牙设备并确认张数。建档和补打都使用网页显示的编号、作家和售价。每组两枚，最后一组可以只印一枚。中断时先看已确认的数量及最后一组编号，再核对纸卷。

## 构建与安装

使用 Flutter 3.44.9、CocoaPods 和 niimbot_print 0.3.2。运行 flutter pub get --enforce-lockfile、flutter analyze、flutter test，然后运行 flutter build ios --release --no-codesign。公开仓库的 Actions 提供用于个人签名的 Youle-ERP.ipa。在 Windows 上用 Sideloadly 和自己的 Apple 账户签名覆盖安装。

## 网页与打印

WKWebView 使用持久会话。只有受信站点的主页面可通过 youlePrintV1 请求打印。打印机连接、预览解码和逐组确认都在手机完成。进入原生打印页保留网页现场，返回时向页面报告确认张数。测试素材均为虚构标签。

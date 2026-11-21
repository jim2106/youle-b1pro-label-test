# 有乐 ERP iPhone 客户端

App 从有乐站点加载网页。账号和会话由站点处理。首次连接打印机时，在 ERP 标签页选择 30 × 15 毫米，点「用 B1 Pro 打印贴纸」，选本机蓝牙设备并确认张数。建档和补打都使用网页显示的编号、作家和售价。每组两枚，最后一组可以只印一枚。中断时先看已确认的数量及最后一组编号，再核对纸卷。

## 构建与安装

使用 Flutter 3.44.9、CocoaPods 和 niimbot_print 0.3.2。运行 flutter pub get --enforce-lockfile、flutter analyze、flutter test，然后运行 flutter build ios --release --no-codesign。公开仓库的 Actions 提供用于个人签名的 Youle-ERP.ipa。在 Windows 上用 Sideloadly 和自己的 Apple 账户签名覆盖安装。

## 网页与打印

WKWebView 使用持久会话。只有受信站点的主页面可以请求打印。绑定后可直接打印，手机按组核对预览编号并返回设备回执。测试素材均为虚构标签。

0.2.5 通过 youlePrintV3 告知网页支持单枚走纸。前后排列的纸卷上，单枚按 30 × 15 毫米生成预览并送印。双枚使用原来的间距和旋转设置。网页可按数量自动分组，也可每次发送一枚，或把单数留待下次拼排。实际停纸位置取决于纸卷定位。

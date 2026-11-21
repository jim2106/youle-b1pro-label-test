# 有乐 B1 Pro 双排试印

独立的 iPhone 蓝牙试印程序，使用 `niimbot_print 0.3.2`。单枚尺寸为 30 × 15 毫米，上排和下排各一个编号，点击一次发送一组。

## Windows 安装

在本仓库 Actions 的成功构建中下载 `Youle-B1Pro-iPhone`，解压得到 `Youle-B1Pro-Test.ipa`。该 IPA 需要在安装时用自己的 Apple 账户签名。Windows 可使用 AltStore Classic，首次按照官方指引安装 AltServer 和手机上的 AltStore，然后在手机的 My Apps 点加号选这份 IPA。[AltStore 的 Windows 安装说明](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)

## 真机试印

1. 装入 T30×15/2R 上下双排纸，开机。在测试版中点「搜索打印机」，允许蓝牙，选身边这台的设备名称。B1 Pro 可能以 B1 开头。
2. 点「打印两张测试标签」。从 0.1.1 起，二维码与三行文字由精臣 SDK 分别绘制。App 会读取 SDK 返回的本次预览图，检查每枚标签的黑色面积并解码两个编号，通过后才发送一组。上排的测试作家甲标价 ¥128，编号 `090001`。下排的测试作家乙标价 ¥168，编号 `090002`。
3. 看两份内容是否完整落在对应贴纸内，再分别扫码，核对六位数和开头的零。若第二排有偏移，先量两枚贴纸相邻边缘间的净空，在「纸卷对位设置」修改后重试。初始净间距为 0 毫米；若整组方向与走纸方向相差 90°，可切换整组旋转。
4. 遇到未确认完成的提示，请先查看纸卷。程序不会自动重发。
5. 如果显示「已停止送纸」，保留「本次打印预览」和提示文字。如果预览显示两个二维码但纸面全黑，保留预览截图和纸面照片，用于区分绘图与实际出纸问题。

## 构建

使用 Flutter 3.44.9 和 CocoaPods。运行 `flutter pub get --enforce-lockfile`、`flutter analyze` 和 `flutter test`。iOS 构建使用 `flutter build ios --release --no-codesign`。仓库工作流只在公开仓库的标准 macOS 构建机上运行。

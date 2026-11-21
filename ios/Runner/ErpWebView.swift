import Flutter
import UIKit
import WebKit

private let home = URL(string: "https://youle.piroad.cn/")!
private func isErp(_ url: URL?) -> Bool {
  guard let url else { return false }
  return url.scheme == "https" && url.host == home.host && (url.port ?? 443) == 443
      && url.user == nil && url.password == nil
}

final class ErpWebFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    ErpWeb(frame: frame, messenger: messenger)
  }
}

private final class PrintBridge: NSObject, WKScriptMessageHandlerWithReply {
  let channel: FlutterMethodChannel
  init(_ messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "youle/erp", binaryMessenger: messenger)
  }
  func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage,
                             replyHandler: @escaping (Any?, String?) -> Void) {
    let frame = message.frameInfo
    let origin = frame.securityOrigin
    guard frame.isMainFrame, origin.protocol == "https", origin.host == home.host,
          [0, 443].contains(origin.port), isErp(message.webView?.url),
          ["/", "/index.html"].contains(message.webView?.url?.path ?? "") else {
      replyHandler(nil, "无效的页面")
      return
    }
    if message.name == "youleSessionReady" {
      channel.invokeMethod("sessionReady", arguments: nil)
      replyHandler(true, nil)
      return
    }
    guard let job = message.body as? [String: Any],
          job["version"] as? Int == 1, let rows = job["items"] as? [[String: String]], !rows.isEmpty else {
      replyHandler(nil, "无效的打印请求")
      return
    }
    channel.invokeMethod("printLabels", arguments: ["version": 1, "items": rows]) { result in
      if let summary = result as? String { replyHandler(summary, nil) }
      else { replyHandler(nil, (result as? FlutterError)?.message ?? "无法打开打印任务") }
    }
  }
}

private final class ErpWeb: NSObject, FlutterPlatformView, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
  private let web: WKWebView
  private let retry = UIButton(type: .system)
  private var downloads: [ObjectIdentifier: URL] = [:]

  init(frame: CGRect, messenger: FlutterBinaryMessenger) {
    let config = WKWebViewConfiguration()
    config.allowsInlineMediaPlayback = true
    config.mediaTypesRequiringUserActionForPlayback = .audio
    config.websiteDataStore = .default()
    let bridge = PrintBridge(messenger)
    config.userContentController.addScriptMessageHandler(bridge, contentWorld: .page, name: "youlePrintV1")
    config.userContentController.addScriptMessageHandler(bridge, contentWorld: .page, name: "youleSessionReady")
    web = WKWebView(frame: frame, configuration: config)
    super.init()
    web.navigationDelegate = self
    web.uiDelegate = self
    web.allowsBackForwardNavigationGestures = true
    retry.setTitle("网页未能加载，点此重试", for: .normal)
    retry.backgroundColor = .systemBackground
    retry.isHidden = true
    retry.addTarget(self, action: #selector(reloadPage), for: .touchUpInside)
    retry.translatesAutoresizingMaskIntoConstraints = false
    web.addSubview(retry)
    NSLayoutConstraint.activate([retry.centerXAnchor.constraint(equalTo: web.centerXAnchor),
                                 retry.centerYAnchor.constraint(equalTo: web.centerYAnchor)])
    web.load(URLRequest(url: home))
  }
  func view() -> UIView { web }
  @objc private func reloadPage() {
    retry.isHidden = true
    web.load(URLRequest(url: isErp(web.url) ? web.url! : home))
  }
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { retry.isHidden = true }
  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    if (error as NSError).code != NSURLErrorCancelled { retry.isHidden = false }
  }
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    if (error as NSError).code != NSURLErrorCancelled { retry.isHidden = false }
  }
  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { retry.isHidden = false }

  func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
               decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    guard let url = action.request.url else { decisionHandler(.cancel); return }
    let localFile = isErp(action.sourceFrame.request.url) &&
        (url.absoluteString.hasPrefix("blob:" + home.absoluteString) || url.scheme == "data")
    if (isErp(url) || localFile) && (action.shouldPerformDownload || (localFile && action.targetFrame == nil)) {
      decisionHandler(.download)
    } else if isErp(url) {
      decisionHandler(.allow)
    } else if action.targetFrame?.isMainFrame == false && url.absoluteString == "about:blank" {
      decisionHandler(.allow)
    } else {
      decisionHandler(.cancel)
      if action.navigationType == .linkActivated && url.scheme == "https" {
        UIApplication.shared.open(url)
      }
    }
  }
  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
               for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    if action.targetFrame == nil && isErp(action.request.url) { webView.load(action.request) }
    return nil
  }
  func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
               decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
    let header = (response.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition") ?? ""
    decisionHandler(!response.canShowMIMEType || header.lowercased().hasPrefix("attachment") ? .download : .allow)
  }
  func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
    download.delegate = self
  }
  func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
    download.delegate = self
  }
  func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String,
                completionHandler: @escaping (URL?) -> Void) {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let name = (suggestedFilename as NSString).lastPathComponent
      let dest = folder.appendingPathComponent(["", ".", "..", "/"].contains(name) ? "有乐导出" : name)
      downloads[ObjectIdentifier(download)] = dest
      completionHandler(dest)
    } catch { completionHandler(nil) }
  }
  private var presenter: UIViewController? {
    var controller = web.window?.rootViewController
    while let next = controller?.presentedViewController { controller = next }
    return controller
  }
  func downloadDidFinish(_ download: WKDownload) {
    guard let file = downloads.removeValue(forKey: ObjectIdentifier(download)) else { return }
    guard let presenter else { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()); return }
    let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
    sheet.popoverPresentationController?.sourceView = web
    sheet.popoverPresentationController?.sourceRect = CGRect(x: web.bounds.midX, y: web.bounds.midY, width: 1, height: 1)
    sheet.completionWithItemsHandler = { _,_,_,_ in try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    presenter.present(sheet, animated: true)
  }
  func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
    if let file = downloads.removeValue(forKey: ObjectIdentifier(download)) {
      try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
    }
    if let presenter {
      let alert = UIAlertController(title: "下载未完成", message: error.localizedDescription, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "好", style: .default))
      presenter.present(alert, animated: true)
    }
  }
  func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
               initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
    guard let presenter else { completionHandler(false); return }
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
    alert.addAction(UIAlertAction(title: "确认", style: .default) { _ in completionHandler(true) })
    presenter.present(alert, animated: true)
  }
  func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
               initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
    guard let presenter else { completionHandler(); return }
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
    presenter.present(alert, animated: true)
  }
}

import AppKit
import WebKit

final class SeatPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  override func sendEvent(_ event: NSEvent) {
    switch event.type {
    case .leftMouseDown, .leftMouseUp, .leftMouseDragged,
      .rightMouseDown, .rightMouseUp, .rightMouseDragged,
      .otherMouseDown, .otherMouseUp, .otherMouseDragged, .mouseMoved, .scrollWheel:
      // macOS events belong to the owner's trackpad/shared cursor, never this seat.
      break
    default:
      super.sendEvent(event)
    }
  }
}

final class BrowserPanel: NSObject, WKNavigationDelegate {
  let panel: SeatPanel
  let web: WKWebView
  var onLoaded: (() -> Void)?
  private let status = NSTextField(
    labelWithString: "Separação desativada · ative o mouse exclusivo no controle Duo")
  private let address = NSTextField(labelWithString: "https://www.youtube.com")
  private let pointer = NSView()
  private(set) var cursor: SeatCursor
  private var captureActive = false
  private var addressSelected = false
  private var shifted = false
  private var timer: Timer?
  private var moved = false
  private let keyboardHeight: CGFloat = 180

  init(screen: NSScreen, resourceDirectory: URL) throws {
    let frame = screen.visibleFrame
    cursor = SeatCursor(width: frame.width, height: frame.height)
    panel = SeatPanel(
      contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
      defer: false)
    let config = WKWebViewConfiguration()
    let editing = try String(
      contentsOf: resourceDirectory.appendingPathComponent("virtual-input.cjs"))
    let interactions = try String(
      contentsOf: resourceDirectory.appendingPathComponent("page-input.js"))
    config.userContentController.addUserScript(
      WKUserScript(
        source: editing + "\n" + interactions, injectionTime: .atDocumentEnd, forMainFrameOnly: true
      ))
    web = WKWebView(frame: .zero, configuration: config)
    super.init()
    configure(frame)
  }

  private func configure(_ frame: NSRect) {
    panel.hidesOnDeactivate = false
    panel.ignoresMouseEvents = false
    // Keep this seat above the app the other user activates, without becoming key.
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isReleasedWhenClosed = false
    panel.backgroundColor = NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.09, alpha: 1)
    guard let content = panel.contentView else { return }
    addLabel("DUO / ESPAÇO DIREITO", x: 24, y: frame.height - 32, width: 260)
    status.frame = NSRect(x: 300, y: frame.height - 36, width: frame.width - 330, height: 24)
    status.textColor = .systemOrange
    content.addSubview(status)
    addButton("←", x: 20, y: frame.height - 80, width: 45, action: #selector(back))
    addButton("↻", x: 70, y: frame.height - 80, width: 45, action: #selector(reload))
    address.frame = NSRect(x: 130, y: frame.height - 77, width: frame.width - 240, height: 28)
    address.textColor = .white
    address.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
    content.addSubview(address)
    addButton(
      "Ir", x: frame.width - 95, y: frame.height - 80, width: 70, action: #selector(navigate))
    web.frame = NSRect(
      x: 0, y: keyboardHeight, width: frame.width, height: frame.height - keyboardHeight - 92)
    web.navigationDelegate = self
    content.addSubview(web)
    buildKeyboard(width: frame.width)
    pointer.frame = NSRect(x: 30, y: 30, width: 16, height: 16)
    pointer.wantsLayer = true
    pointer.isHidden = true
    pointer.layer?.backgroundColor = NSColor.systemGreen.cgColor
    pointer.layer?.cornerRadius = 8
    content.addSubview(pointer)
    panel.orderFrontRegardless()
    navigate()
    timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
      self?.renderPointer()
    }
  }

  private func addLabel(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat) {
    let label = NSTextField(labelWithString: text)
    label.frame = NSRect(x: x, y: y, width: width, height: 24)
    label.textColor = .white
    label.font = NSFont(name: "AvenirNext-DemiBold", size: 16)
    panel.contentView?.addSubview(label)
  }

  private func addButton(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, action: Selector) {
    let button = NSButton(title: text, target: self, action: action)
    button.frame = NSRect(x: x, y: y, width: width, height: 34)
    button.bezelStyle = .rounded
    panel.contentView?.addSubview(button)
  }

  private func buildKeyboard(width: CGFloat) {
    let rows = [
      "1 2 3 4 5 6 7 8 9 0 - =", "q w e r t y u i o p á é", "a s d f g h j k l ç í ó",
      "Shift z x c v b n m , . / ú", "Endereço Espaço Backspace Enter",
    ]
    for (rowIndex, row) in rows.enumerated() {
      let keys = row.split(separator: " ").map(String.init)
      let keyWidth = min(100, (width - 48) / CGFloat(keys.count))
      let start = (width - CGFloat(keys.count) * keyWidth) / 2
      for (index, key) in keys.enumerated() {
        addButton(
          key, x: start + CGFloat(index) * keyWidth, y: 142 - CGFloat(rowIndex) * 34,
          width: keyWidth - 4, action: #selector(pressKey(_:)))
      }
    }
  }

  @objc private func back() { web.goBack() }
  @objc private func reload() { web.reload() }
  @objc private func navigate() {
    guard let url = browserURL(address.stringValue) else {
      setStatus("Endereço inválido: use http/https ou uma busca.")
      return
    }
    addressSelected = false
    web.load(URLRequest(url: url))
  }

  @objc private func pressKey(_ sender: NSButton) {
    let key = sender.title
    if key == "Shift" {
      shifted.toggle()
      return
    }
    if key == "Endereço" {
      addressSelected = true
      address.stringValue = ""
      return
    }
    let typed = key == "Espaço" ? " " : (shifted ? key.uppercased() : key)
    guard addressSelected else {
      send("key", key: key == "Enter" || key == "Backspace" ? key : typed)
      return
    }
    if key == "Enter" {
      navigate()
      return
    }
    if key == "Backspace" {
      if !address.stringValue.isEmpty { address.stringValue.removeLast() }
      return
    }
    address.stringValue += typed
  }

  func setStatus(_ text: String) {
    status.stringValue = text
    status.textColor = captureActive ? .systemGreen : .systemOrange
  }

  func setCaptureActive(_ active: Bool) {
    captureActive = active
    pointer.isHidden = !active
    moved = active
  }

  func input(page: UInt32, usage: UInt32, value: Int) {
    guard captureActive else { return }
    if page == 1 && usage == 0x30 {
      cursor.move(dx: Double(value), dy: 0)
      moved = true
    }
    if page == 1 && usage == 0x31 {
      cursor.move(dx: 0, dy: Double(value))
      moved = true
    }
    if page == 1 && usage == 0x38 { send("scroll", key: value) }
    if page == 9 && usage == 1 && value == 1 { click() }
  }

  private func renderPointer() {
    guard moved, let content = panel.contentView else { return }
    moved = false
    pointer.setFrameOrigin(NSPoint(x: cursor.x, y: content.bounds.height - cursor.y - 16))
    send("move")
  }

  private func click() {
    guard let content = panel.contentView else { return }
    let point = NSPoint(x: cursor.x, y: content.bounds.height - cursor.y)
    if address.frame.contains(point) {
      addressSelected = true
      address.stringValue = ""
      return
    }
    if let button = content.subviews.compactMap({ $0 as? NSButton }).first(where: {
      $0.frame.contains(point)
    }) {
      button.performClick(nil)
      return
    }
    if web.frame.contains(point) {
      addressSelected = false
      send("click")
    }
  }

  private func send(_ kind: String, key: Any = "") {
    guard let content = panel.contentView,
      let encoded = try? JSONSerialization.data(withJSONObject: [
        kind, cursor.x, cursor.y - (content.bounds.height - web.frame.maxY), key,
      ]),
      let arguments = String(data: encoded, encoding: .utf8)
    else { return }
    web.evaluateJavaScript("window.__duo?.(...\(arguments))", completionHandler: nil)
  }

  func webView(
    _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    let scheme = navigationAction.request.url?.scheme ?? ""
    decisionHandler(["https", "http", "about"].contains(scheme) ? .allow : .cancel)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    if let url = webView.url { address.stringValue = url.absoluteString }
    onLoaded?()
  }
}

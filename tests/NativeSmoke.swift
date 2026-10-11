import AppKit
import WebKit

final class SmokeApp: NSObject, NSApplicationDelegate {
  private var browser: BrowserPanel?
  private var timeout: Timer?
  private var ownerPID: pid_t?

  func applicationDidFinishLaunching(_ notification: Notification) {
    ownerPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
    guard let screen = NSScreen.screens.first(where: { $0.localizedName.contains("DELL") }) else {
      fputs("FAIL: Dell is required for native integration test\n", stderr)
      exit(1)
    }
    do {
      let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("native")
      browser = try BrowserPanel(screen: screen, resourceDirectory: resources)
      let initialAddresses = browser?.panel.contentView?.subviews.compactMap {
        ($0 as? NSTextField)?.stringValue
      } ?? []
      guard initialAddresses.contains("https://www.youtube.com") else {
        fputs("FAIL: Right browser must start at YouTube\n", stderr)
        exit(1)
      }
      browser?.onLoaded = { [weak self] in self?.verify() }
      browser?.web.loadHTMLString(
        "<input id='fixture' value='abc' style='position:absolute;left:0;top:0;width:200px;height:80px'>",
        baseURL: nil)
      timeout = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { _ in
        fputs("FAIL: WKWebView integration timed out\n", stderr)
        exit(1)
      }
    } catch {
      fputs("FAIL: \(error)\n", stderr)
      exit(1)
    }
  }

  private func verify() {
    guard let browser else { return }
    guard !browser.panel.ignoresMouseEvents, browser.panel.level == .floating else {
      fputs(
        "FAIL: Right panel lets clicks through or disappears behind the activated app\n", stderr)
      exit(1)
    }
    let originalPosition = browser.cursor
    let trackpadClick = NSEvent.mouseEvent(
      with: .leftMouseDown, location: NSPoint(x: 400, y: 400),
      modifierFlags: [], timestamp: 0, windowNumber: browser.panel.windowNumber,
      context: nil, eventNumber: 2, clickCount: 1, pressure: 1)!
    browser.panel.sendEvent(trackpadClick)
    browser.input(page: 1, usage: 0x30, value: 100)
    guard browser.cursor.x == originalPosition.x && browser.cursor.y == originalPosition.y else {
      fputs("FAIL: System pointer must never move the right-seat cursor\n", stderr)
      exit(1)
    }
    browser.setCaptureActive(true)
    browser.input(page: 1, usage: 0x30, value: Int(20 - browser.cursor.x))
    browser.input(page: 1, usage: 0x31, value: Int(112 - browser.cursor.y))
    browser.input(page: 9, usage: 1, value: 1)
    let capturedPosition = browser.cursor
    browser.panel.sendEvent(trackpadClick)
    guard browser.cursor.x == capturedPosition.x && browser.cursor.y == capturedPosition.y else {
      fputs("FAIL: Trackpad events must not overwrite the captured USB cursor\n", stderr)
      exit(1)
    }
    let script = """
      (() => {
        const field = document.getElementById('fixture');
        if (!field) return false;
        if (document.activeElement !== field) return false;
        field.setSelectionRange(1, 2);
        window.__duo('key', 20, 20, 'X');
        return field.value === 'aXc';
      })()
      """
    browser.web.evaluateJavaScript(script) { [weak self] result, error in
      guard let self, result as? Bool == true, error == nil,
        !browser.panel.canBecomeKey, !browser.panel.isKeyWindow,
        NSWorkspace.shared.frontmostApplication?.processIdentifier == self.ownerPID
      else {
        fputs("FAIL: Native edit or focus isolation failed: \(String(describing: error))\n", stderr)
        exit(1)
      }
      self.timeout?.invalidate()
      browser.setCaptureActive(false)
      let releasedPosition = browser.cursor
      browser.input(page: 1, usage: 0x30, value: 100)
      guard browser.cursor.x == releasedPosition.x else {
        fputs("FAIL: Released capture must reject USB input\n", stderr)
        exit(1)
      }
      browser.panel.close()
      print(
        "PASS: USB-only seat input, trackpad isolation, capture release and WKWebView typing without focus change"
      )
      exit(0)
    }
  }
}

@main
struct NativeSmoke {
  static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = SmokeApp()
    app.delegate = delegate
    app.run()
  }
}

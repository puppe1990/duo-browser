import AppKit

final class BraveSmokeApp: NSObject, NSApplicationDelegate {
  private var browser: BrowserPanel?
  private var connection: BraveConnection?
  private var clicked = false
  private var timeout: Timer?
  private var youtube = ProcessInfo.processInfo.environment["DUO_TEST_YOUTUBE"] == "1"

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard let screen = NSScreen.screens.first(where: { $0.localizedName.contains("DELL") }) else {
      fputs("FAIL: Dell is required for Brave integration\n", stderr)
      exit(1)
    }
    do {
      let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("native/DuoNative.app/Contents/Resources")
      let browser = try BrowserPanel(screen: screen, resourceDirectory: resources)
      self.browser = browser
      browser.panel.orderOut(nil)
      let connection = try BraveConnection(
        resources: resources,
        width: Int(browser.web.frame.width), height: Int(browser.web.frame.height),
        initialURL: youtube
          ? "https://www.youtube.com"
          : "chrome-extension://kkpaikgpkehmkicjmaecojgmbagdhmkk/fixture.html")
      self.connection = connection
      browser.onBraveCommand = { [weak connection] kind, x, y, key in
        connection?.send(kind: kind, x: x, y: y, key: key)
      }
      connection.onFrame = { [weak self] bytes in
        browser.showBraveFrame(bytes)
        guard let self, !self.clicked else { return }
        self.clicked = true
        DispatchQueue.main.asyncAfter(deadline: .now() + (self.youtube ? 5 : 0)) {
          self.clickAndType()
        }
      }
      connection.onFixtureProof = { [weak self] passed in
        guard passed else {
          fputs("FAIL: Native HID click and keyboard did not reach Brave fixture\n", stderr)
          exit(1)
        }
        guard let self else { exit(1) }
        if !self.youtube {
          print("PASS: Native HID click and virtual keyboard reach the Brave fixture")
          self.youtube = true
          self.clicked = false
          connection.send(kind: "navigate", key: "https://www.youtube.com")
          return
        }
        self.connection?.stop()
        browser.panel.close()
        print(
          "PASS: Native HID click and virtual keyboard reach the real YouTube search box after a burst of mouse movement"
        )
        exit(0)
      }
      connection.onStatus = { print($0) }
      connection.start()
      timeout = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { _ in
        fputs("FAIL: Native-to-Brave integration timed out\n", stderr)
        exit(1)
      }
    } catch {
      fputs("FAIL: \(error)\n", stderr)
      exit(1)
    }
  }

  private func clickAndType() {
    guard let browser else { return }
    browser.setCaptureActive(true)
    for index in 0..<100 {
      connection?.send(kind: "move", x: Double(700 + index), y: 30)
    }
    move(to: youtube ? NSPoint(x: 900, y: 122) : NSPoint(x: 20, y: 112))
    browser.input(page: 9, usage: 1, value: 1)
    for key in ["d", "u", "o"] {
      guard
        let button = browser.panel.contentView?.subviews.compactMap({ $0 as? NSButton }).first(
          where: { $0.title == key }), let content = browser.panel.contentView
      else { exit(1) }
      move(to: NSPoint(x: button.frame.midX, y: content.bounds.height - button.frame.midY))
      browser.input(page: 9, usage: 1, value: 1)
    }
    connection?.send(kind: youtube ? "youtubeProof" : "fixtureProof")
  }

  private func move(to point: NSPoint) {
    guard let browser else { return }
    browser.input(page: 1, usage: 0x30, value: Int(point.x - browser.cursor.x))
    browser.input(page: 1, usage: 0x31, value: Int(point.y - browser.cursor.y))
  }
}

@main
struct BraveSmoke {
  static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = BraveSmokeApp()
    app.delegate = delegate
    app.run()
  }
}

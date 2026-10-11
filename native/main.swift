import AppKit
import IOKit.hid
import IOKit.hidsystem

func report(_ message: String) {
  guard let encoded = try? JSONSerialization.data(withJSONObject: ["status": message]),
    let line = String(data: encoded, encoding: .utf8)
  else { return }
  print(line)
  fflush(stdout)
}

final class NativeApp: NSObject, NSApplicationDelegate {
  private var browser: BrowserPanel?
  private let mouse = MouseCapture()
  private var watchdog: Timer?
  private let originalParent = getppid()

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard let screen = NSScreen.screens.first(where: { $0.localizedName.contains("DELL") }) else {
      report("Dell não encontrado. Esperado monitor DELL conectado; captura não iniciada.")
      NSApp.terminate(nil)
      return
    }
    do {
      browser = try BrowserPanel(screen: screen, resourceDirectory: Bundle.main.resourceURL!)
    } catch {
      report("Falha ao carregar recursos do navegador: \(error.localizedDescription)")
      NSApp.terminate(nil)
      return
    }
    mouse.onValue = { [weak self] page, usage, value in
      self?.browser?.input(page: page, usage: usage, value: value)
    }
    report("Navegador aberto no \(screen.localizedName). Mouse ainda livre.")
    readCommands()
    watchParent()
  }

  private func readCommands() {
    DispatchQueue.global(qos: .utility).async { [weak self] in
      while let command = readLine() {
        DispatchQueue.main.async { self?.command(command) }
      }
      DispatchQueue.main.async {
        self?.mouse.stop()
        NSApp.terminate(nil)
      }
    }
  }

  private func command(_ text: String) {
    if text == "capture" {
      let failure = mouse.start()
      browser?.setCaptureActive(failure == nil)
      let status = failure ?? "Mouse exclusivo ativo · Dell independente (experimental)"
      browser?.setStatus(status)
      report(status)
    }
    if text == "release" {
      mouse.stop()
      browser?.setCaptureActive(false)
      browser?.setStatus("Separação desativada · ative o mouse exclusivo no controle Duo")
      report("Mouse liberado. Separação desativada; ative o mouse exclusivo para usar o Dell.")
    }
    if text == "quit" {
      mouse.stop()
      NSApp.terminate(nil)
    }
  }

  private func watchParent() {
    watchdog = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      guard let self else { return }
      if getppid() != self.originalParent {
        self.mouse.stop()
        NSApp.terminate(nil)
      }
      if !NSScreen.screens.contains(where: { $0.localizedName.contains("DELL") }) {
        self.mouse.stop()
        report("Dell desconectado; mouse liberado.")
        NSApp.terminate(nil)
      }
    }
  }

  func applicationWillTerminate(_ notification: Notification) { mouse.stop() }
}

if CommandLine.arguments.contains("--probe") {
  let monitors = NSScreen.screens.map {
    ["name": $0.localizedName, "width": Int($0.frame.width), "height": Int($0.frame.height)]
      as [String: Any]
  }
  let permission = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
  let result: [String: Any] = [
    "screens": monitors, "inputAccess": permission.rawValue, "captureAttempted": false,
  ]
  let encoded = try JSONSerialization.data(withJSONObject: result, options: .prettyPrinted)
  print(String(data: encoded, encoding: .utf8)!)
} else {
  let app = NSApplication.shared
  app.setActivationPolicy(.accessory)
  let delegate = NativeApp()
  app.delegate = delegate
  app.run()
}

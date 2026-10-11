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
  private var brave: BraveConnection?
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
    if ProcessInfo.processInfo.environment["DUO_START_BRAVE"] == "1" { openBrave() }
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
    if text == "brave" { openBrave() }
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

  private func openBrave() {
    if let brave {
      brave.send(kind: "reconnect")
      return
    }
    guard let browser else { return }
    do {
      let connection = try BraveConnection(
        resources: Bundle.main.resourceURL!, width: Int(browser.web.frame.width),
        height: Int(browser.web.frame.height))
      brave = connection
      connection.onReady = { [weak self] in self?.command("capture") }
      browser.onBraveCommand = { [weak connection] kind, x, y, key in
        connection?.send(kind: kind, x: x, y: y, key: key)
      }
      var firstFrame = true
      connection.onFrame = { [weak self] bytes in
        self?.browser?.showBraveFrame(bytes)
        let state = self?.browser?.isCaptureActive == true ? "ativo" : "desativado"
        self?.browser?.setStatus("Brave do seu perfil · mouse exclusivo \(state) · experimental")
        if firstFrame {
          report("Brave conectado ao perfil atual · imagem recebida no Dell")
          firstFrame = false
        }
      }
      connection.onStatus = { [weak self] status in
        if status.contains("desconectado") || status.contains("encerrada") {
          self?.mouse.stop()
          self?.browser?.setCaptureActive(false)
          self?.browser?.hideBraveFrame()
        }
        self?.browser?.setStatus(status)
        report(status)
      }
      connection.start()
    } catch { report("Falha ao iniciar Brave: \(error.localizedDescription)") }
  }

  func applicationWillTerminate(_ notification: Notification) {
    brave?.stop()
    mouse.stop()
  }
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

import AppKit

final class BraveConnection {
  var onFrame: ((Data) -> Void)?
  var onStatus: ((String) -> Void)?
  private let process = Process()
  private let token = UUID().uuidString
  private let extensionID =
    ProcessInfo.processInfo.environment["DUO_BRAVE_EXTENSION_ID"]
    ?? "kkpaikgpkehmkicjmaecojgmbagdhmkk"
  private var socket: URLSessionWebSocketTask?
  private let input = Pipe()
  private let output = Pipe()
  private let width: Int
  private let height: Int
  private var stopped = false

  init(resources: URL, width: Int, height: Int) throws {
    self.width = width
    self.height = height
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["node", resources.appendingPathComponent("brave-bridge.cjs").path]
    var environment = ProcessInfo.processInfo.environment
    environment["PATH"] =
      "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin")
    environment["DUO_BRIDGE_TOKEN"] = token
    environment["DUO_BRAVE_EXTENSION_ID"] = extensionID
    process.environment = environment
    process.standardInput = input
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    try process.run()
  }

  func start() {
    output.fileHandleForReading.readabilityHandler = { [weak self] file in
      let bytes = file.availableData
      guard !bytes.isEmpty,
        let message = try? JSONSerialization.jsonObject(with: bytes) as? [String: Int],
        let port = message["port"]
      else { return }
      file.readabilityHandler = nil
      DispatchQueue.main.async { self?.connect(port: port) }
    }
    process.terminationHandler = { [weak self] _ in
      DispatchQueue.main.async {
        guard let self, !self.stopped else { return }
        self.onStatus?("Conexão Brave encerrada. Verifique Node.js e a extensão Duo.")
      }
    }
  }

  private func connect(port: Int) {
    let address = URL(string: "ws://127.0.0.1:\(port)/\(token)/native")!
    socket = URLSession.shared.webSocketTask(with: address)
    socket?.resume()
    receive()
    let link = "chrome-extension://\(extensionID)/popup.html?bridge=\(port)&token=\(token)"
    let owner = NSWorkspace.shared.frontmostApplication
    let script = """
      tell application "Brave Browser"
        set duoWindow to make new window
        set URL of active tab of duoWindow to "\(link)"
      end tell
      """
    var failure: NSDictionary?
    NSAppleScript(source: script)?.executeAndReturnError(&failure)
    owner?.activate(options: [])
    onStatus?(
      failure == nil
        ? "Conectando ao Brave do seu perfil…"
        : "Não foi possível abrir a extensão Duo no Brave: \(failure!)")
  }

  func send(kind: String, x: Double = 0, y: Double = 0, key: Any = "") {
    write(["kind": kind, "x": x, "y": y, "key": key])
  }

  private func write(_ message: [String: Any]) {
    guard let bytes = try? JSONSerialization.data(withJSONObject: message),
      let text = String(data: bytes, encoding: .utf8)
    else { return }
    socket?.send(.string(text)) { _ in }
  }

  private func receive() {
    socket?.receive { [weak self] result in
      DispatchQueue.main.async {
        guard let self, !self.stopped else { return }
        switch result {
        case .success(.string(let text)):
          self.handle(text)
          self.receive()
        case .success:
          self.receive()
        case .failure:
          self.onStatus?("Brave desconectado. Feche e reabra o navegador Duo.")
        }
      }
    }
  }

  private func handle(_ text: String) {
    guard let bytes = text.data(using: .utf8),
      let message = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any]
    else { return }
    if message["kind"] as? String == "ready" {
      write(["kind": "init", "width": width, "height": height, "url": "https://www.youtube.com"])
    }
    if message["kind"] as? String == "frame", let image = message["image"] as? String,
      let data = Data(base64Encoded: image)
    {
      onFrame?(data)
    }
    if message["kind"] as? String == "error", let error = message["message"] as? String {
      onStatus?("Brave: \(error)")
    }
  }

  func stop() {
    stopped = true
    output.fileHandleForReading.readabilityHandler = nil
    socket?.cancel(with: .goingAway, reason: nil)
    try? input.fileHandleForWriting.close()
    if process.isRunning { process.terminate() }
  }

  deinit { stop() }
}

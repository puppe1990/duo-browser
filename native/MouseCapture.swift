import Foundation
import IOKit.hid

final class MouseCapture {
  private let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
  private var device: IOHIDDevice?
  var onValue: ((UInt32, UInt32, Int) -> Void)?

  func start() -> String? {
    guard device == nil else { return nil }
    let match: [String: Int] = [
      kIOHIDVendorIDKey: 0x30fa, kIOHIDProductIDKey: 0x1040,
      kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: 2,
    ]
    IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
    guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
      devices.count == 1, let mouse = devices.first
    else {
      return "Encontrados zero ou múltiplos mouses 30fa:1040; esperado exatamente um."
    }
    // ManagerOpen opens the devices too. A second DeviceOpen does not upgrade
    // a shared link, even when it returns success. Seize on the very first open.
    let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
    guard result == kIOReturnSuccess else {
      IOHIDManagerClose(manager, 0)
      return
        "Captura negada (\(result)). Autorize Duo Native em Privacidade e Segurança → Monitoramento de Entrada e reabra o app."
    }
    device = mouse
    register(mouse)
    return nil
  }

  private func register(_ mouse: IOHIDDevice) {
    let context = Unmanaged.passUnretained(self).toOpaque()
    IOHIDDeviceRegisterInputValueCallback(
      mouse,
      { pointer, _, _, value in
        guard let pointer else { return }
        let capture = Unmanaged<MouseCapture>.fromOpaque(pointer).takeUnretainedValue()
        let element = IOHIDValueGetElement(value)
        if IOHIDElementGetUsagePage(element) == 9 {
          traceSeatEvent(
            "HID button usage=\(IOHIDElementGetUsage(element)) value=\(IOHIDValueGetIntegerValue(value))"
          )
        }
        capture.onValue?(
          IOHIDElementGetUsagePage(element),
          IOHIDElementGetUsage(element), IOHIDValueGetIntegerValue(value))
      }, context)
    IOHIDDeviceScheduleWithRunLoop(mouse, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
  }

  func stop() {
    if let device {
      IOHIDDeviceUnscheduleFromRunLoop(
        device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
    }
    device = nil
    IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
  }

  deinit { stop() }
}

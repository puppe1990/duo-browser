import Foundation
import IOKit.hid

@main
struct ExclusiveProbe {
  static func main() throws {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
    let match: [String: Int] = [
      kIOHIDVendorIDKey: 0x30fa, kIOHIDProductIDKey: 0x1040,
      kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: 2,
    ]
    IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
    guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
      devices.count == 1, let mouse = devices.first
    else {
      fputs("Expected exactly one USB mouse 30fa:1040 for foreign-client probe\n", stderr)
      exit(1)
    }
    let result = IOHIDDeviceOpen(mouse, IOOptionBits(kIOHIDOptionsTypeNone))
    if result == kIOReturnSuccess { IOHIDDeviceClose(mouse, 0) }
    let encoded = try JSONSerialization.data(withJSONObject: [
      "opened": result == kIOReturnSuccess,
      "exclusiveBlocked": result == kIOReturnExclusiveAccess,
      "result": result,
    ])
    print(String(data: encoded, encoding: .utf8)!)
  }
}

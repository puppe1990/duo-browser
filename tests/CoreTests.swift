import Foundation

func expect(_ condition: Bool, _ message: String) {
  guard condition else { fatalError(message) }
}

@main
struct CoreTests {
  static func main() {
    var cursor = SeatCursor(width: 1920, height: 1080)
    cursor.move(dx: -5000, dy: 5000)
    expect(cursor.x == 0 && cursor.y == 1079, "Cursor must remain inside right display")
    cursor.move(dx: 9000, dy: -9000)
    expect(cursor.x == 1919 && cursor.y == 0, "Both cursor axes must clamp")
    expect(isSeatMouse(vendor: 0x30fa, product: 0x1040, page: 1, usage: 2), "USB mouse must match")
    expect(
      !isSeatMouse(vendor: 0x30fa, product: 0x1040, page: 1, usage: 6),
      "Mouse keyboard interface must not match")
    expect(
      !isSeatMouse(vendor: 0, product: 0, page: 1, usage: 2), "Internal trackpad must never match")
    expect(browserURL("example.com")?.absoluteString == "https://example.com", "Host gets https")
    expect(browserURL("javascript:alert(1)") == nil, "Executable URL must be rejected")
    expect(browserURL("file:///etc/passwd") == nil, "Local file navigation must be rejected")
    expect(browserURL("uma busca")?.host == "www.google.com", "Search is encoded")
    print("PASS: cursor bounds, physical mouse isolation and URL validation")
  }
}

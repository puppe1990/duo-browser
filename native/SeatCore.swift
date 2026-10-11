import Foundation

struct SeatCursor {
  var x: Double
  var y: Double
  let width: Double
  let height: Double

  init(width: Double, height: Double) {
    self.width = width
    self.height = height
    x = width / 2
    y = height / 2
  }

  mutating func move(dx: Double, dy: Double) {
    x = min(max(0, x + dx), width - 1)
    y = min(max(0, y + dy), height - 1)
  }
}

func isSeatMouse(vendor: Int, product: Int, page: Int, usage: Int) -> Bool {
  vendor == 0x30fa && product == 0x1040 && page == 1 && usage == 2
}

func browserURL(_ text: String) -> URL? {
  let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !input.isEmpty else { return nil }
  if input.contains(" ") || (!input.contains(".") && !input.contains(":")) {
    var parts = URLComponents(string: "https://www.google.com/search")!
    parts.queryItems = [URLQueryItem(name: "q", value: input)]
    return parts.url
  }
  let candidate = input.contains(":") ? input : "https://" + input
  guard let url = URL(string: candidate),
    ["http", "https"].contains(url.scheme ?? ""), url.host != nil
  else { return nil }
  return url
}

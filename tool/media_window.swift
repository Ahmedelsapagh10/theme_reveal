// Read-only CoreGraphics window metadata; no accessibility inspection.
import Foundation
import CoreGraphics
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
if let window = windows.first(where: { ($0[kCGWindowOwnerName as String] as? String) == "theme_reveal_kit_example" && ($0[kCGWindowLayer as String] as? Int) == 0 }),
   let bounds = window[kCGWindowBounds as String] as? [String: Any] {
    let result: [String: Any] = ["id": window[kCGWindowNumber as String]!, "bounds": bounds]
    let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
    print(String(data: data, encoding: .utf8)!)
} else { exit(2) }

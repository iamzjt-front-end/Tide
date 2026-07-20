import AppKit
import SwiftUI

enum TideFormatting {
  static func clock(_ seconds: Int) -> String {
    let safe = max(0, seconds)
    let hours = safe / 3_600
    let minutes = (safe % 3_600) / 60
    let remaining = safe % 60
    if hours > 0 {
      return String(format: "%02d:%02d:%02d", hours, minutes, remaining)
    }
    return String(format: "%02d:%02d", minutes, remaining)
  }

  static func menuBarTime(_ seconds: Int) -> String {
    let safe = max(0, seconds)
    guard safe >= 3_600 else { return clock(safe) }
    let hours = safe / 3_600
    let minutes = (safe % 3_600) / 60
    return minutes == 0 ? "\(hours)h" : "\(hours)h\(minutes)m"
  }

  static func compactDuration(_ seconds: Int) -> String {
    let minutes = max(0, seconds) / 60
    if minutes < 60 { return "\(minutes) 分钟" }
    let hours = minutes / 60
    let remainder = minutes % 60
    return remainder == 0 ? "\(hours) 小时" : "\(hours) 小时 \(remainder) 分"
  }

  static func dayLabel(_ date: Date, calendar: Calendar = .current) -> String {
    if calendar.isDateInToday(date) { return "今天" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "M/d"
    return formatter.string(from: date)
  }
}

extension Color {
  init(hex: String) {
    let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var number: UInt64 = 0
    Scanner(string: value).scanHexInt64(&number)
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    switch value.count {
    case 8:
      red = Double((number >> 24) & 0xFF) / 255
      green = Double((number >> 16) & 0xFF) / 255
      blue = Double((number >> 8) & 0xFF) / 255
      alpha = Double(number & 0xFF) / 255
    default:
      red = Double((number >> 16) & 0xFF) / 255
      green = Double((number >> 8) & 0xFF) / 255
      blue = Double(number & 0xFF) / 255
      alpha = 1
    }
    self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
  }
}

extension NSColor {
  convenience init(hex: String) {
    let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var number: UInt64 = 0
    Scanner(string: value).scanHexInt64(&number)
    self.init(
      srgbRed: CGFloat((number >> 16) & 0xFF) / 255,
      green: CGFloat((number >> 8) & 0xFF) / 255,
      blue: CGFloat(number & 0xFF) / 255,
      alpha: 1
    )
  }
}

//
//  DailySegments.swift
//  Stan
//
//  Created by Michał Lisicki on 28/11/2025.
//

import Foundation
import SwiftData

@Model
final class DailySegments {
  @Attribute(.unique) var date: Date
  var segmentsCount: Int

  init(date: Date = Calendar.current.startOfDay(for: Date()), segmentsCount: Int = 0) {
    self.date = date
    self.segmentsCount = segmentsCount
  }
}

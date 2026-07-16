//
//  MiscExtensions.swift
//  Stan
//
//  Created by Michał Lisicki on 06/11/2025.
//

import Foundation

extension TimeInterval {
  var asMinutes: Int {
    Int(self / 60)
  }

  init(minutes: Int) {
    self.init(minutes * 60)
  }
}

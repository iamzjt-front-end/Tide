//
//  AppStorageObservables.swift
//  Stan
//
//  Created by Michał Lisicki on 14/11/2025.
//

import SwiftUI

@Observable
final class AppStorageObservables {
  private let storage = Storage()

  final class Storage {
    @AppStorage("menuBarTimer") var menuBarTimer = false
    @AppStorage("stanDuration") var stanDuration = DurationConstants.stanDuration
    @AppStorage("shortBreakDuration") var shortBreakDuration = DurationConstants
      .shortBreakDuration
    @AppStorage("longBreakDuration") var longBreakDuration = DurationConstants
      .longBreakDuration
    @AppStorage("numberOfSegments") var numberOfSegments = DurationConstants.numberOfSegments
  }

  init() {
    self.stanDuration = storage.stanDuration
    self.shortBreakDuration = storage.shortBreakDuration
    self.longBreakDuration = storage.longBreakDuration
    self.numberOfSegments = storage.numberOfSegments
    self.menuBarTimer = storage.menuBarTimer
  }

  var stanDuration: TimeInterval {
    didSet {
      storage.stanDuration = stanDuration
    }
  }

  var shortBreakDuration: TimeInterval {
    didSet {
      storage.shortBreakDuration = shortBreakDuration
    }
  }

  var longBreakDuration: TimeInterval {
    didSet {
      storage.longBreakDuration = longBreakDuration
    }
  }

  var numberOfSegments: Int {
    didSet {
      storage.numberOfSegments = numberOfSegments
    }
  }

  var menuBarTimer: Bool {
    didSet {
      storage.menuBarTimer = menuBarTimer
    }
  }
}

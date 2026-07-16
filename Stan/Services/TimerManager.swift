//
//  TimerManager.swift
//  Stan
//
//  Created by Michał Lisicki on 06/11/2025.
//

import OSLog
import SwiftData
import SwiftUI

@Observable
final class TimerManager {
  private let clock: ClockService = ClockService()
  private var appStorage: AppStorageObservables
  var modelContext: ModelContext?

  // MARK: Segments
  private var storedSegment: Int = 0

  var currentSegment: Int {
    get { storedSegment }
    set {
      storedSegment = newValue % appStorage.numberOfSegments
      totalElapsedTimeOfCurrentSegment = 0
    }
  }

  init(appStorage: AppStorageObservables) {
    self.appStorage = appStorage
  }

  // MARK: - SwiftData

  private func incrementTodaySegments() {
    guard let modelContext else { return }

    let today = Calendar.current.startOfDay(for: Date())
    let descriptor = FetchDescriptor<DailySegments>(
      predicate: #Predicate { $0.date == today }
    )

    do {
      let results = try modelContext.fetch(descriptor)
      if let existing = results.first {
        existing.segmentsCount += 1
      } else {
        let newRecord = DailySegments(date: today, segmentsCount: 1)
        modelContext.insert(newRecord)
      }
      try modelContext.save()
    } catch {
      log.error("Failed to save daily segments: \(error.localizedDescription)")
    }
  }

  private(set) var isBreakActive: Bool = false

  var isLongBreakActive: Bool {
    isBreakActive && currentSegment == appStorage.numberOfSegments - 1
  }

  // MARK: - Time

  private(set) var totalElapsedTimeOfCurrentSegment: TimeInterval = 0

  private(set) var currentStartTime: Date?
  private(set) var targetEndTime: Date?
  var surplus = false

  var durationTimeOfCurrentSegment: TimeInterval {
    let duration: TimeInterval
    switch (isLongBreakActive, isBreakActive) {
    case (true, _): duration = appStorage.longBreakDuration
    case (_, true): duration = appStorage.shortBreakDuration
    default: duration = appStorage.stanDuration
    }
    return duration
  }

  func segmentDurationChanged() {
    guard !clock.isCancelled, !isPaused else { return }

    clock.cancel()

    if surplus {
      targetEndTime = Date()
    } else {
      targetEndTime = Date().addingTimeInterval(remainingTimeOfCurrentSegment)
      clock.start(interval: remainingTimeOfCurrentSegment, closure: clockDidReturned)
    }
  }

  private var liveElapsedTimeOfCurrentSegment: TimeInterval {
    guard let currentStartTime, !isPaused else { return totalElapsedTimeOfCurrentSegment }
    return totalElapsedTimeOfCurrentSegment + Date().timeIntervalSince(currentStartTime)
  }

  var remainingTimeOfCurrentSegment: TimeInterval {
    return max(durationTimeOfCurrentSegment - liveElapsedTimeOfCurrentSegment, 0)
  }

  var elapsedSurplusTime: TimeInterval {
    guard surplus, let targetEndTime else { return 0 }
    return Date().timeIntervalSince(targetEndTime)
  }

  func start() {
    if !clock.isCancelled {
      clock.cancel()
    }

    currentStartTime = .now
    targetEndTime = Date().addingTimeInterval(remainingTimeOfCurrentSegment)

    clock.start(interval: remainingTimeOfCurrentSegment, closure: clockDidReturned)
    isPaused = false
  }

  private func clockDidReturned() {
    NotificationManager.pushNotification(isBreak: isBreakActive)

    withAnimation {
      surplus = true
    }

    clock.cancel()
  }

  private(set) var isPaused = true {
    didSet {
      if isPaused {
        currentStartTime = nil
      }
    }
  }

  func shouldViewBeGreen() -> Bool {
    !isPaused && !isBreakActive
  }

  func pause() {
    guard let currentStartTime, !isPaused else { return }
    totalElapsedTimeOfCurrentSegment += Date().timeIntervalSince(currentStartTime)
    isPaused = true
    clock.cancel()
    targetEndTime = nil
  }

  func reset() {
    clock.cancel()

    currentSegment = 0
    isBreakActive = false
    isPaused = true
  }

  func skipSegment() {
    clock.cancel()
    surplus = false

    if isBreakActive {
      currentSegment += 1
      incrementTodaySegments()
    }

    isBreakActive.toggle()

    if !isPaused {
      start()
    }
  }
}

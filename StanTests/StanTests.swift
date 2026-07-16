//
//  StanTests.swift
//  StanTests
//
//  Created by Michał Lisicki on 06/11/2025.
//

import Foundation
import SwiftData
import Testing

@testable import Stan

// MARK: - TimerManager Tests

@Suite("TimerManager Tests")
struct TimerManagerTests {
  let appStorage = AppStorageObservables()

  @Test("Initial state is paused")
  func initialStateIsPaused() {
    let timerManager = TimerManager(appStorage: appStorage)
    #expect(timerManager.isPaused == true)
    #expect(timerManager.isBreakActive == false)
    #expect(timerManager.currentSegment == 0)
    #expect(timerManager.surplus == false)
  }

  @Test("Start sets isPaused to false")
  func startSetsIsPausedToFalse() {
    let timerManager = TimerManager(appStorage: appStorage)
    timerManager.start()
    #expect(timerManager.isPaused == false)
    #expect(timerManager.targetEndTime != nil)
  }

  @Test("Pause sets isPaused to true")
  func pauseSetsIsPausedToTrue() {
    let timerManager = TimerManager(appStorage: appStorage)
    timerManager.start()
    timerManager.pause()
    #expect(timerManager.isPaused == true)
    #expect(timerManager.targetEndTime == nil)
  }

  @Test("Skip toggles break state")
  func skipTogglesBreakState() {
    let timerManager = TimerManager(appStorage: appStorage)
    #expect(timerManager.isBreakActive == false)
    timerManager.skipSegment()
    #expect(timerManager.isBreakActive == true)
    timerManager.skipSegment()
    #expect(timerManager.isBreakActive == false)
  }

  @Test("Skip from break increments segment")
  func skipFromBreakIncrementsSegment() {
    let timerManager = TimerManager(appStorage: appStorage)
    #expect(timerManager.currentSegment == 0)
    timerManager.skipSegment()  // work -> break
    #expect(timerManager.currentSegment == 0)
    timerManager.skipSegment()  // break -> work
    #expect(timerManager.currentSegment == 1)
  }

  @Test("Segment wraps around after numberOfSegments")
  func segmentWrapsAround() {
    appStorage.numberOfSegments = 2
    let timerManager = TimerManager(appStorage: appStorage)

    timerManager.skipSegment()  // work -> break (segment 0)
    timerManager.skipSegment()  // break -> work (segment 1)
    timerManager.skipSegment()  // work -> break (segment 1)
    timerManager.skipSegment()  // break -> work (segment 0, wrapped)
    #expect(timerManager.currentSegment == 0)
  }

  @Test("Reset restores initial state")
  func resetRestoresInitialState() {
    let timerManager = TimerManager(appStorage: appStorage)
    timerManager.start()
    timerManager.skipSegment()
    timerManager.skipSegment()
    timerManager.reset()

    #expect(timerManager.isPaused == true)
    #expect(timerManager.isBreakActive == false)
    #expect(timerManager.currentSegment == 0)
  }

  @Test("Duration returns correct value for each state")
  func durationReturnsCorrectValue() {
    appStorage.stanDuration = 100
    appStorage.shortBreakDuration = 50
    appStorage.longBreakDuration = 200
    appStorage.numberOfSegments = 2
    let timerManager = TimerManager(appStorage: appStorage)

    #expect(timerManager.durationTimeOfCurrentSegment == 100)  // work

    timerManager.skipSegment()  // -> break (not long break yet)
    #expect(timerManager.durationTimeOfCurrentSegment == 50)

    timerManager.skipSegment()  // -> work segment 1
    timerManager.skipSegment()  // -> long break (last segment)
    #expect(timerManager.isLongBreakActive == true)
    #expect(timerManager.durationTimeOfCurrentSegment == 200)
  }

  @Test("shouldViewBeGreen returns true when running and not on break")
  func shouldViewBeGreenLogic() {
    let timerManager = TimerManager(appStorage: appStorage)

    #expect(timerManager.shouldViewBeGreen() == false)  // paused

    timerManager.start()
    #expect(timerManager.shouldViewBeGreen() == true)  // running, not break

    timerManager.skipSegment()
    #expect(timerManager.shouldViewBeGreen() == false)  // running, but on break
  }
}

// MARK: - TimeInterval Extension Tests

@Suite("TimeInterval Extension Tests")
struct TimeIntervalExtensionTests {
  @Test("asMinutes converts correctly")
  func asMinutesConvertsCorrectly() {
    #expect(TimeInterval(60).asMinutes == 1)
    #expect(TimeInterval(120).asMinutes == 2)
    #expect(TimeInterval(90).asMinutes == 1)  // truncates
    #expect(TimeInterval(0).asMinutes == 0)
  }

  @Test("init(minutes:) converts correctly")
  func initMinutesConvertsCorrectly() {
    #expect(TimeInterval(minutes: 1) == 60)
    #expect(TimeInterval(minutes: 5) == 300)
    #expect(TimeInterval(minutes: 0) == 0)
  }
}

// MARK: - DailySegments Tests

@Suite("DailySegments Model Tests")
struct DailySegmentsTests {
  @Test("DailySegments initializes with defaults")
  func dailySegmentsInitializesWithDefaults() {
    let segments = DailySegments()
    let today = Calendar.current.startOfDay(for: Date())

    #expect(segments.segmentsCount == 0)
    #expect(Calendar.current.isDate(segments.date, inSameDayAs: today))
  }

  @Test("DailySegments initializes with custom values")
  func dailySegmentsInitializesWithCustomValues() {
    let customDate = Calendar.current.startOfDay(for: Date())
    let segments = DailySegments(date: customDate, segmentsCount: 5)

    #expect(segments.segmentsCount == 5)
    #expect(segments.date == customDate)
  }

  @Test("DailySegments can be modified")
  func dailySegmentsCanBeModified() {
    let segments = DailySegments()
    segments.segmentsCount = 10
    #expect(segments.segmentsCount == 10)
  }
}

// MARK: - SwiftData Integration Tests

@Suite("SwiftData Integration Tests")
struct SwiftDataIntegrationTests {
  @Test("Can save and fetch DailySegments")
  func canSaveAndFetchDailySegments() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: DailySegments.self, configurations: config)
    let context = container.mainContext

    let today = Calendar.current.startOfDay(for: Date())
    let segments = DailySegments(date: today, segmentsCount: 3)
    context.insert(segments)
    try context.save()

    let descriptor = FetchDescriptor<DailySegments>()
    let results = try context.fetch(descriptor)

    #expect(results.count == 1)
    #expect(results.first?.segmentsCount == 3)
  }

  @Test("Can update existing DailySegments")
  func canUpdateExistingDailySegments() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: DailySegments.self, configurations: config)
    let context = container.mainContext

    let segments = DailySegments(segmentsCount: 1)
    context.insert(segments)
    try context.save()

    segments.segmentsCount += 1
    try context.save()

    let descriptor = FetchDescriptor<DailySegments>()
    let results = try context.fetch(descriptor)

    #expect(results.first?.segmentsCount == 2)
  }

  @Test("TimerManager increments segments correctly")
  func timerManagerIncrementsSegments() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: DailySegments.self, configurations: config)
    let context = container.mainContext

    let appStorage = AppStorageObservables()
    let timerManager = TimerManager(appStorage: appStorage)
    timerManager.modelContext = context

    // Skip from work to break should increment
    timerManager.skipSegment()

    let descriptor = FetchDescriptor<DailySegments>()
    let results = try context.fetch(descriptor)

    #expect(results.count == 1)
    #expect(results.first?.segmentsCount == 1)

    // Skip from break to work should not increment
    timerManager.skipSegment()
    let results2 = try context.fetch(descriptor)
    #expect(results2.first?.segmentsCount == 1)

    // Skip from work to break again should increment
    timerManager.skipSegment()
    let results3 = try context.fetch(descriptor)
    #expect(results3.first?.segmentsCount == 2)
  }
}

// MARK: - ClockService Tests

@Suite("ClockService Tests")
struct ClockServiceTests {
  @Test("ClockService starts not cancelled")
  func clockServiceStartsNotCancelled() {
    let clock = ClockService()
    #expect(clock.isCancelled == false)
  }

  @Test("ClockService cancel sets task to nil")
  func clockServiceCancelSetsTaskToNil() {
    let clock = ClockService()
    #expect(clock.isCancelled == true)
    clock.start(interval: 10) {}
    #expect(clock.isCancelled == false)  // running task is not cancelled
    clock.cancel()
    #expect(clock.isCancelled == true)
  }

  @Test("ClockService executes closure after interval")
  func clockServiceExecutesClosure() async throws {
    let clock = ClockService()
    var executed = false

    clock.start(interval: 0.1) {
      executed = true
    }

    try await Task.sleep(for: .milliseconds(200))
    #expect(executed == true)
  }

  @Test("ClockService does not execute if cancelled")
  func clockServiceDoesNotExecuteIfCancelled() async throws {
    let clock = ClockService()
    var executed = false

    clock.start(interval: 0.2) {
      executed = true
    }

    clock.cancel()
    try await Task.sleep(for: .milliseconds(300))
    #expect(executed == false)
  }
}

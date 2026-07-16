//
//  TimerDisplayManager.swift
//  Stan
//
//  Created by Michał Lisicki on 27/11/2025.
//

import Foundation

@Observable
final class TimerDisplayManager {
  var currentTimeToDisplay: String = ""

  private var updateTask: Task<Void, Never>?
  private let timerManager: TimerManager
  private let appStorage: AppStorageObservables

  init(timerManager: TimerManager, appStorage: AppStorageObservables) {
    self.timerManager = timerManager
    self.appStorage = appStorage
  }

  private func formatTime(time: TimeInterval) -> String {
    Duration(
      secondsComponent: Int64(time),
      attosecondsComponent: 0
    ).formatted(.time(pattern: .minuteSecond))
  }

  func viewAppeared() {
    updateDisplayTime()
    if !timerManager.isPaused {
      startDisplayUpdate()
    }
  }

  func viewDisappeared() {
    guard !appStorage.menuBarTimer else {
      return
    }
    updateTask?.cancel()
  }

  func updateDisplayTime() {
    currentTimeToDisplay = formatTime(
      time: timerManager.surplus
        ? timerManager.elapsedSurplusTime : timerManager.remainingTimeOfCurrentSegment)
  }

  func onPausedChanged(_ newValue: Bool) {
    if !newValue {
      startDisplayUpdate()
    } else {
      updateTask?.cancel()
    }
  }

  private func startDisplayUpdate() {
    updateTask = Task {
      let clock = ContinuousClock()
      updateDisplayTime()
      repeat {
        do {
          try await clock.sleep(for: .seconds(0.5), tolerance: .seconds(0.025))
          updateDisplayTime()
        } catch {
          break
        }
      } while !Task.isCancelled
    }
  }
}

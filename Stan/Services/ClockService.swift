//
//  TimerService.swift
//  Stan
//
//  Created by Michał Lisicki on 06/11/2025.
//

import Foundation
import OSLog

final class ClockService {
  private var task: Task<Void, Never>?

  var isCancelled: Bool {
    guard let task else { return true }
    return task.isCancelled
  }

  func start(interval: TimeInterval, closure: @escaping () -> Void) {
    self.task = Task {
      let clock = ContinuousClock()
      do {
        try await clock.sleep(
          until: .now + .seconds(interval), tolerance: .seconds(interval * 0.05))

        try Task.checkCancellation()

        closure()
      } catch {
        if error is CancellationError {
          log.info("Timer is cancelled")
        }
      }
    }
  }

  func cancel() {
    task?.cancel()
    task = nil
  }
}

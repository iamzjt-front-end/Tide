//
//  StanApp.swift
//  Stan
//
//  Created by Michał Lisicki on 06/11/2025.
//

import OSLog
import SwiftData
import SwiftUI

let log = Logger()

@main
struct StanApp: App {
  @State private var timerManager: TimerManager
  @State private var displayTimerManager: TimerDisplayManager
  @State var isInserted: Bool = true
  @State private var appStorage: AppStorageObservables

  init() {
    let _appStorage = AppStorageObservables()
    let timerManager = TimerManager(appStorage: _appStorage)
    self.timerManager = timerManager
    timerManager.modelContext = sharedModelContainer.mainContext
    displayTimerManager = TimerDisplayManager(timerManager: timerManager, appStorage: _appStorage)
    appStorage = _appStorage
  }

  var sharedModelContainer: ModelContainer = {
    let schema = Schema([DailySegments.self])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    MenuBarExtra(isInserted: $isInserted) {
      TimerView()
        .environment(timerManager)
        .environment(displayTimerManager)
        .environment(appStorage)
        .modelContainer(sharedModelContainer)
    } label: {
      if timerManager.isBreakActive {
        if timerManager.isPaused {
          menuBarTimer
          Image(systemName: "timer.circle").symbolRenderingMode(.palette).foregroundStyle(
            Color.green)
        } else if timerManager.surplus {
          menuBarTimer
          Image(systemName: "timer.circle.fill").symbolRenderingMode(.palette).foregroundStyle(
            Color.green, Color.black)
        } else {
          menuBarTimer
          Image(systemName: "timer.circle.fill").symbolRenderingMode(.palette).foregroundStyle(
            Color.green)
        }
      } else {
        if timerManager.isPaused {
          menuBarTimer
          Image(systemName: "timer.circle").symbolRenderingMode(.hierarchical)
        } else if timerManager.surplus {
          menuBarTimer
          Image(systemName: "timer.circle.fill").foregroundStyle(Color.white, Color.black)
        } else {
          menuBarTimer
          Image(systemName: "timer.circle.fill").symbolRenderingMode(.hierarchical)
        }
      }
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsView()
        .environment(appStorage)
        //TODO: - rework trivial approach
        .onChange(of: appStorage.menuBarTimer) { _, newValue in
          if newValue == false {
            displayTimerManager.viewDisappeared()
          } else {
            displayTimerManager.viewAppeared()
          }
        }
    }

  }

  @ViewBuilder
  var menuBarTimer: some View {
    if appStorage.menuBarTimer {
      Text(displayTimerManager.currentTimeToDisplay)
    }
  }
}

//
//  SettingsView.swift
//  Stan
//
//  Created by Michał Lisicki on 06/11/2025.
//

import SwiftUI

struct SettingsView: View {
  var body: some View {
    TabView {
      Tab("General", systemImage: "gear") {
        GeneralSettingsView()
          .frame(maxWidth: 350, minHeight: 70)
      }
      Tab("Durations", systemImage: "hourglass") {
        DurationsSettingsView()
          .frame(maxWidth: 350, minHeight: 100)
      }
    }
    .scenePadding()
  }
}

struct DurationConstants {
  static let stanDuration = TimeInterval(25)
  static let shortBreakDuration = TimeInterval(minutes: 5)
  static let longBreakDuration = TimeInterval(minutes: 30)
  static let numberOfSegments = 4
}

struct GeneralSettingsView: View {
  //@AppStorage("timerTransition") private var timerTransition = false
  @Environment(AppStorageObservables.self) var appStorage

  var body: some View {
    @Bindable var appStorage = appStorage

    Form {
      //Toggle("Timer Transition Animation", isOn: $timerTransition)
      Toggle("Timer always on in menu bar", isOn: $appStorage.menuBarTimer)
    }
  }
}

struct DurationsSettingsView: View {
  @Environment(AppStorageObservables.self) var appStorage

  var body: some View {
    @Bindable var appStorage = appStorage

    Form {
      Picker("Number of Stan's:", selection: $appStorage.numberOfSegments) {
        ForEach(1...4, id: \.self) { value in
          Text("\(value)")
        }
      }

      Picker("Stan Duration:", selection: $appStorage.stanDuration) {
        ForEach(Array(stride(from: 25, through: 150, by: 25)), id: \.self) { value in
          Text("\(value) minutes").tag(TimeInterval(minutes: value))
        }
      }

      Picker("Short Break Time:", selection: $appStorage.shortBreakDuration) {
        ForEach(Array(stride(from: 5, through: 15, by: 5)), id: \.self) { value in
          Text("\(value) minutes").tag(TimeInterval(minutes: value))
        }
      }

      Picker("Long Break Time:", selection: $appStorage.longBreakDuration) {
        ForEach(Array(stride(from: 15, through: 60, by: 15)), id: \.self) { value in
          Text("\(value) minutes").tag(TimeInterval(minutes: value))
        }
      }
    }
  }
}

#Preview {
  SettingsView()
}

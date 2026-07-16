//
//  TimerView.swift
//  Stan
//
//  Created by Michał Lisicki on 06/11/2025.
//

import SwiftUI

struct TimerView: View {
  @Environment(TimerManager.self) var timerManager
  @Environment(AppStorageObservables.self) var appStorage
  @Environment(TimerDisplayManager.self) var displayTimerManager
  @State private var showStats = false

  var body: some View {
    ZStack {
      GradientBackground().ignoresSafeArea()
      VStack {
        Group {
          HStack {
            Spacer()

            Button {
              NSApplication.shared.terminate(nil)
            } label: {
              Text("Quit")
                .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
          }
          .padding([.horizontal])

          segmentView()
            .padding()
            .frame(maxWidth: 100)
            .frame(height: 50)

          Group {
            if timerManager.isBreakActive {
              Text("Break")
            } else if timerManager.surplus {
              Text("Surplus")
            } else {
              Text("Segment")
            }
          }
          .font(.title3)
          .fontWeight(.medium)
          .fontWidth(.expanded)

          HStack {
            if timerManager.surplus {
              Text("+")
            }
            Text(displayTimerManager.currentTimeToDisplay)
              .monospacedDigit()
              .transition(.identity)
          }
          .font(.system(size: 48))

          HStack(spacing: 17) {
            if timerManager.isPaused {
              Button("Start") {
                withAnimation {
                  timerManager.start()
                }
              }
              .keyboardShortcut(KeyEquivalent(" "))
            } else if !timerManager.surplus {
              Button("Pause") {
                withAnimation {
                  timerManager.pause()
                }
              }
              .keyboardShortcut(KeyEquivalent(" "))
            }
            Button(timerManager.surplus ? "Next" : "Skip") {
              withAnimation {
                timerManager.skipSegment()
                displayTimerManager.updateDisplayTime()
              }
            }
          }

          HStack(spacing: 16) {
            Button {
              withAnimation {
                showStats.toggle()
              }
            } label: {
              Label("Stats", systemImage: "chart.bar.fill")
                .font(.caption)
            }
            .buttonStyle(.plain)

            SettingsLink {
              Label("Settings", systemImage: "gear")
                .font(.caption)
            }
            .buttonStyle(.plain)
          }
          .padding()
          .foregroundStyle(.secondary)
        }
        .animation(nil, value: showStats)

        if showStats {
          StatsView()
            .transition(.scale)
        }
      }
      .padding()
      .onAppear {
        displayTimerManager.viewAppeared()
      }
      .onDisappear {
        displayTimerManager.viewDisappeared()
      }
      .onChange(of: timerManager.isPaused) { _, newValue in
        displayTimerManager.onPausedChanged(newValue)
      }
      .onChange(of: appStorage.stanDuration) { _, _ in
        timerManager.segmentDurationChanged()
      }
      .onChange(of: appStorage.longBreakDuration) { _, _ in
        timerManager.segmentDurationChanged()
      }
      .onChange(of: appStorage.shortBreakDuration) { _, _ in
        timerManager.segmentDurationChanged()
      }
    }
  }

  @Namespace var segments

  func segmentView() -> some View {
    HStack {
      ForEach(0..<appStorage.numberOfSegments, id: \.self) { index in
        if timerManager.currentSegment == index && !timerManager.isPaused {
          RoundedRectangle(cornerRadius: CGFloat(5), style: .circular).fill(
            timerManager.isBreakActive ? Color.green : Color("BorderCircles")
          ).matchedGeometryEffect(id: "rounded", in: segments)
            .transition(.scale)
        } else {
          Circle().fill(index <= timerManager.currentSegment ? Color("BorderCircles") : .clear)
            .strokeBorder(Color("BorderCircles"), lineWidth: 2)
            .transition(.scale)
        }
      }
    }
  }
}

#Preview {
  @State var appStorage = AppStorageObservables()
  @State var timerManager = TimerManager(appStorage: appStorage)
  @State var displayTimerManager = TimerDisplayManager(
    timerManager: timerManager, appStorage: appStorage)

  TimerView()
    .environment(timerManager)
    .environment(displayTimerManager)
    .environment(appStorage)
  //    .frame(height: 500)
}

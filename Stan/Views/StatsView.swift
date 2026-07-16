//
//  StatsView.swift
//  Stan
//
//  Created by Michał Lisicki on 28/11/2025.
//

import Charts
import SwiftData
import SwiftUI

struct StatsView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \DailySegments.date) private var allSegments: [DailySegments]
  @State private var weekOffset = 0
  @State private var editValue = ""

  @Environment(\.colorScheme) private var colorScheme

  private var currentWeekDays: [DailySegments] {
    let calendar = Calendar.autoupdatingCurrent
    let today = calendar.startOfDay(for: Date())
    let weekEnd = calendar.date(byAdding: .day, value: -7 * weekOffset, to: today)!
    let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd)!

    let existingData = allSegments.filter { $0.date >= weekStart && $0.date <= weekEnd }

    var result: [DailySegments] = []
    for dayOffset in (0..<7) {
      let date = calendar.date(byAdding: .day, value: -dayOffset, to: weekEnd)!
      if let existing = existingData.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
        result.append(existing)
      } else {
        result.append(DailySegments(date: date, segmentsCount: 0))
      }
    }
    return result
  }

  private var totalSegments: Int {
    allSegments.reduce(0) { $0 + $1.segmentsCount }
  }

  private var weekTotal: Int {
    currentWeekDays.reduce(0) { $0 + $1.segmentsCount }
  }

  private var weekLabel: String {
    if weekOffset == 0 {
      return "This Week"
    } else if weekOffset == 1 {
      return "Last Week"
    } else {
      return "\(weekOffset) Weeks Ago"
    }
  }

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Button {
          weekOffset += 1
        } label: {
          Image(systemName: "chevron.left")
        }
        .buttonStyle(.plain)

        Spacer()

        Text(weekLabel)
          .font(.subheadline)
          .fontWeight(.medium)

        Spacer()

        Button {
          weekOffset -= 1
        } label: {
          Image(systemName: "chevron.right")
        }
        .buttonStyle(.plain)
        .disabled(weekOffset == 0)
      }

      Chart(currentWeekDays, id: \.date) { segment in
        BarMark(
          x: .value("Day", segment.date, unit: .day),
          y: .value("Segments", segment.segmentsCount)
        )
        .foregroundStyle(
          colorScheme == .dark ? .pink : .green
        )
        .cornerRadius(6)
      }
      .frame(height: 101)
      .chartXAxis {
        AxisMarks(values: .stride(by: .day)) { value in
          AxisValueLabel(format: .dateTime.weekday(.narrow))
            .font(.caption2)
        }
      }
      .chartYAxis {
        AxisMarks(position: .leading) { value in
          AxisValueLabel()
            .font(.caption2)
        }
      }
      .padding()
    }

    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text("Shown Week")
          .font(.caption2)
          .foregroundStyle(.secondary)
        Text("\(weekTotal)")
          .font(.title3)
          .fontWeight(.semibold)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 2) {
        Text("All Time")
          .font(.caption2)
          .foregroundStyle(.secondary)
        Text("\(totalSegments)")
          .font(.title3)
          .fontWeight(.semibold)
      }
    }
    .padding(.top, 4)
  }
}

#Preview {
  let container = try! ModelContainer(
    for: DailySegments.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
  )
  let calendar = Calendar.current
  let today = calendar.startOfDay(for: Date())

  for dayOffset in 0..<21 {
    let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
    let segments = DailySegments(date: date, segmentsCount: Int.random(in: 0...12))
    container.mainContext.insert(segments)
  }

  return StatsView()
    .modelContainer(container)
}

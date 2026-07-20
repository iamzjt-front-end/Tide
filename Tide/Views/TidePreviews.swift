#if DEBUG
import SwiftUI

@MainActor
private enum TidePreviewFactory {
  static let now = Date(timeIntervalSince1970: 1_800_000_000)

  static func controller(
    state: TimerRunState = .idle,
    withHistory: Bool = false,
    appearance: TideAppearance = .system
  ) -> PomodoroController {
    var archive = PomodoroArchive.fresh(now: now)
    let tag = FocusTag(name: "学习", colorHex: "#4DABF7")
    archive.focusTags = [tag, FocusTag(name: "写作", colorHex: "#F783AC")]
    archive.configuration.selectedTagID = tag.id
    archive.configuration.focusMinutes = 25
    archive.configuration.targetSessions = 4
    archive.configuration.breakSeconds = 300
    archive.configuration.appearance = appearance
    archive.snapshot.phaseDurationSeconds = 1_500
    archive.snapshot.remainingSeconds = state == .idle ? 1_500 : 1_037
    archive.snapshot.runState = state
    archive.snapshot.completedSessions = state == .idle ? 0 : 2
    if state != .idle {
      archive.snapshot.activeRunID = UUID()
      archive.snapshot.startedAt = now.addingTimeInterval(-463)
      archive.snapshot.lockedTagID = tag.id
      archive.snapshot.lockedTagName = tag.name
      archive.snapshot.lockedTagColorHex = tag.colorHex
    }
    if state == .running {
      archive.snapshot.deadline = now.addingTimeInterval(1_037)
    }
    if withHistory {
      archive.sessions = (0..<12).map { offset in
        let end = Calendar.current.date(byAdding: .day, value: -offset, to: now) ?? now
        return FocusSession(
          runID: UUID(),
          startedAt: end.addingTimeInterval(-1_500),
          endedAt: end,
          durationSeconds: offset.isMultiple(of: 3) ? 3_000 : 1_500,
          plannedSeconds: 1_500,
          outcome: offset == 4 ? .completedEarly : .completed,
          tagID: tag.id,
          tagName: offset.isMultiple(of: 2) ? "学习" : "写作",
          tagColorHex: offset.isMultiple(of: 2) ? "#4DABF7" : "#F783AC"
        )
      }
    }
    return PomodoroController(
      persistence: InMemoryPomodoroPersistence(archive: archive),
      notifier: SilentPomodoroNotifier(),
      soundPlayer: SilentPomodoroSoundPlayer(),
      initialNow: now
    )
  }

  static func presentation(page: TidePage = .timer) -> TidePresentationState {
    let presentation = TidePresentationState()
    presentation.page = page
    return presentation
  }
}

#Preview("番茄钟 · 待开始") {
  TidePopoverRoot(
    controller: TidePreviewFactory.controller(),
    presentation: TidePreviewFactory.presentation()
  )
}

#Preview("番茄钟 · 进行中") {
  TidePopoverRoot(
    controller: TidePreviewFactory.controller(state: .running, withHistory: true),
    presentation: TidePreviewFactory.presentation()
  )
}

#Preview("番茄钟 · 已暂停") {
  TidePopoverRoot(
    controller: TidePreviewFactory.controller(state: .paused),
    presentation: TidePreviewFactory.presentation()
  )
}

#Preview("统计 · 空数据") {
  TidePopoverRoot(
    controller: TidePreviewFactory.controller(),
    presentation: TidePreviewFactory.presentation(page: .statistics)
  )
}

#Preview("统计 · 有数据") {
  TidePopoverRoot(
    controller: TidePreviewFactory.controller(withHistory: true),
    presentation: TidePreviewFactory.presentation(page: .statistics)
  )
}

#Preview("设置") {
  ZStack {
    ClipoBackground()
    ClipoSettingsPage(controller: TidePreviewFactory.controller(withHistory: true))
  }
  .frame(width: 380, height: 530)
}

#Preview("停止确认") {
  ClipoConfirmationPopover(
    title: "停止专注",
    message: "当前实际专注时长会保存为一次提前完成，并计入本轮。",
    confirmTitle: "完成并停止",
    destructive: true,
    onCancel: {},
    onConfirm: {}
  )
  .frame(width: 420, height: 250)
  .background(ClipoBackground())
}

#Preview("高对比度") {
  TidePopoverRoot(
    controller: TidePreviewFactory.controller(state: .paused, withHistory: true),
    presentation: TidePreviewFactory.presentation()
  )
  .environment(\._colorSchemeContrast, .increased)
}

#Preview("浅色 Liquid Glass") {
  TidePopoverRoot(
    controller: TidePreviewFactory.controller(withHistory: true, appearance: .light),
    presentation: TidePreviewFactory.presentation()
  )
  .preferredColorScheme(.light)
}

#Preview("深色 Liquid Glass") {
  TidePopoverRoot(
    controller: TidePreviewFactory.controller(withHistory: true, appearance: .dark),
    presentation: TidePreviewFactory.presentation()
  )
  .preferredColorScheme(.dark)
}
#endif

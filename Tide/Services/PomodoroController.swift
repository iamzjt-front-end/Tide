import Foundation
import Observation

struct TideBanner: Identifiable, Equatable {
  enum Kind: Equatable {
    case success
    case info
  }

  var id = UUID()
  var text: String
  var kind: Kind
}

@MainActor
@Observable
final class PomodoroController {
  private(set) var archive: PomodoroArchive
  private(set) var currentTime: Date
  private(set) var banner: TideBanner?
  private(set) var persistentError: String?
  private(set) var notificationAuthorization: PomodoroNotificationAuthorization = .unknown

  @ObservationIgnored private let persistence: PomodoroPersisting
  @ObservationIgnored private let notifier: PomodoroNotifying
  @ObservationIgnored private let soundPlayer: PomodoroSounding
  @ObservationIgnored private var canPersist = true
  @ObservationIgnored private var monitorTask: Task<Void, Never>?
  @ObservationIgnored private var notificationAuthorizationTask: Task<Bool, Never>?

  init(
    persistence: PomodoroPersisting,
    notifier: PomodoroNotifying,
    soundPlayer: PomodoroSounding,
    initialNow: Date = .now
  ) {
    self.persistence = persistence
    self.notifier = notifier
    self.soundPlayer = soundPlayer
    currentTime = initialNow
    do {
      if let stored = try persistence.load() {
        archive = stored
      } else {
        archive = .fresh(now: initialNow)
        try persistence.save(archive)
      }
    } catch {
      archive = .fresh(now: initialNow)
      persistentError = "无法读取本地番茄钟数据。原数据未被覆盖：\(error.localizedDescription)"
      canPersist = false
    }
    let repairedSelection = ensureSelectionIntegrity()
    normalizeIdleSnapshot()
    reconcile(at: initialNow)
    if repairedSelection { persist() }
  }

  convenience init() {
    self.init(
      persistence: UserDefaultsPomodoroPersistence(),
      notifier: SystemPomodoroNotifier(),
      soundPlayer: SystemPomodoroSoundPlayer()
    )
  }

  var configuration: PomodoroConfiguration { archive.configuration }
  var snapshot: TimerSnapshot { archive.snapshot }
  var focusTags: [FocusTag] { archive.focusTags }
  var categories: [PomodoroCategory] { archive.categories }
  var sessions: [FocusSession] { archive.sessions }
  var roundRecords: [PomodoroRoundRecord] { archive.roundRecords }

  var displaySeconds: Int {
    switch archive.snapshot.timerMode {
    case .stopwatch:
      if archive.snapshot.runState == .running,
         let anchor = archive.snapshot.stopwatchAnchor {
        return max(0, Int(currentTime.timeIntervalSince(anchor).rounded(.down)))
      }
      return max(0, archive.snapshot.elapsedSeconds)
    case .pomodoro:
      if archive.snapshot.runState == .running,
         let deadline = archive.snapshot.deadline {
        return max(0, Int(deadline.timeIntervalSince(currentTime).rounded(.up)))
      }
      return max(0, archive.snapshot.remainingSeconds)
    }
  }

  var formattedTime: String { TideFormatting.clock(displaySeconds) }
  var menuBarTime: String { TideFormatting.menuBarTime(displaySeconds) }

  var menuBarSymbol: String {
    if archive.snapshot.runState == .paused { return "pause.circle.fill" }
    if archive.snapshot.timerMode == .stopwatch { return "stopwatch" }
    return archive.snapshot.phase.symbolName
  }

  var progress: Double {
    guard archive.snapshot.timerMode == .pomodoro,
          archive.snapshot.phaseDurationSeconds > 0
    else { return 0 }
    return min(1, max(0, 1 - Double(displaySeconds) / Double(archive.snapshot.phaseDurationSeconds)))
  }

  var selectedTag: FocusTag? {
    archive.focusTags.first { $0.id == archive.configuration.selectedTagID }
  }

  var selectedCategory: PomodoroCategory? {
    archive.categories.first { $0.id == archive.configuration.selectedCategoryID }
  }

  var selectedFocusLabelName: String? {
    selectedTag?.name ?? selectedCategory?.name
  }

  var selectedFocusLabelColorHex: String? {
    selectedTag?.colorHex ?? selectedCategory?.colorHex
  }

  var lockedContextText: String {
    let category = archive.snapshot.lockedCategoryName
    let tag = archive.snapshot.lockedTagName
    return switch (category, tag) {
    case let (.some(category), .some(tag)): "\(category) · \(tag)"
    case let (.some(category), .none): category
    case let (.none, .some(tag)): tag
    case (.none, .none): "未使用标签"
    }
  }

  var currentAccentHex: String {
    if archive.snapshot.phase == .breakTime { return "#69DB7C" }
    if archive.snapshot.runState != .idle,
       let locked = archive.snapshot.lockedTagColorHex ?? archive.snapshot.lockedCategoryColorHex {
      return locked
    }
    return selectedTag?.colorHex ?? selectedCategory?.colorHex ?? "#FF6B6B"
  }

  func statistics(for period: StatisticsPeriod) -> PomodoroStatisticsSnapshot {
    PomodoroStatistics.snapshot(
      sessions: archive.sessions,
      period: period,
      now: currentTime
    )
  }

  func tick(at now: Date = .now) {
    reconcile(at: now)
  }

  func startMonitoring() {
    guard monitorTask == nil else { return }
    monitorTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        self?.reconcile(at: .now)
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  func reconcile(at now: Date = .now) {
    currentTime = now
    guard archive.snapshot.timerMode == .pomodoro,
          archive.snapshot.runState == .running
    else { return }

    var safetyCounter = 0
    while archive.snapshot.runState == .running,
          let deadline = archive.snapshot.deadline,
          deadline <= now,
          safetyCounter < 100 {
      completeCurrentPhase(at: deadline)
      safetyCounter += 1
    }
  }

  func setTimerMode(_ mode: TimerMode, at now: Date = .now) {
    guard archive.snapshot.runState == .idle,
          archive.snapshot.timerMode != mode
    else { return }
    archive.snapshot.timerMode = mode
    archive.snapshot.isShowingCompletion = false
    archive.snapshot.elapsedSeconds = 0
    archive.snapshot.stopwatchAnchor = nil
    if mode == .pomodoro {
      archive.snapshot.phase = .focus
      archive.snapshot.phaseDurationSeconds = archive.configuration.focusMinutes * 60
      archive.snapshot.remainingSeconds = archive.snapshot.phaseDurationSeconds
    }
    archive.snapshot.lastUpdatedAt = now
    persist()
  }

  func start(at now: Date = .now) {
    guard archive.snapshot.runState == .idle else { return }
    currentTime = now
    if archive.snapshot.timerMode == .stopwatch {
      archive.snapshot.runState = .running
      archive.snapshot.stopwatchAnchor = now.addingTimeInterval(-Double(archive.snapshot.elapsedSeconds))
      archive.snapshot.lastUpdatedAt = now
      show("正计时已开始", kind: .success)
      persist()
      return
    }

    if archive.snapshot.isShowingCompletion {
      archive.snapshot.completedSessions = 0
      archive.snapshot.roundStartedAt = nil
      archive.snapshot.isShowingCompletion = false
    }
    startFocus(at: now, feedback: true)
  }

  func pause(at now: Date = .now) {
    guard archive.snapshot.runState == .running else { return }
    currentTime = now
    if archive.snapshot.timerMode == .stopwatch {
      if let anchor = archive.snapshot.stopwatchAnchor {
        archive.snapshot.elapsedSeconds = max(0, Int(now.timeIntervalSince(anchor).rounded(.down)))
      }
      archive.snapshot.stopwatchAnchor = nil
    } else {
      guard let deadline = archive.snapshot.deadline else { return }
      archive.snapshot.remainingSeconds = max(0, Int(deadline.timeIntervalSince(now).rounded(.up)))
      archive.snapshot.deadline = nil
      cancelActiveNotification()
    }
    archive.snapshot.runState = .paused
    archive.snapshot.lastUpdatedAt = now
    show("已暂停", kind: .info)
    persist()
  }

  func resume(at now: Date = .now) {
    guard archive.snapshot.runState == .paused else { return }
    currentTime = now
    archive.snapshot.runState = .running
    if archive.snapshot.timerMode == .stopwatch {
      archive.snapshot.stopwatchAnchor = now.addingTimeInterval(-Double(archive.snapshot.elapsedSeconds))
    } else {
      archive.snapshot.deadline = now.addingTimeInterval(Double(archive.snapshot.remainingSeconds))
      scheduleActiveNotification()
    }
    archive.snapshot.lastUpdatedAt = now
    show("已继续", kind: .success)
    persist()
  }

  func stop(at now: Date = .now) {
    guard archive.snapshot.runState != .idle else { return }
    currentTime = now
    if archive.snapshot.timerMode == .stopwatch {
      archive.snapshot.runState = .idle
      archive.snapshot.elapsedSeconds = 0
      archive.snapshot.stopwatchAnchor = nil
      archive.snapshot.lastUpdatedAt = now
      show("正计时已重置", kind: .info)
      persist()
      return
    }

    cancelActiveNotification()
    if archive.snapshot.phase == .focus {
      let focusedSeconds = elapsedInCurrentPhase(at: now)
      let didRecord = appendFocusSession(outcome: .completedEarly, endedAt: now)
      if didRecord {
        archive.snapshot.completedSessions += 1
      }
      let completedRound = archive.snapshot.completedSessions >= archive.configuration.targetSessions
      if completedRound, let roundStartedAt = archive.snapshot.roundStartedAt {
        archive.roundRecords.append(PomodoroRoundRecord(
          startedAt: roundStartedAt,
          endedAt: now,
          completedSessions: archive.snapshot.completedSessions,
          targetSessions: archive.configuration.targetSessions,
          outcome: completionOutcomeForRound(startedAt: roundStartedAt)
        ))
      }
      prepareIdleFocus(at: now, showingCompletion: completedRound)
      show(
        "已完成本次专注，记录 \(TideFormatting.compactDuration(focusedSeconds))",
        kind: .success
      )
    } else {
      prepareIdleFocus(at: now, showingCompletion: false)
      show("休息已结束", kind: .info)
    }
    persist()
  }

  func resetStopwatch(at now: Date = .now) {
    guard archive.snapshot.timerMode == .stopwatch else { return }
    archive.snapshot.runState = .idle
    archive.snapshot.elapsedSeconds = 0
    archive.snapshot.stopwatchAnchor = nil
    archive.snapshot.lastUpdatedAt = now
    show("正计时已重置", kind: .info)
    persist()
  }

  func skipBreak(at now: Date = .now) {
    guard archive.snapshot.timerMode == .pomodoro,
          archive.snapshot.phase == .breakTime,
          archive.snapshot.runState != .idle
    else { return }
    cancelActiveNotification()
    startFocus(at: now, feedback: false)
    show("已跳过休息", kind: .info)
  }

  func beginNewRound(at now: Date = .now) {
    guard archive.snapshot.runState == .idle,
          archive.snapshot.isShowingCompletion
    else { return }
    archive.snapshot.completedSessions = 0
    archive.snapshot.roundStartedAt = nil
    archive.snapshot.isShowingCompletion = false
    archive.snapshot.lastUpdatedAt = now
    persist()
    startFocus(at: now, feedback: true)
  }

  func setFocusMinutes(_ value: Int) {
    let clamped = min(max(value, PomodoroConfiguration.focusMinutesRange.lowerBound), PomodoroConfiguration.focusMinutesRange.upperBound)
    guard clamped != archive.configuration.focusMinutes else { return }
    archive.configuration.focusMinutes = clamped
    if archive.snapshot.timerMode == .pomodoro,
       archive.snapshot.phase == .focus,
       archive.snapshot.runState == .idle,
       !archive.snapshot.isShowingCompletion {
      archive.snapshot.phaseDurationSeconds = clamped * 60
      archive.snapshot.remainingSeconds = clamped * 60
    }
    persist()
  }

  func setTargetSessions(_ value: Int) {
    archive.configuration.targetSessions = min(max(value, PomodoroConfiguration.targetSessionsRange.lowerBound), PomodoroConfiguration.targetSessionsRange.upperBound)
    persist()
  }

  func setBreakMinutes(_ value: Int) {
    let clamped = min(
      max(value, PomodoroConfiguration.breakMinutesRange.lowerBound),
      PomodoroConfiguration.breakMinutesRange.upperBound
    )
    setBreakSeconds(clamped * 60)
  }

  func setBreakSeconds(_ value: Int) {
    let clamped = min(max(value, 30), 60 * 60)
    archive.configuration.breakSeconds = clamped
    if archive.snapshot.phase == .breakTime,
       archive.snapshot.runState == .idle {
      archive.snapshot.phaseDurationSeconds = clamped
      archive.snapshot.remainingSeconds = clamped
    }
    persist()
  }

  func setNotificationsEnabled(_ enabled: Bool) {
    if !enabled {
      guard archive.configuration.notificationsEnabled else { return }
      archive.configuration.notificationsEnabled = false
      cancelActiveNotification()
      persist()
      return
    }

    if !archive.configuration.notificationsEnabled {
      archive.configuration.notificationsEnabled = true
      persist()
    }
    Task { @MainActor [weak self] in
      guard let self else { return }
      let allowed = await self.requestNotificationAuthorizationIfNeeded(showFeedback: true)
      if allowed {
        self.scheduleActiveNotification()
      }
    }
  }

  @discardableResult
  func requestNotificationAuthorizationIfNeeded(showFeedback: Bool = false) async -> Bool {
    let status = await notifier.authorizationStatus()
    notificationAuthorization = status

    guard archive.configuration.notificationsEnabled else { return false }

    switch status {
    case .authorized:
      if showFeedback { show("通知已开启", kind: .success) }
      return true
    case .denied:
      archive.configuration.notificationsEnabled = false
      if showFeedback { show("通知权限已关闭，请在系统设置中开启", kind: .info) }
      persist()
      return false
    case .notDetermined, .unknown:
      let allowed: Bool
      if let existingTask = notificationAuthorizationTask {
        allowed = await existingTask.value
      } else {
        let notifier = notifier
        let requestTask = Task { @MainActor in
          await notifier.requestAuthorization()
        }
        notificationAuthorizationTask = requestTask
        allowed = await requestTask.value
        notificationAuthorizationTask = nil
      }
      notificationAuthorization = await notifier.authorizationStatus()
      if allowed {
        if showFeedback { show("通知已开启", kind: .success) }
        return true
      }
      archive.configuration.notificationsEnabled = false
      if showFeedback { show("未获得通知权限", kind: .info) }
      persist()
      return false
    }
  }

  func setAppearance(_ appearance: TideAppearance) {
    guard archive.configuration.appearance != appearance else { return }
    archive.configuration.appearance = appearance
    persist()
  }

  @discardableResult
  func addTag(name: String, colorHex: String) -> Bool {
    let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty, archive.focusTags.count < 8 else { return false }
    let tag = FocusTag(name: cleaned, colorHex: normalizedColor(colorHex))
    archive.focusTags.append(tag)
    archive.configuration.selectedTagID = tag.id
    archive.configuration.selectedCategoryID = nil
    persist()
    show("标签已添加", kind: .success)
    return true
  }

  func updateTag(id: UUID, name: String, colorHex: String) {
    guard let index = archive.focusTags.firstIndex(where: { $0.id == id }) else { return }
    let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return }
    archive.focusTags[index].name = cleaned
    archive.focusTags[index].colorHex = normalizedColor(colorHex)
    persist()
  }

  func deleteTag(id: UUID) {
    archive.focusTags.removeAll { $0.id == id }
    if archive.configuration.selectedTagID == id {
      archive.configuration.selectedTagID = nil
    }
    persist()
    show("标签已删除，历史记录保持不变", kind: .info)
  }

  func selectTag(_ id: UUID?) {
    guard archive.snapshot.runState == .idle else { return }
    archive.configuration.selectedTagID = id
    archive.configuration.selectedCategoryID = nil
    persist()
  }

  @discardableResult
  func addCategory(name: String, colorHex: String) -> Bool {
    let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty, archive.categories.count < 10 else { return false }
    let category = PomodoroCategory(name: cleaned, colorHex: normalizedColor(colorHex))
    archive.categories.append(category)
    archive.configuration.selectedCategoryID = category.id
    archive.configuration.selectedTagID = nil
    persist()
    show("分组已添加", kind: .success)
    return true
  }

  func updateCategory(id: UUID, name: String, colorHex: String) {
    guard let index = archive.categories.firstIndex(where: { $0.id == id }) else { return }
    let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return }
    archive.categories[index].name = cleaned
    archive.categories[index].colorHex = normalizedColor(colorHex)
    persist()
  }

  func deleteCategory(id: UUID) {
    archive.categories.removeAll { $0.id == id }
    if archive.configuration.selectedCategoryID == id {
      archive.configuration.selectedCategoryID = nil
    }
    persist()
    show("分组已删除，历史记录保持不变", kind: .info)
  }

  func selectCategory(_ id: UUID?) {
    guard archive.snapshot.runState == .idle else { return }
    archive.configuration.selectedCategoryID = id
    archive.configuration.selectedTagID = nil
    persist()
  }

  func clearHistory() {
    archive.sessions.removeAll()
    archive.roundRecords.removeAll()
    persist()
    show("统计记录已清空", kind: .success)
  }

  func dismissBanner(id: UUID? = nil) {
    guard id == nil || banner?.id == id else { return }
    banner = nil
  }

  func dismissPersistentError() {
    persistentError = nil
  }

  private func startFocus(at date: Date, feedback: Bool) {
    let tag = selectedTag
    let category = selectedCategory
    let duration = archive.configuration.focusMinutes * 60
    if archive.snapshot.roundStartedAt == nil {
      archive.snapshot.roundStartedAt = date
    }
    archive.snapshot.phase = .focus
    archive.snapshot.runState = .running
    archive.snapshot.phaseDurationSeconds = duration
    archive.snapshot.remainingSeconds = duration
    archive.snapshot.deadline = date.addingTimeInterval(Double(duration))
    archive.snapshot.startedAt = date
    archive.snapshot.activeRunID = UUID()
    archive.snapshot.lockedTagID = tag?.id
    archive.snapshot.lockedTagName = tag?.name
    archive.snapshot.lockedTagColorHex = tag?.colorHex
    archive.snapshot.lockedCategoryID = category?.id
    archive.snapshot.lockedCategoryName = category?.name
    archive.snapshot.lockedCategoryColorHex = category?.colorHex
    archive.snapshot.isShowingCompletion = false
    archive.snapshot.lastUpdatedAt = date
    persist()
    scheduleActiveNotification()
    if feedback { show("开始专注", kind: .success) }
  }

  private func startBreak(at date: Date) {
    let duration = archive.configuration.breakSeconds
    archive.snapshot.phase = .breakTime
    archive.snapshot.runState = .running
    archive.snapshot.phaseDurationSeconds = duration
    archive.snapshot.remainingSeconds = duration
    archive.snapshot.deadline = date.addingTimeInterval(Double(duration))
    archive.snapshot.startedAt = date
    archive.snapshot.activeRunID = UUID()
    clearLockedContext()
    archive.snapshot.lastUpdatedAt = date
    persist()
    scheduleActiveNotification()
  }

  private func completeCurrentPhase(at date: Date) {
    switch archive.snapshot.phase {
    case .focus:
      appendFocusSession(outcome: .completed, endedAt: date)
      archive.snapshot.completedSessions += 1
      soundPlayer.playCompletion()
      if archive.snapshot.completedSessions >= archive.configuration.targetSessions {
        if let roundStartedAt = archive.snapshot.roundStartedAt {
          archive.roundRecords.append(PomodoroRoundRecord(
            startedAt: roundStartedAt,
            endedAt: date,
            completedSessions: archive.snapshot.completedSessions,
            targetSessions: archive.configuration.targetSessions,
            outcome: completionOutcomeForRound(startedAt: roundStartedAt)
          ))
        }
        archive.snapshot.phase = .focus
        archive.snapshot.runState = .idle
        archive.snapshot.phaseDurationSeconds = archive.configuration.focusMinutes * 60
        archive.snapshot.remainingSeconds = archive.snapshot.phaseDurationSeconds
        archive.snapshot.deadline = nil
        archive.snapshot.startedAt = nil
        archive.snapshot.activeRunID = nil
        archive.snapshot.isShowingCompletion = true
        clearLockedContext()
        archive.snapshot.lastUpdatedAt = date
        persist()
        show("本轮番茄钟已完成，休息一下吧", kind: .success)
      } else {
        startBreak(at: date)
        show("专注完成，开始休息", kind: .success)
      }
    case .breakTime:
      soundPlayer.playCompletion()
      startFocus(at: date, feedback: false)
      show("休息结束，继续专注", kind: .success)
    }
  }

  @discardableResult
  private func appendFocusSession(outcome: SessionOutcome, endedAt: Date) -> Bool {
    guard let runID = archive.snapshot.activeRunID,
          !archive.sessions.contains(where: { $0.runID == runID }),
          let startedAt = archive.snapshot.startedAt
    else { return false }
    let duration = switch outcome {
    case .completed: archive.snapshot.phaseDurationSeconds
    case .completedEarly: elapsedInCurrentPhase(at: endedAt)
    }
    archive.sessions.append(FocusSession(
      runID: runID,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: duration,
      plannedSeconds: archive.snapshot.phaseDurationSeconds,
      outcome: outcome,
      tagID: archive.snapshot.lockedTagID,
      tagName: archive.snapshot.lockedTagName,
      tagColorHex: archive.snapshot.lockedTagColorHex,
      categoryID: archive.snapshot.lockedCategoryID,
      categoryName: archive.snapshot.lockedCategoryName,
      categoryColorHex: archive.snapshot.lockedCategoryColorHex
    ))
    return true
  }

  private func elapsedInCurrentPhase(at date: Date) -> Int {
    switch archive.snapshot.runState {
    case .running:
      guard let deadline = archive.snapshot.deadline else { return 0 }
      let remaining = max(0, Int(deadline.timeIntervalSince(date).rounded(.up)))
      return max(0, archive.snapshot.phaseDurationSeconds - remaining)
    case .paused:
      return max(0, archive.snapshot.phaseDurationSeconds - archive.snapshot.remainingSeconds)
    case .idle:
      return 0
    }
  }

  private func prepareIdleFocus(at date: Date, showingCompletion: Bool) {
    let duration = archive.configuration.focusMinutes * 60
    archive.snapshot.phase = .focus
    archive.snapshot.runState = .idle
    archive.snapshot.phaseDurationSeconds = duration
    archive.snapshot.remainingSeconds = duration
    archive.snapshot.elapsedSeconds = 0
    archive.snapshot.deadline = nil
    archive.snapshot.stopwatchAnchor = nil
    archive.snapshot.startedAt = nil
    archive.snapshot.activeRunID = nil
    archive.snapshot.isShowingCompletion = showingCompletion
    archive.snapshot.lastUpdatedAt = date
    clearLockedContext()
  }

  private func completionOutcomeForRound(startedAt: Date) -> SessionOutcome {
    archive.sessions.contains {
      $0.endedAt >= startedAt && $0.outcome.isEarlyCompletion
    } ? .completedEarly : .completed
  }

  private func clearLockedContext() {
    archive.snapshot.lockedTagID = nil
    archive.snapshot.lockedTagName = nil
    archive.snapshot.lockedTagColorHex = nil
    archive.snapshot.lockedCategoryID = nil
    archive.snapshot.lockedCategoryName = nil
    archive.snapshot.lockedCategoryColorHex = nil
  }

  private func normalizeIdleSnapshot() {
    guard archive.snapshot.runState == .idle else { return }
    if archive.snapshot.timerMode == .pomodoro,
       !archive.snapshot.isShowingCompletion {
      let duration = archive.snapshot.phase == .focus
        ? archive.configuration.focusMinutes * 60
        : archive.configuration.breakSeconds
      archive.snapshot.phaseDurationSeconds = duration
      archive.snapshot.remainingSeconds = duration
    }
  }

  private func ensureSelectionIntegrity() -> Bool {
    var changed = false
    if let selectedCategoryID = archive.configuration.selectedCategoryID,
       let selectedCategory = archive.categories.first(where: { $0.id == selectedCategoryID }),
       selectedCategory.name == "未命名分组" {
      archive.configuration.selectedCategoryID = nil
      changed = true
    } else if let selectedCategoryID = archive.configuration.selectedCategoryID,
              !archive.categories.contains(where: { $0.id == selectedCategoryID }) {
      archive.configuration.selectedCategoryID = nil
      changed = true
    }
    if let selectedTagID = archive.configuration.selectedTagID,
       !archive.focusTags.contains(where: { $0.id == selectedTagID }) {
      archive.configuration.selectedTagID = nil
      changed = true
    }
    if archive.configuration.selectedTagID != nil,
       archive.configuration.selectedCategoryID != nil {
      archive.configuration.selectedCategoryID = nil
      changed = true
    }
    return changed
  }

  private func scheduleActiveNotification() {
    guard archive.configuration.notificationsEnabled,
          archive.snapshot.timerMode == .pomodoro,
          archive.snapshot.runState == .running,
          let runID = archive.snapshot.activeRunID,
          let deadline = archive.snapshot.deadline,
          deadline > currentTime
    else { return }
    let phase = archive.snapshot.phase
    let breakDuration = TideFormatting.compactDuration(archive.configuration.breakSeconds)
    Task { @MainActor [weak self] in
      guard let self,
            await self.requestNotificationAuthorizationIfNeeded(showFeedback: true)
      else { return }
      await self.notifier.schedule(
        id: notificationID(runID),
        title: phase == .focus ? "专注完成 · 该休息了" : "休息结束 · 回来专注吧",
        body: phase == .focus ? "开始 \(breakDuration)休息，放松一下眼睛和肩颈。" : "准备好开始下一次专注。",
        at: deadline
      )
    }
  }

  private func cancelActiveNotification() {
    guard let runID = archive.snapshot.activeRunID else { return }
    notifier.cancel(id: notificationID(runID))
  }

  private func notificationID(_ runID: UUID) -> String {
    "Tide.Pomodoro.\(runID.uuidString)"
  }

  private func normalizedColor(_ color: String) -> String {
    TidePalette.colors.contains(color.uppercased()) ? color.uppercased() : TidePalette.colors[0]
  }

  private func persist() {
    guard canPersist else { return }
    do {
      try persistence.save(archive)
    } catch {
      persistentError = "保存失败：\(error.localizedDescription)"
    }
  }

  private func show(_ text: String, kind: TideBanner.Kind) {
    banner = TideBanner(text: text, kind: kind)
  }
}

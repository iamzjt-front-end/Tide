import Foundation
import Testing
@testable import Tide

@MainActor
struct PomodoroControllerTests {
  private let start = Date(timeIntervalSince1970: 1_800_000_000)

  @Test func startPauseResumeKeepsRemainingTime() {
    let rig = makeRig()
    rig.controller.setFocusMinutes(1)
    rig.controller.start(at: start)

    #expect(rig.controller.snapshot.runState == .running)
    #expect(rig.controller.displaySeconds == 60)

    rig.controller.pause(at: start.addingTimeInterval(17))
    #expect(rig.controller.snapshot.runState == .paused)
    #expect(rig.controller.displaySeconds == 43)

    rig.controller.tick(at: start.addingTimeInterval(200))
    #expect(rig.controller.displaySeconds == 43)

    rig.controller.resume(at: start.addingTimeInterval(200))
    rig.controller.tick(at: start.addingTimeInterval(210))
    #expect(rig.controller.displaySeconds == 33)
  }

  @Test func stopRecordsActualDurationAsEarlyCompletion() {
    let rig = makeRig()
    rig.controller.setFocusMinutes(1)
    rig.controller.start(at: start)
    rig.controller.stop(at: start.addingTimeInterval(22))

    #expect(rig.controller.snapshot.runState == .idle)
    #expect(rig.controller.snapshot.phase == .breakTime)
    #expect(rig.controller.snapshot.completedSessions == 1)
    #expect(rig.controller.displaySeconds == rig.controller.configuration.breakSeconds)
    #expect(rig.controller.sessions.count == 1)
    #expect(rig.controller.sessions.first?.outcome == .completedEarly)
    #expect(rig.controller.sessions.first?.durationSeconds == 22)

    rig.controller.stop(at: start.addingTimeInterval(25))
    #expect(rig.controller.sessions.count == 1)
  }

  @Test func evenAnImmediateStopCountsAsACompletedPomodoro() {
    let rig = makeRig()
    rig.controller.setFocusMinutes(45)
    rig.controller.setTargetSessions(1)
    rig.controller.start(at: start)
    rig.controller.stop(at: start)

    #expect(rig.controller.sessions.count == 1)
    #expect(rig.controller.sessions.first?.durationSeconds == 0)
    #expect(rig.controller.sessions.first?.outcome == .completedEarly)
    #expect(rig.controller.snapshot.completedSessions == 1)
    #expect(rig.controller.snapshot.phase == .longBreak)
    #expect(rig.controller.snapshot.runState == .idle)
    #expect(!rig.controller.snapshot.isShowingCompletion)
    #expect(rig.controller.roundRecords.first?.outcome == .completedEarly)
  }

  @Test func completedFocusPreparesBreakForManualStart() {
    let rig = makeRig()
    rig.controller.setFocusMinutes(1)
    rig.controller.setBreakMinutes(1)
    rig.controller.start(at: start)
    rig.controller.tick(at: start.addingTimeInterval(60))

    #expect(rig.controller.snapshot.phase == .breakTime)
    #expect(rig.controller.snapshot.runState == .idle)
    #expect(rig.controller.snapshot.deadline == nil)
    #expect(rig.controller.snapshot.activeRunID == nil)
    #expect(rig.controller.displaySeconds == 60)
    #expect(rig.controller.snapshot.completedSessions == 1)
    #expect(rig.controller.sessions.count == 1)
    #expect(rig.controller.sessions.first?.outcome == .completed)
    #expect(rig.sound.playCount == 1)

    rig.controller.start(at: start.addingTimeInterval(75))
    #expect(rig.controller.snapshot.phase == .breakTime)
    #expect(rig.controller.snapshot.runState == .running)
    #expect(rig.controller.snapshot.deadline == start.addingTimeInterval(135))
  }

  @Test func naturalFocusCompletionWaitsToScheduleRestUntilManualStart() async {
    let rig = makeRig()
    rig.controller.setFocusMinutes(1)
    rig.controller.setBreakMinutes(1)
    rig.controller.start(at: start)
    await settleNotificationTasks()

    let focusNotification = rig.notifier.scheduled.first
    #expect(focusNotification != nil)
    #expect(focusNotification?.title == "做得不错，休息一下吧")
    #expect(focusNotification?.body.contains("短休息 1 分钟") == true)
    #expect(focusNotification?.delivery == .completion)

    rig.controller.tick(at: start.addingTimeInterval(60))
    await settleNotificationTasks()

    #expect(rig.controller.snapshot.phase == .breakTime)
    #expect(rig.controller.snapshot.runState == .idle)
    #expect(focusNotification.map { !rig.notifier.cancelledIDs.contains($0.id) } == true)
    #expect(!rig.notifier.scheduled.contains { $0.title == "休息好了" })

    rig.controller.start(at: start.addingTimeInterval(75))
    await settleNotificationTasks()
    #expect(rig.notifier.scheduled.contains { $0.title == "休息好了" })
  }

  @Test func finalFocusNotificationUsesLongBreakDuration() async {
    let rig = makeRig()
    rig.controller.setTargetSessions(1)
    rig.controller.setLongBreakMinutes(30)
    rig.controller.start(at: start)
    await settleNotificationTasks()

    let notification = rig.notifier.scheduled.first
    #expect(notification?.title == "这一轮完成了")
    #expect(notification?.body.contains("长休息 30 分钟") == true)
    #expect(notification?.delivery == .completion)
  }

  @Test func runningPhaseSchedulesGentleLeadInAndCompletionReminders() async {
    let rig = makeRig()
    rig.controller.setFocusMinutes(25)
    rig.controller.start(at: start)
    await settleNotificationTasks()

    let gentle = rig.notifier.scheduled.first { $0.delivery == .gentleReminder }
    let completion = rig.notifier.scheduled.first { $0.delivery == .completion }

    #expect(gentle?.title == "这一段专注快完成了")
    #expect(gentle?.body == "还有 1 分钟，慢慢收尾就好。")
    #expect(gentle?.date == start.addingTimeInterval(24 * 60))
    #expect(completion?.title == "做得不错，休息一下吧")
    #expect(completion?.date == start.addingTimeInterval(25 * 60))
  }

  @Test func pausingCancelsGentleAndCompletionReminders() async {
    let rig = makeRig()
    rig.controller.setFocusMinutes(25)
    rig.controller.start(at: start)
    await settleNotificationTasks()

    let scheduledIDs = Set(rig.notifier.scheduled.map(\.id))
    #expect(scheduledIDs.count == 2)

    rig.controller.pause(at: start.addingTimeInterval(30))

    #expect(rig.notifier.scheduled.isEmpty)
    #expect(scheduledIDs.isSubset(of: Set(rig.notifier.cancelledIDs)))
  }

  @Test func completedBreakPreparesFocusForManualStart() {
    let rig = makeRig()
    rig.controller.setFocusMinutes(1)
    rig.controller.setBreakMinutes(1)
    rig.controller.start(at: start)
    rig.controller.tick(at: start.addingTimeInterval(60))
    rig.controller.start(at: start.addingTimeInterval(70))
    rig.controller.tick(at: start.addingTimeInterval(130))

    #expect(rig.controller.snapshot.phase == .focus)
    #expect(rig.controller.snapshot.runState == .idle)
    #expect(rig.controller.snapshot.completedSessions == 1)
    #expect(rig.controller.displaySeconds == 60)
    #expect(rig.sound.playCount == 2)

    rig.controller.start(at: start.addingTimeInterval(140))
    #expect(rig.controller.snapshot.runState == .running)
    #expect(rig.controller.snapshot.roundStartedAt == start)
  }

  @Test func targetSessionsPreparesLongBreakAndNextRoundForManualStart() {
    let rig = makeRig()
    rig.controller.setFocusMinutes(1)
    rig.controller.setTargetSessions(1)
    rig.controller.setLongBreakMinutes(1)
    rig.controller.start(at: start)
    rig.controller.tick(at: start.addingTimeInterval(60))

    #expect(rig.controller.snapshot.phase == .longBreak)
    #expect(rig.controller.snapshot.runState == .idle)
    #expect(rig.controller.displaySeconds == 60)
    #expect(!rig.controller.snapshot.isShowingCompletion)
    #expect(rig.controller.roundRecords.count == 1)
    #expect(rig.controller.roundRecords.first?.outcome == .completed)

    rig.controller.start(at: start.addingTimeInterval(70))
    #expect(rig.controller.snapshot.phase == .longBreak)
    #expect(rig.controller.snapshot.runState == .running)

    rig.controller.tick(at: start.addingTimeInterval(130))
    #expect(rig.controller.snapshot.phase == .focus)
    #expect(rig.controller.snapshot.runState == .idle)
    #expect(rig.controller.snapshot.completedSessions == 0)
    #expect(rig.controller.snapshot.roundStartedAt == nil)

    rig.controller.start(at: start.addingTimeInterval(140))
    #expect(rig.controller.snapshot.runState == .running)
    #expect(rig.controller.snapshot.roundStartedAt == start.addingTimeInterval(140))
  }

  @Test func skippingLongBreakPreparesANewRoundForManualStart() {
    let rig = makeRig()
    rig.controller.setFocusMinutes(1)
    rig.controller.setTargetSessions(1)
    rig.controller.start(at: start)
    rig.controller.tick(at: start.addingTimeInterval(60))
    rig.controller.start(at: start.addingTimeInterval(65))

    rig.controller.skipBreak(at: start.addingTimeInterval(70))

    #expect(rig.controller.snapshot.phase == .focus)
    #expect(rig.controller.snapshot.runState == .idle)
    #expect(rig.controller.snapshot.completedSessions == 0)
    #expect(rig.controller.snapshot.roundStartedAt == nil)

    rig.controller.start(at: start.addingTimeInterval(75))
    #expect(rig.controller.snapshot.runState == .running)
    #expect(rig.controller.snapshot.roundStartedAt == start.addingTimeInterval(75))
  }

  @Test func preparedBreakCanBeSkippedWithoutStartingIt() {
    let rig = makeRig()
    rig.controller.setFocusMinutes(1)
    rig.controller.start(at: start)
    rig.controller.tick(at: start.addingTimeInterval(60))

    #expect(rig.controller.snapshot.phase == .breakTime)
    #expect(rig.controller.snapshot.runState == .idle)

    rig.controller.skipBreak(at: start.addingTimeInterval(65))

    #expect(rig.controller.snapshot.phase == .focus)
    #expect(rig.controller.snapshot.runState == .idle)
    #expect(rig.controller.snapshot.completedSessions == 1)
    #expect(rig.controller.snapshot.deadline == nil)
    #expect(rig.controller.sessions.count == 1)
  }

  @Test func restartRestoresRunningDeadline() {
    let store = InMemoryPomodoroPersistence()
    let first = PomodoroController(
      persistence: store,
      notifier: SilentPomodoroNotifier(),
      soundPlayer: SilentPomodoroSoundPlayer(),
      initialNow: start
    )
    first.setFocusMinutes(1)
    first.start(at: start)

    let restored = PomodoroController(
      persistence: store,
      notifier: SilentPomodoroNotifier(),
      soundPlayer: SilentPomodoroSoundPlayer(),
      initialNow: start.addingTimeInterval(25)
    )
    #expect(restored.snapshot.runState == .running)
    #expect(restored.displaySeconds == 35)
  }

  @Test func restartPastDeadlineCompletesExactlyOnce() {
    let store = InMemoryPomodoroPersistence()
    let first = PomodoroController(
      persistence: store,
      notifier: SilentPomodoroNotifier(),
      soundPlayer: SilentPomodoroSoundPlayer(),
      initialNow: start
    )
    first.setFocusMinutes(1)
    first.start(at: start)

    let restored = PomodoroController(
      persistence: store,
      notifier: SilentPomodoroNotifier(),
      soundPlayer: SilentPomodoroSoundPlayer(),
      initialNow: start.addingTimeInterval(61)
    )
    #expect(restored.sessions.count == 1)
    #expect(restored.snapshot.phase == .breakTime)
    #expect(restored.snapshot.runState == .idle)

    restored.reconcile(at: start.addingTimeInterval(61))
    restored.reconcile(at: start.addingTimeInterval(61))
    #expect(restored.sessions.count == 1)
  }

  @Test func activeRunReflectsTagMetadataEdits() {
    let rig = makeRig()
    rig.controller.addTag(name: "学习", colorHex: "#4DABF7")
    let tag = try! #require(rig.controller.selectedTag)
    rig.controller.setFocusMinutes(1)
    rig.controller.start(at: start)
    rig.controller.updateTag(id: tag.id, name: "新名称", colorHex: "#FF6B6B")

    #expect(rig.controller.lockedContextText.contains("新名称"))
    rig.controller.tick(at: start.addingTimeInterval(60))
    #expect(rig.controller.sessions.first?.tagName == "新名称")
    #expect(rig.controller.sessions.first?.tagColorHex == "#FF6B6B")
  }

  @Test func selectedTagColorDrivesThemeAndUpdatesDuringFocus() {
    let rig = makeRig()
    rig.controller.addTag(name: "阅读", colorHex: "#FFA94D")
    let tag = try! #require(rig.controller.selectedTag)

    #expect(rig.controller.currentAccentHex == "#FFA94D")

    rig.controller.start(at: start)
    rig.controller.updateTag(id: tag.id, name: "阅读", colorHex: "#4DABF7")

    #expect(rig.controller.currentAccentHex == "#4DABF7")
  }

  @Test func fixedSemanticColorsRemainStableWhenSelectedTagChangesTheme() {
    let rig = makeRig()
    rig.controller.addTag(name: "阅读", colorHex: "#FFA94D")

    #expect(rig.controller.currentAccentHex == "#FFA94D")
    #expect(TidePalette.brandAccentHex == "#4DABF7")
    #expect(TidePalette.skipRestAccentHex == "#FF9F0A")
  }

  @Test func noTagUsesDefaultTideBlueTheme() {
    let rig = makeRig()

    #expect(rig.controller.selectedFocusLabelName == nil)
    #expect(rig.controller.currentAccentHex == TidePalette.defaultAccentHex)
    #expect(rig.controller.currentAccentHex == "#4DABF7")
  }

  @Test func runningFocusCanChangeTagWithoutChangingTimer() {
    let rig = makeRig()
    rig.controller.addTag(name: "阅读", colorHex: "#FFA94D")
    let reading = try! #require(rig.controller.selectedTag)
    rig.controller.addTag(name: "写作", colorHex: "#F783AC")
    let writing = try! #require(rig.controller.selectedTag)
    rig.controller.selectTag(reading.id)
    rig.controller.setFocusMinutes(1)
    rig.controller.start(at: start)
    let deadline = rig.controller.snapshot.deadline

    rig.controller.selectTag(writing.id)

    #expect(rig.controller.snapshot.runState == .running)
    #expect(rig.controller.snapshot.deadline == deadline)
    #expect(rig.controller.displaySeconds == 60)
    #expect(rig.controller.lockedContextText == "写作")
    #expect(rig.controller.currentAccentHex == "#F783AC")

    rig.controller.tick(at: start.addingTimeInterval(60))
    #expect(rig.controller.sessions.first?.tagID == writing.id)
    #expect(rig.controller.sessions.first?.tagName == "写作")
    #expect(rig.controller.sessions.first?.tagColorHex == "#F783AC")
  }

  @Test func pausedFocusCanChangeToNoTagWithoutLosingProgress() {
    let rig = makeRig()
    rig.controller.addTag(name: "学习", colorHex: "#4DABF7")
    rig.controller.setFocusMinutes(1)
    rig.controller.start(at: start)
    rig.controller.pause(at: start.addingTimeInterval(17))

    rig.controller.selectTag(nil)

    #expect(rig.controller.snapshot.runState == .paused)
    #expect(rig.controller.displaySeconds == 43)
    #expect(rig.controller.lockedContextText == "无标签")

    rig.controller.stop(at: start.addingTimeInterval(200))
    #expect(rig.controller.sessions.first?.durationSeconds == 17)
    #expect(rig.controller.sessions.first?.tagID == nil)
    #expect(rig.controller.sessions.first?.tagName == nil)
  }

  @Test func unifiedLabelSelectionKeepsOnlyOneActiveSource() {
    var archive = PomodoroArchive.fresh(now: start)
    let legacyCategory = PomodoroCategory(name: "旧项目", colorHex: "#69DB7C")
    let tag = FocusTag(name: "学习", colorHex: "#4DABF7")
    archive.categories = [legacyCategory]
    archive.focusTags = [tag]
    archive.configuration.selectedCategoryID = legacyCategory.id

    let controller = PomodoroController(
      persistence: InMemoryPomodoroPersistence(archive: archive),
      notifier: SilentPomodoroNotifier(),
      soundPlayer: SilentPomodoroSoundPlayer(),
      initialNow: start
    )

    #expect(controller.selectedFocusLabelName == "旧项目")
    controller.selectTag(tag.id)
    #expect(controller.configuration.selectedTagID == tag.id)
    #expect(controller.configuration.selectedCategoryID == nil)
    #expect(controller.selectedFocusLabelName == "学习")

    controller.selectCategory(legacyCategory.id)
    #expect(controller.configuration.selectedCategoryID == legacyCategory.id)
    #expect(controller.configuration.selectedTagID == nil)
    #expect(controller.selectedFocusLabelName == "旧项目")
  }

  @Test func legacyDefaultCategoryIsPreservedButNoLongerAutoSelected() {
    var archive = PomodoroArchive.fresh(now: start)
    let legacyDefault = PomodoroCategory(name: "未命名分组", colorHex: "#868E96")
    archive.categories = [legacyDefault]
    archive.configuration.selectedCategoryID = legacyDefault.id

    let controller = PomodoroController(
      persistence: InMemoryPomodoroPersistence(archive: archive),
      notifier: SilentPomodoroNotifier(),
      soundPlayer: SilentPomodoroSoundPlayer(),
      initialNow: start
    )

    #expect(controller.categories == [legacyDefault])
    #expect(controller.configuration.selectedCategoryID == nil)
    #expect(controller.selectedFocusLabelName == nil)
    #expect(controller.lockedContextText == "无标签")
  }

  @Test func stopwatchCountsFromDateAndCanPause() {
    let rig = makeRig()
    rig.controller.setTimerMode(.stopwatch, at: start)
    rig.controller.start(at: start)
    rig.controller.tick(at: start.addingTimeInterval(75))
    #expect(rig.controller.displaySeconds == 75)

    rig.controller.pause(at: start.addingTimeInterval(75))
    rig.controller.tick(at: start.addingTimeInterval(500))
    #expect(rig.controller.displaySeconds == 75)

    rig.controller.resume(at: start.addingTimeInterval(500))
    rig.controller.tick(at: start.addingTimeInterval(510))
    #expect(rig.controller.displaySeconds == 85)
  }

  @Test func enabledNotificationsRequestSystemPermissionWhenUndetermined() async {
    let rig = makeRig()
    rig.notifier.authorizationStatusValue = .notDetermined
    rig.notifier.authorizationResult = true

    let allowed = await rig.controller.requestNotificationAuthorizationIfNeeded()

    #expect(allowed)
    #expect(rig.notifier.authorizationRequestCount == 1)
    #expect(rig.controller.notificationAuthorization == .authorized)
    #expect(rig.controller.configuration.notificationsEnabled)
  }

  @Test func testReminderUsesAudibleCompletionDelivery() async {
    let rig = makeRig()

    rig.controller.sendTestNotification()
    await settleNotificationTasks()

    let notification = rig.notifier.scheduled.first {
      $0.id.hasPrefix("Tide.Notification.Test.")
    }
    #expect(notification?.title == "Tide 已准备好提醒你")
    #expect(notification?.delivery == .completion)
    #expect(rig.controller.testNotificationState == .scheduled)
  }

  @Test func testReminderReportsSchedulingFailureInsteadOfSilentlySucceeding() async {
    let rig = makeRig()
    rig.notifier.scheduleResult = .failed("模拟调度失败")

    rig.controller.sendTestNotification()
    await settleNotificationTasks()

    #expect(rig.notifier.scheduled.isEmpty)
    #expect(rig.controller.testNotificationState == .failed("模拟调度失败"))
  }

  @Test func restoredRunningTimerReschedulesItsSystemNotification() async {
    let store = InMemoryPomodoroPersistence()
    let originalNotifier = SilentPomodoroNotifier()
    let original = PomodoroController(
      persistence: store,
      notifier: originalNotifier,
      soundPlayer: SilentPomodoroSoundPlayer(),
      initialNow: start
    )
    original.setFocusMinutes(1)
    original.start(at: start)
    await settleNotificationTasks()

    let restoredNotifier = SilentPomodoroNotifier()
    let restored = PomodoroController(
      persistence: store,
      notifier: restoredNotifier,
      soundPlayer: SilentPomodoroSoundPlayer(),
      initialNow: start.addingTimeInterval(10)
    )

    restored.restoreActiveNotification()
    await settleNotificationTasks()

    let request = restoredNotifier.scheduled.first
    #expect(request?.id.contains(restored.snapshot.activeRunID?.uuidString ?? "") == true)
    #expect(request?.title == "做得不错，休息一下吧")
    #expect(request?.delivery == .completion)
    #expect(request?.date == start.addingTimeInterval(60))
  }

  @Test func customBreakDurationUsesOneToSixtyMinuteRange() {
    let rig = makeRig()

    rig.controller.setBreakMinutes(37)
    #expect(rig.controller.configuration.breakSeconds == 37 * 60)

    rig.controller.setBreakMinutes(0)
    #expect(rig.controller.configuration.breakSeconds == 60)

    rig.controller.setBreakMinutes(61)
    #expect(rig.controller.configuration.breakSeconds == 60 * 60)
  }

  @Test func customLongBreakDurationUsesOneToSixtyMinuteRange() {
    let rig = makeRig()

    rig.controller.setLongBreakMinutes(37)
    #expect(rig.controller.configuration.longBreakSeconds == 37 * 60)
    #expect(rig.store.archive?.configuration.longBreakSeconds == 37 * 60)

    rig.controller.setLongBreakMinutes(0)
    #expect(rig.controller.configuration.longBreakSeconds == 60)

    rig.controller.setLongBreakMinutes(61)
    #expect(rig.controller.configuration.longBreakSeconds == 60 * 60)
  }

  @Test func deniedSystemPermissionDisablesMisleadingNotificationPreference() async {
    let rig = makeRig()
    rig.notifier.authorizationStatusValue = .denied

    let allowed = await rig.controller.requestNotificationAuthorizationIfNeeded()

    #expect(!allowed)
    #expect(rig.notifier.authorizationRequestCount == 0)
    #expect(rig.controller.notificationAuthorization == .denied)
    #expect(!rig.controller.configuration.notificationsEnabled)
  }

  private func makeRig() -> TestRig {
    TestRig(now: start)
  }

  private func settleNotificationTasks() async {
    await Task.yield()
    await Task.yield()
  }
}

@MainActor
private struct TestRig {
  let store: InMemoryPomodoroPersistence
  let notifier: SilentPomodoroNotifier
  let sound: SilentPomodoroSoundPlayer
  let controller: PomodoroController

  init(now: Date) {
    store = InMemoryPomodoroPersistence()
    notifier = SilentPomodoroNotifier()
    sound = SilentPomodoroSoundPlayer()
    controller = PomodoroController(
      persistence: store,
      notifier: notifier,
      soundPlayer: sound,
      initialNow: now
    )
  }
}

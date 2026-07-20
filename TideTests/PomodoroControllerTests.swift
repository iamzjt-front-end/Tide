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
    #expect(rig.controller.snapshot.completedSessions == 1)
    #expect(rig.controller.displaySeconds == 60)
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
    #expect(rig.controller.snapshot.isShowingCompletion)
    #expect(rig.controller.roundRecords.first?.outcome == .completedEarly)
  }

  @Test func completedFocusAutomaticallyStartsBreak() {
    let rig = makeRig()
    rig.controller.setFocusMinutes(1)
    rig.controller.setBreakMinutes(1)
    rig.controller.start(at: start)
    rig.controller.tick(at: start.addingTimeInterval(60))

    #expect(rig.controller.snapshot.phase == .breakTime)
    #expect(rig.controller.snapshot.runState == .running)
    #expect(rig.controller.snapshot.completedSessions == 1)
    #expect(rig.controller.sessions.count == 1)
    #expect(rig.controller.sessions.first?.outcome == .completed)
    #expect(rig.sound.playCount == 1)
  }

  @Test func naturalFocusCompletionKeepsTheDueRestNotification() async {
    let rig = makeRig()
    rig.controller.setFocusMinutes(1)
    rig.controller.setBreakMinutes(1)
    rig.controller.start(at: start)
    await settleNotificationTasks()

    let focusNotification = rig.notifier.scheduled.first
    #expect(focusNotification != nil)
    #expect(focusNotification?.title == "专注完成 · 该休息了")
    #expect(focusNotification?.body.contains("1 分钟休息") == true)

    rig.controller.tick(at: start.addingTimeInterval(60))
    await settleNotificationTasks()

    #expect(rig.controller.snapshot.phase == .breakTime)
    #expect(focusNotification.map { !rig.notifier.cancelledIDs.contains($0.id) } == true)
    #expect(rig.notifier.scheduled.contains { $0.title == "休息结束 · 回来专注吧" })
  }

  @Test func completedBreakAutomaticallyStartsFocus() {
    let rig = makeRig()
    rig.controller.setFocusMinutes(1)
    rig.controller.setBreakMinutes(1)
    rig.controller.start(at: start)
    rig.controller.tick(at: start.addingTimeInterval(120))

    #expect(rig.controller.snapshot.phase == .focus)
    #expect(rig.controller.snapshot.runState == .running)
    #expect(rig.controller.snapshot.completedSessions == 1)
    #expect(rig.controller.displaySeconds == 60)
    #expect(rig.sound.playCount == 2)
  }

  @Test func targetSessionsCompletesRoundWithoutStartingBreak() {
    let rig = makeRig()
    rig.controller.setFocusMinutes(1)
    rig.controller.setTargetSessions(1)
    rig.controller.start(at: start)
    rig.controller.tick(at: start.addingTimeInterval(60))

    #expect(rig.controller.snapshot.runState == .idle)
    #expect(rig.controller.snapshot.isShowingCompletion)
    #expect(rig.controller.roundRecords.count == 1)
    #expect(rig.controller.roundRecords.first?.outcome == .completed)

    rig.controller.beginNewRound(at: start.addingTimeInterval(61))
    #expect(rig.controller.snapshot.runState == .running)
    #expect(rig.controller.snapshot.completedSessions == 0)
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

    restored.reconcile(at: start.addingTimeInterval(61))
    restored.reconcile(at: start.addingTimeInterval(61))
    #expect(restored.sessions.count == 1)
  }

  @Test func activeRunKeepsTagSnapshotAfterEditing() {
    let rig = makeRig()
    rig.controller.addTag(name: "学习", colorHex: "#4DABF7")
    let tag = try! #require(rig.controller.selectedTag)
    rig.controller.setFocusMinutes(1)
    rig.controller.start(at: start)
    rig.controller.updateTag(id: tag.id, name: "新名称", colorHex: "#FF6B6B")

    #expect(rig.controller.lockedContextText.contains("学习"))
    rig.controller.tick(at: start.addingTimeInterval(60))
    #expect(rig.controller.sessions.first?.tagName == "学习")
    #expect(rig.controller.sessions.first?.tagColorHex == "#4DABF7")
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

  @Test func customBreakDurationUsesOneToSixtyMinuteRange() {
    let rig = makeRig()

    rig.controller.setBreakMinutes(37)
    #expect(rig.controller.configuration.breakSeconds == 37 * 60)

    rig.controller.setBreakMinutes(0)
    #expect(rig.controller.configuration.breakSeconds == 60)

    rig.controller.setBreakMinutes(61)
    #expect(rig.controller.configuration.breakSeconds == 60 * 60)
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

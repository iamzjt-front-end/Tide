import Foundation
import Testing
@testable import Tide

@MainActor
struct PomodoroPersistenceAndExportTests {
  @Test func menuBarTimeStaysCompactAfterOneHour() {
    #expect(TideFormatting.menuBarTime(3_599) == "59:59")
    #expect(TideFormatting.menuBarTime(3_600) == "1h")
    #expect(TideFormatting.menuBarTime(5_160) == "1h26m")
    #expect(TideFormatting.menuBarTime(7_199) == "1h59m")
    #expect(TideFormatting.menuBarTime(7_200) == "2h")
  }

  @Test func legacyAbandonedOutcomeMigratesToEarlyCompletion() throws {
    let legacy = Data("\"abandoned\"".utf8)
    let outcome = try JSONDecoder().decode(SessionOutcome.self, from: legacy)
    #expect(outcome == .completedEarly)

    let encoded = try JSONEncoder().encode(outcome)
    #expect(String(decoding: encoded, as: UTF8.self) == "\"completedEarly\"")
  }

  @Test func userDefaultsRoundTripPreservesSnapshotAndTags() throws {
    let suite = "TideTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = UserDefaultsPomodoroPersistence(defaults: defaults, key: "archive")
    var archive = PomodoroArchive.fresh(now: Date(timeIntervalSince1970: 10))
    archive.configuration.focusMinutes = 42
    archive.configuration.longBreakSeconds = 1_800
    archive.focusTags = [FocusTag(name: "学习", colorHex: "#4DABF7")]
    archive.snapshot.runState = .paused
    archive.snapshot.remainingSeconds = 123

    try store.save(archive)
    let loaded = try store.load()
    let restored = try #require(loaded)
    #expect(restored == archive)
  }

  @Test func appearanceRoundTripAndLegacyDefaultAreStable() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    var configuration = PomodoroConfiguration()
    configuration.appearance = .dark

    let restored = try decoder.decode(
      PomodoroConfiguration.self,
      from: encoder.encode(configuration)
    )
    #expect(restored.appearance == .dark)

    let legacy = Data(#"{"focusMinutes":25,"targetSessions":4,"breakSeconds":300,"notificationsEnabled":true}"#.utf8)
    let migrated = try decoder.decode(PomodoroConfiguration.self, from: legacy)
    #expect(migrated.appearance == .system)
    #expect(migrated.longBreakSeconds == 15 * 60)
  }

  @Test func controllerPersistsAppearanceSelection() {
    let store = InMemoryPomodoroPersistence()
    let controller = PomodoroController(
      persistence: store,
      notifier: SilentPomodoroNotifier(),
      soundPlayer: SilentPomodoroSoundPlayer()
    )

    controller.setAppearance(.light)

    #expect(controller.configuration.appearance == .light)
    #expect(store.archive?.configuration.appearance == .light)
  }

  @Test func csvEscapesCommaQuoteAndNewline() throws {
    var archive = PomodoroArchive.fresh()
    archive.sessions = [FocusSession(
      runID: UUID(),
      startedAt: Date(timeIntervalSince1970: 1),
      endedAt: Date(timeIntervalSince1970: 2),
      durationSeconds: 1,
      plannedSeconds: 60,
      outcome: .completed,
      tagName: "任务,\"A\"\n第二行"
    )]
    let data = try PomodoroExportService.data(for: archive, format: .csv)
    let csv = try #require(String(data: data, encoding: .utf8))
    #expect(csv.contains("\"任务,\"\"A\"\"\n第二行\""))
  }

  @Test func jsonIncludesSchemaAndISO8601Dates() throws {
    var archive = PomodoroArchive.fresh()
    archive.sessions = [FocusSession(
      runID: UUID(),
      startedAt: Date(timeIntervalSince1970: 0),
      endedAt: Date(timeIntervalSince1970: 60),
      durationSeconds: 60,
      plannedSeconds: 60,
      outcome: .completed
    )]
    let data = try PomodoroExportService.data(
      for: archive,
      format: .json,
      now: Date(timeIntervalSince1970: 120)
    )
    let decoded = try JSONSerialization.jsonObject(with: data)
    let object = try #require(decoded as? [String: Any])
    #expect(object["schemaVersion"] as? Int == 1)
    #expect((object["exportedAt"] as? String)?.contains("1970-01-01") == true)
    #expect((object["sessions"] as? [[String: Any]])?.count == 1)
  }
}

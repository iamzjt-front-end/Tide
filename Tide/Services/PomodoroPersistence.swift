import Foundation

@MainActor
protocol PomodoroPersisting: AnyObject {
  func load() throws -> PomodoroArchive?
  func save(_ archive: PomodoroArchive) throws
}

@MainActor
final class UserDefaultsPomodoroPersistence: PomodoroPersisting {
  private let defaults: UserDefaults
  private let key: String
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(
    defaults: UserDefaults = .standard,
    key: String = "Tide.Pomodoro.Archive.v1"
  ) {
    self.defaults = defaults
    self.key = key
    encoder = JSONEncoder()
    decoder = JSONDecoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    decoder.dateDecodingStrategy = .millisecondsSince1970
  }

  func load() throws -> PomodoroArchive? {
    guard let data = defaults.data(forKey: key) else { return nil }
    return try decoder.decode(PomodoroArchive.self, from: data)
  }

  func save(_ archive: PomodoroArchive) throws {
    defaults.set(try encoder.encode(archive), forKey: key)
  }
}

@MainActor
final class InMemoryPomodoroPersistence: PomodoroPersisting {
  var archive: PomodoroArchive?
  var loadError: Error?
  var saveError: Error?
  private(set) var saveCount = 0

  init(archive: PomodoroArchive? = nil) {
    self.archive = archive
  }

  func load() throws -> PomodoroArchive? {
    if let loadError { throw loadError }
    return archive
  }

  func save(_ archive: PomodoroArchive) throws {
    if let saveError { throw saveError }
    self.archive = archive
    saveCount += 1
  }
}

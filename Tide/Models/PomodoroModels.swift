import Foundation

enum TideAppearance: String, Codable, CaseIterable, Identifiable, Sendable {
  case system
  case light
  case dark

  var id: Self { self }

  var title: String {
    switch self {
    case .system: "跟随系统"
    case .light: "浅色"
    case .dark: "深色"
    }
  }
}

enum TimerMode: String, Codable, CaseIterable, Identifiable, Sendable {
  case pomodoro
  case stopwatch

  var id: Self { self }

  var title: String {
    switch self {
    case .pomodoro: "番茄钟"
    case .stopwatch: "正计时"
    }
  }
}

enum PomodoroPhase: String, Codable, Sendable {
  case focus
  case breakTime
  case longBreak

  var isBreak: Bool { self != .focus }

  var title: String {
    switch self {
    case .focus: "专注"
    case .breakTime: "短休息"
    case .longBreak: "长休息"
    }
  }

  var symbolName: String {
    switch self {
    case .focus: "timer"
    case .breakTime, .longBreak: "cup.and.saucer.fill"
    }
  }
}

enum TimerRunState: String, Codable, Sendable {
  case idle
  case running
  case paused

  var title: String {
    switch self {
    case .idle: "待开始"
    case .running: "进行中"
    case .paused: "已暂停"
    }
  }
}

enum SessionOutcome: String, Codable, Sendable {
  case completed
  case completedEarly

  var title: String {
    switch self {
    case .completed: "按计划完成"
    case .completedEarly: "提前完成"
    }
  }

  var isEarlyCompletion: Bool { self == .completedEarly }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    switch rawValue {
    case Self.completed.rawValue:
      self = .completed
    case Self.completedEarly.rawValue, "abandoned":
      self = .completedEarly
    default:
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unknown session outcome: \(rawValue)"
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

struct FocusTag: Identifiable, Codable, Hashable, Sendable {
  var id: UUID
  var name: String
  var colorHex: String

  init(id: UUID = UUID(), name: String, colorHex: String) {
    self.id = id
    self.name = name
    self.colorHex = colorHex
  }
}

struct PomodoroCategory: Identifiable, Codable, Hashable, Sendable {
  var id: UUID
  var name: String
  var colorHex: String

  init(id: UUID = UUID(), name: String, colorHex: String) {
    self.id = id
    self.name = name
    self.colorHex = colorHex
  }
}

struct FocusSession: Identifiable, Codable, Hashable, Sendable {
  var id: UUID
  var runID: UUID
  var startedAt: Date
  var endedAt: Date
  var durationSeconds: Int
  var plannedSeconds: Int
  var outcome: SessionOutcome
  var tagID: UUID?
  var tagName: String?
  var tagColorHex: String?
  var categoryID: UUID?
  var categoryName: String?
  var categoryColorHex: String?

  init(
    id: UUID = UUID(),
    runID: UUID,
    startedAt: Date,
    endedAt: Date,
    durationSeconds: Int,
    plannedSeconds: Int,
    outcome: SessionOutcome,
    tagID: UUID? = nil,
    tagName: String? = nil,
    tagColorHex: String? = nil,
    categoryID: UUID? = nil,
    categoryName: String? = nil,
    categoryColorHex: String? = nil
  ) {
    self.id = id
    self.runID = runID
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.durationSeconds = durationSeconds
    self.plannedSeconds = plannedSeconds
    self.outcome = outcome
    self.tagID = tagID
    self.tagName = tagName
    self.tagColorHex = tagColorHex
    self.categoryID = categoryID
    self.categoryName = categoryName
    self.categoryColorHex = categoryColorHex
  }
}

struct PomodoroRoundRecord: Identifiable, Codable, Hashable, Sendable {
  var id: UUID
  var startedAt: Date
  var endedAt: Date
  var completedSessions: Int
  var targetSessions: Int
  var outcome: SessionOutcome

  init(
    id: UUID = UUID(),
    startedAt: Date,
    endedAt: Date,
    completedSessions: Int,
    targetSessions: Int,
    outcome: SessionOutcome
  ) {
    self.id = id
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.completedSessions = completedSessions
    self.targetSessions = targetSessions
    self.outcome = outcome
  }
}

struct PomodoroConfiguration: Codable, Equatable, Sendable {
  var focusMinutes: Int = 25
  var targetSessions: Int = 4
  var breakSeconds: Int = 5 * 60
  var longBreakSeconds: Int = 15 * 60
  var notificationsEnabled: Bool = true
  var appearance: TideAppearance = .system
  var selectedTagID: UUID?
  var selectedCategoryID: UUID?

  static let focusMinutesRange = 1...120
  static let targetSessionsRange = 1...12
  static let breakMinutesRange = 1...60
  static let longBreakMinutesRange = 1...60
  static let breakSecondPresets = [300, 600, 900, 1_200, 1_800, 2_700]
  static let longBreakSecondPresets = [900, 1_200, 1_500, 1_800, 2_700, 3_600]

  private enum CodingKeys: String, CodingKey {
    case focusMinutes
    case targetSessions
    case breakSeconds
    case breakMinutes
    case longBreakSeconds
    case longBreakMinutes
    case notificationsEnabled
    case appearance
    case selectedTagID
    case selectedCategoryID
  }

  init() {}

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    focusMinutes = try values.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 25
    targetSessions = try values.decodeIfPresent(Int.self, forKey: .targetSessions) ?? 4
    if let seconds = try values.decodeIfPresent(Int.self, forKey: .breakSeconds) {
      breakSeconds = seconds
    } else {
      breakSeconds = (try values.decodeIfPresent(Int.self, forKey: .breakMinutes) ?? 5) * 60
    }
    if let seconds = try values.decodeIfPresent(Int.self, forKey: .longBreakSeconds) {
      longBreakSeconds = seconds
    } else {
      longBreakSeconds = (try values.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? 15) * 60
    }
    notificationsEnabled = try values.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
    appearance = try values.decodeIfPresent(TideAppearance.self, forKey: .appearance) ?? .system
    selectedTagID = try values.decodeIfPresent(UUID.self, forKey: .selectedTagID)
    selectedCategoryID = try values.decodeIfPresent(UUID.self, forKey: .selectedCategoryID)
  }

  func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(focusMinutes, forKey: .focusMinutes)
    try values.encode(targetSessions, forKey: .targetSessions)
    try values.encode(breakSeconds, forKey: .breakSeconds)
    try values.encode(longBreakSeconds, forKey: .longBreakSeconds)
    try values.encode(notificationsEnabled, forKey: .notificationsEnabled)
    try values.encode(appearance, forKey: .appearance)
    try values.encodeIfPresent(selectedTagID, forKey: .selectedTagID)
    try values.encodeIfPresent(selectedCategoryID, forKey: .selectedCategoryID)
  }
}

struct TimerSnapshot: Codable, Equatable, Sendable {
  var timerMode: TimerMode = .pomodoro
  var phase: PomodoroPhase = .focus
  var runState: TimerRunState = .idle
  var phaseDurationSeconds: Int = 25 * 60
  var remainingSeconds: Int = 25 * 60
  var elapsedSeconds: Int = 0
  var completedSessions: Int = 0
  var deadline: Date?
  var stopwatchAnchor: Date?
  var startedAt: Date?
  var roundStartedAt: Date?
  var activeRunID: UUID?
  var lockedTagID: UUID?
  var lockedTagName: String?
  var lockedTagColorHex: String?
  var lockedCategoryID: UUID?
  var lockedCategoryName: String?
  var lockedCategoryColorHex: String?
  var isShowingCompletion = false
  var lastUpdatedAt: Date = .now
}

struct PomodoroArchive: Codable, Equatable, Sendable {
  var schemaVersion = 1
  var configuration = PomodoroConfiguration()
  var snapshot = TimerSnapshot()
  var focusTags: [FocusTag] = []
  var categories: [PomodoroCategory] = []
  var sessions: [FocusSession] = []
  var roundRecords: [PomodoroRoundRecord] = []

  static func fresh(now: Date = .now) -> PomodoroArchive {
    var archive = PomodoroArchive()
    archive.snapshot.lastUpdatedAt = now
    return archive
  }
}

enum TidePalette {
  static let brandAccentHex = "#4DABF7"
  static let skipRestAccentHex = "#FF9F0A"
  static let defaultAccentHex = brandAccentHex

  static let colors = [
    "#FF6B6B",
    "#FFA94D",
    "#FFD43B",
    "#69DB7C",
    "#3BC9DB",
    "#4DABF7",
    "#B197FC",
    "#F783AC",
  ]
}

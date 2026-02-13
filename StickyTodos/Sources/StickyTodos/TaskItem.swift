import Foundation

struct TaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    var isInProgress: Bool
    var isDivider: Bool
    var isImportant: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        isInProgress: Bool = false,
        isDivider: Bool = false,
        isImportant: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.isInProgress = isInProgress
        self.isDivider = isDivider
        self.isImportant = isImportant
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isDone
        case isInProgress
        case isDivider
        case isImportant
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        isInProgress = try container.decodeIfPresent(Bool.self, forKey: .isInProgress) ?? false
        isDivider = try container.decodeIfPresent(Bool.self, forKey: .isDivider) ?? false
        isImportant = try container.decodeIfPresent(Bool.self, forKey: .isImportant) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(isDone, forKey: .isDone)
        try container.encode(isInProgress, forKey: .isInProgress)
        try container.encode(isDivider, forKey: .isDivider)
        try container.encode(isImportant, forKey: .isImportant)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

import Foundation

/// On-device persistence for the plan. There is no account and no server.
protocol PlanStore {
    func load() throws -> UserPlan?
    func save(_ plan: UserPlan) throws
}

struct FilePlanStore: PlanStore {
    private let fileURL: URL

    init(directory: URL) {
        fileURL = directory.appendingPathComponent("plan.json")
    }

    /// Application Support on this device. The directory is created if it is missing.
    static func applicationSupport() throws -> FilePlanStore {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent("Coastline", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return FilePlanStore(directory: directory)
    }

    func load() throws -> UserPlan? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder().decode(UserPlan.self, from: data)
    }

    func save(_ plan: UserPlan) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder().encode(plan)
        try data.write(to: fileURL, options: .atomic)
    }

    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// In-memory stand-in used when Application Support cannot be created, and in tests.
final class MemoryPlanStore: PlanStore {
    private var stored: UserPlan?

    func load() throws -> UserPlan? {
        stored
    }

    func save(_ plan: UserPlan) throws {
        stored = plan
    }
}

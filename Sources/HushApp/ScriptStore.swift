import Foundation

/// A teleprompter script. M1 persists to a JSON file in Application Support;
/// a SwiftData-backed library with sections/markers can replace this later.
struct Script: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var body: String
    var updatedAt: Date = Date()

    var wordCount: Int {
        body.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).count
    }
    /// Estimated read time in seconds at ~150 wpm.
    var estReadSeconds: Int { Int(Double(wordCount) / 150.0 * 60.0) }
}

@MainActor
final class ScriptStore: ObservableObject {
    @Published var scripts: [Script] = []

    private let url: URL

    init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Hush", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("scripts.json")
        load()
        if scripts.isEmpty {
            scripts = [Script(title: "Welcome to Hush", body: HushApp.sampleScript)]
            save()
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Script].self, from: data) else { return }
        scripts = decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(scripts) { try? data.write(to: url) }
    }

    @discardableResult
    func add() -> Script {
        let script = Script(title: "Untitled", body: "")
        scripts.insert(script, at: 0)
        save()
        return script
    }

    func update(_ script: Script) {
        guard let i = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        scripts[i] = script
        scripts[i].updatedAt = Date()
        save()
    }

    func delete(_ script: Script) {
        scripts.removeAll { $0.id == script.id }
        save()
    }
}

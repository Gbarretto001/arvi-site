import Foundation

struct SavedLecture: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let date: Date
    var name: String { url.deletingPathExtension().lastPathComponent }
}

/// Gerencia os arquivos .docx salvos na pasta Documents do app — que fica
/// visível no app Arquivos (em "No meu iPad › Gravador de Aulas").
@MainActor
final class RecordingsStore: ObservableObject {

    @Published var lectures: [SavedLecture] = []

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func refresh() {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        lectures = items
            .filter { $0.pathExtension.lowercased() == "docx" }
            .map { url in
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
                return SavedLecture(url: url, date: date)
            }
            .sorted { $0.date > $1.date }
    }

    @discardableResult
    func save(title: String, transcript: String) throws -> URL {
        let data = DocxExporter.makeDocx(title: title, body: transcript)
        let base = documentsURL.appendingPathComponent("\(sanitize(title)).docx")
        let url = uniqueURL(for: base)
        try data.write(to: url, options: .atomic)
        refresh()
        return url
    }

    func delete(_ lecture: SavedLecture) {
        try? FileManager.default.removeItem(at: lecture.url)
        refresh()
    }

    // MARK: - Helpers

    private func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = name
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Aula" : cleaned
    }

    private func uniqueURL(for url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }
        let dir = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var index = 2
        while true {
            let candidate = dir.appendingPathComponent("\(base) (\(index)).\(ext)")
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }
}

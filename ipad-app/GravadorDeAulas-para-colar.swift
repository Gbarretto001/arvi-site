// ============================================================================
//  Gravador de Aulas — arquivo único para colar no Swift Playgrounds
//
//  COMO USAR (no iPad):
//  1. Abra o Swift Playgrounds e crie um app novo (+ → App).
//  2. Abra o arquivo de código, selecione TODO o conteúdo e apague.
//  3. Cole TODO este arquivo no lugar.
//  4. Nas Configurações do App (ícone ⚙︎/•••), adicione as capacidades:
//     - Microfone (Microphone)
//     - Reconhecimento de Fala (Speech Recognition)
//     Escreva uma justificativa em cada uma (ex.: "Gravar e transcrever aulas").
//  5. Toque em ▶ para rodar.
// ============================================================================

import SwiftUI
import Foundation
import AVFoundation
import Speech

// MARK: - Ponto de entrada do app

@main
struct GravadorDeAulasApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Interface

struct ContentView: View {
    @StateObject private var recorder = LectureRecorder()
    @StateObject private var store = RecordingsStore()

    @State private var lectureTitle: String = ""
    @State private var feedback: String?
    @State private var lastSavedURL: URL?

    var body: some View {
        NavigationSplitView {
            SavedLecturesList(store: store)
                .navigationTitle("Aulas")
        } detail: {
            recorderView
                .navigationTitle("Gravar aula")
                .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { store.refresh() }
    }

    private var recorderView: some View {
        VStack(spacing: 20) {
            statusHeader
            recordButton
            titleField
            transcriptEditor
            actionBar
            if let feedback {
                Text(feedback)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity)
    }

    private var statusHeader: some View {
        VStack(spacing: 6) {
            Text(recorder.status)
                .font(.headline)
                .foregroundStyle(recorder.isRecording ? .red : .secondary)
            if let error = recorder.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var recordButton: some View {
        Button(action: recorder.toggle) {
            ZStack {
                Circle()
                    .fill(recorder.isRecording ? Color.red : Color.accentColor)
                    .frame(width: 130, height: 130)
                    .shadow(radius: 8)
                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recorder.isRecording ? "Parar gravação" : "Iniciar gravação")
    }

    private var titleField: some View {
        TextField("Título da aula (opcional)", text: $lectureTitle)
            .textFieldStyle(.roundedBorder)
            .disabled(recorder.isRecording)
    }

    private var transcriptEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Transcrição em tempo real")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            TextEditor(text: $recorder.transcript)
                .font(.body)
                .frame(minHeight: 220)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.3))
                )
        }
    }

    private var actionBar: some View {
        HStack(spacing: 16) {
            Button(role: .destructive) {
                recorder.reset()
                feedback = nil
            } label: {
                Label("Nova aula", systemImage: "trash")
            }
            .disabled(recorder.isRecording || recorder.transcript.isEmpty)

            Spacer()

            if let lastSavedURL {
                ShareLink(item: lastSavedURL) {
                    Label("Compartilhar", systemImage: "square.and.arrow.up")
                }
            }

            Button(action: save) {
                Label("Salvar em Word (.docx)", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(recorder.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func save() {
        let title = lectureTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = title.isEmpty ? defaultTitle() : title
        do {
            let url = try store.save(title: finalTitle, transcript: recorder.transcript)
            lastSavedURL = url
            feedback = "Salvo em Arquivos › No meu iPad › Gravador de Aulas › \(url.lastPathComponent)"
        } catch {
            feedback = "Erro ao salvar: \(error.localizedDescription)"
        }
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "yyyy-MM-dd HH-mm"
        return "Aula \(formatter.string(from: Date()))"
    }
}

private struct SavedLecturesList: View {
    @ObservedObject var store: RecordingsStore

    var body: some View {
        Group {
            if store.lectures.isEmpty {
                ContentUnavailableView(
                    "Nenhuma aula salva",
                    systemImage: "doc.text",
                    description: Text("As aulas salvas em .docx aparecem aqui e no app Arquivos.")
                )
            } else {
                List {
                    ForEach(store.lectures) { lecture in
                        row(for: lecture)
                    }
                    .onDelete { indexSet in
                        indexSet.map { store.lectures[$0] }.forEach(store.delete)
                    }
                }
            }
        }
        .toolbar {
            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
    }

    private func row(for lecture: SavedLecture) -> some View {
        HStack {
            Image(systemName: "doc.richtext")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(lecture.name)
                    .font(.body)
                    .lineLimit(1)
                Text(lecture.date, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ShareLink(item: lecture.url) {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }
}

// MARK: - Gravação de áudio + transcrição em tempo real

@MainActor
final class LectureRecorder: ObservableObject {

    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var status: String = "Pronto para gravar"
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?
    private var finalizedText: String = ""

    init(localeIdentifier: String = "pt-BR") {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
    }

    func toggle() {
        if isRecording { stop() } else { start() }
    }

    func start() {
        errorMessage = nil
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Reconhecimento de voz indisponível para pt-BR neste dispositivo."
            return
        }
        Task {
            guard await requestPermissions() else {
                errorMessage = "Permissão de microfone ou de reconhecimento de voz negada. Ajuste em Ajustes › Privacidade."
                return
            }
            do {
                try startEngine()
                startRecognition()
            } catch {
                errorMessage = "Não foi possível iniciar a gravação: \(error.localizedDescription)"
                stop()
            }
        }
    }

    func stop() {
        isRecording = false
        status = "Gravação parada"
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        recognitionTask?.cancel()
        request = nil
        recognitionTask = nil
        finalizedText = transcript
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func reset() {
        guard !isRecording else { return }
        transcript = ""
        finalizedText = ""
        status = "Pronto para gravar"
        errorMessage = nil
    }

    private func requestPermissions() async -> Bool {
        let speechAuthorized: Bool = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                continuation.resume(returning: authStatus == .authorized)
            }
        }
        let micAuthorized: Bool = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        return speechAuthorized && micAuthorized
    }

    private func startEngine() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true
        status = "Gravando…"
    }

    private func startRecognition() {
        guard let recognizer else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                self.handle(result: result, error: error)
            }
        }
    }

    private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            transcript = combined(with: result.bestTranscription.formattedString)
            if result.isFinal {
                finalizedText = transcript
                cycleRecognition()
                return
            }
        }
        if error != nil {
            finalizedText = transcript
            if isRecording {
                cycleRecognition()
            }
        }
    }

    private func combined(with partial: String) -> String {
        if finalizedText.isEmpty { return partial }
        if partial.isEmpty { return finalizedText }
        return finalizedText + " " + partial
    }

    private func cycleRecognition() {
        request?.endAudio()
        request = nil
        recognitionTask = nil
        guard isRecording else { return }
        startRecognition()
    }
}

// MARK: - Armazenamento dos arquivos .docx

struct SavedLecture: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let date: Date
    var name: String { url.deletingPathExtension().lastPathComponent }
}

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

// MARK: - Geração do documento Word (.docx)

enum DocxExporter {

    static func makeDocx(title: String, body: String) -> Data {
        let entries: [ZipArchive.Entry] = [
            .init(path: "[Content_Types].xml", data: Data(contentTypesXML.utf8)),
            .init(path: "_rels/.rels", data: Data(relsXML.utf8)),
            .init(path: "word/document.xml", data: Data(documentXML(title: title, body: body).utf8))
        ]
        return ZipArchive.create(entries: entries)
    }

    private static let contentTypesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
    </Types>
    """

    private static let relsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    </Relationships>
    """

    private static func documentXML(title: String, body: String) -> String {
        var paragraphs = titleParagraph(title)

        let lines = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            paragraphs += bodyParagraph("(Sem transcrição.)")
        } else {
            for line in lines {
                paragraphs += bodyParagraph(line)
            }
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
        \(paragraphs)
            <w:sectPr>
              <w:pgSz w:w="11906" w:h="16838"/>
              <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
            </w:sectPr>
          </w:body>
        </w:document>
        """
    }

    private static func titleParagraph(_ text: String) -> String {
        """
            <w:p>
              <w:pPr><w:spacing w:after="240"/></w:pPr>
              <w:r>
                <w:rPr><w:b/><w:sz w:val="36"/></w:rPr>
                <w:t xml:space="preserve">\(escape(text))</w:t>
              </w:r>
            </w:p>
        """
    }

    private static func bodyParagraph(_ text: String) -> String {
        """
            <w:p>
              <w:pPr><w:spacing w:after="120"/></w:pPr>
              <w:r>
                <w:rPr><w:sz w:val="24"/></w:rPr>
                <w:t xml:space="preserve">\(escape(text))</w:t>
              </w:r>
            </w:p>
        """
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - Escritor de ZIP (contêiner do .docx), em Swift puro

enum ZipArchive {

    struct Entry {
        let path: String
        let data: Data
    }

    static func create(entries: [Entry]) -> Data {
        var output = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0

        for entry in entries {
            let nameData = Data(entry.path.utf8)
            let crc = crc32(entry.data)
            let size = UInt32(entry.data.count)
            let localHeaderOffset = offset

            var local = Data()
            local.appendLE(UInt32(0x04034b50))
            local.appendLE(UInt16(20))
            local.appendLE(UInt16(0))
            local.appendLE(UInt16(0))
            local.appendLE(UInt16(0))
            local.appendLE(UInt16(0x21))
            local.appendLE(crc)
            local.appendLE(size)
            local.appendLE(size)
            local.appendLE(UInt16(nameData.count))
            local.appendLE(UInt16(0))
            local.append(nameData)
            local.append(entry.data)

            output.append(local)
            offset += UInt32(local.count)

            centralDirectory.appendLE(UInt32(0x02014b50))
            centralDirectory.appendLE(UInt16(20))
            centralDirectory.appendLE(UInt16(20))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0x21))
            centralDirectory.appendLE(crc)
            centralDirectory.appendLE(size)
            centralDirectory.appendLE(size)
            centralDirectory.appendLE(UInt16(nameData.count))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt32(0))
            centralDirectory.appendLE(localHeaderOffset)
            centralDirectory.append(nameData)
        }

        let centralOffset = offset
        let centralSize = UInt32(centralDirectory.count)
        output.append(centralDirectory)

        var end = Data()
        end.appendLE(UInt32(0x06054b50))
        end.appendLE(UInt16(0))
        end.appendLE(UInt16(0))
        end.appendLE(UInt16(entries.count))
        end.appendLE(UInt16(entries.count))
        end.appendLE(centralSize)
        end.appendLE(centralOffset)
        end.appendLE(UInt16(0))
        output.append(end)

        return output
    }

    private static let crcTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) == 1 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = crcTable[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendLE(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}

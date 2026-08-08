import SwiftUI

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

    // MARK: - Tela principal de gravação

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

    // MARK: - Ações

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

// MARK: - Lista lateral de aulas salvas

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

#Preview {
    ContentView()
}

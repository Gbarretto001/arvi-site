import Foundation
import AVFoundation
import Speech

/// Grava o áudio do microfone e faz a transcrição em tempo real usando o
/// framework Speech da Apple (funciona no dispositivo, sem enviar áudio para
/// servidores quando o reconhecimento on-device está disponível).
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

    /// Texto já consolidado (resultados finais das sessões anteriores de
    /// reconhecimento). O trecho parcial em andamento é acrescentado a ele.
    private var finalizedText: String = ""

    init(localeIdentifier: String = "pt-BR") {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
    }

    // MARK: - Controle público

    func toggle() {
        if isRecording {
            stop()
        } else {
            start()
        }
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

    /// Limpa o texto atual para começar uma nova aula.
    func reset() {
        guard !isRecording else { return }
        transcript = ""
        finalizedText = ""
        status = "Pronto para gravar"
        errorMessage = nil
    }

    // MARK: - Permissões

    private func requestPermissions() async -> Bool {
        let speechAuthorized: Bool = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                continuation.resume(returning: authStatus == .authorized)
            }
        }

        let micAuthorized: Bool = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        return speechAuthorized && micAuthorized
    }

    // MARK: - Áudio + reconhecimento

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
            // A sessão de reconhecimento chegou ao fim (ex.: limite de tempo ou
            // pausa longa). Se ainda estamos gravando, reinicia uma nova sessão
            // sem interromper o áudio, para transcrever aulas longas.
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
